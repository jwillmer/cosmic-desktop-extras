#!/usr/bin/env bash
# Tests for lib/patchset.sh against a local "upstream" repo in a temp dir: no network, no dpkg
# (every apply/check/dev gets its commit explicitly), no real cache (XDG_CACHE_HOME is temp).
#
#   lib/test_patchset.sh    prints ok / not ok per case, exit 1 if any failed
set -uo pipefail
PS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patchset.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$ROOT/gitconfig"
git config --file "$GIT_CONFIG_GLOBAL" user.name test
git config --file "$GIT_CONFIG_GLOBAL" user.email test@localhost
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
git config --file "$GIT_CONFIG_GLOBAL" advice.detachedHead false

fail() { echo "FAIL: $*" >&2; exit 1; }
ps() { "$PS" "$H" "$@"; }
line() { sed -n "${2}p" "$1"; }
commit_all() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }

# Fresh world per case in $T:
#   up.git  upstream: C1 (a.txt lines 1..10), C2 (C1 + line 5 changed, inside the diff context of our line 2), C3 (C1 + line 2 changed)
#   helper  patchset.conf + patches/, $SRC cache clone, $DEV dev worktree
setup() {
  T="$ROOT/$1"; mkdir -p "$T/helper"
  export XDG_CACHE_HOME="$T/cache" TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
  H="$T/helper"; SRC="$XDG_CACHE_HOME/app/up"; DEV="$XDG_CACHE_HOME/app/dev"
  printf 'UPSTREAM=file://%s\nPACKAGE=no-such-package\nNAME=app\n' "$T/up.git" > "$H/patchset.conf"
  git init -q --bare "$T/up.git"; git -C "$T/up.git" config uploadpack.allowFilter true
  local w="$T/work"; git clone -q "$T/up.git" "$w" 2>/dev/null
  seq 1 10 > "$w/a.txt"; commit_all "$w" C1; C1="$(git -C "$w" rev-parse HEAD)"
  sed -i 's/^5$/five upstream/' "$w/a.txt"; commit_all "$w" C2; C2="$(git -C "$w" rev-parse HEAD)"
  git -C "$w" checkout -q -b conflict "$C1"
  sed -i 's/^2$/two upstream/' "$w/a.txt"; commit_all "$w" C3; C3="$(git -C "$w" rev-parse HEAD)"
  git -C "$w" push -q origin main conflict 2>/dev/null
}

# Our series on C1: patch 1 changes line 2 of a.txt, patch 2 adds new.txt. Leaves $DEV in place.
make_series() {
  ps dev "$C1" >/dev/null
  sed -i 's/^2$/two ours/' "$DEV/a.txt"; commit_all "$DEV" "ours: line 2"
  echo new > "$DEV/new.txt"; commit_all "$DEV" "ours: new file"
  ps export >/dev/null
}
drop_dev() { git -C "$SRC" worktree remove --force "$DEV"; }
assert_patched() {   # assert_patched <tree> <base>
  [[ "$(git -C "$1" rev-list --count "$2..HEAD")" == 2 ]] || fail "not 2 commits on $2 in $1"
  [[ "$(line "$1/a.txt" 2)" == "two ours" ]] || fail "line 2 not patched in $1"
  [[ -f "$1/new.txt" ]] || fail "new.txt missing in $1"
}
assert_clean() { [[ -z "$(git -C "$1" status --porcelain --ignored)" ]] || fail "$1 not clean"; }
assert_no_am() { [[ ! -d "$(git -C "$1" rev-parse --git-path rebase-apply)" ]] || fail "git am in progress in $1"; }

t_export_writes_series() {
  make_series
  [[ "$(ls "$H/patches"/*.patch | wc -l)" == 2 ]] || fail "expected 2 patches"
  [[ "$(cat "$H/patches/BASE")" == "$C1" ]] || fail "BASE is not C1"
}

t_dev_export_round_trip() {
  make_series; drop_dev
  cp -r "$H/patches" "$T/before"
  ps dev "$C1" >/dev/null
  ps export >/dev/null
  diff -r "$T/before" "$H/patches" || fail "export changed the patches"
}

t_apply_builds_tree() {
  make_series; drop_dev
  ps apply "$C1"
  assert_patched "$SRC" "$C1"
  assert_clean "$SRC"
}

t_apply_twice_idempotent() {
  make_series; drop_dev
  ps apply "$C1"
  echo junk > "$SRC/stray.txt"; echo edit >> "$SRC/a.txt"
  ps apply "$C1"
  assert_patched "$SRC" "$C1"
  assert_clean "$SRC"
  [[ "$(git -C "$SRC" rev-parse HEAD^^)" == "$C1" ]] || fail "second apply not on C1"
}

