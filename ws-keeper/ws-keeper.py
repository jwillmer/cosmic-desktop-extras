"""ws-keeper: remember which COSMIC workspace each window is on, and put windows back after a restart.

  ws-keeper watch                stay connected and snapshot window -> workspace when it changes (user service)
  ws-keeper save                 snapshot window -> workspace once
  ws-keeper restore [--watch S]  move windows back, using the newest snapshot taken before this session
                                 started; --watch keeps matching new windows for S seconds (login)
  ws-keeper restore --latest     use the newest snapshot (manual fix-up after you moved things)
  ws-keeper list                 show windows and their workspace now
  ws-keeper snapshots            list stored snapshots

Windows are matched by app id + title (Firefox: title of the active tab). Similar titles can swap.
"""
import collections, difflib, json, os, re, select, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "lib"))
from wsk import State

DIR = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "ws-keeper")
KEEP = 300          # snapshots kept
DEBOUNCE = 3        # s without further change before a new or moved window is written
MAX_WAIT = 30       # s at most before a new or moved window is written while changes keep coming
SLOW = 60           # s before a closed window or a title-only change is written
LOGIN_GRACE = 300   # s after the compositor started before watch writes (login restore runs until then)
SKIP_APPS = {"", "com.system76.CosmicPanel", "Handy"}
CONNECT_WAIT = 60   # s watch/restore retry while the compositor socket is missing (login, relogin)

def norm(t):
    t = re.sub(r"\s+[—-]\s+(Mozilla Firefox|COSMIC Terminal|Visual Studio Code)$", "", t)
    t = re.sub(r"^[◐◑◒◓●○•*]\s*", "", re.sub(r"^\(\d+\)\s*", "", t))
    return t.strip().lower()

def session_start():
    """Start time of the running compositor (seconds since epoch)."""
    for pid in os.listdir("/proc"):
        if pid.isdigit():
            try:
                if open(f"/proc/{pid}/comm").read().strip() == "cosmic-comp" and os.stat(f"/proc/{pid}").st_uid == os.getuid():
                    ticks = int(open(f"/proc/{pid}/stat").read().rsplit(")", 1)[1].split()[19])
                    boot = time.time() - float(open("/proc/uptime").read().split()[0])
                    return boot + ticks / os.sysconf("SC_CLK_TCK")
            except (OSError, ValueError, IndexError):
                pass
    return 0

def snapshot(st):
    return [{"app_id": w["app_id"], "title": w["title"], "ws": st.win_ws(w)}
            for w in st.ordered_wins() if w["app_id"] not in SKIP_APPS and st.win_ws(w)]

def parse_snapshot(text):
    """Snapshot dict from file text, or None when it is empty, corrupt or not a snapshot."""
    try:
        d = json.loads(text)
    except ValueError:
        return None
    ok = isinstance(d, dict) and isinstance(d.get("time"), (int, float)) and isinstance(d.get("windows"), list) and all(
        isinstance(w, dict) and isinstance(w.get("app_id"), str) and isinstance(w.get("title"), str)
        and isinstance(w.get("ws"), int) for w in d["windows"])
    return d if ok else None

def snapshot_json(snap, workspaces, t):
    return json.dumps({"time": t, "workspaces": workspaces, "windows": snap}, ensure_ascii=False, indent=1)

def stale(files, keep=KEEP):
    """Oldest files to delete so that keep remain after one more is written (files sorted oldest first)."""
    return files[:max(0, len(files) + 1 - keep)]

def closed(prev, cur):
    """True when some app has fewer windows in cur than in prev (a new dialog does not hide a close)."""
    return bool(collections.Counter(e["app_id"] for e in prev) - collections.Counter(e["app_id"] for e in cur))

def change(prev, cur):
    """How cur differs from the last written snapshot prev (None: nothing written yet):
    None (same windows, or no window at all), "mapping" (a window appeared or moved to another
    workspace), "closed" (an app has fewer windows) or "titles" (only titles changed)."""
    if not cur: return None
    if prev is None: return "mapping"
    mapping = lambda s: sorted((e["app_id"], e["ws"]) for e in s)
    if mapping(cur) != mapping(prev): return "closed" if closed(prev, cur) else "mapping"
    titled = lambda s: sorted((e["app_id"], e["ws"], e["title"]) for e in s)
    return None if titled(cur) == titled(prev) else "titles"

