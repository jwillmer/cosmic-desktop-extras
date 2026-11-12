"""Minimal COSMIC window/workspace client (raw Wayland wire protocol, stdlib only). Used by ws-keeper."""
import os, select, socket, struct, sys, time

MINIMIZED = 1   # zcosmic_toplevel_handle_v1.state

def pad(n): return (n + 3) & ~3
def enc_str(s):
    b = s.encode() + b"\0"; return struct.pack("<I", len(b)) + b + b"\0" * (pad(len(b)) - len(b))

def connect(path, wait=0, sleep=time.sleep, clock=time.monotonic):
    """Connect to the compositor socket. With wait > 0, retry for up to wait s while the socket is
    missing or refuses (compositor still starting, e.g. a second login right after a logout)."""
    end = clock() + wait
    while True:
        s = socket.socket(socket.AF_UNIX)
        try: s.connect(path); return s
        except (FileNotFoundError, ConnectionRefusedError):
            s.close()
            if clock() >= end: raise
            sleep(1)

class Conn:
    def __init__(self, wait=0):
        self.s = connect(os.path.join(os.environ["XDG_RUNTIME_DIR"], os.environ.get("WAYLAND_DISPLAY", "wayland-0")), wait)
        self.next_id = 2; self.objs = {1: "wl_display"}; self.buf = b""; self.handlers = {}
        self.registry = self.new("wl_registry"); self.req(1, 1, struct.pack("<I", self.registry))
        self.globals = {}
    def new(self, iface):
        i = self.next_id; self.next_id += 1; self.objs[i] = iface; return i
    def req(self, obj, op, payload=b""):
        self.s.sendall(struct.pack("<IHH", obj, op, 8 + len(payload)) + payload)
    def bind(self, iface, ver):
        name, have = self.globals[iface]; i = self.new(iface)
        self.req(self.registry, 0, struct.pack("<I", name) + enc_str(iface) + struct.pack("<II", min(ver, have), i)); return i
    def roundtrip(self):
        cb = self.new("wl_callback"); self.req(1, 0, struct.pack("<I", cb)); done = [False]
        self.handlers[(cb, 0)] = lambda b: done.__setitem__(0, True)
        while not done[0]: self.dispatch()
    def dispatch(self):
        data = self.s.recv(1 << 20)
        if not data: raise ConnectionError("Wayland connection closed by the compositor")
        self.buf += data
        while len(self.buf) >= 8:
            obj, op, size = struct.unpack("<IHH", self.buf[:8])
            if len(self.buf) < size: break
            body, self.buf = self.buf[8:size], self.buf[size:]
            if obj == self.registry and op == 0:
                name, ln = struct.unpack("<II", body[:8]); iface = body[8:8 + ln - 1].decode()
                self.globals[iface] = (name, struct.unpack("<I", body[8 + pad(ln):12 + pad(ln)])[0])
            if obj == 1 and op == 0:
                print("PROTOCOL ERROR on object", u32(body), self.objs.get(u32(body)), "code", u32(body, 4), rd_str(body[8:]), file=sys.stderr)
            h = self.handlers.get((obj, op)) or self.handlers.get((self.objs.get(obj), op))
            if h: h(obj, body) if (obj, op) not in self.handlers else h(body)

def rd_str(b):
    ln = struct.unpack("<I", b[:4])[0]; return b[4:4 + ln - 1].decode(errors="replace")
def u32(b, o=0): return struct.unpack("<I", b[o:o + 4])[0]