t_check_ok_and_conflict() {
  make_series; drop_dev
  local refs; refs="$(git -C "$SRC" for-each-ref refs/heads)"
  ps check "$C1" || fail "check C1 should pass"
  if ps check "$C3"; then fail "check C3 should fail"; fi
  [[ "$(git -C "$SRC" worktree list | wc -l)" == 1 ]] || fail "worktree left behind"
  [[ "$(git -C "$SRC" for-each-ref refs/heads)" == "$refs" ]] || fail "branch left behind"
  [[ -z "$(ls -A "$TMPDIR")" ]] || fail "temp dir left behind"
}

t_apply_three_way() {
  make_series; drop_dev
  ps apply "$C2"
  assert_patched "$SRC" "$C2"
  [[ "$(line "$SRC/a.txt" 5)" == "five upstream" ]] || fail "upstream line 5 lost"
}

t_rebase_then_export() {
  make_series
  ps rebase "$C2" >/dev/null
  ps export >/dev/null
  [[ "$(cat "$H/patches/BASE")" == "$C2" ]] || fail "BASE is not C2"
  [[ "$(ls "$H/patches"/*.patch | wc -l)" == 2 ]] || fail "expected 2 patches"
  drop_dev
  ps check "$C2" || fail "rebased series does not apply to C2"
}

t_failed_apply_hint() {
  make_series; drop_dev
  if ps apply "$C3" 2> "$T/err"; then fail "apply C3 should fail"; fi
  grep -qF "dev $C3" "$T/err" || fail "no dev hint: $(cat "$T/err")"
  assert_no_am "$SRC"
  assert_clean "$SRC"
}

t_apply_refuses_older_than_base() {
  make_series
  ps rebase "$C2" >/dev/null
  ps export >/dev/null
  drop_dev
  if ps apply "$C1" 2> "$T/err"; then fail "apply C1 should fail: BASE is C2"; fi
  grep -qF "older than the COSMIC release these patches need ($C2)" "$T/err" || fail "no update hint: $(cat "$T/err")"
  grep -qF "sudo apt full-upgrade" "$T/err" || fail "no update command: $(cat "$T/err")"
  ps apply "$C2" || fail "apply C2 should pass"
  assert_patched "$SRC" "$C2"
}

# taskbar/check.sh --print: dpkg-query is a stub on PATH that reports $INSTALLED, the cache
# clone is made from the local upstream beforehand (so check.sh never clones from GitHub), and
# C4 on upstream master changes the applet folder. The real series does not apply to the fake
# upstream, so step 1 always says "do NOT apply".
setup_check_sh() {
  local w="$T/work"
  git -C "$w" checkout -q main
  mkdir -p "$w/cosmic-applet-minimize"; echo x > "$w/cosmic-applet-minimize/x"
  commit_all "$w" "applet: upstream change"; C4="$(git -C "$w" rev-parse HEAD)"
  git -C "$w" push -q origin main:master 2>/dev/null   # cosmic-applets uses master
  git clone -q "$T/up.git" "$XDG_CACHE_HOME/minimize-ws/cosmic-applets"
  mkdir -p "$T/bin" "$T/state/minimize-ws"
  printf '#!/bin/sh\necho "1.0~$INSTALLED"\n' > "$T/bin/dpkg-query"; chmod +x "$T/bin/dpkg-query"
  printf '#!/bin/sh\necho "$*" >> "%s/journal-args"\ncat "%s/journal" 2>/dev/null\n' "$T" "$T" > "$T/bin/journalctl"
  printf '#!/bin/sh\necho "$*" >> "%s/notified"\n' "$T" > "$T/bin/gdbus"
  chmod +x "$T/bin/journalctl" "$T/bin/gdbus"
  export PATH="$T/bin:$PATH" XDG_STATE_HOME="$T/state"
  CHECK="$(dirname "$PS")/../taskbar/check.sh"
}

t_check_sh_update_and_upstream_change() {
  setup_check_sh
  echo "$C1" > "$T/state/minimize-ws/built-commit"
  INSTALLED="$C2" "$CHECK" --print > "$T/out"
  grep -qF "cosmic-applets was updated ($C1 -> $C2)" "$T/out" || fail "no update notice: $(cat "$T/out")"
  grep -qF "do NOT apply" "$T/out" || fail "no apply verdict: $(cat "$T/out")"
  grep -qF "1 commit(s) since $C1" "$T/out" || fail "no upstream notice: $(cat "$T/out")"
  [[ ! -e "$T/state/minimize-ws/seen-upstream" ]] || fail "--print wrote seen-upstream"
}

t_check_sh_quiet_when_current() {
  setup_check_sh
  echo "$C4" > "$T/state/minimize-ws/built-commit"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  [[ ! -s "$T/out" ]] || fail "expected no output: $(cat "$T/out")"
}

