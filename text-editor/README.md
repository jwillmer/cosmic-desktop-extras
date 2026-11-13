# Text Editor

COSMIC Text Editor with the comforts of Notepad++: Markdown files open rendered, every file opens
as a tab in one window, the tabs of your last session come back with their unsaved changes, and
changed lines are marked until you save. It also has a heading outline for Markdown, JSON
formatting, visible whitespace, column selection and code folding. Everything else is the normal COSMIC Text Editor, built
from System76's source for the version you have installed.

![COSMIC Text Editor in Split view: Markdown source left, rendered preview right](../docs/media/text-editor.svg)

## Markdown views

Every Markdown tab has three views. Pick one with the three buttons at the right of the header bar
(the active one is highlighted) or at the top of the View menu; both show only for Markdown files.

- **Preview:** the rendered page, read-only. Markdown files open here.
- **Source:** the plain text, as before.
- **Split:** the editor on the left and a live preview on the right.

| Keys | What it does |
|---|---|
| Ctrl+Shift+V | Switch between Preview and Source |
| Ctrl+Alt+V | Switch between Split and Source |

The preview shows headings, lists, task lists, tables, code blocks and local images, and the HTML
that READMEs use: centred logos, badge rows, fold-out `<details>` sections, GitHub alerts
(`> [!NOTE]`) and footnotes. Code blocks with a language tag (`json`, `bash`, `python`, ...) get
the same syntax colours as in the editor. It is drawn by the editor itself, without a built-in browser, so the
editor still opens instantly.

In Split view the preview scrolls along with the editor (View, **Sync preview scrolling**; one
way, and only roughly inside long paragraphs and tables). View, **Outline** (Ctrl+Alt+O) shows the
file's headings in a panel at the left: the one you are in is highlighted, a click jumps to it.

Links are safe to click: web and `mailto` links open in your browser or mail app, links to text and
Markdown files open in the editor, images and PDFs open in their viewer. Anything that could run a
program (scripts, `.desktop` files, other link types) is ignored.

## One window

Opening a file while the editor runs (double-click, "Open with", `cosmic-edit file.md`) adds a tab
to the running window, which comes forward with focus, instead of opening a new one. A file that is already open gets its tab
focused. File, New window still opens a second window.

## Session restore

Like Notepad++: the editor brings back every tab from last time, including unsaved changes and
untitled drafts, with cursor, scroll position and Markdown view. The window opens at its last size,
maximized if it was; where it sits on screen is up to COSMIC (Wayland apps cannot place windows).

- Closing the window does not ask to save: your drafts are kept. Closing a single tab with unsaved
  changes still asks.
- Drafts are saved a few seconds after you stop typing, at least every 15 seconds while you type,
  and when you quit. A crash loses only the last seconds.
- If a draft cannot be written (disk full), closing the window asks to save as before.

## Changes

Like Notepad++ change history, a thin bar left of the line numbers shows what you changed:
**orange** for unsaved changes, **green** for changes saved in this session. Inside an orange line
the changed words are tinted, so you see what you typed without reading the whole line.

When another program changes a file you have unsaved changes in, the editor does not throw your
work away. A bar above the text asks: **Reload** (take the version on disk; Undo brings yours
back), **Keep mine** (your next Save overwrites it) or **Compare**. Save never silently overwrites a
change it has not shown you. A tab without unsaved changes simply reloads, as before.

![Changed lines, tinted words and the "changed on disk" bar](../docs/media/text-editor-changes.svg)

**Compare with saved** (File menu or right-click, or a click on an orange bar) opens a tab with your
unsaved changes against the file on disk: removed lines red, added lines green.

![Compare with saved](../docs/media/text-editor-compare.svg)

## Editing tools

**JSON** (on `.json` tabs, Edit menu):

| Keys | What it does |
|---|---|
| Ctrl+Alt+Shift+F | Format JSON (indented with the tab width) |
| Ctrl+Alt+Shift+M | Minify JSON |
| Edit, Validate JSON | Shows line, column and reason of the first error, with Go to |

Key order and numbers stay exactly as written, and Undo brings the old text back in one step.
Files over 20 MB are not touched.

**Whitespace and line endings** (View menu): Show whitespace marks spaces with dots and tabs with
arrows, Show line endings marks each line end. The Line endings submenu shows whether the file uses
LF, CRLF, CR or a mix, and converts to LF or CRLF in one undo step. Enter uses the file's own line
ending.

**Column selection:** hold Alt and drag, or press Alt+Shift+arrows, to select a block of columns
over several lines. Typing, Backspace, Delete, Copy, Cut and Paste then work on every line, in one
undo step. Not available with vi key bindings.

**Folding:** click the arrow right of a line number (▸ folded, ▾ shows on hover or on the cursor
line), or use View, Fold (Ctrl+Shift+[) and Unfold (Ctrl+Shift+]), Fold all and Unfold all. It
folds JSON and code blocks, indented blocks and Markdown sections; a folded line ends in `…`.
Folding only hides lines, the text is never changed, and folds are not kept after a restart.
Editing, Undo, a search hit or a column selection inside a fold opens it again.

## Upstream request

Markdown preview is requested for COSMIC itself in
[cosmic-edit #247](https://github.com/pop-os/cosmic-edit/issues/247), session restore in
[cosmic-edit #94](https://github.com/pop-os/cosmic-edit/issues/94). Add a 👍 if you want them too.

## Install

```sh
./install.sh text-editor
```

Built from System76's source for the COSMIC version you have installed: needs Rust and a few build
packages (the installer offers to install them). Afterwards, close and reopen the Text Editor:
only editor windows opened after the install use it.

## Uninstall

```sh
./install.sh --uninstall text-editor
```

The launcher, the dock and double-clicking a file start COSMIC's own Text Editor again. Your
session and drafts stay on disk.

## Settings

In the Text Editor's Settings:

- **Open Markdown files in:** Source, Preview or Split. The default is Preview. An empty file always
  opens in Source, so you can start typing straight away.
- **Restore previous session:** on by default. Off: the editor behaves as before and the stored
  session is deleted.
- **Show changed lines** and **Highlight changed text:** on by default.

## Known limits

- Not shown in the preview yet: images from the web (a small label with their description shows
  instead), images inside lists and tables, Mermaid diagrams.
- Split view scroll sync goes one way only: scrolling the preview does not move the editor.
- The window position is not restored, only its size.
- After a COSMIC update, run `./install.sh --update`. The daily update check reminds you.

Technical details: [docs/text-editor.md](../docs/text-editor.md).
