#!/usr/bin/env bash
# Tests for lib/panel-reload.sh with a fake config dir and stubbed pgrep/sleep on PATH.
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

setup() {
  T="$ROOT/$1"; mkdir -p "$T/bin"
  export XDG_CONFIG_HOME="$T/config" PATH="$T/bin:$PATH"
  P="$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.Panel/v1"
  D="$XDG_CONFIG_HOME/cosmic/com.system76.CosmicPanel.Dock/v1"
  mkdir -p "$P" "$D"
  cat > "$P/plugins_wings" <<'EOF'
Some(([
    "com.system76.CosmicPanelAppButton",
    "com.system76.CosmicAppList",
    "com.system76.CosmicAppletMinimize",
], [
    "com.system76.CosmicAppletTime",
]))
EOF
  echo 'Some(["com.system76.CosmicAppList", "com.system76.CosmicAppLibrary"])' > "$D/plugins_center"
  echo 'Some([])' > "$P/plugins_center"
  cp -r "$XDG_CONFIG_HOME" "$T/before"
  printf '#!/bin/sh\n[ "$2" = cosmic-panel ] && exit %s\nexit 1\n' "${PANEL_UP:-0}" > "$T/bin/pgrep"
  printf '#!/bin/sh\ncp -r "%s" "%s/during"\n' "$XDG_CONFIG_HOME" "$T" > "$T/bin/sleep"
  chmod +x "$T/bin/pgrep" "$T/bin/sleep"
  # shellcheck source=panel-reload.sh
  . "$LIB/panel-reload.sh"
}

t_removes_then_restores() {
  setup removes_then_restores
  reload_panel_applets com.system76.CosmicAppList com.system76.CosmicAppletMinimize > "$T/out"
  local w="$T/during/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"
  [[ -f "$w" ]] || fail "no snapshot during the wait"
  grep -q CosmicAppList "$w" && fail "AppList still listed during the wait"
  grep -q CosmicAppletMinimize "$w" && fail "Minimize still listed during the wait"
  grep -q CosmicPanelAppButton "$w" || fail "other applet removed"
  grep -q CosmicAppletTime "$w" || fail "other wing changed"
  grep -q CosmicAppList "$T/during/cosmic/com.system76.CosmicPanel.Dock/v1/plugins_center" \
    && fail "inline list not handled"
  grep -q CosmicAppLibrary "$T/during/cosmic/com.system76.CosmicPanel.Dock/v1/plugins_center" \
    || fail "inline neighbour removed"
  diff -r "$T/before" "$XDG_CONFIG_HOME" || fail "config not restored exactly"
  grep -q "Reloaded" "$T/out" || fail "no confirmation: $(cat "$T/out")"
}

t_panel_not_running() {
  PANEL_UP=1 setup panel_not_running
  reload_panel_applets com.system76.CosmicAppList > "$T/out"
  [[ ! -e "$T/during" ]] || fail "touched the config without a panel"
  grep -q "not running" "$T/out" || fail "no notice: $(cat "$T/out")"
}

t_applet_not_on_panel() {
  setup applet_not_on_panel
  reload_panel_applets com.example.Nothing > "$T/out"
  [[ ! -e "$T/during" ]] || fail "touched the config for an applet that is not listed"
  diff -r "$T/before" "$XDG_CONFIG_HOME" || fail "config changed"
}

failed=0
for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  name="${t#t_}"
  ( set -e; "$t" ) > "$ROOT/$name.log" 2>&1
  if [[ $? -eq 0 ]]; then echo "ok - $name"
  else echo "not ok - $name"; sed 's/^/#   /' "$ROOT/$name.log"; failed=1; fi
done
exit "$failed"