t_check_sh_applet_errors() {
  setup_check_sh
  echo "$C4" > "$T/state/minimize-ws/built-commit"
  cat > "$T/journal" <<'J'
com.system76.CosmicAppList: thread 'main' (1) panicked at src/app.rs:10:5:
com.system76.CosmicAppletMinimize: Protocol error 1 on object ext_image_copy_capture_session_v1@8
com.system76.CosmicAppletMinimize: Protocol error 1 on object ext_image_copy_capture_session_v1@9
com.system76.CosmicPanelAppButton: thread 'main' (2) panicked at lib.rs:94:39:
cosmic-panel: unrelated line
J
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  grep -qF "1 panic(s), 2 protocol error line(s)" "$T/out" || fail "wrong counts: $(cat "$T/out")"
  grep -qF "CosmicAppList: thread 'main' (1) panicked" "$T/out" || fail "no first line: $(cat "$T/out")"
  [[ ! -e "$T/state/minimize-ws/errors-since" ]] || fail "--print wrote errors-since"
  INSTALLED="$C4" "$CHECK"
  grep -qF "1 panic(s)" "$T/notified" || fail "no notification sent"
  [[ -s "$T/state/minimize-ws/errors-since" ]] || fail "errors-since not written"
  since="$(cat "$T/state/minimize-ws/errors-since")"
  : > "$T/journal-args"
  INSTALLED="$C4" "$CHECK" --print > /dev/null
  grep -qF -- "--since @$since " "$T/journal-args" || fail "next check does not start at the last one: $(cat "$T/journal-args")"
}

t_check_sh_ignores_other_applets() {
  setup_check_sh
  echo "$C4" > "$T/state/minimize-ws/built-commit"
  echo "com.system76.CosmicPanelAppButton: thread 'main' (2) panicked at lib.rs:94:39:" > "$T/journal"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  [[ ! -s "$T/out" ]] || fail "expected no output: $(cat "$T/out")"
}

t_check_sh_files_tabs_update() {
  setup_check_sh
  echo "$C4" > "$T/state/minimize-ws/built-commit"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  [[ ! -s "$T/out" ]] || fail "expected no output before files-tabs is built: $(cat "$T/out")"
  git clone -q "$T/up.git" "$XDG_CACHE_HOME/files-tabs/cosmic-files"
  mkdir -p "$T/state/files-tabs"; echo "$C1" > "$T/state/files-tabs/built-commit"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  grep -qF "cosmic-files was updated ($C1 -> $C4)" "$T/out" || fail "no files-tabs notice: $(cat "$T/out")"
  grep -qF "do NOT apply" "$T/out" || fail "no apply verdict: $(cat "$T/out")"
  echo "$C4" > "$T/state/files-tabs/built-commit"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  [[ ! -s "$T/out" ]] || fail "expected no output when files-tabs is current: $(cat "$T/out")"
}

t_check_sh_text_editor_update() {
  setup_check_sh
  echo "$C4" > "$T/state/minimize-ws/built-commit"
  git clone -q "$T/up.git" "$XDG_CACHE_HOME/edit-md/cosmic-edit"
  mkdir -p "$T/state/edit-md"; echo "$C1" > "$T/state/edit-md/built-commit"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  grep -qF "cosmic-edit was updated ($C1 -> $C4)" "$T/out" || fail "no text-editor notice: $(cat "$T/out")"
  grep -qF "do NOT apply" "$T/out" || fail "no apply verdict: $(cat "$T/out")"
  echo "$C4" > "$T/state/edit-md/built-commit"
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  [[ ! -s "$T/out" ]] || fail "expected no output when text-editor is current: $(cat "$T/out")"
}

t_check_sh_offline_goes_on() {
  setup_check_sh
  echo "$C1" > "$T/state/minimize-ws/built-commit"
  mv "$T/up.git" "$T/up.gone"   # upstream unreachable
  INSTALLED="$C2" "$CHECK" --print > "$T/out" 2> "$T/err" || fail "check.sh failed offline: $(cat "$T/err")"
  grep -qF "cosmic-applets was updated ($C1 -> $C2)" "$T/out" || fail "no update notice: $(cat "$T/out")"
  grep -qF "Could not check whether the patches still apply (offline)" "$T/out" || fail "no offline note: $(cat "$T/out")"
  grep -qF "could not fetch cosmic-applets" "$T/err" || fail "fetch failure not logged: $(cat "$T/err")"
}

t_check_sh_quiet_without_taskbar() {
  setup_check_sh
  INSTALLED="$C4" "$CHECK" --print > "$T/out"
  [[ ! -s "$T/out" ]] || fail "expected no output when the taskbar is not built: $(cat "$T/out")"
  [[ ! -e "$T/state/minimize-ws/errors-since" ]] || fail "taskbar checks ran without the taskbar"
}

failed=0
for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  name="${t#t_}"
  ( set -e; setup "$name"; "$t" ) > "$ROOT/$name.log" 2>&1
  if [[ $? -eq 0 ]]; then echo "ok - $name"
  else echo "not ok - $name"; sed 's/^/#   /' "$ROOT/$name.log"; failed=1; fi
done
exit "$failed"
