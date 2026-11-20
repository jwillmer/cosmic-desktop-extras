#!/usr/bin/env bash
# Patch series on top of an upstream git repo, kept as `git format-patch` files.
#
#   patchset.sh <dir> apply  [commit]   check out <commit> in the cache clone and `git am -3` the series
#   patchset.sh <dir> check  [commit]   exit 0 if the series applies to <commit> (throwaway worktree); else
#                                       name the failed step or first failing patch, exit 1
#   patchset.sh <dir> dev    [commit]   worktree with the series as commits, to edit or rebase
#   patchset.sh <dir> rebase <commit>   move the dev worktree's commits onto <commit>
#   patchset.sh <dir> export            write the dev worktree's commits back to <dir>/patches
#   patchset.sh all check [<dir>...]    check every series (default: each */patchset.conf of this
#                                       repo) against its installed commit; goes on after a failure,
#                                       ends with a summary, exit 1 if any failed
#
# <dir> holds `patchset.conf` (UPSTREAM url, PACKAGE apt package, NAME cache name) and `patches/`.
# [commit] defaults to patches/BASE (the tested base, what build.sh builds) for apply, and to the upstream
# commit of the installed package (last `~` part of its version) for check and dev.
# 3-way apply means an upstream change near our lines merges by itself; a real conflict stops in
# the dev worktree, where it is fixed with normal git (`git am --continue` / `git rebase --continue`).
set -euo pipefail
if [[ "${1:-}" == all ]]; then
  [[ "${2:-}" == check ]] || { echo "usage: $0 all check [<dir>...]" >&2; exit 2; }
  shift 2
  if [[ $# -eq 0 ]]; then set -- "$(dirname "${BASH_SOURCE[0]}")"/../*/patchset.conf; set -- "${@%/patchset.conf}"; fi
  failed=()
  for d in "$@"; do
    name="$(basename "$d")"
    if err="$(bash "${BASH_SOURCE[0]}" "$d" check 2>&1 >/dev/null)"; then echo "ok      $name"
    else
      echo "FAILED  $name"; sed 's/^/        /' <<<"$err"
      first="$(grep -m1 '^check failed' <<<"$err" || head -1 <<<"$err")"
      failed+=("$name: ${first:-no error output}")
    fi
  done
  [[ ${#failed[@]} -gt 0 ]] || { echo "All $# series apply."; exit 0; }
  echo "${#failed[@]} of $# series failed:"; printf '  %s\n' "${failed[@]}"
  exit 1
fi
DIR="$(cd "$1" && pwd)"; CMD="${2:?command}"; ARG="${3:-}"
# shellcheck source=/dev/null
source "$DIR/patchset.conf"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/$NAME"
SRC="$CACHE/$(basename "$UPSTREAM" .git)"
DEV="$CACHE/dev"
PATCHES="$DIR/patches"
GIT=(git -c commit.gpgsign=false -c user.name=patchset -c user.email=patchset@localhost)

installed_commit() { local v; v="$(dpkg-query -W -f='${Version}' "$PACKAGE")"; echo "${v##*~}"; }

clone() {   # && keeps a failed clone visible also where set -e is off (check runs it under ||)
  { [[ -d "$SRC/.git" ]] || git clone -q --filter=blob:none "$UPSTREAM" "$SRC"; } && git -C "$SRC" fetch -q origin
}

series() { ls "$PATCHES"/*.patch 2>/dev/null | sort; }

am_into() {   # am_into <worktree>
  local p; mapfile -t p < <(series)
  [[ ${#p[@]} -eq 0 ]] || "${GIT[@]}" -C "$1" am -q -3 --keep-cr "${p[@]}"
}

# Prints why a check step failed: git's first error line, and a hint for a missing git-lfs.
check_failed() {   # check_failed <step> <git output>
  local line; line="$(grep -m1 "^CONFLICT" <<<"$2" || grep -m1 -E "^(error|fatal)|not found" <<<"$2" || head -1 <<<"$2")"
  echo "check failed: $1: ${line:-no output from git}" >&2
  if grep -q "git-lfs" <<<"$2"; then echo "git-lfs not installed: sudo apt install git-lfs" >&2; fi
  exit 1
}

case "$CMD" in
  apply) commit="${ARG:-$(cat "$PATCHES/BASE")}" ;;
  check|dev) commit="${ARG:-$(installed_commit)}" ;;
esac
case "$CMD" in
  apply)
    clone
    # The series is built and tested on patches/BASE; an older commit lacks what it relies on.
    base="$(cat "$PATCHES/BASE" 2>/dev/null || true)"
    if [[ -n "$base" ]] && ! git -C "$SRC" merge-base --is-ancestor "$base" "$commit" 2>/dev/null; then
      echo "Your $PACKAGE ($commit) is older than the COSMIC release these patches need ($base)." >&2
      echo "Update COSMIC first: sudo apt update && sudo apt full-upgrade" >&2
      exit 1
    fi
    "${GIT[@]}" -C "$SRC" am --abort 2>/dev/null || true
    git -C "$SRC" checkout -q -f --detach "$commit"
    git -C "$SRC" clean -fdq
    if ! am_into "$SRC"; then
      "${GIT[@]}" -C "$SRC" am --abort || true
      echo "The patches do not apply to $PACKAGE $commit, a COSMIC release newer than they were" >&2
      echo "tested on. Please report it: https://github.com/jwillmer/cosmic-ext-desktop-extras/issues" >&2
      echo "(Developers: fix it with $0 $DIR dev $commit)" >&2
      exit 1
    fi
    ;;
  check)
    # Stops at the first failing step or patch and says which; the trap removes the worktree.
    out="$(clone 2>&1)" || check_failed "clone/fetch $UPSTREAM" "$out"
    tmp="$(mktemp -d)"; trap 'git -C "$SRC" worktree remove --force "$tmp" 2>/dev/null || true; rm -rf "$tmp"' EXIT
    out="$(git -C "$SRC" worktree add -q --detach "$tmp" "$commit" 2>&1)" ||
      check_failed "worktree setup at $commit" "$out"
    mapfile -t p < <(series)
    for f in "${p[@]}"; do
      out="$("${GIT[@]}" -C "$tmp" am -3 --keep-cr "$f" 2>&1)" ||
        check_failed "$(basename "$f") does not apply to $commit" "$out"
    done
    echo "${#p[@]} patch(es) apply to $commit."
    ;;
  dev)
    clone
    if [[ -d "$DEV" ]]; then echo "dev worktree exists: $DEV (export or remove it first)" >&2; exit 1; fi
    git -C "$SRC" worktree add -q --detach "$DEV" "$commit"
    echo "$commit" > "$CACHE/dev.base"
    if am_into "$DEV"; then
      echo "Dev worktree: $DEV (base $commit). Commit changes there, then: $0 $DIR export"
    else
      echo "Conflict in $DEV: resolve, git add, then git -C $DEV am --continue; then export." >&2
      exit 1
    fi
    ;;
  rebase)
    [[ -n "$ARG" ]] || { echo "rebase needs the new upstream commit" >&2; exit 1; }
    git -C "$SRC" fetch -q origin
    base="$(cat "$CACHE/dev.base")"
    echo "$ARG" > "$CACHE/dev.base"
    "${GIT[@]}" -C "$DEV" rebase -q --onto "$ARG" "$base" ||
      { echo "Conflict: resolve in $DEV, git add, git -C $DEV rebase --continue; then export." >&2; exit 1; }
    echo "Rebased onto $ARG. Build and test, then: $0 $DIR export"
    ;;
  export)
    base="$(cat "$CACHE/dev.base")"
    rm -f "$PATCHES"/*.patch; mkdir -p "$PATCHES"
    git -C "$DEV" format-patch -q --no-signature --zero-commit --no-stat -o "$PATCHES" "$base..HEAD"
    echo "$base" > "$PATCHES/BASE"
    echo "Exported $(series | wc -l) patch(es) based on $base to $PATCHES."
    echo "Remove the dev worktree when done: git -C $SRC worktree remove $DEV"
    ;;
  *) echo "unknown command $CMD" >&2; exit 2 ;;
esac
