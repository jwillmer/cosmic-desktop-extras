# Sourced by build scripts. Every patched tool builds the upstream commit its patch series was
# tested on (<dir>/patches/BASE), not the commit of the installed Pop!_OS package: the series is
# only known to apply and work there, and the result is a self-contained build in ~/.local/bin.
#
#   upstream_commit <dir>          print the tested base (<dir>/patches/BASE)
#   upstream_notice <tool> <dir>   compare the installed package with the tested base: a newer one
#                                  prints a notice and goes on; an older one fails (update COSMIC
#                                  first). Call it after `patchset.sh <dir> apply`, which fetches
#                                  the clone it uses to tell older from newer.

upstream_commit() { cat "$1/patches/BASE"; }

upstream_notice() (
  tool="$1" dir="$2"
  # shellcheck source=/dev/null
  source "$dir/patchset.conf"
  base="$(upstream_commit "$dir")"
  version="$(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null || true)"
  installed="${version##*~}"
  # No Pop!_OS package version to compare with (install.sh refuses those before building).
  [[ "$version" == *~* && -n "$installed" ]] || exit 0
  # Short and full hashes of the same commit.
  [[ "$base" == "$installed"* || "$installed" == "$base"* ]] && exit 0
  src="${XDG_CACHE_HOME:-$HOME/.cache}/$NAME/$(basename "$UPSTREAM" .git)"
  if git -C "$src" merge-base --is-ancestor "$base" "$installed" 2>/dev/null; then
    echo "$tool: Pop!_OS has a newer $PACKAGE ($installed) than the tested base ($base); building the tested base. The patches will move to the new version in a later release."
  elif git -C "$src" merge-base --is-ancestor "$installed" "$base" 2>/dev/null; then
    # The series relies on what came after the installed version (in the build and in the rest of COSMIC).
    echo "Your $PACKAGE ($installed) is older than the COSMIC release these patches need ($base)." >&2
    echo "Update COSMIC first: sudo apt update && sudo apt full-upgrade" >&2
    exit 1
  else
    # The clone cannot tell (commit not fetched, or not on a line with the base).
    echo "$tool: Pop!_OS has $PACKAGE $installed, which differs from the tested base ($base); building the tested base. The patches will move to the new version in a later release."
  fi
)
