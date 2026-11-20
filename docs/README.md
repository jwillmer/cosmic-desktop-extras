# Technical documentation

How the tools work, which files they install, and how to maintain them. For what each tool does
and how to install it, start at the [main README](../README.md).

| Page | What it covers |
|---|---|
| [taskbar.md](taskbar.md) | Taskbar: behaviour in detail, second-line sources, workspace pins, installed files, settings files, update check |
| [launcher-entry.md](launcher-entry.md) | How any app can fill the taskbar's second line with the Unity LauncherEntry D-Bus signal |
| [terminal-tabs.md](terminal-tabs.md) | Patched COSMIC Terminal: the tab-count file it writes, installed files |
| [files-tabs.md](files-tabs.md) | Patched COSMIC Files: the tab and item-count file it writes, folder icons from `.directory`, installed files |
| [tray-colors.md](tray-colors.md) | Patched tray applet: the icon colour rule, installed files |
| [text-editor/](text-editor/README.md) | Patched COSMIC Text Editor: Markdown views, "/" menu, Markdown shortcuts, list and table editing, large files, one window, session restore, change history, changed-on-disk bar, preview selection, two views and clones, tab file menu, typed and pasted paths in the file dialogs, sidebar width, Find and Replace window, Find All, Find in Files, links in the text, selection scrolling, link safety, installed files |
| [ws-keeper.md](ws-keeper.md) | Workspace Keeper: snapshot rules, restore matching, pins, commands, services |
| [show-desktop.md](show-desktop.md) | Show Desktop: minimize/restore logic, the Super+D shortcut |
| [patch-series.md](patch-series.md) | How the patches on System76's code are kept, which upstream commit a build uses, and how the patches move to a new COSMIC version |
| [testing.md](testing.md) | `./test.sh`, what the tests cover and what is tested by hand |

Internal names are older than the folder names and stay as they are: the taskbar's binaries are
`cosmic-applet-minimize-ws` and `cosmic-app-list-ws`, its settings live in
`~/.config/minimize-ws/`, and its cache and state folders, systemd units and patch-series `NAME`
say `minimize-ws`. The other patched tools use `term-tabs`, `files-tabs`, `tray-color` and `edit-md`
for the same purpose.

## Workarounds to remove

Temporary code that works around a bug fixed upstream but not yet released. Remove each one once
the fix reaches the component it depends on.

- **Taskbar card titles: zero-width space after each space.** `wrap_title` in
  `cosmic-applet-minimize/src/preview.rs` (patch 0047). cosmic-text 0.19.0 starts the second line
  of a two-line ellipsized title with the space it broke at, so that line looked indented; the
  zero-width space moves the break behind the space. Fixed upstream in
  [cosmic-text c5d32054 "fix ellipsize on last line"](https://github.com/pop-os/cosmic-text/commit/c5d32054ad0f284873e344e0ea87902d9dc2bca8),
  not in a release yet. Remove once the cosmic-text used by libcosmic includes it (a release after
  0.19.0). The canary test `cosmic_text_ellipsize_space_bug_still_present` fails when that happens.
