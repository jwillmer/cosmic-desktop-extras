#!/usr/bin/env bash
# Re-cut a patch series into its feature layout and export it.
#
#   recut.sh <dir> [final-ref]
#
# Builds the series again from the base: one commit per group in <dir>/patch-groups that only
# ADDS that group's new files, then one last commit with every change to upstream files (the
# hooks). Files that only we add cannot conflict with upstream, so an upstream release conflicts
# in the hooks patch alone. The re-cut tree must equal <final-ref>, every new file must be in a
# group, then the series is written to <dir>/patches and the base to <dir>/patches/BASE.
#
# Without <final-ref> it re-cuts HEAD of the dev worktree on that worktree's base (also after a
# `rebase` onto a new upstream commit). With <final-ref> (a commit in the cache clone) the base is
# <dir>/patches/BASE. The commits take author and dates of the final commit, so the same final
# ref always exports the same patches, whoever runs it.
#
# patch-groups: blocks of `key: value` lines, separated by blank lines; `#` starts a comment line.
#   subject: <commit subject>      first line of a block
#   body: <paragraph>              optional, repeatable: one paragraph each (trailers too)
#   files: <path> <path> ...       repeatable: new files of the group, paths without spaces
# The last block has no `files:`: it is the hooks patch.
set -euo pipefail
set -f   # paths from patch-groups are never globs
DIR="$(cd "$1" && pwd)"; FINAL_ARG="${2:-}"
# shellcheck source=/dev/null
source "$DIR/patchset.conf"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/$NAME"
SRC="$CACHE/$(basename "$UPSTREAM" .git)"
DEV="$CACHE/dev"
PATCHES="$DIR/patches"
GROUPS_FILE="$DIR/patch-groups"

die() { echo "$*" >&2; exit 1; }
[[ -d "$SRC/.git" ]] || die "no cache clone $SRC: start with lib/patchset.sh $DIR dev"
[[ -f "$GROUPS_FILE" ]] || die "no $GROUPS_FILE"
if [[ -n "$FINAL_ARG" ]]; then final="$(git -C "$SRC" rev-parse --verify "$FINAL_ARG^{commit}")"
else [[ -d "$DEV" ]] || die "no dev worktree $DEV: give the final ref"; final="$(git -C "$DEV" rev-parse HEAD)"; fi
if [[ -z "$FINAL_ARG" ]]; then base_name="$(cat "$CACHE/dev.base")"; else base_name="$(cat "$PATCHES/BASE")"; fi
base="$(git -C "$SRC" rev-parse --verify "$base_name^{commit}")"
git -C "$SRC" merge-base --is-ancestor "$base" "$final" || die "$final is not based on $base"

# Parse the groups into parallel arrays; a message is its paragraphs, each ended by \x1f.
subjects=(); messages=(); filelists=()
while IFS= read -r l || [[ -n "$l" ]]; do
  case "$l" in
    ''|'#'*) ;;
    subject:*) subjects+=("$(sed -E 's/^subject:[[:space:]]*//' <<<"$l")"); messages+=(""); filelists+=("") ;;
    body:*|files:*)
      [[ ${#subjects[@]} -gt 0 ]] || die "$GROUPS_FILE: '${l%%:*}:' before the first 'subject:'"
      i=$((${#subjects[@]} - 1)); v="$(sed -E 's/^[a-z]+:[[:space:]]*//' <<<"$l")"
      if [[ "$l" == body:* ]]; then messages[i]+="$v"$'\x1f'; else filelists[i]+=" $v"; fi ;;
    *) die "$GROUPS_FILE: cannot read line: $l" ;;
  esac
done < "$GROUPS_FILE"
n=${#subjects[@]}
[[ $n -gt 0 && -z "${filelists[n-1]// /}" ]] || die "$GROUPS_FILE: the last block (the hooks patch) must have no 'files:'"
for ((i = 0; i < n - 1; i++)); do
  [[ -n "${filelists[i]// /}" ]] || die "$GROUPS_FILE: group '${subjects[i]}' has no files (only the last block may)"
done

mapfile -t added < <(git -C "$SRC" diff --no-renames --name-only --diff-filter=A "$base" "$final")
mapfile -t hooked < <(git -C "$SRC" diff --no-renames --name-only --diff-filter=MDT "$base" "$final")
# shellcheck disable=SC2086
listed="$(printf '%s\n' ${filelists[*]} | sort)"
twice="$(uniq -d <<<"$listed")"
[[ -z "$twice" ]] || die "files listed twice in $GROUPS_FILE:"$'\n'"$twice"
new="$(printf '%s\n' "${added[@]}" | sed '/^$/d' | sort)"
missing="$(comm -23 <(echo "$new") <(echo "$listed") | sed '/^$/d')"
[[ -z "$missing" ]] || die "new files in no group of $GROUPS_FILE:"$'\n'"$missing"
extra="$(comm -13 <(echo "$new") <(echo "$listed") | sed '/^$/d')"
[[ -z "$extra" ]] || die "files in $GROUPS_FILE that are not new in $final:"$'\n'"$extra"

tmp="$(mktemp -d)"; WT="$tmp/recut"
trap 'git -C "$SRC" worktree remove --force "$WT" 2>/dev/null || true; rm -rf "$tmp"' EXIT
git -C "$SRC" worktree add -q --detach "$WT" "$base"
{ read -r GIT_AUTHOR_NAME; read -r GIT_AUTHOR_EMAIL; read -r GIT_AUTHOR_DATE; } \
  < <(git -C "$SRC" log -1 --format=$'%an\n%ae\n%aI' "$final")
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
commit() {   # commit <group index>
  local args=(-m "${subjects[$1]}") p
  while IFS= read -r -d $'\x1f' p; do args+=(-m "$p"); done <<<"${messages[$1]}"
  git -C "$WT" -c commit.gpgsign=false commit -q "${args[@]}"
}

for ((i = 0; i < n - 1; i++)); do
  for f in ${filelists[i]}; do
    mkdir -p "$WT/$(dirname "$f")"
    git -C "$SRC" cat-file blob "$final:$f" > "$WT/$f"
    [[ "$(git -C "$SRC" ls-tree "$final" -- "$f")" != 100755* ]] || chmod +x "$WT/$f"
  done
  # shellcheck disable=SC2086
  git -C "$WT" add -- ${filelists[i]}
  commit "$i"
done
if [[ ${#hooked[@]} -gt 0 ]]; then
  git -C "$SRC" diff --histogram --binary --no-renames "$base" "$final" -- "${hooked[@]}" | git -C "$WT" apply --index
  commit $((n - 1))
fi

if ! git -C "$WT" diff --quiet "$final" HEAD; then
  git -C "$WT" diff --stat "$final" HEAD >&2
  die "re-cut tree differs from $final"
fi
git -C "$WT" format-patch -q --histogram --zero-commit --no-signature --no-stat -o "$tmp/out" "$base..HEAD"
mkdir -p "$PATCHES"; find "$PATCHES" -maxdepth 1 -name '*.patch' -delete
(set +f; mv "$tmp/out"/*.patch "$PATCHES"/)
echo "$base_name" > "$PATCHES/BASE"
echo "Re-cut $(git -C "$WT" rev-list --count "$base..HEAD") patch(es) on $base, tree equals $final, to $PATCHES."
