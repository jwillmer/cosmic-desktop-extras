# Testing

## Run

```sh
./test.sh          # everything
./test.sh --fast   # skip the Rust builds (Python and shell tests only)
```

It runs, in order:

1. The Show Desktop Python tests: `python3 -I -m unittest discover -s show-desktop`.
2. The Workspace Keeper Python tests: `python3 -I -m unittest discover -s ws-keeper`, and the
   shared Wayland client tests in `lib/test_wsk.py`.
3. The patch-series tooling: `lib/test_patchset.sh` (local temp repos, no network, no real cache),
   and the panel applet reload: `lib/test_panel_reload.sh`.
4. The taskbar patch series applied to the installed `cosmic-applets` commit, then
   `cargo test --release -q -p cosmic-applet-minimize -p cosmic-app-list`.
5. The terminal-tabs patch series applied to the installed `cosmic-term` commit, then
   `cargo test --release -q tab_publisher`.
6. The files-tabs patch series applied to the installed `cosmic-files` commit, then
   `cargo test --release -q --lib tab_publisher`.
7. The tray-colors patch applied to the installed `cosmic-applets` commit, then the
   `cosmic-applet-status-area` tests.

It stops at the first failure and prints `All tests passed.` at the end. Steps 4 to 7 need the
Rust toolchain and build dependencies from [taskbar](taskbar.md#commands), and network access for
the first clone. `--fast` skips them.

Only the Python tests:

```sh
python3 -m unittest discover -s show-desktop -v
python3 -m unittest discover -s ws-keeper -v
python3 -m unittest discover -s lib -v
```

## What is tested

| Part | Tests | Covers |
|---|---|---|
| Show Desktop | `show-desktop/test_show_desktop.py` | `decide()`: minimize open windows and record focus, other workspaces untouched, skipped apps, restore with focus last, user-minimized windows stay, new window in between, no-op cases |
| Workspace Keeper | `ws-keeper/test_ws_keeper.py`, `lib/test_wsk.py` | snapshot contents and skipped apps, snapshot JSON round trip, empty/corrupt/wrong-shape snapshot files skipped, pruning to `KEEP`, picking the snapshot (before the session, a window on workspace 2+), title normalising, matching (app id, 0.75 threshold, best match first, duplicate titles, window closed since the snapshot), target workspace that no longer exists; watch: change kind (moved/new, closed, titles only, order ignored), write decision with an injected clock (debounce, 30 s cap, 60 s for titles, closes only after a later title change or move, a new window does not confirm, a reverted change dropped, nothing before the login grace), the watch loop against a fake connection and clock (one write per burst, lost connection writes nothing, a stalled logout writes nothing, a failed write is retried, unknown compositor start holds writes until found), writing and pruning files, `main` exit status; `wsk.py`: string encoding and padding, message framing split across reads, closed socket raises, registry globals, workspace and toplevel events, closed windows removed with both handles destroyed and late events ignored, `complete()` |
| Taskbar | patches `0002`, `0003`, `0008`, `0009`, `0011`, `0012`, `0014` and `0015` (in `detail.rs`, `launcher.rs`, `media.rs`, `window_tabs.rs`, `menu_page.rs`, `live_capture/pacing.rs`, `ignore_file.rs`, `taskbar_pid.rs`, `firefox_tabs.rs`, `term_tabs.rs`, `lib.rs`, `wayland_handler.rs`) | lz4/mozlz4 decoding including corrupt input, Firefox session parsing (selected tab, empty titles, shared titles, bad indexes, invalid JSON), terminal tab files (dead processes, malformed files, missing folder), the ignore file, title shortening; patch `0003`: workspace labels for the move menu (order by coordinates, names kept); live-preview pacing: no frame created inside a ready/failed handler, one frame in flight, stale timers ignored, exhaustive over event sequences up to 6; ignore file reloaded on mtime change; pid file written; move-to-workspace capability gate with the list COSMIC sends; workspace menu pages (main entry, back, fallback when no targets), named vs numbered labels; second row: 20 real titles (Teams, Slack, VS Code, Chrome, Firefox, GitHub, dashes), source precedence, count prefix kept when a higher source wins, overrides file; LauncherEntry partial merge and clearing, per-window vs per-app, forget on sender gone; MPRIS player-to-window matching; terminal/Files files re-read only on mtime change |
| App List | patches `0005` and `0013` (`taskbar_hide.rs`) | which apps hide: a window on an active workspace (any workspace group) hides, pinned without windows stays, ignored apps stay, missing workspace info counts as shown, disabled hides nothing; pinned index mapping past hidden items; the ignore file; overflow and popup sizes, panel/popup split and pinned index exhaustive over every hidden mask up to 7 items, equal to upstream with nothing hidden; taskbar liveness from the pid file and `/proc` |
| Terminal tab counts | patch `0002` (`tab_publisher.rs`) | JSON output and escaping, written file, skip unchanged, rewrite changed, file removed on drop |
| Files tab counts | patch `0001` (`tab_publisher.rs`) | JSON output and escaping; coalescing with an injected clock: first change at once, unchanged skipped, change after the interval at once, only the latest change within the interval written at the deadline, a change reverted within the interval dropped; writer thread: written file (atomic, no temp file left), unchanged counts and title not rewritten, changed counts and title rewritten, nothing written without a title, file removed on window close and on drop |
| Tray colors | patch `0001` | the `-symbolic` file-name rule |
| `lib/panel-reload.sh` | `lib/test_panel_reload.sh` (config in a temp dir, `pgrep` and `sleep` stubbed) | applets removed from multi-line and inline plugin lists during the wait, neighbours kept, config restored byte for byte; nothing touched when the panel is not running or the applet is not listed |
| `lib/patchset.sh` | `lib/test_patchset.sh` | dev, commit and export writes the series and `BASE`; dev then export without changes is byte-identical; apply builds the tree with the patches as commits; apply twice leaves a clean tree; check passes, fails on a conflict and leaves no worktree, branch or temp dir; 3-way apply merges an upstream change inside the diff context; rebase then export moves `BASE`; a failed apply leaves no `git am` running and prints the `dev` hint |
| `taskbar/check.sh` | `lib/test_patchset.sh` (`check_sh_*`, `--print`, `dpkg-query`, `journalctl` and `gdbus` stubbed on `PATH`) | update notice with the apply verdict, upstream-change notice, `--print` does not mark the change as seen, no output when nothing changed; applet errors: panic and protocol-error counts, other applets ignored, the next check starts where the last one ended; files-tabs: silent until built, update notice with the apply verdict, silent when current |

## What is not covered

Anything visual or needing a live Wayland session is tested by hand only:

- Workspace Keeper: the Wayland requests (moving windows, the login `--watch` loop), the
  compositor start time, the watch service across a compositor restart and a logout.
- Show Desktop: the Wayland requests in `main()`.
- Taskbar: the panel UI, hover previews and live capture, the menu (including "Move to
  workspace"), click/middle-click actions.
- Terminal tab counts: that the real terminal writes the file when titles and tabs change.
- Files tab counts: that the real file manager writes the file when titles, tabs and items change.
- Tray colors: how the icons look in the panel.
- `install.sh` and the `build.sh` scripts: no automated tests. Use `./install.sh --dry-run`.
- `check.sh`: the "patches apply" branch, the terminal-tabs part and the real notification
  (`gdbus` is stubbed).
