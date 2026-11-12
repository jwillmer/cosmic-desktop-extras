# Terminal tab counts (taskbar add-on)

Lets the [Taskbar](../taskbar/README.md) show how many tabs each COSMIC Terminal window has, for
example "3 tabs" under the window title.

COSMIC Terminal does not tell other programs about its tabs. This add-on installs a COSMIC
Terminal with one small addition: it writes its window titles and tab counts to a file the
taskbar reads. Everything else is the normal COSMIC Terminal, built from System76's source for the
version you have installed.

Only useful together with the Taskbar.

## Install

```sh
./install.sh terminal-tabs
```

Needs Rust and a few build packages (the installer offers to install them). Afterwards, close
and reopen open terminal windows: only terminals started after the install show a count.

## Uninstall

```sh
./install.sh --uninstall terminal-tabs
```

Super+T, the launcher and the dock start COSMIC's own terminal again.

## Settings

None.

## Known limits

- Tabs of split panes are added up.
- Two terminal windows with exactly the same title get no count.
- After a COSMIC update, run `./install.sh --update`. The taskbar's daily check reminds you.

Technical details: [docs/terminal-tabs.md](../docs/terminal-tabs.md).