class State:
    def __init__(self, fast=False, wait=0):
        c = self.c = Conn(wait); c.roundtrip()
        self.ws = {}; self.groups = []; self.wins = {}; self.f2h = {}   # cosmic handle id -> dict
        self.out = c.bind("wl_output", 1)
        self.wsm = c.bind("ext_workspace_manager_v1", 1)
        self.tli = c.bind("zcosmic_toplevel_info_v1", 3)
        self.tlm = c.bind("zcosmic_toplevel_manager_v1", 4)
        self.ftl = c.bind("ext_foreign_toplevel_list_v1", 1)
        self.cwm = c.bind("zcosmic_workspace_manager_v2", 2) if "zcosmic_workspace_manager_v2" in c.globals else None
        self.cws = {}   # ext workspace id -> {"h": cosmic handle, "caps": [...], "state": int}
        H = c.handlers
        def ws_new(_o, b):
            i = u32(b); c.objs[i] = "ext_workspace_handle_v1"; self.ws[i] = {"id": i, "name": "", "coords": [], "state": 0}
            if self.cwm:
                h = c.new("zcosmic_workspace_handle_v2"); self.cws[i] = {"h": h, "caps": [], "state": 0}; self.cws_by_h[h] = i
                c.req(self.cwm, 0, struct.pack("<II", h, i))
        self.cws_by_h = {}
        # Late events for a removed workspace go to a throwaway dict, as for closed windows below.
        def cws(h): return self.cws.get(self.cws_by_h.get(h)) or {}
        def ws(i): return self.ws.get(i) or {}
        H[("zcosmic_workspace_handle_v2", 0)] = lambda o, b: cws(o).update(caps=u32(b))
        H[("zcosmic_workspace_handle_v2", 2)] = lambda o, b: cws(o).update(state=u32(b))
        def grp_new(_o, b): i = u32(b); c.objs[i] = "ext_workspace_group_handle_v1"; self.groups.append(i)
        H[("ext_workspace_manager_v1", 0)] = grp_new
        H[("ext_workspace_manager_v1", 1)] = ws_new
        def ws_removed(i, _b):
            """Destroy the cosmic extension, then the workspace handle, so a long-running client does not keep them."""
            self.ws.pop(i, None); x = self.cws.pop(i, None)
            if x: self.cws_by_h.pop(x["h"], None); c.req(x["h"], 0)
            c.req(i, 0)
        H[("ext_workspace_handle_v1", 1)] = lambda o, b: ws(o).update(name=rd_str(b))
        H[("ext_workspace_handle_v1", 2)] = lambda o, b: ws(o).update(coords=[u32(b, 4 + 4 * k) for k in range(u32(b) // 4)])
        H[("ext_workspace_handle_v1", 3)] = lambda o, b: ws(o).update(state=u32(b))
        H[("ext_workspace_handle_v1", 5)] = ws_removed
        # Events can still arrive for a window that just closed; they go to a throwaway dict.
        def win(h): return self.wins.get(h) or {"ws": set()}
        def ext_win(f): return win(self.f2h.get(f))
        def ftl_new(_o, b):
            f = u32(b); c.objs[f] = "ext_foreign_toplevel_handle_v1"; h = c.new("zcosmic_toplevel_handle_v1")
            self.wins[h] = {"h": h, "title": "", "app_id": "", "ws": set()}; self.f2h[f] = h
            c.req(self.tli, 1, struct.pack("<II", h, f))
        def ftl_closed(f, _b):
            """zcosmic_toplevel_handle_v1 v2+ sends no closed event, this one replaces it.
            Destroy both handles so a long-running client does not keep them."""
            h = self.f2h.pop(f, None); self.wins.pop(h, None)
            if h: c.req(h, 0)
            c.req(f, 0)
        H[("ext_foreign_toplevel_list_v1", 0)] = ftl_new
        H[("ext_foreign_toplevel_handle_v1", 0)] = ftl_closed
        H[("ext_foreign_toplevel_handle_v1", 2)] = lambda o, b: ext_win(o).update(title=rd_str(b))
        H[("ext_foreign_toplevel_handle_v1", 4)] = lambda o, b: ext_win(o).update(ident=rd_str(b))
        H[("ext_foreign_toplevel_handle_v1", 3)] = lambda o, b: ext_win(o).update(app_id=rd_str(b))
        H[("zcosmic_toplevel_handle_v1", 2)] = lambda o, b: win(o).update(title=rd_str(b))
        H[("zcosmic_toplevel_handle_v1", 3)] = lambda o, b: win(o).update(app_id=rd_str(b))
        H[("zcosmic_toplevel_manager_v1", 0)] = lambda o, b: setattr(self, "caps", [u32(b, 4 + 4 * k) for k in range(u32(b) // 4)])
        H[("zcosmic_toplevel_handle_v1", 8)] = lambda o, b: win(o).update(states={u32(b, 4 + 4 * k) for k in range(u32(b) // 4)})
        H[("zcosmic_toplevel_handle_v1", 10)] = lambda o, b: win(o)["ws"].add(u32(b))
        H[("zcosmic_toplevel_handle_v1", 11)] = lambda o, b: win(o)["ws"].discard(u32(b))
        H[("zcosmic_toplevel_handle_v1", 0)] = lambda o, b: self.wins.pop(o, None)
        for _ in range(3): c.roundtrip()
        self.settle(fast=fast)
    def complete(self):
        return bool(self.wins) and all("states" in w and w.get("ident") and w["ws"] for w in self.wins.values())
    def settle(self, secs=0.8, fast=False):
        """cosmic-comp sends toplevel state in its refresh cycle, after sync replies; wait for it.
        fast: stop as soon as every window has its state, identifier and workspace (usually < 0.15 s)."""
        end = time.time() + secs
        while time.time() < end:
            if select.select([self.c.s], [], [], 0.02 if fast else 0.1)[0]: self.c.dispatch()
            else: self.c.roundtrip()
            if fast and self.complete(): return
    def ordered_ws(self): return sorted(self.ws.values(), key=lambda w: (w["coords"] or [999], w["id"]))
    def ws_no(self, wid):
        for n, w in enumerate(self.ordered_ws(), 1):
            if w["id"] == wid: return n
    def ordered_wins(self): return sorted(self.wins.values(), key=lambda w: w["h"])
    def move(self, win, ws):
        """Move a window; COSMIC minimizes windows moved to a background workspace, so undo that
        unless the window was already minimized."""
        was_min = MINIMIZED in win.get("states", ())
        self.c.req(self.tlm, 13, struct.pack("<III", win["h"], ws["id"], self.out))
        if not was_min: self.c.req(self.tlm, 6, struct.pack("<I", win["h"]))   # unset_minimized
        self.c.roundtrip()
    def win_ws(self, win):
        return min((self.ws_no(x) or 99) for x in win["ws"]) if win["ws"] else None
    def ws_op(self, ws, op, payload=b""):
        """zcosmic_workspace_handle_v2 request (1 rename, 3 move_before, 4 move_after, 5 pin, 6 unpin), then commit."""
        self.c.req(self.cws[ws["id"]]["h"], op, payload); self.c.req(self.wsm, 0); self.c.roundtrip()
    # rename (op 1) and move_before/after (3/4) exist in the protocol but cosmic-comp ignores
    # rename and does not offer move (capabilities = rename|tiling|pin), so only pin is used.
    def pin(self, ws): self.ws_op(ws, 5)
    def create(self, name):
        self.c.req(self.groups[0], 0, enc_str(name)); self.c.req(self.wsm, 0); self.c.roundtrip()

