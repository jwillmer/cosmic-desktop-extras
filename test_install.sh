#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2317  # stub bodies expand when they run; tests are called by name
# Tests for install.sh with a fake HOME and stubs on PATH: systemctl, loginctl, pgrep, dpkg-query,
# git, cargo, sudo, apt, curl. Nothing touches the real home, session, panel or network: the stub
# git "clones" by making an empty folder, the stub cargo "builds" by writing a dummy binary.
#
#   ./test_install.sh    prints ok / not ok per case, exit 1 if any failed
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

setup() {
  T="$ROOT/$1"; mkdir -p "$T/home" "$T/bin" "$T/apps"
  export HOME="$T/home" INSTALL_NO_TTY=1 XDG_CURRENT_DESKTOP=COSMIC
  unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME
  # Only system dirs after the stubs: a real ~/.cargo/bin on PATH must not be found.
  export PATH="$T/bin:/usr/local/bin:/usr/bin:/bin"
  export SYSTEM_APPLICATIONS="$T/apps" COSMIC_SYSTEM_CONFIG="$T/syscfg"
  for id in CosmicAppletMinimize CosmicAppList CosmicAppletStatusArea CosmicTerm CosmicFiles CosmicEdit; do
    printf '[Desktop Entry]\nName=%s\nExec=%s\nX-OverflowMinSize=1\n' "$id" \
      "$(case $id in CosmicTerm) echo cosmic-term ;; CosmicFiles) echo cosmic-files %U ;; CosmicEdit) echo cosmic-edit %F ;; *) echo "cosmic-$id" ;; esac)" \
      > "$T/apps/com.system76.$id.desktop"
  done
  # Stock panel config: only the Panel is active; the taskbar applet is on it, the tray is not.
  mkdir -p "$T/syscfg/com.system76.CosmicPanel/v1" "$T/syscfg/com.system76.CosmicPanel.Panel/v1"
  echo '["Panel"]' > "$T/syscfg/com.system76.CosmicPanel/v1/entries"
  echo 'Some((["com.system76.CosmicAppList", "com.system76.CosmicAppletMinimize"], ["com.system76.CosmicAppletTime"]))' \
    > "$T/syscfg/com.system76.CosmicPanel.Panel/v1/plugins_wings"

  stub() { printf '#!/bin/sh\n%s\n' "$2" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
  stub systemctl "echo \"\$*\" >> '$T/systemctl.log'; case \"\$*\" in *is-active*) exit 1 ;; esac; exit 0"
  stub loginctl "echo \"\$*\" >> '$T/loginctl.log'"
  stub pgrep 'exit 1'
  stub sleep 'exit 0'
  stub dpkg-query 'case "$*" in *Status*) echo "install ok installed" ;; *) echo "1.11.0~1793636322~24.04~6f89bfa" ;; esac'
  # clone: make the target with an empty .git; every other git command succeeds without doing anything.
  stub git 'if [ "$1" = clone ]; then for a; do d="$a"; done; mkdir -p "$d/.git"; fi; exit 0'
  # cargo build [-p crate | --bin name] in the source dir: write target/release/<crate or dir name>.
  stub cargo 'n=$(basename "$PWD"); while [ $# -gt 0 ]; do case "$1" in -p|--bin) n="$2"; shift ;; esac; shift; done
mkdir -p target/release; printf "#!/bin/sh\n" > "target/release/$n"; chmod +x "target/release/$n"'
  for c in sudo apt apt-get curl gh; do stub "$c" "echo \"$c \$*\" >> '$T/forbidden.log'; exit 1"; done
}

inst() { "$REPO/install.sh" "$@" > "$T/out" 2>&1 || fail "install.sh $* failed: $(cat "$T/out")"; }
assert_link() { [[ "$(readlink "$1")" == "$2" ]] || fail "$1 -> $(readlink "$1"), expected $2"; }
assert_gone() { local f; for f; do [[ ! -e "$f" && ! -L "$f" ]] || fail "$f still there"; done; }
assert_none_forbidden() { [[ ! -e "$T/forbidden.log" ]] || fail "called: $(cat "$T/forbidden.log")"; }

t_install_all_then_uninstall_all() {
  # Another user shortcut that must survive the show-desktop uninstall.
  local sc="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
  mkdir -p "$(dirname "$sc")"
  printf '{\n    (\n        modifiers: [\n            Ctrl,\n        ],\n        key: "e",\n    ): Spawn("editor"),\n}\n' > "$sc"
  inst all
  local b="$HOME/.local/bin" a="$HOME/.local/share/applications" u="$HOME/.config/systemd/user"
  for f in cosmic-applet-minimize-ws cosmic-app-list-ws cosmic-term-tabs cosmic-files-tabs \
           cosmic-applet-status-area-color cosmic-edit-md ws-keeper show-desktop; do
    [[ -x "$b/$f" ]] || fail "$b/$f not installed"
  done
  grep -qx "Exec=$b/cosmic-applet-minimize-ws" "$a/com.system76.CosmicAppletMinimize.desktop" || fail "taskbar desktop entry"
  grep -qx "X-OverflowMinSize=4" "$a/com.system76.CosmicAppletMinimize.desktop" || fail "taskbar overflow override"
  grep -qx "Exec=$b/cosmic-term-tabs" "$a/com.system76.CosmicTerm.desktop" || fail "terminal desktop entry"
  grep -qx "Exec=$b/cosmic-applet-status-area-color" "$a/com.system76.CosmicAppletStatusArea.desktop" || fail "tray desktop entry"
  grep -qx "Exec=$b/cosmic-edit-md %F" "$a/com.system76.CosmicEdit.desktop" || fail "text editor desktop entry"
  assert_link "$b/cosmic-term" "$b/cosmic-term-tabs"
  assert_link "$b/cosmic-files" "$b/cosmic-files-tabs"
  assert_link "$HOME/.local/lib/ws-keeper" "$REPO/ws-keeper"
  assert_link "$HOME/.local/lib/show-desktop" "$REPO/show-desktop"
  assert_link "$HOME/.local/lib/minimize-ws" "$REPO/taskbar"
  for f in ws-keeper-restore.service ws-keeper-watch.service minimize-ws-check.service minimize-ws-check.timer; do
    [[ -f "$u/$f" ]] || fail "unit $f not installed"
  done
  grep -qx "6f89bfa" "$HOME/.local/state/minimize-ws/built-commit" || fail "taskbar built-commit"
  grep -q "enable --now minimize-ws-check.timer" "$T/systemctl.log" || fail "check timer not enabled"
  grep -q "enable ws-keeper-restore.service ws-keeper-watch.service" "$T/systemctl.log" || fail "ws-keeper not enabled"
  [[ "$(grep -c 'show-desktop' "$sc")" == 1 ]] || fail "shortcut: $(cat "$sc")"
  grep -qF '(cosmic-desktop-extras)' "$sc" || fail "shortcut description"
  grep -qF 'Spawn("editor")' "$sc" || fail "other shortcut lost"
  grep -qF 'replaced the "Minimized Windows" applet on your Panel' "$T/out" || fail "no panel note: $(cat "$T/out")"
  grep -qF 'add the "Notifications Tray" applet' "$T/out" || fail "no tray hint: $(cat "$T/out")"
  # The wrappers' scripts find lib/wsk.py through the linked folders.
  python3 -I -c 'import importlib.util, sys
for p in sys.argv[1:]:
    s = importlib.util.spec_from_file_location("m", p); s.loader.exec_module(importlib.util.module_from_spec(s))' \
    "$HOME/.local/lib/ws-keeper/ws-keeper.py" "$HOME/.local/lib/show-desktop/show-desktop.py" || fail "wsk import via the links"
  find "$REPO" -name __pycache__ -prune -exec rm -rf {} +
  assert_none_forbidden

  "$REPO/install.sh" --list > "$T/list"
  [[ "$(grep -c ' yes ' "$T/list")" == 7 ]] || fail "--list: $(cat "$T/list")"

  inst all   # again: idempotent
  [[ "$(grep -c 'show-desktop' "$sc")" == 1 ]] || fail "shortcut added twice: $(cat "$sc")"

  mkdir -p "$HOME/.local/state/ws-keeper" "$HOME/.config/minimize-ws"
  touch "$HOME/.local/state/ws-keeper/snap.json" "$HOME/.config/minimize-ws/ignore"
  inst --uninstall all
  assert_gone "$b/cosmic-applet-minimize-ws" "$b/cosmic-app-list-ws" "$b/cosmic-term-tabs" "$b/cosmic-files-tabs" \
    "$b/cosmic-applet-status-area-color" "$b/cosmic-edit-md" "$b/ws-keeper" "$b/show-desktop" "$b/cosmic-term" "$b/cosmic-files" \
    "$a/com.system76.CosmicAppletMinimize.desktop" "$a/com.system76.CosmicAppList.desktop" \
    "$a/com.system76.CosmicTerm.desktop" "$a/com.system76.CosmicFiles.desktop" "$a/com.system76.CosmicAppletStatusArea.desktop" \
    "$a/com.system76.CosmicEdit.desktop" "$HOME/.local/state/edit-md/built-commit" \
    "$HOME/.local/lib/ws-keeper" "$HOME/.local/lib/show-desktop" "$HOME/.local/lib/minimize-ws" \
    "$u/ws-keeper-restore.service" "$u/ws-keeper-watch.service" "$u/minimize-ws-check.service" "$u/minimize-ws-check.timer" \
    "$HOME/.local/state/minimize-ws/built-commit"
  grep -q "disable --now ws-keeper-watch.service ws-keeper-restore.service" "$T/systemctl.log" || fail "ws-keeper not disabled"
  grep -q "disable --now minimize-ws-check.timer" "$T/systemctl.log" || fail "check timer not disabled"
  ! grep -q 'show-desktop' "$sc" || fail "shortcut not removed: $(cat "$sc")"
  grep -qF 'Spawn("editor")' "$sc" || fail "other shortcut lost: $(cat "$sc")"
  [[ -f "$HOME/.local/state/ws-keeper/snap.json" ]] || fail "user data removed"
  [[ -f "$HOME/.config/minimize-ws/ignore" ]] || fail "taskbar config removed"
  [[ -d "$HOME/.local/state/minimize-ws" ]] || fail "taskbar state folder removed"
  "$REPO/install.sh" --list > "$T/list"
  [[ "$(grep -c ' no ' "$T/list")" == 7 ]] || fail "--list after uninstall: $(cat "$T/list")"
}

t_dry_run_changes_nothing() {
  "$REPO/install.sh" --dry-run all > "$T/out" 2>&1 || fail "dry run failed: $(cat "$T/out")"
  [[ -z "$(find "$HOME" -mindepth 1)" ]] || fail "dry run wrote: $(find "$HOME" -mindepth 1)"
  [[ ! -e "$T/systemctl.log" ]] || ! grep -qv 'is-active' "$T/systemctl.log" || fail "dry run ran systemctl: $(cat "$T/systemctl.log")"
  grep -qF "would run: $REPO/taskbar/build.sh" "$T/out" || fail "no plan: $(cat "$T/out")"
  inst ws-keeper
  "$REPO/install.sh" --dry-run --uninstall ws-keeper > "$T/out" 2>&1 || fail "dry uninstall failed"
  [[ -x "$HOME/.local/bin/ws-keeper" ]] || fail "dry uninstall removed ws-keeper"
}

t_check_timer_follows_patched_tools() {
  local u="$HOME/.config/systemd/user"
  inst tray-colors
  [[ -f "$u/minimize-ws-check.timer" ]] || fail "timer not installed with tray-colors"
  [[ ! -e "$HOME/.local/bin/cosmic-applet-minimize-ws" ]] || fail "taskbar installed unasked"
  inst taskbar
  inst --uninstall tray-colors
  [[ -f "$u/minimize-ws-check.timer" ]] || fail "timer removed while the taskbar is installed"
  inst --uninstall taskbar
  assert_gone "$u/minimize-ws-check.timer"
}

t_text_editor_alone() {
  # Not a taskbar add-on: no warning, and the daily update check still covers it.
  inst text-editor
  ! grep -qF "taskbar add-on" "$T/out" || fail "add-on warning for text-editor: $(cat "$T/out")"
  grep -qF "reopen the Text Editor" "$T/out" || fail "no next step: $(cat "$T/out")"
  [[ -x "$HOME/.local/bin/cosmic-edit-md" ]] || fail "cosmic-edit-md not installed"
  grep -qx "6f89bfa" "$HOME/.local/state/edit-md/built-commit" || fail "edit-md built-commit"
  [[ -f "$HOME/.config/systemd/user/minimize-ws-check.timer" ]] || fail "update timer not installed"
  [[ ! -e "$HOME/.local/bin/cosmic-applet-minimize-ws" ]] || fail "taskbar installed unasked"
  inst --uninstall text-editor
  assert_gone "$HOME/.local/bin/cosmic-edit-md" "$HOME/.local/share/applications/com.system76.CosmicEdit.desktop" \
    "$HOME/.config/systemd/user/minimize-ws-check.timer"
}

t_addon_without_taskbar_warns() {
  inst terminal-tabs
  grep -qF "terminal-tabs is a taskbar add-on" "$T/out" || fail "no add-on note: $(cat "$T/out")"
}

t_unknown_tool_fails() {
  if "$REPO/install.sh" taskbarr > "$T/out" 2>&1; then fail "unknown tool accepted"; fi
  grep -qF 'unknown tool "taskbarr"' "$T/out" || fail "message: $(cat "$T/out")"
  [[ -z "$(find "$HOME" -mindepth 1)" ]] || fail "wrote files"
}

t_no_args_without_tty_fails() {
  if "$REPO/install.sh" > "$T/out" 2>&1; then fail "menu without a terminal"; fi
  grep -qF "name the tools" "$T/out" || fail "message: $(cat "$T/out")"
}

t_missing_cargo_prints_rustup() {
  rm "$T/bin/cargo"
  if "$REPO/install.sh" taskbar > "$T/out" 2>&1; then fail "built without cargo"; fi
  grep -qF "sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path" "$T/out" || fail "no rustup hint: $(cat "$T/out")"
  assert_none_forbidden
}

t_missing_build_packages_listed() {
  printf '#!/bin/sh\ncase "$*" in *libwayland-dev*) exit 1 ;; *Status*) echo "install ok installed" ;; *) echo "1.0~1~24.04~6f89bfa" ;; esac\n' > "$T/bin/dpkg-query"
  if "$REPO/install.sh" taskbar > "$T/out" 2>&1; then fail "built without libwayland-dev"; fi
  grep -qF "sudo apt install libwayland-dev" "$T/out" || fail "no apt hint: $(cat "$T/out")"
  assert_none_forbidden
}

t_non_pop_package_refused() {
  printf '#!/bin/sh\ncase "$*" in *Status*) echo "install ok installed" ;; *) echo "1.0.0-1" ;; esac\n' > "$T/bin/dpkg-query"
  if "$REPO/install.sh" taskbar > "$T/out" 2>&1; then fail "accepted a version without a commit"; fi
  grep -qF "needs the Pop!_OS build of cosmic-applets" "$T/out" || fail "message: $(cat "$T/out")"
  # ws-keeper needs no build: still installs.
  inst ws-keeper
}

t_bootstrap_clones_and_reexecs() {
  # Run from a pipe, as with curl | bash: the stub git clone copies this repo into place.
  printf '#!/bin/sh\nif [ "$1" = clone ]; then for a; do d="$a"; done; cp -r "%s" "$d"; mkdir -p "$d/.git"; fi\nexit 0\n' "$REPO" > "$T/bin/git"
  (cd "$T" && bash -s -- --list < "$REPO/install.sh") > "$T/out" 2>&1 || fail "bootstrap failed: $(cat "$T/out")"
  [[ -f "$HOME/.local/share/cosmic-desktop-extras/install.sh" ]] || fail "not cloned"
  grep -qF "Downloading cosmic-desktop-extras" "$T/out" || fail "no download note: $(cat "$T/out")"
  grep -q '^taskbar ' "$T/out" || fail "--list not run from the clone: $(cat "$T/out")"
  (cd "$T" && bash -s -- --list < "$REPO/install.sh") > "$T/out" 2>&1 || fail "second bootstrap failed"
  grep -qF "Updating" "$T/out" || fail "second run did not pull: $(cat "$T/out")"
}

t_bootstrap_dry_run_leaves_home_empty() {
  printf '#!/bin/sh\nif [ "$1" = clone ]; then for a; do d="$a"; done; cp -r "%s" "$d"; mkdir -p "$d/.git"; fi\nexit 0\n' "$REPO" > "$T/bin/git"
  export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
  (cd "$T" && bash -s -- --dry-run all < "$REPO/install.sh") > "$T/out" 2>&1 || fail "dry bootstrap failed: $(cat "$T/out")"
  grep -qF "would download cosmic-desktop-extras to $HOME/.local/share/cosmic-desktop-extras" "$T/out" || fail "no note: $(cat "$T/out")"
  grep -qF "Dry run done" "$T/out" || fail "no plan: $(cat "$T/out")"
  [[ -z "$(find "$HOME" -mindepth 1)" ]] || fail "dry bootstrap wrote: $(find "$HOME" -mindepth 1 -maxdepth 4)"
  [[ -z "$(find "$TMPDIR" -mindepth 1)" ]] || fail "temporary copy left behind"
}

t_bootstrap_offline_pull_goes_on() {
  printf '#!/bin/sh\nif [ "$1" = clone ]; then for a; do d="$a"; done; cp -r "%s" "$d"; mkdir -p "$d/.git"; fi\n[ "$3" = pull ] && exit 1\nexit 0\n' "$REPO" > "$T/bin/git"
  (cd "$T" && bash -s -- --list < "$REPO/install.sh") > /dev/null 2>&1 || fail "first bootstrap failed"
  (cd "$T" && bash -s -- --list < "$REPO/install.sh") > "$T/out" 2>&1 || fail "offline bootstrap stopped: $(cat "$T/out")"
  grep -qF "going on with the copy that is there" "$T/out" || fail "no offline note: $(cat "$T/out")"
  grep -q '^taskbar ' "$T/out" || fail "--list not run: $(cat "$T/out")"
}

t_failed_build_does_not_stop_the_rest() {
  # cargo fails for cosmic-term only.
  sed -i '1a [ "$(basename "$PWD")" = cosmic-term ] && exit 1' "$T/bin/cargo"
  if "$REPO/install.sh" taskbar terminal-tabs ws-keeper > "$T/out" 2>&1; then fail "exit 0 despite a failed build"; fi
  grep -qE "^  FAILED  terminal-tabs" "$T/out" || fail "no FAILED line: $(cat "$T/out")"
  grep -qE "^  OK      taskbar" "$T/out" || fail "taskbar not OK: $(cat "$T/out")"
  grep -qE "^  OK      ws-keeper" "$T/out" || fail "ws-keeper not OK: $(cat "$T/out")"
  [[ -x "$HOME/.local/bin/ws-keeper" ]] || fail "ws-keeper skipped after the failure"
  [[ -f "$HOME/.config/systemd/user/minimize-ws-check.timer" ]] || fail "update timer skipped"
}

t_real_folder_in_lib_is_not_deleted() {
  mkdir -p "$HOME/.local/lib/ws-keeper"; touch "$HOME/.local/lib/ws-keeper/mine"
  if "$REPO/install.sh" ws-keeper > "$T/out" 2>&1; then fail "replaced a real folder"; fi
  [[ -f "$HOME/.local/lib/ws-keeper/mine" ]] || fail "real folder deleted"
  grep -qF "is a real folder" "$T/out" || fail "message: $(cat "$T/out")"
}

t_shortcut_non_ascii_home() {
  export HOME="$T/jöhn \"q\\x"; mkdir -p "$HOME"
  inst show-desktop
  local sc="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
  grep -qF "Spawn(\"$T/jöhn \\\"q\\\\x/.local/bin/show-desktop\")" "$sc" || fail "path not escaped: $(cat "$sc")"
  inst --uninstall show-desktop
  ! grep -q 'show-desktop' "$sc" || fail "not removed: $(cat "$sc")"
}

t_shortcut_super_d_taken_or_unreadable() {
  local sc="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom"
  mkdir -p "$(dirname "$sc")"
  printf '{\n    (\n        modifiers: [\n            Super,\n        ],\n        key: "d",\n    ): Spawn("other"),\n}\n' > "$sc"
  inst show-desktop
  grep -qF "already uses Super+D" "$T/out" || fail "no warning: $(cat "$T/out")"
  [[ "$(grep -c Spawn "$sc")" == 1 ]] || fail "second Super+D added: $(cat "$sc")"
  inst --uninstall show-desktop
  echo 'garbage' > "$sc"
  inst show-desktop
  grep -qF "could not read $sc" "$T/out" || fail "no warning: $(cat "$T/out")"
  [[ "$(cat "$sc")" == garbage ]] || fail "file changed"
}

failed=0
for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  name="${t#t_}"
  if ( set -e; setup "$name"; "$t" ) > "$ROOT/$name.log" 2>&1; then echo "ok - $name"
  else echo "not ok - $name"; sed 's/^/#   /' "$ROOT/$name.log"; failed=1; fi
done
exit "$failed"
