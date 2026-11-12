# Tray colors (technical)

Patch for COSMIC's "Notifications Tray" panel applet (`cosmic-applet-status-area`). Tray icons that
an app hands over as a file path keep their own colours. Upstream draws every such icon in the
theme colour, so coloured tray icons (unread counts, status dots) become one flat colour. User
overview: [tray-colors/README.md](../tray-colors/README.md).

## How it works

- The patch in `tray-colors/patches/` changes one line in
  `cosmic-applet-status-area/src/components/status_menu.rs` and adds `path_is_symbolic()`.
- An icon given as a file path is drawn in the theme colour only when its file name ends in
  `-symbolic` (`foo-symbolic.svg`), the same rule as named icons. Every other file keeps its
  colours.
- Icons given by name or as pixmaps are unchanged.
- Only the panel applet is replaced. The session also starts the system binary as
  `cosmic-applet-status-area --status-notifier-watcher` (the D-Bus tray watcher); that stays the
  system one.

## Installed files

`tray-colors/build.sh` (run by `./install.sh tray-colors`) installs:

| Path | What |
|---|---|
| `~/.local/bin/cosmic-applet-status-area-color` | The patched tray applet |
| `~/.local/share/applications/com.system76.CosmicAppletStatusArea.desktop` | Copy of the system entry with `Exec=` pointing at the patched applet. A user entry with the same id overrides the system one, so the panel config is unchanged. |
| `~/.local/state/tray-color/built-commit` | Upstream commit it was built from |
| `~/.cache/tray-color/cosmic-applets` | Upstream source clone |

## Commands

```text
./install.sh tray-colors                build the installed cosmic-applets version + patches, install, reload the applet
./install.sh --uninstall tray-colors    back to the system tray applet
tray-colors/build.sh [--uninstall]      the same steps without the installer
tray-colors/build.sh --no-restart       install without reloading; the patched applet starts with the next login
```

Needs the same Rust toolchain as the taskbar, see [taskbar](taskbar.md#commands). The applet is
reloaded without restarting the panel ([lib/panel-reload.sh](../lib/panel-reload.sh)).

**Run `./install.sh --update` after apt updates `cosmic-applets`.** The taskbar's daily check
(`taskbar/check.sh`) notifies once this applet was built, and says whether the patch still applies.
How to move the patch to a new version: [patch series](patch-series.md).

## Limits

- An app that sends a coloured icon under a `-symbolic` file name still gets the theme colour.
- Rust unit tests cover the file-name rule only (`./test.sh` runs them); how the icon looks in
  the panel is tested by hand.
