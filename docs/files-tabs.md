# Files tab counts (technical)

Patch for COSMIC Files. Each file manager writes its window title, tab count and the item count of
the active tab to a file, so the [taskbar](taskbar.md) can show "N tabs" or "M items" for file
manager windows. COSMIC Files does not expose its tabs otherwise. User overview:
[files-tabs/README.md](../files-tabs/README.md).

## How it works

- The patch in `files-tabs/patches/` adds `src/tab_publisher.rs` to cosmic-files.
- Each process has one main window (New window starts a new process). The patched app writes
  `$XDG_RUNTIME_DIR/cosmic-files-tabs/<pid>.json`:

  ```json
  {"windows":[{"title":"Downloads — COSMIC Files","tabs":N,"items":M}]}
  ```

- `title` is the exact title the app sets on the window. `items` counts what the active tab
  lists: files and folders, hidden ones only while "Show hidden files" is on, search results
  while a search runs. It comes from the app's own item list, not from a disk read.
- The app checks the counts on every view rebuild, but walks the item list only when the list
  was replaced or resized, the active tab changed or "Show hidden files" was toggled, and at most
  once per 500 ms otherwise. While a folder is still loading, `items` is 0.
- The file is rewritten atomically and only when the title, tab count or item count changes, from
  a writer thread off the UI thread. While a big folder loads, the count changes many times: the
  first change is written at once, then at most one write per 500 ms with the latest count.
- The file is removed when the window closes and when the app exits normally. A file left by a
  crashed process names a dead pid.
- The taskbar matches the file's entries to windows by title.

## Folder icons from `.directory`

A second patch adds `src/dir_icon.rs`: a folder with a `.directory` file (the KDE/Dolphin
convention) shows the icon named there instead of `folder` or the XDG special-folder icon.

```ini
[Desktop Entry]
Icon=folder-development
```

- Only `Icon` in the `[Desktop Entry]` group counts; other groups, `#`/`;` comments, blank lines,
  CRLF line endings, a UTF-8 BOM and localized keys (`Icon[de]=`) are handled. `Icon=` is a theme
  icon name or an absolute path to an image file of at most 1 MB; relative paths are ignored.
- Used for the grid and list icons, and for the sidebar (`<name>-symbolic`). A name missing from
  the theme falls back to `folder` (`folder-symbolic` in the sidebar); an image path that does not
  exist keeps the normal icon.
- Reads at most the first 4 KB, only for directories. Folders below remote, FUSE and automount
  points (gvfs, smb/cifs, nfs, sshfs and other `fuse.*`, `autofs`; from `/proc/self/mountinfo`,
  re-read at most every 5 s) are skipped without any file access. A remote folder reached through
  a symlink is caught by the folder's own file system type (the app's `FsKind`).
- The result is cached per folder and checked against the size, mtime, inode and ctime of
  `.directory` on every lookup (one `stat`), so a new, edited or removed file shows the next time the parent folder is
  listed. A missing or unreadable file means the normal icon, logged at debug level only.
- The hooks are three lines each in `folder_icon` and `folder_icon_symbolic` (`src/item/mod.rs`). The
  desktop icons (`cosmic-files-applet`) stay the system build and do not show these icons.

## Installed files

`files-tabs/build.sh` (run by `./install.sh files-tabs`) installs:

| Path | What |
|---|---|
| `~/.local/bin/cosmic-files-tabs` | The patched file manager |
| `~/.local/bin/cosmic-files` | Link to it. "Show in folder" in other apps (`org.freedesktop.FileManager1`, served by `cosmic-files-applet`) and other launches by name start `cosmic-files` from the session `PATH`, which has `~/.local/bin` first. |
| `~/.local/share/applications/com.system76.CosmicFiles.desktop` | Copy of the system entry pointing at the patched file manager (launcher, dock, folders opened through the `inode/directory` type) |
| `~/.local/share/icons/hicolor/scalable/places/folder-development{,-symbolic}.svg` | The code folder icon for `Icon=folder-development` in a `.directory` file (COSMIC has none) |
| `~/.local/state/files-tabs/built-commit` | Upstream commit it was built from |
| `~/.cache/files-tabs/cosmic-files` | Upstream source clone |

No D-Bus service override: no package ships an activatable `org.freedesktop.FileManager1`
service; `cosmic-files-applet` (desktop icons, started by the session) owns the name and starts
`cosmic-files` by name. The desktop icons themselves stay the system `cosmic-files-applet`.

## Commands

```text
./install.sh files-tabs               build the installed cosmic-files version + patches, install per user
./install.sh --uninstall files-tabs   back to the system file manager
files-tabs/build.sh [--uninstall]     the same steps without the installer
```

Needs the same Rust toolchain as the taskbar, see [taskbar](taskbar.md#commands). `build.sh` does
not restart the panel and does not close file manager windows.

## Configuration

None.

## Limits

- Only windows opened after the install use it: open file manager windows keep the old binary
  until they are closed.
- The file of a process killed by a signal stays until its pid is reused or the session ends.
- Two windows with the same title get no count.
- Built from the `cosmic-files` commit the patches were tested on (`files-tabs/patches/BASE`),
  whatever version is installed: it is a self-contained binary. A newer `cosmic-files` from apt
  gets one notice during the build and needs no rebuild; `./install.sh --update` moves to a newer
  base when a release of this repo does. See [patch series](patch-series.md#what-the-user-builds).
