# Tray colors

Tray icons keep their colours. COSMIC's notification tray paints many app icons in one flat theme
colour, so a red unread badge or a green status dot turns grey or white. With this tool those
icons look the way the app drew them.

![Tray icons before and after](../docs/media/tray-colors.svg)

## What changes

- Icons that an app hands over as an image file keep their colours.
- Icons that are meant to be monochrome (their file name ends in `-symbolic`) still follow the
  theme, as before.
- Everything else about the tray stays as it is.

## Upstream request

Proposed for COSMIC itself in [cosmic-applets #1625](https://github.com/pop-os/cosmic-applets/issues/1625).

## Install

```sh
./install.sh tray-colors
```

Built from System76's source for the COSMIC version you have installed: needs Rust and a few build
packages (the installer offers to install them). The tray applet reloads; the rest of the panel
keeps running.

## Uninstall

```sh
./install.sh --uninstall tray-colors
```

The panel goes back to COSMIC's own tray applet.

## Settings

None.

## Known limits

- An app that gives a coloured icon a `-symbolic` file name still gets the theme colour.
- Icons the app sends by icon name or as raw pixels are drawn as COSMIC always draws them.
- After a COSMIC update, run `./install.sh --update`. The taskbar's daily check reminds you if the
  taskbar is installed too.

Technical details: [docs/tray-colors.md](../docs/tray-colors.md).
