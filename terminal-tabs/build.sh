#!/usr/bin/env bash
# Build COSMIC Terminal with the patches in patches/ and install it for this user. The patched terminal
# writes $XDG_RUNTIME_DIR/cosmic-term-tabs/<pid>.json (window title -> tab count), which the
# taskbar shows as "N tabs".
#
#   terminal-tabs/build.sh              build the installed cosmic-term version and install it
#   terminal-tabs/build.sh --uninstall  back to the system terminal
#
# Only terminals started afterwards use it: close and reopen open terminal windows.
# Re-run after apt updates cosmic-term (taskbar/check.sh reminds you).
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${XDG_CACHE_HOME:-$HOME/.cache}/term-tabs/cosmic-term"
BIN="$HOME/.local/bin/cosmic-term-tabs"
ID=com.system76.CosmicTerm
SYS_DESKTOP="${SYSTEM_APPLICATIONS:-/usr/share/applications}/$ID.desktop"
USER_DESKTOP="$HOME/.local/share/applications/$ID.desktop"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/term-tabs"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$BIN" "$USER_DESKTOP" "$STATE/built-commit"
  [[ -L "$HOME/.local/bin/cosmic-term" ]] && rm -f "$HOME/.local/bin/cosmic-term"
  echo "Removed the patched terminal; new terminals use the system one again."
  exit 0
fi

export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || { echo "cargo not found: install rustup first" >&2; exit 1; }

# Package version looks like 1.11.0~1793291766~24.04~8a05e91: the last part is the upstream commit.
version="$(dpkg-query -W -f='${Version}' cosmic-term)"
commit="${version##*~}"
echo "Installed cosmic-term $version -> upstream commit $commit"

"$R/../lib/patchset.sh" "$R" apply "$commit"

(cd "$SRC" && cargo build --release)
install -Dm755 "$SRC/target/release/cosmic-term" "$BIN"

# A user desktop entry with the same id overrides the system one (launcher, dock, Super+T).
mkdir -p "$(dirname "$USER_DESKTOP")" "$STATE"
sed "s|^Exec=cosmic-term|Exec=$BIN|" "$SYS_DESKTOP" > "$USER_DESKTOP"
# Super+T (System(Terminal)) starts `cosmic-term` by name, not via the desktop entry; the session
# PATH has ~/.local/bin first, so a link there catches it (and any other launch by name).
ln -sfn "$BIN" "$HOME/.local/bin/cosmic-term"
echo "$commit" > "$STATE/built-commit"
echo "Installed $BIN (cosmic-term $commit + patches/). Reopen terminal windows to use it."