class Pending:
    """When watch writes: tracks the last written snapshot, the kind of change (see change) and
    since when that kind holds, and when the current snapshot last changed. A new kind restarts
    its own delay, so an old title change does not make a later close or move due at once.
    A close is written only once confirmed: SLOW after a later title change or move of a window
    that stayed. Windows that only close (a logout, also one stalled by a save prompt or a hung
    app) never replace the fuller snapshot.
    Pure (times are passed in) so the decision is testable without a compositor."""
    def __init__(self, written, ready_at):
        self.written, self.ready_at = written, ready_at
        self.cur = self.kind = self.kind_since = self.last_change = self.confirmed = None
    def update(self, snap, now):
        if snap != self.cur:
            if self.cur is not None and closed(self.cur, snap): self.confirmed = None
            elif self.cur is not None and len(snap) == len(self.cur): self.confirmed = now
            self.cur, self.last_change = snap, now
        kind = change(self.written, snap)
        if kind != self.kind: self.kind, self.kind_since = kind, now
    def due(self):
        """Time at which cur should be written, or None when there is nothing to write."""
        if self.kind is None: return None
        if self.kind == "mapping": t = min(self.last_change + DEBOUNCE, self.kind_since + MAX_WAIT)
        elif self.kind == "titles": t = self.kind_since + SLOW
        elif self.confirmed is None: return None
        else: t = self.confirmed + SLOW
        return max(t, self.ready_at)
    def wrote(self):
        self.written, self.kind, self.confirmed = self.cur, None, None

def pick_snapshot(snaps, t0):
    """First (name, snapshot) of snaps (newest first) taken before t0 with a window on workspace 2 or higher."""
    for f, d in snaps:
        if d["time"] < t0 and any(w["ws"] > 1 for w in d["windows"]): return f, d
    return None, None

def read(path):
    try:
        with open(path) as fh: return parse_snapshot(fh.read())
    except OSError:
        return None

def snapshot_files():
    return sorted(f for f in os.listdir(DIR) if f.endswith(".json")) if os.path.isdir(DIR) else []

def newest():
    """Windows of the newest snapshot file, or None."""
    files = snapshot_files(); d = read(os.path.join(DIR, files[-1])) if files else None
    return d["windows"] if d else None

def write(snap, workspaces):
    os.makedirs(DIR, exist_ok=True); files = snapshot_files()
    name = time.strftime("%Y%m%d-%H%M%S") + ".json"; tmp = os.path.join(DIR, "." + name)
    with open(tmp, "w") as fh: fh.write(snapshot_json(snap, workspaces, time.time()))
    os.replace(tmp, os.path.join(DIR, name))
    for f in stale([f for f in files if f != name], KEEP): os.remove(os.path.join(DIR, f))

def save():
    st = State(); snap = snapshot(st)
    if snap and newest() != snap: write(snap, len(st.ws))

def log(msg): print(f"ws-keeper watch: {msg}", file=sys.stderr, flush=True)

def login_ready(now):
    """(time from which watch may write, whether the compositor start is known). Without a
    cosmic-comp of this user the login grace cannot be placed: write nothing, look again in SLOW s."""
    t = session_start()
    if t: return t + LOGIN_GRACE, True
    log(f"no cosmic-comp process of uid {os.getuid()} in /proc, so the login grace is unknown; "
        f"not writing, checking again in {SLOW} s")
    return now + SLOW, False

def watch():
    """Keep one Wayland connection and write a snapshot when window -> workspace changed (see Pending).
    Nothing is written in the first LOGIN_GRACE seconds of the compositor, so the half-restored login
    state never becomes the newest snapshot. A lost connection raises ConnectionError; pending
    changes are dropped, not written. A failed write is logged and retried SLOW s later."""
    st = State(wait=CONNECT_WAIT); ready, known = login_ready(time.time()); p = Pending(newest(), ready)
    while True:
        now = time.time(); snap = snapshot(st); p.update(snap, now); due = p.due()
        if due is not None and due <= now and not known:
            p.ready_at, known = login_ready(now); due = p.due()
        if due is not None and due <= now:
            try:
                write(snap, len(st.ws)); p.wrote(); due = None
            except OSError as e:
                log(f"cannot write a snapshot to {e.filename or DIR}: {e.strerror or e}; retrying in {SLOW} s")
                p.ready_at = now + SLOW; due = p.due()
        if select.select([st.c.s], [], [], None if due is None else due - now)[0]: st.c.dispatch()

