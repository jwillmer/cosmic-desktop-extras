# Files tab counts (taskbar add-on)

Lets the [Taskbar](../taskbar/README.md) show what each COSMIC Files window holds: "2 tabs" when
it has several tabs, or "14 items" for the folder you are looking at when it has one.

COSMIC Files does not tell other programs about its tabs. This add-on installs a COSMIC Files with
one small addition: it writes its window title, tab count and item count to a file the taskbar
reads. Everything else is the normal COSMIC Files, built from System76's source at the version the
patches were tested on.

Only useful together with the Taskbar.

It also gives folders their own icon: a folder with a `.directory` file (the convention KDE's
Dolphin uses) shows the icon named in it, the way Music shows the music icon.

```ini
[Desktop Entry]
Icon=folder-development
```

Put that in `~/projects/.directory` and `projects` shows a code folder: `folder-development`, a
COSMIC-style folder with `</>` that this tool installs (see [icons/](icons/README.md)). `Icon=` also takes an absolute path to an image of up to 1 MB. An icon name the theme does
not have shows the plain folder.

## What the count means

- "N tabs" when the window has more than one tab.
- "M items" with one tab: the files and folders the window shows, hidden files only while "Show
  hidden files" is on, and the search results while a search runs.

## Install

```sh
./install.sh files-tabs
```

Needs Rust and a few build packages (the installer offers to install them). File manager windows
that are already open keep running the old version until you close them.

## Uninstall

```sh
./install.sh --uninstall files-tabs
```

The launcher, the dock and "Show in folder" open COSMIC's own file manager again. The desktop
icons are not affected either way.

## Settings

None.

## Known limits

- Two file manager windows with exactly the same title get no count.
- Folder icons from `.directory` show in the file manager windows and their sidebar, not in the
  desktop icons (those are COSMIC's own). Folders on network shares (smb, sftp, nfs) keep the
  plain icon. After you add or edit a `.directory` file, reload the folder that lists it (F5).
- While a large folder is still loading, the count starts at 0 and climbs until the folder is loaded.
- A COSMIC update needs no rebuild: it is always built from the tested version. `./install.sh --update`
  brings new releases, which move the patches to newer COSMIC versions.

Technical details: [docs/files-tabs.md](../docs/files-tabs.md).
