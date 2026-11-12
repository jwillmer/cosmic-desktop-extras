#!/usr/bin/env bash
# Run every test: show-desktop, ws-keeper and lib/wsk.py (Python), lib/patchset.sh and
# taskbar/check.sh (local temp repos), lib/panel-reload.sh and install.sh (fake HOME, stubs), then
# the Rust tests of each patch series, built on the upstream commit of the installed package.
#
#   ./test.sh          everything (the Rust part compiles for several minutes the first time)
#   ./test.sh --fast   skip the Rust tests
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.cargo/bin:$PATH"

for d in show-desktop ws-keeper lib; do   # lib: test_wsk.py
  python3 -I -m unittest discover -s "$R/$d"
  find "$R/$d" -name __pycache__ -prune -exec rm -rf {} +
done

"$R/lib/test_patchset.sh"
"$R/lib/test_panel_reload.sh"
"$R/test_install.sh"

if [[ "${1:-}" == "--fast" ]]; then
  echo "Rust tests skipped (--fast)."
  echo "All tests passed."
  exit 0
fi

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
"$R/lib/patchset.sh" "$R/taskbar" apply
(cd "$CACHE/minimize-ws/cosmic-applets" && cargo test --release -q -p cosmic-applet-minimize -p cosmic-app-list)
"$R/lib/patchset.sh" "$R/terminal-tabs" apply
(cd "$CACHE/term-tabs/cosmic-term" && cargo test --release -q tab_publisher)
"$R/lib/patchset.sh" "$R/files-tabs" apply
(cd "$CACHE/files-tabs/cosmic-files" && cargo test --release -q --lib tab_publisher)
"$R/lib/patchset.sh" "$R/tray-colors" apply
(cd "$CACHE/tray-color/cosmic-applets" && cargo test --release -q -p cosmic-applet-status-area)
"$R/text-editor/build.sh" --test   # also prepares the cosmic-files checkout the editor builds against
echo "All tests passed."
