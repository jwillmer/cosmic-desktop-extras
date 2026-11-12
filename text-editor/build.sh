#!/usr/bin/env bash
# Build COSMIC Text Editor with the patches in patches/ and install it for this user. The patched
# editor shows Markdown files as Source, Preview or Split view, opens files as tabs in one window,
# restores the previous session and marks unsaved changes.
#
#   text-editor/build.sh              build the installed cosmic-edit version and install it
#   text-editor/build.sh --uninstall  back to the system editor
#   text-editor/build.sh --test       apply the patches and run the editor's unit tests, install nothing
#
# Only editor windows started afterwards use it: close and reopen open editor windows.
# Re-run after apt updates cosmic-edit (the daily update check, taskbar/check.sh, notifies).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_CACHE_HOME:-$HOME/.cache}/edit-md/cosmic-edit"
BIN="$HOME/.local/bin/cosmic-edit-md"
ID=com.system76.CosmicEdit
SYS_DESKTOP="${SYSTEM_APPLICATIONS:-/usr/share/applications}/$ID.desktop"
USER_DESKTOP="$HOME/.local/share/applications/$ID.desktop"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/edit-md"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$BIN" "$USER_DESKTOP" "$STATE/built-commit"
  [[ -L "$HOME/.local/bin/cosmic-edit" ]] && rm -f "$HOME/.local/bin/cosmic-edit"
  echo "Removed the patched editor; new editor windows use the system one again."
  exit 0
fi

export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || { echo "cargo not found: install rustup first" >&2; exit 1; }

# Package version looks like 1.11.0~1793291775~24.04~ec8375c: the last part is the upstream commit.
version="$(dpkg-query -W -f='${Version}' cosmic-edit)"
commit="${version##*~}"
echo "Installed cosmic-edit $version -> upstream commit $commit"

"$R/../lib/patchset.sh" "$R" apply "$commit"

# Single instance needs a one-line fix in cosmic-files (the editor's file dialogs come from it). Patch 0003
# points Cargo at ../cosmic-files; check that out at the revision the editor's Cargo.lock pins and apply
# patches-cosmic-files/ to it. patches-cosmic-files/BASE records the revision the fix was made on.
CF="$(dirname "$SRC")/cosmic-files"
cf_rev="$(awk '/^name = "cosmic-files"$/{f=1} f&&/^$/{exit} f&&/^source = /{sub(/.*#/,""); sub(/"$/,""); print; exit}' "$SRC/Cargo.lock" 2>/dev/null || true)"
[[ -n "$cf_rev" ]] || cf_rev="$(cat "$R/patches-cosmic-files/BASE")"
[[ -d "$CF/.git" ]] || git clone -q --filter=blob:none https://github.com/pop-os/cosmic-files.git "$CF"
git -C "$CF" am --abort 2>/dev/null || true
git -C "$CF" fetch -q origin "$cf_rev" 2>/dev/null || git -C "$CF" fetch -q origin
git -C "$CF" checkout -q -f --detach "$cf_rev"
git -C "$CF" -c user.name=patchset -c user.email=patchset@localhost -c commit.gpgsign=false am -q -3 "$R"/patches-cosmic-files/*.patch

if [[ "${1:-}" == "--test" ]]; then
  (cd "$SRC" && cargo test --release --bin cosmic-edit)
  exit 0
fi

(cd "$SRC" && cargo build --release)
install -Dm755 "$SRC/target/release/cosmic-edit" "$BIN"

# A user desktop entry with the same id overrides the system one (launcher, dock, "Open with").
mkdir -p "$(dirname "$USER_DESKTOP")" "$STATE"
sed "s|^Exec=cosmic-edit|Exec=$BIN|" "$SYS_DESKTOP" > "$USER_DESKTOP"
# Launches by name (terminal, scripts) find ~/.local/bin first on the session PATH.
ln -sfn "$BIN" "$HOME/.local/bin/cosmic-edit"
echo "$commit" > "$STATE/built-commit"
echo "Installed $BIN (cosmic-edit $commit + patches/). Reopen editor windows to use it."
