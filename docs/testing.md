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
8. `text-editor/build.sh --test`: the text-editor patch series applied to the installed
   `cosmic-edit` commit (and its one-line `cosmic-files` patch), then the 254 unit tests (and 1 ignored) of the
   patched editor (`cargo test --release --bin cosmic-edit`).

It stops at the first failure and prints `All tests passed.` at the end. Steps 4 to 8 need the
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
| Taskbar | patches `0002`, `0003`, `0008`, `0009`, `0011`, `0012`, `0014` and `0015` (in `detail.rs`, `launcher.rs`, `media.rs`, `window_tabs.rs`, `menu_page.rs`, `live_capture/pacing.rs`, `ignore_file.rs`, `taskbar_pid.rs`, `firefox_tabs.rs`, `term_tabs.rs`, `lib.rs`, `wayland_handler.rs`) | lz4/mozlz4 decoding including corrupt input, Firefox session parsing (selected tab, empty titles, bad indexes, invalid JSON), Firefox window matching (shared titles told apart by recent titles, no count when they cannot be, a stale then fresh session file, blank windows), terminal tab files (dead processes, malformed files, missing folder), the ignore file, title shortening; patch `0003`: workspace labels for the move menu (order by coordinates, names kept); live-preview pacing: no frame created inside a ready/failed handler, one frame in flight, stale timers ignored, exhaustive over event sequences up to 6; ignore file reloaded on mtime change; pid file written; move-to-workspace capability gate with the list COSMIC sends; workspace menu pages (main entry, back, fallback when no targets), named vs numbered labels; second row: 20 real titles (Teams, Slack, VS Code, Chrome, Firefox, GitHub, dashes), source precedence, count prefix kept when a higher source wins, overrides file; LauncherEntry partial merge and clearing, per-window vs per-app, forget on sender gone; MPRIS player-to-window matching; terminal/Files files re-read only on mtime change; patch `0037`: blank tabs stored with their URL as title, a unique title counted on first sight among many blank windows, a window whose tab switch the file has not seen takes the session window no other window shows, never another window's count; patch `0038` (`options.rs`, `lib.rs`): options file defaults, true/false, bad values keep the default; without the second line no row 2 (Firefox tabs, media), tab count as `(n) ` prefix for Firefox, Terminal and Files tabs, a long title measured on one line; hover does not start the preview when it is off |
| App List | patches `0005` and `0013` (`taskbar_hide.rs`) | which apps hide: a window on an active workspace (any workspace group) hides, pinned without windows stays, ignored apps stay, missing workspace info counts as shown, disabled hides nothing; pinned index mapping past hidden items; the ignore file; overflow and popup sizes, panel/popup split and pinned index exhaustive over every hidden mask up to 7 items, equal to upstream with nothing hidden; taskbar liveness from the pid file and `/proc` |
| Terminal tab counts | patch `0002` (`tab_publisher.rs`) | JSON output and escaping, written file, skip unchanged, rewrite changed, file removed on drop |
| Files tab counts | patch `0001` (`tab_publisher.rs`) | JSON output and escaping; coalescing with an injected clock: first change at once, unchanged skipped, change after the interval at once, only the latest change within the interval written at the deadline, a change reverted within the interval dropped; writer thread: written file (atomic, no temp file left), unchanged counts and title not rewritten, changed counts and title rewritten, nothing written without a title, file removed on window close and on drop |
| Tray colors | patch `0001` | the `-symbolic` file-name rule |
| Text Editor | patches `0002`, `0005`, `0006`, `0008`, `0010`, `0013`, `0016`, `0018`, `0021`, `0022`, `0024`–`0027`, `0029`, `0031`, `0033`, `0035`, `0036`, `0039`–`0042`, `0044`, `0046`, `0047`, `0049`–`0052`, `0054`, `0055`, `0057`–`0067`, `0069`–`0072`, `0074`, `0076`, `0078`–`0084`, `0088`–`0095`, `0098`, `0100`, `0101`, `0104`–`0106`, `0108` (281 Rust unit tests and 1 ignored, named after the behaviours) | two views, newer: clones mirror edits both ways (also unsaved and untitled tabs), saving or Save As in one saves both, reload acts on all clones, clones with different drafts stay apart, a mirrored edit unfolds hidden text, restored clones stay paired, the divider keeps a minimum width, the dragged tab is the one under the pointer, only a view a drop moves to is highlighted, synchronized scrolling sideways; scroll sync both ways: the preview leads the editor without echo, wrapped lines, hard-wrapped prose, tables row by row, measured block positions; outline: scrolls to the current heading, follows the preview in Preview, labels without images; open `<details>` kept by heading, summary and source, also when a block is added above or the open one is edited; images inline in headings, lists and tables; Mermaid flowchart and sequence diagrams, invalid code stays code; web images: nothing fetched when off, https only, each URL once, size and type limits, the log names the host only; folds restored by header text; column blocks with tabs: paste, typing, copy and delete line up, the highlight covers the cut part of a tab; closing tabs: Close all, others and to the right, one prompt for unsaved tabs, Cancel closes nothing, Save all stops at a cancelled Save As, Discard all drops the drafts, an empty tab is left; two views: move and clone, a view left empty closes the split, a clone moved or cloned into the view of its twin finds that twin, closing a whole view keeps the other view's tab; preview selection: selection across blocks, word, block and Shift+click selection, copy with list markers, alert titles and tab-separated tables, copy from the current text, hit tests in scrolled code and tables, odd documents copy without panicking, highlight contrast, the session keeps the views and loads older sessions into one; compare with another tab and the two views; folding: folded lines take no height and keep their text, fold ranges for brackets, indentation and Markdown sections, chevrons toggle one block, edits, undo and column blocks unfold, cursor skips folds, copy and Save include hidden text, folding drops a selection in hidden text and edits unfold first; column selection: Alt+drag and Alt+Shift+arrows, typing, Backspace, copy and paste on every line, short lines skipped, one undo step, a plain click leaves block mode, a copied block pastes as a block at a single cursor; whitespace and line endings: marks without moving text, detection (LF, CRLF, mixed), conversion as one undo step, Enter and Save keep CRLF; JSON: format and minify keep key order and number text, one undo step, errors with line and column, trailing commas, size limit, menu only on JSON tabs; window size kept and clamped; outline headings; scroll sync positions; code block colours (known, unknown and missing tags, size limit); bringing the window forward; changed on disk: clean tabs reload, dirty tabs show the bar, save never overwrites an unseen change (also with the bar up, a rename-replace found by inode), redo of a reload shows the tab saved, restored text not shifted left, the bar survives a restart; snapshots: 2 s after a pause, at least every 15 s, nothing without changes, failures retried and make quit prompt, stale results ignored; README HTML: inline badge rows, centred blocks and headings, details, stripped tags, alerts, footnotes; gutter click opens compare; compare with saved: removed and added lines with context, untitled against empty, nothing to compare when unchanged, compare tabs not restored, reopening focuses the tab; changed-text tint: changed words only, new lines whole, saved changes untinted, undo removes it, multibyte ranges; changed lines: orange until saved, green after, undo to the saved text clears orange, inserted and deleted lines, restored drafts against disk, reload clears, stale diff results ignored, longer debounce for large files; session restore: closing the window keeps drafts without a prompt, closing a tab still asks, discard deletes the draft, failed draft or session writes bring the save prompt back, unreadable or corrupt session files and drafts are never overwritten or deleted, restore order and active tab, untitled and missing-file drafts, file changed on disk, only changed drafts written, private permissions; views on open, empty file in Source, Save As keeps the view, Preview read-only, scroll per tab, Split debounce; Markdown detection by extension, view switching (Ctrl+Shift+V, Ctrl+Alt+V), link resolution (relative, `../`, `file://`, percent-encoding, anchors) and the link safety rules (schemes, `mailto` fields, `.desktop`, executables, folders, media types), file arguments of a second launch and focusing an open tab |
| `lib/panel-reload.sh` | `lib/test_panel_reload.sh` (config in a temp dir, `pgrep` and `sleep` stubbed) | applets removed from multi-line and inline plugin lists during the wait, neighbours kept, config restored byte for byte; nothing touched when the panel is not running or the applet is not listed |
| `lib/patchset.sh` | `lib/test_patchset.sh` | dev, commit and export writes the series and `BASE`; dev then export without changes is byte-identical; apply builds the tree with the patches as commits; apply twice leaves a clean tree; check passes, fails on a conflict and leaves no worktree, branch or temp dir; 3-way apply merges an upstream change inside the diff context; rebase then export moves `BASE`; a failed apply leaves no `git am` running and prints the `dev` hint; apply refuses an install older than `BASE` with the update hint |
| `taskbar/check.sh` | `lib/test_patchset.sh` (`check_sh_*`, `--print`, `dpkg-query`, `journalctl` and `gdbus` stubbed on `PATH`) | update notice with the apply verdict, upstream-change notice, `--print` does not mark the change as seen, no output when nothing changed; applet errors: panic and protocol-error counts, other applets ignored, the next check starts where the last one ended; files-tabs and text-editor: silent until built, update notice with the apply verdict, silent when current |

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
- Text Editor: how the rendered page looks, the view buttons, menu entries and shortcuts,
  opening links, fonts and IME input, the D-Bus hand-off to the running editor, the snapshot and
  diff timers, the gutter bars, the word tint and the "changed on disk" bar, code block colours,
  scroll sync, the outline panel, whitespace marks, fold chevrons, the restored window size, the
  tab right-click menu, the two-view layout with its active-view line and synchronized scrolling,
  dragging the divider and tabs, Mermaid diagrams and images from the web, the preview selection
  highlight, drag and auto-scroll, and the check for changes on disk when the window gets focus.
- `install.sh` and the `build.sh` scripts: no automated tests. Use `./install.sh --dry-run`.
- `check.sh`: the "patches apply" branch, the terminal-tabs part and the real notification
  (`gdbus` is stubbed).
