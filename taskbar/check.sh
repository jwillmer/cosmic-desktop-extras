#!/usr/bin/env bash
# Daily check (minimize-ws-check.timer): sends a desktop notification when
#  1. the patches moved to a new upstream base (patches/BASE) but the applet was not rebuilt yet
#     (a newer cosmic-applets from apt needs no rebuild: the build always uses the tested base), or
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

  # 1. Patches moved to a new base, applet not rebuilt yet.
  base="$(cat "$R/patches/BASE")"
  if [[ "$built" != "$base" ]]; then
    notify ${mode:+$mode} "The taskbar patches moved to a new cosmic-applets base ($built -> $base); the taskbar still runs the old build. Run $UPDATE"
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

# 4. Same for the other patched tools, if they were built: rebuild when their patches moved to a
#    new base. <folder> <state name> <what still runs the old build, and what to do after the update>
for t in "terminal-tabs term-tabs new terminals still start the old build. Run $UPDATE, then reopen terminals" \
         "files-tabs files-tabs new file manager windows still start the old build. Run $UPDATE, then reopen file manager windows" \
         "text-editor edit-md the Text Editor still starts the old build. Run $UPDATE, then reopen the Text Editor" \
         "tray-colors tray-color the tray still runs the old build. Run $UPDATE"; do
  read -r dir name rest <<<"$t"
  f="${XDG_STATE_HOME:-$HOME/.local/state}/$name/built-commit"
  [[ -f "$f" ]] || continue
  tbuilt="$(cat "$f")"; tbase="$(cat "$R/../$dir/patches/BASE")"
  [[ "$tbuilt" == "$tbase" ]] || notify ${mode:+$mode} "The $dir patches moved to a new base ($tbuilt -> $tbase); $rest"
done

