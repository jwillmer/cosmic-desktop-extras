# COSMIC Desktop Extras

A Windows-style taskbar and a few small helpers for the COSMIC desktop on Pop!_OS: see every
window on your workspace at a glance, keep windows on their workspaces across logins, and show the
desktop with Super+D.

![The COSMIC panel with the taskbar](docs/media/hero.svg)

Pick the tools you want; each one installs on its own and uninstalls back to stock COSMIC.

## What you get

### Taskbar

One button per window on the current workspace, with icon, title and a second line that tells you
something: "3 tabs", the song that is playing, "4 unread". Live preview on hover, middle-click to
close, right-click to move a window to another workspace. The dock stops showing the same apps
twice.

[![Taskbar close-up](docs/media/taskbar.svg)](taskbar/README.md)

Install: `./install.sh taskbar` · [More about the taskbar](taskbar/README.md)

### Terminal tab counts and Files tab counts (taskbar add-ons)

The taskbar shows "3 tabs" for COSMIC Terminal windows, and "2 tabs" or "14 items" for COSMIC Files
windows.

Install: `./install.sh terminal-tabs files-tabs` ·
[Terminal](terminal-tabs/README.md) · [Files](files-tabs/README.md)

### Tray colors

Tray icons keep their colours: a red unread badge stays red instead of turning into a flat
monochrome icon.

[![Tray icons before and after](docs/media/tray-colors.svg)](tray-colors/README.md)

Install: `./install.sh tray-colors` · [More about tray colors](tray-colors/README.md)

### Workspace Keeper

Remembers which workspace each window is on and moves the windows back after you log in again or
after the desktop crashes and restarts.

[![Windows back on their workspaces](docs/media/ws-keeper.svg)](ws-keeper/README.md)

Install: `./install.sh ws-keeper` · [More about Workspace Keeper](ws-keeper/README.md)

### Show Desktop

Super+D minimizes the windows of the current workspace, like on Windows. Press it again and they
come back, with the window you were in on top.

[![Super+D before and after](docs/media/show-desktop.svg)](show-desktop/README.md)

Install: `./install.sh show-desktop` · [More about Show Desktop](show-desktop/README.md)

## Quick install

Open a terminal and run:

```sh
curl -fsSL https://raw.githubusercontent.com/jwillmer/cosmic-desktop-extras/main/install.sh | bash
```

A menu lets you pick the tools; Taskbar, Workspace Keeper and Show Desktop are preselected. To skip the menu, name the
tools:

```sh
curl -fsSL https://raw.githubusercontent.com/jwillmer/cosmic-desktop-extras/main/install.sh | bash -s -- taskbar ws-keeper
```

The one-liner clones the repo to `~/.local/share/cosmic-desktop-extras`. The tools link into that
folder, so leave it in place.

Prefer to look before you run? Clone the repo and use the installer from there:

```sh
git clone https://github.com/jwillmer/cosmic-desktop-extras.git
cd cosmic-desktop-extras
./install.sh --dry-run all     # show what would happen
./install.sh                   # menu
```

All installer commands:

```text
./install.sh                         interactive menu, recommended tools preselected
./install.sh taskbar ws-keeper ...   install the named tools
./install.sh all                     install everything
./install.sh --list                  tools and whether they are installed
./install.sh --uninstall <tool...>   back to stock COSMIC (your settings files are kept)
./install.sh --update                git pull, then re-install/rebuild the installed tools
./install.sh --dry-run <...>         show what would happen
```

Tool names: `taskbar`, `terminal-tabs`, `files-tabs`, `tray-colors`, `ws-keeper`, `show-desktop`.

### What the build takes

The taskbar, the two tab-count add-ons and tray colors are compiled from System76's source code,
for exactly the COSMIC version you have installed. That needs Rust and a few `-dev` packages; the
installer offers to install them and asks for your password only for that step. The first taskbar
build takes several minutes.

Workspace Keeper and Show Desktop need only Python 3, which Pop!_OS already has.

## Requirements

- **Tested on Pop!_OS 24.04 with COSMIC.**
- Other distributions with COSMIC are untested. The patched tools read the COSMIC version from
  the apt package (`cosmic-applets`, `cosmic-term`, `cosmic-files`), so they need a Debian-style
  COSMIC install.
- Disk space for System76's source code and the Rust build of the patched tools, kept under
  `~/.cache` so updates build faster.

## Uninstall

```sh
./install.sh --uninstall taskbar ws-keeper     # or any other tool names
```

Each tool goes back to stock COSMIC. Your settings files (for example `~/.config/minimize-ws/`)
are kept, so a reinstall picks them up again.

## FAQ

**Is it safe? Does it change system files?**
No system files are replaced. Everything installs for your user only, in `~/.local` and
`~/.config`. A patched app is a user copy that COSMIC picks up instead of the system one (a desktop
entry with the same id, or a link in `~/.local/bin`). Uninstall removes those copies and COSMIC
uses its own apps again. The only step that needs `sudo` is installing the build packages, and the
installer asks first.

**What happens when COSMIC updates?**
The patched tools keep running the version they were built for until you rebuild them. The taskbar
checks once a day and notifies you when COSMIC was updated (and whether the patches still fit the
new version). Then run `./install.sh --update`.

**Why patches instead of a separate app?**
COSMIC's "Minimized Windows" applet and App List already do most of the work: window tracking,
icons, previews, the panel look. Patching them keeps everything that already works and matches
the rest of the panel, instead of rebuilding it. Each patch is small and kept as its own commit, so
it can be moved to a new COSMIC version quickly. Terminal and Files
have no way to tell other programs how many tabs they have, so those need a small patch too.

**Can I use just one tool?**
Yes. Every tool installs and uninstalls on its own. The only dependency: the terminal and Files tab
counts are shown by the taskbar, so they are only useful with it.

**Something broke. How do I go back?**
`./install.sh --uninstall <tool>` puts COSMIC's own version back. See the tool's page for logs and
known limits.

## Documentation

| Page | For |
|---|---|
| [taskbar/README.md](taskbar/README.md) | Taskbar features and settings |
| [terminal-tabs/README.md](terminal-tabs/README.md) | Terminal tab counts |
| [files-tabs/README.md](files-tabs/README.md) | Files tab counts |
| [tray-colors/README.md](tray-colors/README.md) | Tray colors |
| [ws-keeper/README.md](ws-keeper/README.md) | Workspace Keeper |
| [show-desktop/README.md](show-desktop/README.md) | Show Desktop |
| [docs/](docs/README.md) | Technical documentation: how each tool works, installed files, settings reference, patch maintenance, tests |
| [docs/launcher-entry.md](docs/launcher-entry.md) | For app developers: put your own text on the taskbar's second line |
| [AGENTS.md](AGENTS.md) | For AI coding agents installing or working on this repo |

Run the tests with `./test.sh` (`./test.sh --fast` skips the Rust builds). See
[docs/testing.md](docs/testing.md).

## Credits and license

Built on System76's [COSMIC](https://github.com/pop-os/cosmic-epoch) desktop. The taskbar and tray
colors patch [pop-os/cosmic-applets](https://github.com/pop-os/cosmic-applets), the tab-count
add-ons patch [pop-os/cosmic-term](https://github.com/pop-os/cosmic-term) and
[pop-os/cosmic-files](https://github.com/pop-os/cosmic-files). All of them are GPL-3.0, and so is
this project: see [LICENSE](LICENSE).

This project is not affiliated with or endorsed by System76.
