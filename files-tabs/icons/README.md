# folder-development icon

A "code folder" icon in the style of the COSMIC icon theme's special folders, for a projects or
source folder: put `Icon=folder-development` in the folder's `.directory` file. `build.sh`
installs both files into `~/.local/share/icons/hicolor/scalable/places/`; the COSMIC theme has no
icon of that name, so the lookup falls through to hicolor and finds them.

The folder shape and colours are copied from COSMIC's `folder-music.svg` and `folder-music-symbolic.svg`
(Copyright 2022 System76), with a `</>` glyph in place of the note. As a derived work, these two
files are licensed under CC BY-SA 4.0, like the COSMIC icons.
