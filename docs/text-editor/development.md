# Text Editor: development (technical)

Part of the [Text Editor technical docs](README.md). What each patch of the series holds; how the series is kept and moved to a new COSMIC version is in [patch-series.md](../patch-series.md#layout-of-the-text-editor-series).

## Patch contents

The patches 0001–0009 only add our own files under `src/`, one patch per feature, with the
feature's tests; 0010 holds every change to upstream files. Why and how to work with it:
[patch-series.md](../patch-series.md#layout-of-the-text-editor-series). The earlier series of 151
patches, one per change, is in git history up to
[b9c3353](https://github.com/jwillmer/cosmic-ext-desktop-extras/tree/b9c3353/text-editor/patches).

| Patch | What |
|---|---|
| `0001-Markdown-preview-…` | `markdown*.rs`, `selectable_rich.rs`: views, parsing, HTML blocks, images, Mermaid, code colours, outline, scroll map, preview selection and its scrolling, bare web addresses as links |
| `0002-Markdown-editing-…` | `md_*.rs`, `slash_menu.rs`, `slash_popup.rs`: "/" menu, Bold and Italic, list, link and code helpers, tables, shortcuts panel |
| `0003-Session-restore-…` | `session.rs`, `single_instance.rs`, `disk_change.rs`: session and drafts, one window, files changed on disk |
| `0004-Change-history-and-compare` | `change_history.rs`, `compare.rs`: change marks and tint, Compare with saved, with another tab and the two views |
| `0005-Two-views-tabs-and-the-sidebar` | `views.rs`, `mirror.rs`, `close_tabs.rs`, `tab_view.rs`, `app_tabs.rs`, `app_focus.rs`, `sidebar.rs` |
| `0006-Editing-tools-…` | `whitespace.rs`, `column_select.rs`, `folding.rs`, `json_tools.rs`, `tab_*.rs`, `language.rs`: whitespace and line endings, column selection, folding, JSON, language per tab, large files, tab file menu |
| `0007-Status-bar-and-Go-to-line` | `status_bar.rs`, `app_status.rs`, `goto_line.rs` |
| `0008-Find-and-replace-like-Notepad` | `find_*.rs`, `tab_find.rs`, `config_ext.rs`: the Find and Replace window, Find All and the Search results panel, Find in Files |
| `0009-Our-text-box-menu-key-and-message-code` | `text_box/`, `menu_ext.rs`, `key_bind_ext.rs` (and its snapshot), `app_update.rs`, `shell.rs`: our drawing, keys, links in the text, selection scrolling, menus, key bindings and update arms |
| `0010-Hook-our-features-into-the-upstream-files` | The only patch that changes upstream files: `Cargo.toml`, the English strings, `main.rs`, `tab.rs`, `text_box.rs`, `menu.rs`, `config.rs`, `key_bind.rs` (`mod` lines, fields, one-line calls, menu entries, keys). An upstream release can conflict only here |
| `patches-cosmic-files/0001-…` | One-line fix so cosmic-files (the editor's file dialogs) builds with `single-instance`. `build.sh` clones cosmic-files at the revision in the editor's `Cargo.lock` to `~/.cache/edit-md/cosmic-files` and applies it; the hooks patch 0010 points Cargo there |
| `patches-cosmic-files/0002-…` | Open dialog: Enter on the typed path of an existing file opens it; test |
| `patches-cosmic-files/0003-…` | File dialogs: typing `/` or `~` in the file list opens the location box with it; test |
| `patches-cosmic-files/0004-…` | File dialogs: Ctrl+V opens, shows or fills in a path from the clipboard (new `src/paste_path.rs`, hook in `dialog.rs`); Ctrl+L and the edit button select the path (`tab.rs`); tests |
| `patches-cosmic-files/0005-…` | File dialogs: Escape in the location box closes only the box, not the dialog (`dialog.rs`); test |
