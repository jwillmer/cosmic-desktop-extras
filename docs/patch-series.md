# Patch series

How the changes to System76's code ([taskbar](taskbar.md), [terminal-tabs](terminal-tabs.md),
[files-tabs](files-tabs.md), [tray-colors](tray-colors.md) and
[text-editor](text-editor/README.md)) are kept, changed and moved to new
upstream versions.

## How it is kept

Each patched project has a folder with:

| File | What |
|---|---|
| `<dir>/patchset.conf` | `UPSTREAM` git URL, `PACKAGE` apt package, `NAME` cache name |
| `<dir>/patches/*.patch` | The series, made with `git format-patch`, one commit per feature |
| `<dir>/patches/BASE` | Upstream commit the series was exported on and tested on. `build.sh` always builds this commit, whatever version is installed (`lib/upstream.sh`) |

| Folder | Upstream | Package | `NAME` (cache and state folders) |
|---|---|---|---|
| `taskbar/` | `pop-os/cosmic-applets` | `cosmic-applets` | `minimize-ws` |
| `terminal-tabs/` | `pop-os/cosmic-term` | `cosmic-term` | `term-tabs` |
| `files-tabs/` | `pop-os/cosmic-files` | `cosmic-files` | `files-tabs` |
| `tray-colors/` | `pop-os/cosmic-applets` | `cosmic-applets` | `tray-color` |
| `text-editor/` | `pop-os/cosmic-edit` | `cosmic-edit` | `edit-md` |

`lib/patchset.sh` applies the series with `git am -3`. A 3-way apply lets upstream changes near our
lines merge by themselves; only real conflicts stop.

The upstream source is cloned once to `~/.cache/<NAME>/<repo>` (blob-less clone). `apply` defaults
to `patches/BASE`; `check` and `dev` default to the commit of the installed package (the last `~`
part of its version), the one to move the series to.

## What the user builds

`build.sh` builds `patches/BASE` with the series, whatever version of the package is installed:
the series is only known to apply and work there, and the result is a self-contained build in
`~/.local/bin`, so it does not have to match the installed package. After the checkout,
`upstream_notice` in `lib/upstream.sh` compares the installed commit with `BASE`:

- the same commit: nothing to say;
- newer (`BASE` is its ancestor in the clone), or a commit the clone cannot place: one notice,
  "Pop!_OS has a newer <pkg> ... building the tested base", and the build goes on;
- older (an ancestor of `BASE`): the build stops and asks to update COSMIC first, because the
  series relies on what came after it.

This holds for the panel applets too (taskbar, tray-colors): an applet is its own process started
by cosmic-panel from its desktop entry, with libcosmic linked in, so there is no shared library it
has to match. A user gets a series on a newer base only through a new release of this repo
(`./install.sh --update`).

## Commands

```text
lib/patchset.sh <dir> apply  [commit]   check out <commit> in the cache clone and apply the series (build.sh, test.sh)
lib/patchset.sh <dir> check  [commit]   exit 0 if the series applies to <commit> (throwaway worktree; daily check)
lib/patchset.sh all check [<dir>...]    check every series against its installed commit, with a summary of the failures
lib/patchset.sh <dir> dev    [commit]   worktree ~/.cache/<NAME>/dev with the series as commits
lib/patchset.sh <dir> rebase <commit>   move the dev worktree's commits onto <commit>
lib/patchset.sh <dir> export            write the dev worktree's commits back to <dir>/patches
lib/recut.sh <dir> [final-ref]          re-cut into the feature layout of <dir>/patch-groups and export (text-editor)
```

`<dir>` is `taskbar`, `terminal-tabs`, `files-tabs`, `tray-colors` or `text-editor`. Commits made by the script are
unsigned, as `patchset <patchset@localhost>`.

Tests for both scripts: `lib/test_patchset.sh` (local temp repos, no network; part of `./test.sh`).

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
`cosmic-files` (files-tabs) and `cosmic-edit` (text-editor). Users need nothing: their builds stay
on `BASE`. Moving the series to the new version is a maintainer step that ends in a release:

1. Check: `lib/patchset.sh taskbar check` (against the installed commit), or every series at once
   with `lib/patchset.sh all check`. A failure names the step or the first patch that does not
   apply and git's error line; a missing `git-lfs` (some upstream repos store images in LFS) gets
   the install command.
