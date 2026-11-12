#!/usr/bin/env bash
# Patch series on top of an upstream git repo, kept as `git format-patch` files.
#
#   patchset.sh <dir> apply  [commit]   check out <commit> in the cache clone and `git am -3` the series
#   patchset.sh <dir> check  [commit]   exit 0 if the series applies to <commit> (throwaway worktree)
#   patchset.sh <dir> dev    [commit]   worktree with the series as commits, to edit or rebase
#   patchset.sh <dir> rebase <commit>   move the dev worktree's commits onto <commit>
#   patchset.sh <dir> export            write the dev worktree's commits back to <dir>/patches
#
# <dir> holds `patchset.conf` (UPSTREAM url, PACKAGE apt package, NAME cache name) and `patches/`.
# [commit] defaults to the upstream commit of the installed package (last `~` part of its version).
# 3-way apply means an upstream change near our lines merges by itself; a real conflict stops in
# the dev worktree, where it is fixed with normal git (`git am --continue` / `git rebase --continue`).
set -euo pipefail
DIR="$(cd "$1" && pwd)"; CMD="${2:?command}"; ARG="${3:-}"
# shellcheck source=/dev/null
source "$DIR/patchset.conf"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/$NAME"
SRC="$CACHE/$(basename "$UPSTREAM" .git)"
DEV="$CACHE/dev"
PATCHES="$DIR/patches"
GIT=(git -c commit.gpgsign=false -c user.name=patchset -c user.email=patchset@localhost)

installed_commit() { local v; v="$(dpkg-query -W -f='${Version}' "$PACKAGE")"; echo "${v##*~}"; }

clone() {
  [[ -d "$SRC/.git" ]] || git clone -q --filter=blob:none "$UPSTREAM" "$SRC"
  git -C "$SRC" fetch -q origin
}

series() { ls "$PATCHES"/*.patch 2>/dev/null | sort; }

am_into() {   # am_into <worktree>
  local p; mapfile -t p < <(series)
  [[ ${#p[@]} -eq 0 ]] || "${GIT[@]}" -C "$1" am -q -3 --keep-cr "${p[@]}"
}

case "$CMD" in apply|check|dev) commit="${ARG:-$(installed_commit)}" ;; esac
case "$CMD" in
  apply)
    clone
    "${GIT[@]}" -C "$SRC" am --abort 2>/dev/null || true
    git -C "$SRC" checkout -q -f --detach "$commit"
    git -C "$SRC" clean -fdq
    if ! am_into "$SRC"; then
      "${GIT[@]}" -C "$SRC" am --abort || true
      echo "The patch series does not apply to $commit. Fix it with: $0 $DIR dev $commit" >&2
      exit 1
    fi
    ;;
  check)
    clone
    tmp="$(mktemp -d)"; trap 'git -C "$SRC" worktree remove --force "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
    git -C "$SRC" worktree add -q --detach "$tmp" "$commit"
    am_into "$tmp" >/dev/null 2>&1
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
