# Workspace Keeper (technical)

Remembers which COSMIC workspace each window is on and moves windows back after a login or a
compositor crash. User overview: [ws-keeper/README.md](../ws-keeper/README.md).

## How it works

- `lib/wsk.py` is a minimal Wayland client: raw wire protocol over the Wayland socket, Python
  standard library only. [Show Desktop](show-desktop.md) uses it too.
- It binds `zcosmic_toplevel_info_v1` (v3), `zcosmic_toplevel_manager_v1` (v4,
  `move_to_ext_workspace`), `ext_foreign_toplevel_list_v1` and `ext_workspace_manager_v1`.
  cosmic-comp sends toplevel state in its refresh cycle, after sync replies, so the client waits
  briefly for late events.
- `ws-keeper watch` (the `ws-keeper-watch` user service) keeps one Wayland connection and listens
  to the toplevel and workspace events. It writes a snapshot (app id, title, workspace number per
  window) to `~/.local/state/ws-keeper/<YYYYmmdd-HHMMSS>.json` only when the windows differ from the
  last written snapshot:
  - a new window or one on another workspace: 3 s after the last change, at most 30 s while
    changes keep coming, so a burst of events writes once;
  - only titles changed: after 60 s. Titles are kept fresh for matching, but a terminal or
    browser changing its title does not write every few seconds;
  - an app has fewer windows (a close, also when a new window of another app came at the same
    time, or workspaces renumbered): only once a window that stayed later changes its title or
    workspace, and then 60 s after that. Windows that only close never replace the fuller
    snapshot, so a logout, also one stalled for minutes by a save prompt or a hung app, does not
    become the newest snapshot. A new window (a save prompt) does not count as confirmation. Until
    confirmed, the snapshot still lists the closed windows; restore finds nothing to match for them;
  - nothing in the first 5 minutes after `cosmic-comp` started. The login restore (15 s + 180 s)
    runs in that time, and a snapshot of the half-restored desktop must not become the newest
    one: after a compositor crash soon after login, restore would use it. When no `cosmic-comp`
    of the user is found in `/proc`, the grace cannot be placed: watch logs it, writes nothing and
    looks again every 60 s. Exiting instead would hit the systemd start limit and stop saving for
    the rest of the session.
- A failed write (disk full, no permission on `~/.local/state/ws-keeper`) is logged with the path
  and the error, and retried 60 s later; the watcher keeps running.
- When the compositor goes away, the watcher exits with status 1 without writing, and systemd
  starts it again after 10 s (it gives up after 6 failed starts within 2 minutes, e.g. after a
  logout, and starts again at the next login). It stops with the desktop session
  (`PartOf=graphical-session.target`) without writing pending changes.
- `ws-keeper save` writes one snapshot now, unless the windows did not change. The last 300
  snapshots are kept.
- `ws-keeper restore` finds the start time of the running `cosmic-comp` and uses the newest
  snapshot from before it that has a window on workspace 2 or higher. Empty or unreadable
  snapshot files are skipped. It matches current windows to snapshot entries by app id and title
  similarity (at least 0.75, best match first) and moves them, lowest target workspace first.
- Titles are normalised before matching: app suffixes (" — Mozilla Firefox", " — COSMIC Terminal",
  " — Visual Studio Code"), leading counters like `(3)` and status marks are dropped.
- The COSMIC panel and `Handy` windows are skipped.

## Installed files

`./install.sh ws-keeper` sets up:

| Path | What |
|---|---|
| `~/.local/lib/ws-keeper` | Link to `ws-keeper/` in the repo checkout |
| `~/.local/bin/ws-keeper` | Wrapper that runs `ws-keeper.py` with `python3 -I` |
| `~/.config/systemd/user/ws-keeper-watch.service` | `ws-keeper watch` for the whole desktop session, restarted 10 s after a failure |
| `~/.config/systemd/user/ws-keeper-restore.service` | At login: waits 15 s, then `ws-keeper restore --watch 180` |

At run time it writes the snapshots to `~/.local/state/ws-keeper/`.
`./install.sh --uninstall ws-keeper` stops and removes the services, the wrapper and the link.

## Commands

```text
ws-keeper list                  windows and their workspace now
ws-keeper watch                 snapshot whenever windows change (run by ws-keeper-watch.service)
ws-keeper save                  take a snapshot now
ws-keeper restore               move windows back using the newest snapshot from before this session
ws-keeper restore --latest      same, from the newest snapshot (fix-up after you moved things by mistake)
ws-keeper restore --watch S     keep matching new windows for S seconds (used at login)
ws-keeper restore --dry-run     print the moves, do not move
ws-keeper snapshots             stored snapshots (~/.local/state/ws-keeper)
```

Tests (no Wayland session needed): `python3 -m unittest discover -s ws-keeper -v` and
`python3 -m unittest discover -s lib -v` (`lib/test_wsk.py`).

## Configuration

None. The snapshot count (`KEEP`), skipped apps (`SKIP_APPS`) and the watch delays (`DEBOUNCE`,
`MAX_WAIT`, `SLOW`, `LOGIN_GRACE`) are constants in `ws-keeper.py`.

Logs: `journalctl --user -u ws-keeper-watch` and `journalctl --user -u ws-keeper-restore`.

## Limits

- Windows are matched by app id and title. For Firefox that is the active tab's title, so two
  windows showing the same page can swap.
- COSMIC removes empty workspaces in the middle and ignores workspace renames, so workspaces are
  numbered. Pin the workspaces you use (Super+W, right-click, Pin): a pinned workspace stays when
  empty, so the numbers in snapshots stay valid.
- A window moved and closed within 60 s may never reach a snapshot; the same for title changes
  in the last minute before a crash. A close reaches a snapshot only after a later title change
  or move of another window.
- Moving windows and the Wayland connection are tested by hand only. See [testing](testing.md).
