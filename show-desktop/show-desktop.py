"""show-desktop: Super+D as on Windows, for the current COSMIC workspace.

  show-desktop    minimize every open window on the active workspace(s); when none is open,
                  bring back the windows the last call minimized and focus the one that had focus

The windows it minimized are kept in ~/.local/state/show-desktop/last.json by their stable
toplevel identifier. Windows you minimized yourself stay minimized on restore.
"""
import json, os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "lib"))
from wsk import State, MINIMIZED

ACTIVATED = 2          # zcosmic_toplevel_handle_v1.state
WS_ACTIVE = 1          # ext_workspace_handle_v1.state bit
SET_MINIMIZED, UNSET_MINIMIZED, ACTIVATE = 5, 6, 2   # zcosmic_toplevel_manager_v1 requests
SKIP_APPS = {"", "com.system76.CosmicPanel"}
STATE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
                     "show-desktop", "last.json")


def load():
    try:
        with open(STATE) as f: return json.load(f)
    except (OSError, ValueError): return {}


def save(data):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f: json.dump(data, f)
    os.replace(tmp, STATE)


def decide(wins, active_ws, last):
    """-> (minimize, restore, focus, new_state). restore excludes focus, which is restored last and
    activated; new_state None means leave the state file alone."""
    wins = [w for w in wins
            if w.get("app_id") not in SKIP_APPS and w["ws"] & active_ws and w.get("ident")]
    shown = [w for w in wins if MINIMIZED not in w.get("states", ())]
    if shown:
        focused = next((w["ident"] for w in shown if ACTIVATED in w.get("states", ())), None)
        return shown, [], None, {"minimized": [w["ident"] for w in shown], "focused": focused}

    ours = set(last.get("minimized", []))
    restore = [w for w in wins if w["ident"] in ours]
    if not restore: return [], [], None, None
    focus = next((w for w in restore if w["ident"] == last.get("focused")), None)
    return [], [w for w in restore if w is not focus], focus, {}


def main():
    st = State(fast=True)
    active = {w["id"] for w in st.ws.values() if w["state"] & WS_ACTIVE}
    minimize, restore, focus, new_state = decide(st.ordered_wins(), active, load())
    if new_state is None: return
    for w in minimize: st.c.req(st.tlm, SET_MINIMIZED, struct.pack("<I", w["h"]))
    for w in restore: st.c.req(st.tlm, UNSET_MINIMIZED, struct.pack("<I", w["h"]))
    if focus:   # restored last, then focused, so it ends up on top
        st.c.req(st.tlm, UNSET_MINIMIZED, struct.pack("<I", focus["h"]))
        seat = st.c.bind("wl_seat", 1)
        st.c.req(st.tlm, ACTIVATE, struct.pack("<II", focus["h"], seat))
    st.c.roundtrip()
    save(new_state)


if __name__ == "__main__":
    main()
