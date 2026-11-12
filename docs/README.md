# Technical documentation

How the tools work, which files they install, and how to maintain them. For what each tool does
and how to install it, start at the [main README](../README.md).

| Page | What it covers |
|---|---|
| [taskbar.md](taskbar.md) | Taskbar: behaviour in detail, second-line sources, installed files, settings files, update check |
| [launcher-entry.md](launcher-entry.md) | How any app can fill the taskbar's second line with the Unity LauncherEntry D-Bus signal |
| [terminal-tabs.md](terminal-tabs.md) | Patched COSMIC Terminal: the tab-count file it writes, installed files |
| [files-tabs.md](files-tabs.md) | Patched COSMIC Files: the tab and item-count file it writes, installed files |
| [tray-colors.md](tray-colors.md) | Patched tray applet: the icon colour rule, installed files |
| [ws-keeper.md](ws-keeper.md) | Workspace Keeper: snapshot rules, restore matching, commands, services |
| [show-desktop.md](show-desktop.md) | Show Desktop: minimize/restore logic, the Super+D shortcut |
| [patch-series.md](patch-series.md) | How the patches on System76's code are kept, changed and moved to a new COSMIC version |
| [testing.md](testing.md) | `./test.sh`, what the tests cover and what is tested by hand |

Internal names are older than the folder names and stay as they are: the taskbar's binaries are
`cosmic-applet-minimize-ws` and `cosmic-app-list-ws`, its settings live in
`~/.config/minimize-ws/`, and its cache and state folders, systemd units and patch-series `NAME`
say `minimize-ws`. The other patched tools use `term-tabs`, `files-tabs` and `tray-color` for the
same purpose.
