# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex and others) that help a user install, fix or
change this repository.

## What this repo is

Add-ons for the COSMIC desktop on Pop!_OS 24.04, installed per user:

| Tool name | Folder | Kind | What it does |
|---|---|---|---|
| `taskbar` | `taskbar/` | Rust, patches on `pop-os/cosmic-applets` | Windows-style taskbar (patched "Minimized Windows" applet) and a patched App List |
| `terminal-tabs` | `terminal-tabs/` | Rust, patches on `pop-os/cosmic-term` | Terminal writes tab counts for the taskbar |
| `files-tabs` | `files-tabs/` | Rust, patches on `pop-os/cosmic-files` | Files writes tab and item counts for the taskbar |
| `tray-colors` | `tray-colors/` | Rust, patch on `pop-os/cosmic-applets` | Tray icons keep their colours |
| `ws-keeper` | `ws-keeper/` | Python 3, two systemd user services | Moves windows back to their workspaces after login or a compositor crash |
| `show-desktop` | `show-desktop/` | Python 3, a COSMIC custom shortcut | Super+D minimizes/restores the current workspace |

`lib/` holds shared code: `patchset.sh` (patch series tooling), `panel-reload.sh` (reloads single
panel applets), `wsk.py` (minimal Wayland client used by ws-keeper and show-desktop).

Internal names are older than the folder names and must stay as they are: binaries
`cosmic-applet-minimize-ws`, `cosmic-app-list-ws`, `cosmic-term-tabs`, `cosmic-files-tabs`,
`cosmic-applet-status-area-color`; taskbar settings in `~/.config/minimize-ws/`; state in
`~/.local/state/{minimize-ws,term-tabs,files-tabs,tray-color,ws-keeper,show-desktop}`; caches in
`~/.cache/{minimize-ws,term-tabs,files-tabs,tray-color}`; units `minimize-ws-check.{service,timer}`,
`ws-keeper-watch.service`, `ws-keeper-restore.service`.

User docs: [README.md](README.md) and the `README.md` in each tool folder. Technical docs:
[docs/](docs/README.md).

## Installing for a user

### 1. Preflight

Run these and read the output before installing:

```sh
cat /etc/os-release | grep -E '^(NAME|VERSION_ID)='        # expect Pop!_OS 24.04
echo "$XDG_CURRENT_DESKTOP $XDG_SESSION_TYPE"              # expect COSMIC wayland
dpkg-query -W cosmic-applets cosmic-term cosmic-files       # the installed COSMIC versions
python3 --version                                           # ws-keeper, show-desktop
command -v cargo || ls ~/.cargo/bin/cargo                   # Rust, only for the patched tools
id -u                                                       # must not be 0
```

Only Pop!_OS 24.04 with COSMIC is tested. On anything else, tell the user it is untested before
going on. The patched tools need COSMIC installed from apt, because the build reads the upstream
commit from the package version.

### 2. Ask which tools

Ask the user which tools they want; do not install everything by default. Name them with the
tool names above. `terminal-tabs` and `files-tabs` are only useful together with `taskbar`.

### 3. Install

From a clone of the repo (preferred, so you can read the scripts first):

```sh
./install.sh --dry-run taskbar ws-keeper     # show what would happen
./install.sh taskbar ws-keeper               # install the named tools
```

Without a clone, the one-liner clones to `~/.local/share/cosmic-desktop-extras` and installs from
there (that folder must stay; the tools link into it):

```sh
curl -fsSL https://raw.githubusercontent.com/jwillmer/cosmic-desktop-extras/main/install.sh | bash -s -- taskbar ws-keeper
```

Run the installer in a terminal the user can see: it may ask to install build packages with
`sudo apt install` (for the patched tools) and Rust with rustup. That `sudo` step is the only one
that needs root, and only with the user's approval. The build prerequisites, if you install them
by hand:

```sh
sudo apt install libxkbcommon-dev libfontconfig-dev libfreetype-dev libwayland-dev pkg-config
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
```

**Build time:** the first `taskbar` build takes several minutes (it clones `cosmic-applets` and
compiles two applets in release mode). `terminal-tabs`, `files-tabs` and `tray-colors` take a few
minutes each. Use a long timeout or run it in the background; do not abort a build that is still
compiling.

### 4. Verify

```sh
./install.sh --list                                   # each chosen tool shows as installed
```

- **taskbar:** the panel shows one item per window instead of COSMIC's Minimized Windows icons.
  Check `ls -l ~/.local/bin/cosmic-applet-minimize-ws ~/.local/bin/cosmic-app-list-ws` and
  `systemctl --user status minimize-ws-check.timer`. Ask the user to look at the panel; you cannot
  see it.
- **terminal-tabs / files-tabs:** `command -v cosmic-term cosmic-files` points into `~/.local/bin`.
  The user must close and reopen open terminal and file manager windows; then the taskbar shows
  "N tabs".
- **tray-colors:** `ls -l ~/.local/bin/cosmic-applet-status-area-color`; coloured tray icons keep
  their colours.
