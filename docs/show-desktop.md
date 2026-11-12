# Show Desktop (technical)

Super+D as on Windows: minimizes the open windows of the current workspace. The next press brings
them back and focuses the window you were in. User overview:
[show-desktop/README.md](../show-desktop/README.md).

## How it works

- `show-desktop/show-desktop.py` uses the shared Wayland client (`lib/wsk.py`, also used by
  [Workspace Keeper](ws-keeper.md)) to read the windows and workspaces, and sends
  `zcosmic_toplevel_manager_v1` requests (set/unset minimized, activate).
- `decide()` holds the logic and has no Wayland dependency:
  - Some window on the active workspace(s) is open: minimize all of them. Store their stable
    toplevel identifiers and the focused one in `~/.local/state/show-desktop/last.json`.
  - Nothing is open: unminimize the windows from the state file. The one that had focus is
    restored last and activated, so it ends up on top. Windows you minimized yourself stay
    minimized.
  - You opened a window in between: that window counts as open, so the press minimizes again.
- The COSMIC panel and windows without an app id or identifier are skipped.
- With several monitors, "active workspace" means the active workspace of any monitor.

## Installed files

`./install.sh show-desktop` sets up:

| Path | What |
|---|---|
| `~/.local/lib/show-desktop` | Link to `show-desktop/` in the repo checkout |
| `~/.local/bin/show-desktop` | Wrapper that runs `show-desktop.py` with `python3 -I` |
| `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom` | Super+D entry, added only if no entry mentions `show-desktop` yet |
| `~/.local/state/show-desktop/last.json` | Windows the last press minimized (written at run time) |

`./install.sh --uninstall show-desktop` removes the wrapper, the link and the Super+D entry (other
custom shortcuts are kept). The state folder is kept.

## Commands

```sh
show-desktop                                       # what Super+D runs
python3 -m unittest discover -s show-desktop -v    # tests, no Wayland needed
```

## Configuration

None. To change the key, edit the custom shortcut in COSMIC Settings (keyboard shortcuts).

## Limits

- Only `decide()` is tested. The Wayland calls are tested by hand. See [testing](testing.md).
