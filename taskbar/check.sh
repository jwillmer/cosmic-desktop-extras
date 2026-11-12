#!/usr/bin/env bash
# Daily check (minimize-ws-check.timer): sends a desktop notification when
#  1. apt updated cosmic-applets, so the patched applet is older than COSMIC and needs a rebuild
#     (also says whether the patch series still applies to the new version), or
#  2. System76 changed a patched applet (taskbar, App List) on upstream master since our base
#     commit (each new upstream change is announced once), or
#  3. a patched applet panicked or hit a Wayland protocol error since the last check.
#
#   taskbar/check.sh           check and notify
#   taskbar/check.sh --print   check and print instead of notifying
set -euo pipefail
R="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# Rebuilds go through the installer of the clone this script lives in.
UPDATE="$(cd "$R/.." && pwd)/install.sh --update"
SRC="${XDG_CACHE_HOME:-$HOME/.cache}/minimize-ws/cosmic-applets"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/minimize-ws"
APPLETS=(cosmic-applet-minimize cosmic-app-list)
APPLET_IDS='com\.system76\.(CosmicAppletMinimize|CosmicAppList)'
mkdir -p "$STATE"

notify() {
  if [[ "${1:-}" == "--print" ]]; then shift; printf '%s\n\n' "$*"; return; fi
  gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify "Taskbar applet (cosmic-desktop-extras)" 0 "" \
    "Taskbar applet" "$1" "[]" "{}" 0 >/dev/null
}
mode="${1:-}"

version="$(dpkg-query -W -f='${Version}' cosmic-applets)"
installed="${version##*~}"
built="$(cat "$STATE/built-commit" 2>/dev/null || echo unknown)"

# Steps 1-3 are about the taskbar itself: skipped when only the add-ons or tray-colors are built.
if [[ "$built" != unknown ]]; then
  # Offline: log it (journal) and go on; step 2 then uses the cached clone, step 3 needs none.
  online=1
  if [[ ! -d "$SRC/.git" ]]; then
    git clone -q --filter=blob:none https://github.com/pop-os/cosmic-applets.git "$SRC" || online=
  fi
  [[ -z "$online" ]] || git -C "$SRC" fetch -q origin || online=
  [[ -n "$online" ]] || echo "check.sh: could not fetch cosmic-applets (offline?): upstream checks use the cached copy" >&2

  # 1. COSMIC updated, applet not rebuilt yet.
  if [[ "$installed" != "$built" ]]; then
    if [[ -z "$online" ]]; then
      applies="Could not check whether the patches still apply (offline). Run $UPDATE"
    elif "$R/../lib/patchset.sh" "$R" check "$installed"; then
      applies="The patches apply to the new version: run $UPDATE"
    else
      applies="The patches do NOT apply cleanly: run $(cd "$R/../lib" && pwd)/patchset.sh $R dev, fix the conflict, export"
    fi
    notify ${mode:+$mode} "cosmic-applets was updated ($built -> $installed); the taskbar still runs the old patched build. $applies"
  fi

  # 2. Upstream changes to the patched applets since the commit our patch is based on.
  base="$built"
  latest="$(git -C "$SRC" log -1 --format=%h origin/master -- "${APPLETS[@]}" 2>/dev/null || true)"
  seen="$(cat "$STATE/seen-upstream" 2>/dev/null || true)"
  count="$(git -C "$SRC" rev-list --count "$base..origin/master" -- "${APPLETS[@]}" 2>/dev/null || echo 0)"
  if [[ -n "$latest" && "$count" -gt 0 && "$latest" != "$seen" ]]; then
    subjects="$(git -C "$SRC" log -3 --format='- %s' "$base..origin/master" -- "${APPLETS[@]}")"
    notify ${mode:+$mode} "System76 changed the patched applets (taskbar, App List) upstream: $count commit(s) since $base. Latest:
$subjects
Rebase the patches onto them (patchset.sh dev, rebase, export) when they reach the cosmic-applets package, or earlier if wanted."
    [[ "$mode" == "--print" ]] || echo "$latest" > "$STATE/seen-upstream"
  fi

  # 3. Crashes and protocol errors of the patched applets since the last check (first run: last day).
  now="$(date +%s)"
  since="$(cat "$STATE/errors-since" 2>/dev/null || echo $((now - 86400)))"
  errors="$(journalctl --user --since "@$since" --until "@$now" -o cat 2>/dev/null \
    | grep -E "^$APPLET_IDS: (thread .* panicked at|.*[Pp]rotocol error)" || true)"
  if [[ -n "$errors" ]]; then
    panics="$(grep -c 'panicked at' <<<"$errors" || true)"
    protocol="$(grep -ci 'protocol error' <<<"$errors" || true)"
    notify ${mode:+$mode} "A patched applet failed since the last check: $panics panic(s), $protocol protocol error line(s). First:
