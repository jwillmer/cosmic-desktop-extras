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
- Pins send an app's windows to a named workspace (see [Pins](#pins)). `ws-keeper watch` moves a
  window to its pinned workspace once, when the window opens. It also does this in the login
  grace, which only holds back snapshot writes. Windows that were open when watch connected are
  left alone, and so is a window you move by hand later. When the moved window is the app's only
  window (the app was just started), the workspace is not shown and the login grace is over,
  watch also activates that workspace (`ext_workspace_handle_v1.activate`), so you follow the app.
  A second window of a running app (a call, a dialog) never switches the workspace. `ws-keeper restore` uses the pin instead
  of the snapshot for pinned apps, also for windows that match no snapshot entry. Without a
  snapshot, restore still applies the pins to the windows open at that moment.
- The COSMIC panel and `Handy` windows are skipped, also for pins.

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
ws-keeper pins                  pin rules, whether each workspace exists, app ids of open windows
```

Tests (no Wayland session needed): `python3 -m unittest discover -s ws-keeper -v` and
`python3 -m unittest discover -s lib -v` (`lib/test_wsk.py`).

## Configuration

### Pins

File: `$XDG_CONFIG_HOME/ws-keeper/pins` (default `~/.config/ws-keeper/pins`). A missing file means
no pins. The taskbar's context menu writes it; you can also edit it by hand. Upstream request:
[cosmic-workspaces-epoch #186](https://github.com/pop-os/cosmic-workspaces-epoch/issues/186).

```text
# app_id = Workspace Name
org.example.Chat = Work
org.example.Mail = Mail
```

- UTF-8 text, one rule per line. The line is split at the first `=`, and spaces around both parts
  are dropped, so a workspace name may contain `=`.
- Blank lines and lines starting with `#` are ignored.
- A line without `=`, or with an empty app id or name, is logged with file, line number and
  content, and skipped. The other rules still apply.
- When an app id appears twice, the last rule wins. App ids match exactly, case included.
- The workspace is found by the name COSMIC reports for it (`ws-keeper pins` lists them). When
  several workspaces have the name, the first one (lowest position) is used. When none has it,
  watch logs that once per app and name, with the names that exist, and leaves the window where
  it is. Restore then falls back to the snapshot for that window.
- Watch reads the file again when its modification time or size changes. It checks this only
  when a new window opens, so editing the file needs no restart.

### Constants

The snapshot count (`KEEP`), skipped apps (`SKIP_APPS`) and the watch delays (`DEBOUNCE`,
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