def load_before(t0):
    files = sorted((f for f in os.listdir(DIR) if f.endswith(".json")), reverse=True) if os.path.isdir(DIR) else []
    return pick_snapshot(((f, d) for f in files for d in [read(os.path.join(DIR, f))] if d), t0)

def plan(st, snap, used):
    """Greedy best-title match between current windows and snapshot entries -> [(win, target_ws)]."""
    pairs = []
    for w in st.ordered_wins():
        if w["app_id"] in SKIP_APPS or w["h"] in used: continue
        for i, e in enumerate(snap):
            if e["app_id"] != w["app_id"]: continue
            r = difflib.SequenceMatcher(None, norm(w["title"]), norm(e["title"])).ratio()
            if r >= 0.75: pairs.append((r, w["h"], i))
    pairs.sort(reverse=True); taken_w, taken_e, out = set(), set(), []
    for r, h, i in pairs:
        if h in taken_w or i in taken_e: continue
        taken_w.add(h); taken_e.add(i); out.append((h, snap[i]["ws"]))
    return out

def remaining(snap, titles):
    """Snapshot entries whose normalised title none of the moved windows had."""
    moved = {norm(t) for t in titles}
    return [e for e in snap if norm(e["title"]) not in moved]

def restore(watch=0, dry=False, latest=False):
    f, d = load_before(time.time() + 1 if latest else session_start())
    if not d: print("no snapshot from before this session"); return
    print(f"using snapshot {f} ({len(d['windows'])} windows)")
    used, end = set(), time.time() + watch
    while True:
        st = State(wait=CONNECT_WAIT); moves = plan(st, d["windows"], used)
        items = [(st.wins[h]["title"], t) for h, t in moves]
        for title, t in items: print(f"  ws {t}: {title[:80]}")
        if items and not dry: apply_by_title(items)
        used |= {h for h, _ in moves}
        left = d["windows"] = remaining(d["windows"], [title for title, _ in items])
        if time.time() >= end or not left: break
        time.sleep(5)

def target_ws(st, n):
    """Workspace number n, or the last workspace when there are fewer than n."""
    ws = st.ordered_ws(); return ws[min(n, len(ws)) - 1]

def apply_by_title(items):
    """Move windows (by exact current title) to target workspaces in ascending order;
    COSMIC adds a trailing empty workspace each time the last one gets a window."""
    for target in sorted({t for _, t in items}):
        st = State(); dest = target_ws(st, target)
        for title, t in items:
            if t != target: continue
            for w in st.ordered_wins():
                if w["title"] == title and st.win_ws(w) != st.ws_no(dest["id"]):
                    st.move(w, dest); break

# Options each command accepts; anything else prints the usage and changes nothing, so a guessed
# `ws-keeper restore --help` never moves windows.
OPTIONS = {"save": set(), "watch": set(), "list": set(), "snapshots": set(),
           "restore": {"--watch", "--dry-run", "--latest"}}

def usage_error():
    print(__doc__, file=sys.stderr); sys.exit(2)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd in ("-h", "--help", "help"): print(__doc__); return
    if cmd not in OPTIONS: usage_error()
    args = sys.argv[2:]
    if cmd == "restore" and "--watch" in args:
        i = args.index("--watch")
        if i + 1 >= len(args) or not args[i + 1].isdigit(): usage_error()
        del args[i + 1]
    if any(a not in OPTIONS[cmd] for a in args): usage_error()
    if cmd == "save": save()
    elif cmd == "watch":
        try:
            watch()
        except OSError as e:   # no Wayland socket, or the compositor went away; systemd restarts us
            log(f"Wayland connection: {e}; exiting without saving"); sys.exit(1)
    elif cmd == "restore":
        secs = int(sys.argv[sys.argv.index("--watch") + 1]) if "--watch" in sys.argv else 0
        restore(secs, "--dry-run" in sys.argv, "--latest" in sys.argv)
    elif cmd == "list":
        st = State()
        for w in sorted(st.ordered_wins(), key=lambda w: st.win_ws(w) or 99): print(f"ws {st.win_ws(w)}  {w['app_id']}: {w['title'][:90]}")
    elif cmd == "snapshots":
        for f in sorted(os.listdir(DIR)) if os.path.isdir(DIR) else []: print(f)

if __name__ == "__main__":
    main()
