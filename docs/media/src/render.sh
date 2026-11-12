#!/usr/bin/env bash
# Regenerate the README mockups and render one of them to PNG for a visual check.
#   docs/media/src/render.sh <name> <width> <height>    e.g. render.sh hero 1280 220
# Writes docs/media/*.svg (gen.py) and <name>.png into a temporary folder, printed at the end.
# Uses headless Firefox with a throwaway profile, so a running Firefox is not touched.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M="$SRC/.."
python3 -I "$SRC/gen.py" "$M"
OUT="$(mktemp -d)"
P="$(mktemp -d)"
timeout 60 firefox --headless --no-remote --profile "$P" --window-size="$2,$3" \
  --screenshot "$OUT/$1.png" "file://$M/$1.svg" >/dev/null 2>&1 || true
rm -rf "$P"
echo "$OUT/$1.png"