$(head -1 <<<"$errors")
Details: journalctl --user --since @$since -g 'panicked|rotocol error'"
  fi
  [[ "$mode" == "--print" ]] || echo "$now" > "$STATE/errors-since"
fi

# 4. Same for the patched COSMIC Terminal (terminal-tabs), if it was built.
TSTATE="${XDG_STATE_HOME:-$HOME/.local/state}/term-tabs"
if [[ -f "$TSTATE/built-commit" ]]; then
  tbuilt="$(cat "$TSTATE/built-commit")"
  tversion="$(dpkg-query -W -f='${Version}' cosmic-term)"
  tinstalled="${tversion##*~}"
  if [[ "$tinstalled" != "$tbuilt" ]]; then
    T="$(cd "$R/../terminal-tabs" && pwd)"
    if "$R/../lib/patchset.sh" "$T" check "$tinstalled"; then
      tapplies="The patches apply: run $UPDATE, then reopen terminals"
    else
      tapplies="The patches do NOT apply cleanly: run $(cd "$R/../lib" && pwd)/patchset.sh $T dev, fix the conflict, export"
    fi
    notify ${mode:+$mode} "cosmic-term was updated ($tbuilt -> $tinstalled); new terminals still start the old patched build. $tapplies"
  fi
fi

# 4. Same for the patched COSMIC Files (files-tabs), if it was built.
FSTATE="${XDG_STATE_HOME:-$HOME/.local/state}/files-tabs"
if [[ -f "$FSTATE/built-commit" ]]; then
  fbuilt="$(cat "$FSTATE/built-commit")"
  fversion="$(dpkg-query -W -f='${Version}' cosmic-files 2>/dev/null || echo not-installed)"
  finstalled="${fversion##*~}"
  if [[ "$finstalled" != "$fbuilt" ]]; then
    F="$(cd "$R/../files-tabs" && pwd)"
    if "$R/../lib/patchset.sh" "$F" check "$finstalled"; then
      fapplies="The patches apply: run $UPDATE, then reopen file manager windows"
    else
      fapplies="The patches do NOT apply cleanly: run $(cd "$R/../lib" && pwd)/patchset.sh $F dev, fix the conflict, export"
    fi
    notify ${mode:+$mode} "cosmic-files was updated ($fbuilt -> $finstalled); new file manager windows still start the old patched build. $fapplies"
  fi
fi

# 4. Same for the patched COSMIC Text Editor (text-editor), if it was built.
ESTATE="${XDG_STATE_HOME:-$HOME/.local/state}/edit-md"
if [[ -f "$ESTATE/built-commit" ]]; then
  ebuilt="$(cat "$ESTATE/built-commit")"
  eversion="$(dpkg-query -W -f='${Version}' cosmic-edit 2>/dev/null || echo not-installed)"
  einstalled="${eversion##*~}"
  if [[ "$einstalled" != "$ebuilt" ]]; then
    E="$(cd "$R/../text-editor" && pwd)"
    if "$R/../lib/patchset.sh" "$E" check "$einstalled"; then
      eapplies="The patches apply: run $UPDATE, then reopen the Text Editor"
    else
      eapplies="The patches do NOT apply cleanly: run $(cd "$R/../lib" && pwd)/patchset.sh $E dev, fix the conflict, export"
    fi
    notify ${mode:+$mode} "cosmic-edit was updated ($ebuilt -> $einstalled); the Text Editor still starts the old patched build. $eapplies"
  fi
fi

# 4. Same for the patched tray applet (tray-colors), if it was built: same package as the taskbar.
CSTATE="${XDG_STATE_HOME:-$HOME/.local/state}/tray-color"
if [[ -f "$CSTATE/built-commit" && "$(cat "$CSTATE/built-commit")" != "$installed" ]]; then
  C="$(cd "$R/../tray-colors" && pwd)"
  if "$R/../lib/patchset.sh" "$C" check "$installed"; then capplies="The patches apply: run $UPDATE"
  else capplies="The patches do NOT apply cleanly: run $(cd "$R/../lib" && pwd)/patchset.sh $C dev, fix the conflict, export"; fi
  notify ${mode:+$mode} "cosmic-applets was updated; the tray still runs the old patched build. $capplies"
fi

