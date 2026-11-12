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

## Installed files

`files-tabs/build.sh` (run by `./install.sh files-tabs`) installs:

| Path | What |
|---|---|
| `~/.local/bin/cosmic-files-tabs` | The patched file manager |
| `~/.local/bin/cosmic-files` | Link to it. "Show in folder" in other apps (`org.freedesktop.FileManager1`, served by `cosmic-files-applet`) and other launches by name start `cosmic-files` from the session `PATH`, which has `~/.local/bin` first. |
| `~/.local/share/applications/com.system76.CosmicFiles.desktop` | Copy of the system entry pointing at the patched file manager (launcher, dock, folders opened through the `inode/directory` type) |
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
- Run `./install.sh --update` after apt updates `cosmic-files`. The taskbar's daily check reminds
  you.
