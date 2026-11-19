#!/usr/bin/env bash
# Build COSMIC's "Minimized Windows" and "App List" panel applets with the patches in patches/ and
# install them for this user: the first becomes a taskbar for the windows of the current workspace,
# the second hides apps that have a window in that taskbar.
#
#   taskbar/build.sh              build the tested cosmic-applets commit, install, reload the applets
#   taskbar/build.sh --uninstall  remove the patched applets, back to the system ones
#
# Re-run when the patches move to a new base: ./install.sh --update does it (taskbar/check.sh reminds you).
# Needs: rustup (~/.cargo/bin), libxkbcommon-dev libfontconfig-dev libfreetype-dev libwayland-dev pkg-config.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_CACHE_HOME:-$HOME/.cache}/minimize-ws/cosmic-applets"
# crate  installed binary  desktop entry id  [desktop entry key=value overrides]
# X-OverflowMinSize is in panel icon units (56 px at size M): 4 units hold one window item
# (default 120-220 px) plus the overflow button, so the panel does not squeeze the taskbar to
# only the button.
APPLETS=(
  "cosmic-applet-minimize cosmic-applet-minimize-ws com.system76.CosmicAppletMinimize X-OverflowMinSize=4"
  "cosmic-app-list cosmic-app-list-ws com.system76.CosmicAppList"
)

# shellcheck source=../lib/panel-reload.sh
. "$R/../lib/panel-reload.sh"
restart_applet() {
  local ids=() a id
  for a in "${APPLETS[@]}"; do read -r _ _ id _ <<<"$a"; ids+=("$id"); done
  reload_panel_applets "${ids[@]}"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  for a in "${APPLETS[@]}"; do
    read -r _ bin id _ <<<"$a"
    rm -f "$HOME/.local/bin/$bin" "$HOME/.local/share/applications/$id.desktop"
  done
  restart_applet
  echo "Removed the patched applets; the panel uses the system ones again."
  exit 0
fi

export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || { echo "cargo not found: install rustup first" >&2; exit 1; }

# Always the upstream commit the series was tested on (patches/BASE), whatever cosmic-applets version is
# installed: see lib/upstream.sh.
# shellcheck source=../lib/upstream.sh
. "$R/../lib/upstream.sh"
commit="$(upstream_commit "$R")"
echo "Building cosmic-applets $commit (the tested base) + patches/"

"$R/../lib/patchset.sh" "$R" apply "$commit"
upstream_notice taskbar "$R"

mkdir -p "$HOME/.local/share/applications"
for a in "${APPLETS[@]}"; do
  read -r crate bin id overrides <<<"$a"
  (cd "$SRC" && cargo build --release -p "$crate")
  install -Dm755 "$SRC/target/release/$crate" "$HOME/.local/bin/$bin"
  # A user desktop entry with the same id overrides the system one, so the panel config stays as is.
  edits=(-e "s|^Exec=.*|Exec=$HOME/.local/bin/$bin|")
  for kv in $overrides; do edits+=(-e "s|^${kv%%=*}=.*|$kv|"); done
  sed "${edits[@]}" "${SYSTEM_APPLICATIONS:-/usr/share/applications}/$id.desktop" > "$HOME/.local/share/applications/$id.desktop"
done

# check.sh compares this with the installed cosmic-applets version.
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/minimize-ws"
echo "$commit" > "${XDG_STATE_HOME:-$HOME/.local/state}/minimize-ws/built-commit"

restart_applet
echo "Installed the patched applets in ~/.local/bin (cosmic-applets $commit + patches/)."
