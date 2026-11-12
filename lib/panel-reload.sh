# Sourced by build scripts. reload_panel_applets <desktop id>...: restart those panel applets
# without restarting cosmic-panel. The panel watches its config: the applets are taken out of every
# panel's plugin lists and put back, so the panel stops them and starts them again from their
# desktop entries. Restarting cosmic-panel itself makes cosmic-session wait longer after every
# restart of the day (minutes after a few), so build scripts avoid it.

reload_panel_applets() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic" files=() f
  if ! pgrep -x cosmic-panel >/dev/null; then
    echo "cosmic-panel is not running: it uses the new applets when it starts."
    return 0
  fi
  for f in "$cfg"/com.system76.CosmicPanel.*/v1/plugins_wings "$cfg"/com.system76.CosmicPanel.*/v1/plugins_center; do
    [[ -f "$f" ]] || continue
    for id in "$@"; do grep -qF "\"$id\"" "$f" && { files+=("$f"); break; }; done
  done
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "None of $* is on a panel: nothing to reload."
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  for f in "${files[@]}"; do cp -p "$f" "$tmp/$(echo "$f" | md5sum | cut -c1-12)"; done
  restore() {
    local f
    for f in "${files[@]}"; do
      cp -p "$tmp/$(echo "$f" | md5sum | cut -c1-12)" "$f.reload-tmp" && mv "$f.reload-tmp" "$f"
    done
    rm -rf "$tmp"
  }
  trap restore EXIT
  for f in "${files[@]}"; do
    python3 -I - "$f" "$@" <<'EOF'
import os, re, sys
path, ids = sys.argv[1], sys.argv[2:]
text = open(path).read()
for i in ids:
    text = re.sub(r'[ \t]*"' + re.escape(i) + r'",?[ \t]*\n?', "", text)
open(path + ".reload-tmp", "w").write(text)
os.replace(path + ".reload-tmp", path)
EOF
  done
  sleep "${PANEL_RELOAD_WAIT:-2}"
  restore
  trap - EXIT
  echo "Reloaded the panel applets: $*"
}
