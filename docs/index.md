---
title: Windows-style taskbar and extras for the COSMIC desktop
description: >-
  A Windows-style taskbar with live window previews for the COSMIC desktop on Pop!_OS 24.04, plus
  Workspace Keeper, Super+D Show Desktop, coloured tray icons and a Text Editor with Markdown
  preview and session restore. Free, open source, per user.
---

# A Windows-style taskbar for the COSMIC desktop

<p class="lead">See every window on your workspace at a glance with live previews, move windows
between workspaces from a right-click, keep windows on their workspaces across logins, and show
the desktop with Super+D. For COSMIC on Pop!_OS 24.04 (Wayland).</p>

<div class="hero"><img src="media/hero.svg" width="1280" height="220" alt="The COSMIC panel with the taskbar, coloured tray icons and clock"></div>

Pick the tools you want; each one installs on its own and uninstalls back to stock COSMIC.

<div class="buttons">
  <a class="primary" href="#install">Install</a>
  <a href="https://github.com/jwillmer/cosmic-desktop-extras">GitHub repository</a>
  <a href="technical.html">Technical docs</a>
</div>

## Taskbar

One button per window on the current workspace, with icon, title and a second line that tells you
something: "3 tabs", the song that is playing, "4 unread". Middle-click to close. The dock stops
showing the same apps twice.

![Taskbar close-up](media/taskbar.svg)

**Live preview on hover.** Rest the pointer on a window and a live picture of it appears, so you
find the right one without switching to it. Minimized windows show their last picture.

![Live preview of a window when hovering its taskbar item](media/taskbar-preview.svg)

**Move a window to another workspace.** Right-click it in the taskbar, pick "Move to workspace" and
choose the target by name or number. No dragging through the workspace overview.

![Right-click menu with Move to workspace](media/taskbar-menu.svg)

[More about the taskbar](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/taskbar/README.md)

### Terminal and Files tab counts

Add-ons for the taskbar: it shows "3 tabs" for COSMIC Terminal windows, and "2 tabs" or "14 items"
for COSMIC Files windows.
[Terminal](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/terminal-tabs/README.md) ·
[Files](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/files-tabs/README.md)

## Tray colors

Tray icons keep their colours: a red unread badge stays red instead of turning into a flat
monochrome icon.

![Tray icons before and after](media/tray-colors.svg)

[More about tray colors](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/tray-colors/README.md)

## Text Editor

COSMIC Text Editor with the comforts of Notepad++. Markdown files open rendered: switch between
Preview, Source and Split with Ctrl+Alt+1 / 2 / 3, with coloured code blocks and an outline of the
headings. Files open as tabs in one window, and every tab of your last session comes back, unsaved
drafts included.

![Text Editor in Split view](media/text-editor.svg)

**Never lose an edit.** Changed lines and words stay marked until you save. When another program
changes a file you are editing, a bar asks Reload, Keep mine or Compare instead of one version
silently winning.

**Tools for code and config files.** JSON format, minify and validate, visible whitespace and line
endings, column selection with Alt+drag, code folding, Close all tabs, and two views side by side
with synchronized scrolling and Compare.

![Two views side by side, each with its own tabs](media/text-editor-views.svg)

[More about the Text Editor](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/text-editor/README.md)

## Workspace Keeper

Remembers which workspace each window is on and moves the windows back after you log in again or
after the desktop crashes and restarts.

![Windows back on their workspaces](media/ws-keeper.svg)

[More about Workspace Keeper](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/ws-keeper/README.md)

## Show Desktop

Super+D minimizes the windows of the current workspace, like on Windows. Press it again and they
come back, with the window you were in on top.

![Super+D before and after](media/show-desktop.svg)

[More about Show Desktop](https://github.com/jwillmer/cosmic-desktop-extras/blob/main/show-desktop/README.md)

## Install

Open a terminal and run:

```sh
curl -fsSL https://raw.githubusercontent.com/jwillmer/cosmic-desktop-extras/main/install.sh | bash
```

A menu lets you pick the tools. Uninstall any tool with `./install.sh --uninstall <tool>`.
Everything installs for your user only; no system files are replaced. Tested on Pop!_OS 24.04
with COSMIC. Build steps, requirements and the FAQ:
[README on GitHub](https://github.com/jwillmer/cosmic-desktop-extras#quick-install).

## Learn more

- [Source code and issues on GitHub](https://github.com/jwillmer/cosmic-desktop-extras)
- [Blog post: why and how it was built](https://jwillmer.de/blog/projects/cosmic-desktop-extras.html)
- [Technical documentation](technical.md): how each tool works, installed files, settings, patch maintenance, tests
- [For app developers](launcher-entry.md): put your own text on the taskbar's second line

Built on System76's [COSMIC](https://github.com/pop-os/cosmic-epoch) desktop. GPL-3.0. This
project is not affiliated with or endorsed by System76.
