# Patch series

How the changes to System76's code ([taskbar](taskbar.md), [terminal-tabs](terminal-tabs.md),
[files-tabs](files-tabs.md), [tray-colors](tray-colors.md) and
[text-editor](text-editor.md)) are kept, changed and moved to new
upstream versions.

## How it is kept

Each patched project has a folder with:

| File | What |
|---|---|
| `<dir>/patchset.conf` | `UPSTREAM` git URL, `PACKAGE` apt package, `NAME` cache name |
| `<dir>/patches/*.patch` | The series, made with `git format-patch`, one commit per feature |
| `<dir>/patches/BASE` | Upstream commit the series was exported on |

| Folder | Upstream | Package | `NAME` (cache and state folders) |
|---|---|---|---|
| `taskbar/` | `pop-os/cosmic-applets` | `cosmic-applets` | `minimize-ws` |
| `terminal-tabs/` | `pop-os/cosmic-term` | `cosmic-term` | `term-tabs` |
| `files-tabs/` | `pop-os/cosmic-files` | `cosmic-files` | `files-tabs` |
| `tray-colors/` | `pop-os/cosmic-applets` | `cosmic-applets` | `tray-color` |
| `text-editor/` | `pop-os/cosmic-edit` | `cosmic-edit` | `edit-md` |

`lib/patchset.sh` applies the series with `git am -3`. A 3-way apply lets upstream changes near our
lines merge by themselves; only real conflicts stop.

The upstream source is cloned once to `~/.cache/<NAME>/<repo>` (blob-less clone). The upstream
commit defaults to the one of the installed package: the last `~` part of its version.

## Commands

```text
lib/patchset.sh <dir> apply  [commit]   check out <commit> in the cache clone and apply the series (build.sh, test.sh)
lib/patchset.sh <dir> check  [commit]   exit 0 if the series applies to <commit> (throwaway worktree; daily check)
lib/patchset.sh <dir> dev    [commit]   worktree ~/.cache/<NAME>/dev with the series as commits
lib/patchset.sh <dir> rebase <commit>   move the dev worktree's commits onto <commit>
lib/patchset.sh <dir> export            write the dev worktree's commits back to <dir>/patches
```

`<dir>` is `taskbar`, `terminal-tabs`, `files-tabs`, `tray-colors` or `text-editor`. Commits made by the script are
unsigned, as `patchset <patchset@localhost>`.

Tests for the script: `lib/test_patchset.sh` (local temp repos, no network; part of `./test.sh`).

## Change a patch

```sh
lib/patchset.sh taskbar dev
cd ~/.cache/minimize-ws/dev
# edit, cargo test -p cosmic-applet-minimize, git commit (or git commit --amend / fixup into the right commit)
cd -
lib/patchset.sh taskbar export
taskbar/build.sh
git -C ~/.cache/minimize-ws/cosmic-applets worktree remove ~/.cache/minimize-ws/dev
```

`dev` refuses to start when a dev worktree already exists: export or remove it first. `export`
replaces all `.patch` files in `patches/` and writes the base to `patches/BASE`.

## After an apt update

Applies to `cosmic-applets` (taskbar, tray-colors), `cosmic-term` (terminal-tabs),
`cosmic-files` (files-tabs) and `cosmic-edit` (text-editor). The daily check (`taskbar/check.sh`) notifies you and says whether the
series still applies.

1. Check: `lib/patchset.sh taskbar check`.
2. It applies: run `./install.sh --update`. Done.
3. It does not apply:

   ```sh
   lib/patchset.sh taskbar dev <old base>      # old base: taskbar/patches/BASE
   lib/patchset.sh taskbar rebase <new commit>
   # fix conflicts with normal git, then: git -C ~/.cache/minimize-ws/dev rebase --continue
   (cd ~/.cache/minimize-ws/dev && cargo test -p cosmic-applet-minimize -p cosmic-app-list)
   lib/patchset.sh taskbar export
   taskbar/build.sh
   git -C ~/.cache/minimize-ws/cosmic-applets worktree remove ~/.cache/minimize-ws/dev
   ```

The same for `terminal-tabs` with `~/.cache/term-tabs/cosmic-term` (reopen terminal windows
afterwards), `files-tabs` with `~/.cache/files-tabs/cosmic-files`, `tray-colors` with
`~/.cache/tray-color/cosmic-applets` (`cargo test -p cosmic-applet-status-area`), and
`text-editor` with `~/.cache/edit-md/cosmic-edit` (`text-editor/build.sh --test`, which also prepares the
`cosmic-files` checkout the editor builds against; reopen the Text Editor afterwards).

A conflict during `dev` stops in the dev worktree: resolve, `git add`, then
`git -C ~/.cache/<NAME>/dev am --continue`, then export.

Read the upstream commits that touched the patched files (`git log BASE..<new> -- <paths>`) even
when the series applied: a clean merge can still change behaviour a hook relies on.

## How to write a change so it keeps merging

System76 ships often, and every change carried here has to move onto each new version. The goal:
an update costs one build, and a real conflict costs minutes, not an afternoon.

- **New file over edited file.** Logic goes into new modules (`firefox_tabs.rs`, `term_tabs.rs`,
  `preview.rs`, `live_capture.rs`, `tab_publisher.rs`). Upstream files get only the hook: a `mod`
  line, an enum variant, one call.
- **Add, don't rewrite.** Append match arms, enum variants, fields and menu entries next to
  upstream's instead of reordering or reformatting existing code. Never run a formatter over an
  upstream file beyond the lines you changed; never rename upstream items.
- **Keep hooks at stable anchors:** function starts or ends, struct ends, `match` ends.
- **Use upstream's own APIs and protocols** (cctk, libcosmic, existing messages). No new crates
  unless unavoidable: a dependency upstream does not have conflicts in `Cargo.toml` and
  `Cargo.lock` on every update.
- **Never commit `Cargo.lock` in a patch** (`git checkout -- Cargo.lock` in the dev tree before
  committing). Cargo adds the lines for new dependencies at build time.
- **Degrade when upstream lacks a feature.** Check protocol versions and capabilities (see
  `MoveToExtWorkspace`) and hide the feature instead of failing.
- **One commit per feature, tests in the same series.** Pure logic gets unit tests in our own
  modules (`#[cfg(test)]`), so they move with the code.
- **When upstream ships something we carry,** drop our commit and use theirs.
- Never edit `*/patches/*.patch` by hand; always `dev` → commit → `./test.sh` → `export`.
- Match upstream style. Comments only for what the code cannot say.

## Adding another patched component

Copy the shape of `terminal-tabs/`: `patchset.conf` (`UPSTREAM`, `PACKAGE`, `NAME`), `patches/`,
and a `build.sh` that calls `lib/patchset.sh <dir> apply`, installs into `~/.local/bin` with a
per-user override (a desktop entry with the same id, or a link earlier in `PATH`), and has
`--uninstall`. Add it to the installer, the daily check, `test.sh`, and a `docs/<name>.md` page.
