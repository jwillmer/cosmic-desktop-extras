# Taskbar second row via Unity LauncherEntry

The [taskbar](taskbar.md) shows two rows per window. Any app can fill row 2 by emitting the
standard Unity LauncherEntry signal on the session bus. KDE, Dash-to-Dock, Plank and other docks read
the same signal and ignore keys they don't know, so an app that sends it works there too.

## Signal

`com.canonical.Unity.LauncherEntry.Update(s app_uri, a{sv} properties)` from any sender, on any
object path.

- `app_uri`: `application://<desktop id>.desktop`, e.g. `application://org.example.App.desktop`.
  Matched against the window's Wayland app id, case ignored, without `.desktop`.
- Updates are partial: each signal carries only the keys that changed. They are merged into the
  last known state.

## Keys

Standard keys (shared with other docks):

| Key | Type | Meaning |
|---|---|---|
| `count` | x | unread or pending count |
| `count-visible` | b | show the count |
| `progress` | d | 0..1 |
| `progress-visible` | b | show the progress |
| `urgent` | b | stored, not shown yet |

Extension keys of this taskbar:

| Key | Type | Meaning |
|---|---|---|
| `x-detail` | s | free text for row 2 |
| `x-busy` | s | label of a running operation, e.g. `Cut` |
| `x-busy-since` | x | unix seconds when it started; row 2 then shows the elapsed time |
| `x-window-title` | s | target one window by its exact title; without it the entry applies to the whole app |

An empty string for `x-detail`, `x-busy` or `x-window-title`, or `x-busy-since` = 0, clears that
key.

## Targeting

- State is kept per (app, `x-window-title` or none).
- An app with several windows sends one Update per window, each with its own `x-window-title`.
- An entry without `x-window-title` is shown on the app's focused (or last focused) window only.

## Row 2

Within one entry: busy > progress (when visible) > `x-detail` > count (when visible and > 0).

- busy: `Cut`, `Cut · 40 %` with visible progress, `Cut · 37 s` with `x-busy-since` (then `2:05`,
  `1:02:05`). The taskbar re-renders every second only while some entry is busy with a start time.
- progress: `40 %`
- count: `3 unread`

Across sources: the app's own data (tab or item counts) > LauncherEntry > media player > `(N)`
title prefix > last title part. See [taskbar](taskbar.md).

## Lifetime

- The state is forgotten when the sending D-Bus connection leaves the bus, and when the app's last
  window closes. Keep the connection open for as long as the row should show.
- A signal is not stored anywhere: after a panel restart, row 2 comes back with the app's next
  update. Send updates on change; the taskbar does not poll.

## Turning it off

`~/.config/minimize-ws/detail`: `<app-id> -launcher` (other rules: `-media`, `-count`, `-split`;
`#` comments).

## Example: Python (PyGObject)

```python
import time
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
APP = "application://org.example.App.desktop"

def update(**props):
    bus.emit_signal(None, "/org/example/App/launcher", "com.canonical.Unity.LauncherEntry",
                    "Update", GLib.Variant("(sa{sv})", (APP, props)))

update(**{"x-busy": GLib.Variant("s", "Cut"),
          "x-busy-since": GLib.Variant("x", int(time.time())),
          "x-window-title": GLib.Variant("s", "plan.scad — Example")})
# later, when the operation finishes:
update(**{"x-busy": GLib.Variant("s", ""), "x-detail": GLib.Variant("s", "saved"),
          "x-window-title": GLib.Variant("s", "plan.scad — Example")})
GLib.MainLoop().run()  # keep the connection open, or the row is cleared
```

## Example: Rust (zbus)

```rust
use std::collections::HashMap;
use zbus::{names::BusName, zvariant::Value};

async fn send(conn: &zbus::Connection, props: HashMap<&str, Value<'_>>) -> zbus::Result<()> {
    conn.emit_signal(
        None::<BusName<'_>>,
        "/org/example/App/launcher",
        "com.canonical.Unity.LauncherEntry",
        "Update",
        &("application://org.example.App.desktop", props),
    )
    .await
}

// let conn = zbus::Connection::session().await?;  // keep it alive
// send(&conn, HashMap::from([("count", Value::from(3i64)), ("count-visible", true.into())])).await?;
// send(&conn, HashMap::from([("progress", Value::from(0.4f64)), ("progress-visible", true.into())])).await?;
```
