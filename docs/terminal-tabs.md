# Terminal tab counts (technical)

Patch for COSMIC Terminal. Each terminal writes its window titles and tab counts to a file, so the
[taskbar](taskbar.md) can show "N tabs" for terminals. COSMIC Terminal does not expose its tabs
otherwise. User overview: [terminal-tabs/README.md](../terminal-tabs/README.md).

## How it works

- The patches in `terminal-tabs/patches/` add `src/tab_publisher.rs` to cosmic-term.
- Whenever the terminal sets a window title, it writes
  `$XDG_RUNTIME_DIR/cosmic-term-tabs/<pid>.json`:

  ```json
  {"windows":[{"title":"…","tabs":N}]}
  ```

- The file is rewritten atomically and only when a window's title or tab count changes. It is
  removed when the terminal exits.
- The taskbar matches the file's entries to windows by title.

## Installed files

`terminal-tabs/build.sh` (run by `./install.sh terminal-tabs`) installs:

| Path | What |
|---|---|
| `~/.local/bin/cosmic-term-tabs` | The patched terminal |
| `~/.local/bin/cosmic-term` | Link to it. Super+T starts the terminal by name, and the session `PATH` has `~/.local/bin` first. |
| `~/.local/share/applications/com.system76.CosmicTerm.desktop` | Copy of the system entry pointing at the patched terminal (launcher, dock) |
| `~/.local/state/term-tabs/built-commit` | Upstream commit it was built from |
| `~/.cache/term-tabs/cosmic-term` | Upstream source clone |

## Commands

```text
./install.sh terminal-tabs               build the installed cosmic-term version + patches, install per user
./install.sh --uninstall terminal-tabs   back to the system terminal
terminal-tabs/build.sh [--uninstall]     the same steps without the installer
```

Needs the same Rust toolchain as the taskbar, see [taskbar](taskbar.md#commands).

## Configuration

None.

## Limits

- Only terminals started after the install use it: close and reopen open terminal windows.
- Tabs of split panes are summed.
- Two windows with the same title get no count.
- Run `./install.sh --update` after apt updates `cosmic-term`. The taskbar's daily check reminds
  you.