2. It applies: still move it, so `BASE` is the commit you built and tested: `dev <old base>`,
   `rebase <new commit>`, test, `export`, as below.
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
`cosmic-files` checkout the editor builds against; reopen the Text Editor afterwards). The Text
Editor ends with `lib/recut.sh text-editor` instead of `export`: see
[Layout of the Text Editor series](#layout-of-the-text-editor-series).

A conflict during `dev` stops in the dev worktree: resolve, `git add`, then
`git -C ~/.cache/<NAME>/dev am --continue`, then export.

Read the upstream commits that touched the patched files (`git log BASE..<new> -- <paths>`) even
when the series applied: a clean merge can still change behaviour a hook relies on.

## Layout of the Text Editor series

The Text Editor carries far more code than the other tools. As one patch per change (151 at the
end) an upstream release conflicted in many patches at once, each needing its own fix. So the
series is cut by feature instead (`text-editor/patches/`, 10 patches):

- `0001`–`0009` **only add our own files**, one patch per feature (Markdown preview, Markdown
  editing, session, change history, views, editing tools, status bar, find and replace, our text
  box, menu, key and message code), each with its tests. A file that only we add cannot conflict.
- `0010` "Hook our features into the upstream files" holds **every change to upstream files**:
  `mod` lines, struct fields, one-line calls into our modules, menu entries, key bindings,
  strings and dependencies. An upstream release conflicts here or nowhere.

The rule: **a new file goes into its feature's group, every change to an upstream file goes into
the last patch.** Which file belongs to which feature is listed in `text-editor/patch-groups`,
read by `lib/recut.sh`:

```text
# comment
subject: Find and replace like Notepad++     starts a block: the commit subject
body: Whole word, extended mode, ...         optional, repeatable: one paragraph each (trailers too)
files: src/find_count.rs src/find_ui.rs      repeatable: the group's new files (paths without spaces)

subject: Hook our features into the upstream files
body: ...                                    the last block has no files: the hooks patch
```

`lib/recut.sh text-editor [final-ref]` builds the series again from the base: one commit per
group with only its files taken from `<final-ref>`, then one commit with the diff of every
changed upstream file. It fails when the result is not exactly the tree of `<final-ref>`, when a
new file is in no group, or when a group lists a file that upstream has too. Then it writes
`patches/` (`git format-patch --histogram --zero-commit --no-signature --no-stat`) and
`patches/BASE`. Without `<final-ref>` it re-cuts the dev worktree's `HEAD` on the dev worktree's
base (which `rebase` moves to the new upstream commit); with `<final-ref>` the base is
`patches/BASE`. The commits take author and date of `<final-ref>`, so re-cutting the same commit
writes the same files, whoever runs it.

### Change the Text Editor

```sh
lib/patchset.sh text-editor dev
cd ~/.cache/edit-md/dev
git config diff.algorithm histogram   # once per clone, see Histogram diff below
# edit, text-editor/build.sh --test or cargo test, then commit on top: as many commits as you like
cd -
# a new file? add it to its block in text-editor/patch-groups (a new feature: a new block before the last)
lib/recut.sh text-editor              # folds the new commits back into the 10 patches, exports
./test.sh
git -C ~/.cache/edit-md/cosmic-edit worktree remove ~/.cache/edit-md/dev
```

Do not use `lib/patchset.sh text-editor export` here: it would write your commits as extra patches
after `0010`. `recut.sh` leaves the dev worktree as it is; remove it when done.

### Move to a new upstream version

```sh
lib/patchset.sh text-editor dev <old base>     # old base: text-editor/patches/BASE
lib/patchset.sh text-editor rebase <new commit>
# conflicts can only be in 0010 (upstream files): fix, git add, git -C ~/.cache/edit-md/dev rebase --continue
text-editor/build.sh --test                    # or cargo test in the dev worktree
lib/recut.sh text-editor                       # base is the new commit now; writes patches/ and BASE
```

Fixes made while rebasing (and any commit on top) end up in the right patches by the re-cut.

### Histogram diff

The hooks patch is exported with git's histogram diff, which anchors hunks on lines that occur
once (a function name) instead of on common lines (`}`, blank lines). The hunks stay small and
apply 3-way more reliably. Git's merges (and so `rebase`) already diff this way; set it once in
the clone so `git diff`, `git show` and `git log -p` show the same hunks:
`git -C ~/.cache/edit-md/cosmic-edit config diff.algorithm histogram` (the dev worktree shares
that config).

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