- **ws-keeper:** `systemctl --user status ws-keeper-watch` is active (running), and
  `ws-keeper list` prints the windows with their workspaces.
- **show-desktop:** `command -v show-desktop`; the user presses Super+D.

## Troubleshooting

- **Build fails after a COSMIC update** (patch does not apply): check with
  `lib/patchset.sh <folder> check`. If it does not apply, follow
  [docs/patch-series.md](docs/patch-series.md) ("After an apt update"): `dev` at the old base,
  `rebase` onto the new commit, fix the conflicts, run the tests, `export`. Tell the user what
  conflicted before changing patch content.
- **Build fails on missing headers or `cargo` not found:** install the prerequisites above; rustup
  installs to `~/.cargo/bin`, which may not be on `PATH` in the current shell.
- **Taskbar not in the panel:** the taskbar replaces the "Minimized Windows" applet. Stock COSMIC has it in the
  dock (`plugins_center` of `com.system76.CosmicPanel.Dock`), not in the panel. The user adds it
  to the panel with `cosmic-settings panel-applet` (COSMIC Settings → Desktop → Panel → Applets). Do not edit the panel config files for them.
- **Taskbar disappeared or crashed:** the panel does not restart an applet that exits. Read
  `journalctl --user --since "1 hour ago" | grep -E 'cosmic-applet-minimize-ws|cosmic-app-list-ws'`
  (panics and Wayland protocol errors). The daily check reports them too:
  `taskbar/check.sh --print`. Re-running `./install.sh taskbar` rebuilds and reloads the applets.
- **Taskbar still old after an update:** `./install.sh --update`.
- **ws-keeper did not move windows:** `journalctl --user -u ws-keeper-restore -u ws-keeper-watch`,
  then `ws-keeper restore --dry-run` to see what it would match. Unpinned workspaces get renumbered;
  suggest pinning (Super+W, right-click, Pin).
- **Super+D does nothing:** check that the custom shortcut exists in COSMIC Settings and that
  `show-desktop` runs from a terminal.

## Safety rules for agents

- **Never run the installer, builds or tools as root.** Everything is per user. The only root step
  is the `apt install` of build packages, and only after the user approved it.
- **Never restart `cosmic-panel` by killing it**, and never kill `cosmic-comp` or the session. The
  build scripts reload only the applets they replace (`lib/panel-reload.sh`); the rest of the panel
  keeps running.
- **Do not edit system files** (`/usr`, `/etc`, system desktop entries). Overrides go in
  `~/.local/share/applications` and `~/.local/bin` only, which is what the build scripts do.
- **Do not delete the user's settings** in `~/.config/minimize-ws/` or the ws-keeper snapshots;
  uninstall keeps them on purpose.
- Ask before `./install.sh --uninstall` or `--update` on a working setup, and say what it changes.
- Do not open issues or pull requests on `pop-os/*` from here: Pop!_OS does not accept
  LLM-generated contributions.

## Repo layout

```text
install.sh            installer (menu, named tools, --list, --uninstall, --update, --dry-run)
test.sh               all tests (--fast skips the Rust builds)
taskbar/              patches/, patchset.conf, build.sh, check.sh (daily update check), systemd/
terminal-tabs/        patches/, patchset.conf, build.sh
files-tabs/           patches/, patchset.conf, build.sh
tray-colors/          patches/, patchset.conf, build.sh
ws-keeper/            ws-keeper.py, tests, systemd/
show-desktop/         show-desktop.py, tests
lib/                  patchset.sh, panel-reload.sh, wsk.py and their tests
docs/                 technical docs; docs/media/ images
```

## Tests

```sh
./test.sh          # everything; builds the patched tools and runs their Rust tests
./test.sh --fast   # Python and shell tests only
```

Details and coverage: [docs/testing.md](docs/testing.md). Visual behaviour (panel, previews,
menus, moving windows) is tested by hand; say so when you report.

## Contributing

- **Patched System76 code:** never edit `*/patches/*.patch` by hand. Use the patch series workflow:

  ```sh
  lib/patchset.sh taskbar dev            # worktree ~/.cache/minimize-ws/dev with the series as commits
  # edit in the dev worktree, cargo test, git commit (one commit per feature)
  lib/patchset.sh taskbar export         # writes taskbar/patches/*.patch and patches/BASE
  ./test.sh
  ```

  One commit per feature, with its tests in the same series. Put new logic in new files and keep
  hooks in upstream files small, so the series keeps applying to new COSMIC versions. Never commit
  `Cargo.lock` in a patch. Rules: [docs/patch-series.md](docs/patch-series.md).
- **Python tools:** standard library only, run with `python3 -I`. Keep logic testable without
  Wayland (see `decide()` in `show-desktop.py`) and add unit tests next to the code.
- Update the tool's `README.md` (user view) and its `docs/` page (technical view) with any
  behaviour change. Do not claim features the code does not have.
- Match the style of the surrounding code and docs.
