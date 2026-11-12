#!/usr/bin/env bash
# Build COSMIC Files with the patches in patches/ and install it for this user. The patched file
# manager writes $XDG_RUNTIME_DIR/cosmic-files-tabs/<pid>.json (window title -> tab and item count),
# which the taskbar shows as "N tabs" or "M items".
#
#   files-tabs/build.sh              build the installed cosmic-files version and install it
#   files-tabs/build.sh --uninstall  back to the system file manager
#
# Only file manager windows opened afterwards use it: open windows keep the old binary until closed.
# Re-run after apt updates cosmic-files (taskbar/check.sh reminds you).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_CACHE_HOME:-$HOME/.cache}/files-tabs/cosmic-files"
BIN="$HOME/.local/bin/cosmic-files-tabs"
ID=com.system76.CosmicFiles
SYS_DESKTOP="${SYSTEM_APPLICATIONS:-/usr/share/applications}/$ID.desktop"
USER_DESKTOP="$HOME/.local/share/applications/$ID.desktop"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/files-tabs"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$BIN" "$USER_DESKTOP" "$STATE/built-commit"
  [[ "$(readlink "$HOME/.local/bin/cosmic-files")" == "$BIN" ]] && rm -f "$HOME/.local/bin/cosmic-files"
  echo "Removed the patched file manager; new windows use the system one again (open ones run until closed)."
  exit 0
fi

export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || { echo "cargo not found: install rustup first" >&2; exit 1; }

# Package version looks like 1.11.0~1793649932~24.04~e03001c: the last part is the upstream commit.
version="$(dpkg-query -W -f='${Version}' cosmic-files)"
commit="${version##*~}"
echo "Installed cosmic-files $version -> upstream commit $commit"

"$R/../lib/patchset.sh" "$R" apply "$commit"

(cd "$SRC" && cargo build --release --bin cosmic-files)
install -Dm755 "$SRC/target/release/cosmic-files" "$BIN"

# A user desktop entry with the same id overrides the system one (launcher, dock, folders opened
# by other apps through the inode/directory MIME type).
mkdir -p "$(dirname "$USER_DESKTOP")" "$STATE"
sed "s|^Exec=cosmic-files|Exec=$BIN|" "$SYS_DESKTOP" > "$USER_DESKTOP"
# "Show in folder" (org.freedesktop.FileManager1, served by cosmic-files-applet) starts
# `cosmic-files` by name; the session PATH has ~/.local/bin first, so a link there catches it.
ln -sfn "$BIN" "$HOME/.local/bin/cosmic-files"
echo "$commit" > "$STATE/built-commit"
echo "Installed $BIN (cosmic-files $commit + patches/)."
echo "Open file manager windows keep running the old binary until you close them."
