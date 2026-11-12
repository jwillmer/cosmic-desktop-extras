#!/usr/bin/env bash
# Build COSMIC's "Notifications Tray" panel applet with the patches in patches/ and install it for
# this user: tray icons that apps hand over as a file path keep their colors instead of being drawn
# in the theme color.
#
#   tray-colors/build.sh              build the installed cosmic-applets version, install, reload the applet
#   tray-colors/build.sh --no-restart build and install, but do not reload the applet
#   tray-colors/build.sh --uninstall  remove the patched applet, back to the system one
#
# Only the panel applet is replaced. The session also starts the system binary as
# `cosmic-applet-status-area --status-notifier-watcher`; that stays as it is.
# Re-run after apt updates cosmic-applets (taskbar/check.sh notifies about that update).
# Needs the same Rust toolchain and build packages as taskbar/build.sh.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_CACHE_HOME:-$HOME/.cache}/tray-color/cosmic-applets"
CRATE=cosmic-applet-status-area
BIN="$HOME/.local/bin/cosmic-applet-status-area-color"
ID=com.system76.CosmicAppletStatusArea
USER_DESKTOP="$HOME/.local/share/applications/$ID.desktop"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/tray-color"

# shellcheck source=../lib/panel-reload.sh
. "$R/../lib/panel-reload.sh"
restart_applet() {
  if [[ "${1:-}" == "--no-restart" ]]; then
    echo "Applet not reloaded: run the script again without --no-restart, or log in again."
    return
  fi
  reload_panel_applets "$ID"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$BIN" "$USER_DESKTOP" "$STATE/built-commit"
  restart_applet
  echo "Removed the patched tray applet; the panel uses the system one again."
  exit 0
fi

export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || { echo "cargo not found: install rustup first" >&2; exit 1; }

# Package version looks like 1.11.0~1793636322~24.04~6f89bfa: the last part is the upstream commit.
version="$(dpkg-query -W -f='${Version}' cosmic-applets)"
commit="${version##*~}"
echo "Installed cosmic-applets $version -> upstream commit $commit"

"$R/../lib/patchset.sh" "$R" apply "$commit"

(cd "$SRC" && cargo build --release -p "$CRATE")
install -Dm755 "$SRC/target/release/$CRATE" "$BIN"
# A user desktop entry with the same id overrides the system one, so the panel config stays as is.
mkdir -p "$(dirname "$USER_DESKTOP")" "$STATE"
sed "s|^Exec=.*|Exec=$BIN|" "${SYSTEM_APPLICATIONS:-/usr/share/applications}/$ID.desktop" > "$USER_DESKTOP"

# taskbar/check.sh compares this with the installed cosmic-applets version.
echo "$commit" > "$STATE/built-commit"

restart_applet "${1:-}"
echo "Installed $BIN (cosmic-applets $commit + patches/)."
