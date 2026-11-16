import importlib.util, json, os, sys, unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("ws_keeper", os.path.join(HERE, "ws-keeper.py"))
wk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wk)
wsk = sys.modules["wsk"]


def state(n_ws, wins):
    """A State without a Wayland connection: n_ws workspaces (ids 101..), wins = [(app_id, title, ws_no)]."""
    st = wsk.State.__new__(wsk.State)
    st.ws = {100 + i: {"id": 100 + i, "name": "", "coords": [i - 1], "state": 0} for i in range(1, n_ws + 1)}
    st.wins = {h: {"h": h, "app_id": app, "title": title, "ws": {100 + ws} if ws else set()}
               for h, (app, title, ws) in enumerate(wins, 1)}
    return st


def entry(app, title, ws):
    return {"app_id": app, "title": title, "ws": ws}


class Norm(unittest.TestCase):
    def test_drops_app_suffix_counter_and_status_mark(self):
        self.assertEqual(wk.norm("(3) Inbox — Mozilla Firefox"), "inbox")
        self.assertEqual(wk.norm("● main.rs - Visual Studio Code"), "main.rs")
        self.assertEqual(wk.norm("  Shell — COSMIC Terminal"), "shell")

    def test_keeps_other_suffixes(self):
        self.assertEqual(wk.norm("Notes — Gedit"), "notes — gedit")


class Snapshot(unittest.TestCase):
    def test_records_app_title_and_workspace(self):
        st = state(3, [("firefox", "A", 2), ("term", "B", 3)])
        self.assertEqual(wk.snapshot(st), [entry("firefox", "A", 2), entry("term", "B", 3)])

    def test_skips_panel_empty_app_id_and_windows_without_workspace(self):
        st = state(2, [("com.system76.CosmicPanel", "panel", 1), ("", "x", 1), ("Handy", "h", 2),
                       ("term", "sticky", None), ("term", "B", 2)])
        self.assertEqual(wk.snapshot(st), [entry("term", "B", 2)])


class Serialisation(unittest.TestCase):
    def test_round_trip(self):
        snap = [entry("firefox", "Straße — Mozilla Firefox", 2)]
        text = wk.snapshot_json(snap, 4, 1700000000.5)
        self.assertIn("Straße", text)
        self.assertEqual(wk.parse_snapshot(text), {"time": 1700000000.5, "workspaces": 4, "windows": snap})

    def test_empty_corrupt_and_wrong_shape_are_none(self):
        for text in ["", "{", "\x00\x01", "null", "[]", '{"windows": []}', '{"time": 1}',
                     '{"time": "x", "windows": []}', '{"time": 1, "windows": {}}', '{"time": 1, "windows": [1]}',
                     '{"time": 1, "windows": [{}]}', '{"time": 1, "windows": [{"app_id": "a", "title": "t", "ws": "2"}]}']:
            with self.subTest(text=text):
                self.assertIsNone(wk.parse_snapshot(text))


class Stale(unittest.TestCase):
    def test_keeps_keep_minus_one_before_next_write(self):
        files = [f"{i:03}.json" for i in range(5)]
        self.assertEqual(wk.stale(files, keep=3), ["000.json", "001.json", "002.json"])
        self.assertEqual(wk.stale(files, keep=6), [])
        self.assertEqual(wk.stale([], keep=3), [])


class Change(unittest.TestCase):
    prev = [entry("firefox", "Inbox", 2), entry("term", "build", 3)]

    def test_same_windows_in_other_order_is_no_change(self):
        self.assertIsNone(wk.change(self.prev, list(reversed(self.prev))))

    def test_empty_current_is_never_written(self):
        self.assertIsNone(wk.change(self.prev, []))
        self.assertIsNone(wk.change(None, []))

    def test_nothing_written_yet(self):
        self.assertEqual(wk.change(None, self.prev), "mapping")

    def test_moved_or_new_window_is_mapping(self):
        self.assertEqual(wk.change(self.prev, [entry("firefox", "Inbox", 3), entry("term", "build", 3)]), "mapping")
        self.assertEqual(wk.change(self.prev, self.prev + [entry("term", "x", 1)]), "mapping")

    def test_close_hidden_by_a_new_window_of_another_app_is_closed(self):
        self.assertEqual(wk.change(self.prev, [entry("term", "build", 2), entry("gedit", "Save?", 2)]), "closed")

    def test_fewer_windows_is_closed_even_when_workspaces_renumber(self):
        self.assertEqual(wk.change(self.prev, self.prev[1:]), "closed")
        self.assertEqual(wk.change(self.prev, [entry("term", "build", 2)]), "closed")

    def test_title_only(self):
        self.assertEqual(wk.change(self.prev, [entry("firefox", "News", 2), entry("term", "build", 3)]), "titles")


class PendingDecision(unittest.TestCase):
    A = [entry("term", "a", 2)]
    MOVED = [entry("term", "a", 3)]

    def test_nothing_due_when_unchanged(self):
        p = wk.Pending(self.A, 0); p.update(self.A, 10)
        self.assertIsNone(p.due())

    def test_mapping_debounced_after_last_change(self):
        p = wk.Pending(self.A, 0); p.update(self.MOVED, 10)
        self.assertEqual(p.due(), 10 + wk.DEBOUNCE)
        p.update([entry("term", "a", 4)], 12)
        self.assertEqual(p.due(), 12 + wk.DEBOUNCE)

    def test_mapping_written_after_max_wait_while_changes_keep_coming(self):
        p = wk.Pending(self.A, 0)
        for t in range(10, 100):
            p.update([entry("term", "a", 3 + t % 2)], t)
        self.assertEqual(p.due(), 10 + wk.MAX_WAIT)

    def test_title_waits_slow(self):
        p = wk.Pending(self.A, 0); p.update([entry("term", "b", 2)], 10)
        self.assertEqual(p.due(), 10 + wk.SLOW)

    def test_close_written_only_after_a_later_title_change_or_move(self):
        dialog = entry("gedit", "Save changes?", 2)
        p = wk.Pending(self.A + self.MOVED, 0); p.update(self.A + self.MOVED, 0)
        p.update(self.A, 10)
        self.assertIsNone(p.due())                       # only shrinking: a logout, maybe stalled
        p.update(self.A + [dialog], 20)
        self.assertIsNone(p.due())                       # a new window (save prompt) does not confirm
        p.update([entry("term", "a2", 2), dialog], 100)
        self.assertEqual(p.due(), 100 + wk.SLOW)         # a remaining window changed: normal session
        p.update([dialog], 120)
        self.assertIsNone(p.due())                       # closing again needs a new confirmation

    def test_change_reverted_before_due_drops_it(self):
        p = wk.Pending(self.A, 0); p.update(self.MOVED, 10); p.update(self.A, 11)
        self.assertIsNone(p.due())
        p.update(self.MOVED, 50)
        self.assertEqual(p.due(), 50 + wk.DEBOUNCE)

    def test_nothing_before_ready_at(self):
        p = wk.Pending(self.A, 300); p.update(self.MOVED, 10)
        self.assertEqual(p.due(), 300)

    def test_older_title_change_does_not_hurry_a_close_or_a_move(self):
        p = wk.Pending(self.A + self.MOVED, 0); p.update([entry("term", "b", 2), entry("term", "a", 3)], 0)
        self.assertEqual(p.due(), wk.SLOW)
        p.update(self.A, 55)
        self.assertIsNone(p.due())
        p.update([entry("term", "b", 4), entry("term", "a", 3)], 70)
        self.assertEqual(p.due(), 70 + wk.DEBOUNCE)

    def test_wrote_clears(self):
        p = wk.Pending(None, 0); p.update(self.A, 10); p.wrote()
        self.assertIsNone(p.due())
        self.assertEqual(p.written, self.A)


class Watch(unittest.TestCase):
    """The watch loop against a fake connection and clock: events at given times, select advances
    the clock to the next event or to its timeout."""

    def run_watch(self, start, session, written, events, fail_writes=0, pins="/nonexistent/ws-keeper/pins"):
        st = state(4, [("term", "a", 2), ("firefox", "b", 3)])
        clock = [start]; writes = []; events = list(events)
        def select(r, _w, _x, timeout):
            if events and (timeout is None or events[0][0] <= clock[0] + timeout):
                clock[0] = events[0][0]; return r, [], []
            if timeout is None: raise AssertionError("watch would block forever")
            clock[0] += timeout; return [], [], []
        def dispatch():
            _, mutate = events.pop(0)
            if mutate is None: raise ConnectionError("Wayland connection closed by the compositor")
            mutate(st)
        def write(snap, _n):
            if fail_writes > sum(1 for w in writes if w is None):
                writes.append(None); raise OSError(28, "No space left on device", "/state/ws-keeper/.x.json")
            writes.append((clock[0], [(e["title"], e["ws"]) for e in snap]))
        st.c = mock.Mock(s="sock", dispatch=dispatch)
        session_start = (lambda: session(clock[0])) if callable(session) else (lambda: session)
        with mock.patch.object(wk, "State", return_value=st), mock.patch.object(wk, "session_start", session_start), \
             mock.patch("sys.stderr"), mock.patch.object(wk, "PINS", pins), \
             mock.patch.object(wk, "newest", return_value=written), mock.patch.object(wk.select, "select", select), \
             mock.patch.object(wk.time, "time", lambda: clock[0]), \
             mock.patch.object(wk, "write", write):
            with self.assertRaises(ConnectionError):
                wk.watch()
        return writes

    @staticmethod
    def move(h, ws):
        return lambda st: st.wins[h].update(ws={100 + ws})

    @staticmethod
    def title(h, t):
        return lambda st: st.wins[h].update(title=t)

    def test_login_guard_debounce_slow_titles_and_lost_connection(self):
        before = [entry("term", "a", 3), entry("firefox", "b", 3)]
        writes = self.run_watch(1010, 1000, before, [
            (1020, self.move(1, 4)),                                       # login: held until 1300
            (1400, self.move(1, 1)), (1401, self.move(2, 2)), (1402, self.move(1, 2)),   # one write at 1405
            (1500, self.title(1, "c")),                                    # title only: 1560
            (1600, self.move(2, 4)), (1601, None)])                        # lost before due: not written
        self.assertEqual(writes, [(1300, [("a", 4), ("b", 3)]), (1405, [("a", 2), ("b", 2)]), (1560, [("c", 2), ("b", 2)])])

    def test_stalled_logout_never_replaces_the_fuller_snapshot(self):
        before = [entry("term", "a", 2), entry("firefox", "b", 3)]
        writes = self.run_watch(1400, 1000, before, [(1500, lambda st: st.wins.pop(1)), (3000, None)])
        self.assertEqual(writes, [])

    def test_new_pinned_window_moved_once_during_login_grace(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            pins = os.path.join(tmp, "pins")
            with open(pins, "w") as fh: fh.write("term = Work\n")
            moves = []
            def appear(st):
                named(st, "Main", "Work", "Mail", "Other")
                st.move = lambda w, d: moves.append((w["h"], d["name"]))
                st.wins[9] = {"h": 9, "app_id": "term", "title": "new", "ws": {101}}
            self.run_watch(1010, 1000, None, [(1020, appear), (1030, self.move(9, 1)), (1040, None)], pins=pins)
        self.assertEqual(moves, [(9, "Work")])     # pre-existing term window 1 untouched, hand move kept

    def test_started_pinned_app_switches_to_its_workspace_after_grace(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            pins = os.path.join(tmp, "pins")
            with open(pins, "w") as fh: fh.write("org.example.Chat = Work\n")
            moves, shown = [], []
            def appear(st):
                named(st, "Main", "Work", "Mail", "Other"); st.ws[101]["state"] = 1
                st.move = lambda w, d: moves.append((w["h"], d["name"]))
                st.activate = lambda d: shown.append(d["name"])
                st.wins[9] = {"h": 9, "app_id": "org.example.Chat", "title": "chat", "ws": {101}}
            def dialog(st):
                st.wins[10] = {"h": 10, "app_id": "org.example.Chat", "title": "call", "ws": {101}}
            self.run_watch(5000, 1000, None, [(5010, appear), (5020, dialog), (5030, None)], pins=pins)
        self.assertEqual(moves, [(9, "Work"), (10, "Work")])
        self.assertEqual(shown, ["Work"])     # the second window of a running app does not switch

    def test_failed_write_is_logged_and_retried(self):
        writes = self.run_watch(5000, 1000, None, [(5100, None)], fail_writes=1)
        self.assertEqual(writes, [None, (5003 + wk.SLOW, [("a", 2), ("b", 3)])])

    def test_unknown_compositor_start_holds_writes_until_found(self):
        writes = self.run_watch(1400, lambda now: 1000 if now >= 2000 else 0, None,
                                [(1500, self.move(2, 1)), (2100, None)])
        self.assertEqual(writes, [(1400 + 10 * wk.SLOW, [("a", 2), ("b", 1)])])   # re-checked every SLOW s

    def test_session_running_long_first_write_after_debounce(self):
        writes = self.run_watch(5000, 1000, None, [(5100, self.move(2, 1)), (5200, None)])
        self.assertEqual(writes, [(5003, [("a", 2), ("b", 3)]), (5103, [("a", 2), ("b", 1)])])


def named(st, *names):
    """Give the workspaces of a test State names, in coordinate order."""
    for w, n in zip(st.ordered_ws(), names): w["name"] = n
    return st


class ParsePins(unittest.TestCase):
    def test_rules_comments_blanks_and_spaces(self):
        text = "# my pins\n\n  org.example.Chat =  Work \n\t# indented comment\nfirefox=Web\n"
        self.assertEqual(wk.parse_pins(text), ({"org.example.Chat": "Work", "firefox": "Web"}, []))

    def test_split_at_first_equals(self):
        self.assertEqual(wk.parse_pins("term = a = b\n")[0], {"term": "a = b"})

    def test_malformed_lines_reported_and_skipped(self):
        text = "no equals here\n= Work\nterm =\n  =  \ngedit = Notes\n"
        rules, bad = wk.parse_pins(text)
        self.assertEqual(rules, {"gedit": "Notes"})
        self.assertEqual([n for n, _ in bad], [1, 2, 3, 4])
        self.assertEqual(bad[0][1], "no equals here")

    def test_duplicate_last_wins_and_app_id_is_case_sensitive(self):
        self.assertEqual(wk.parse_pins("term = A\nTerm = B\nterm = C\n")[0], {"term": "C", "Term": "B"})

    def test_empty(self):
        self.assertEqual(wk.parse_pins(""), ({}, []))


class LoadPins(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.path = os.path.join(self.tmp.name, "pins")

    def write(self, data):
        with open(self.path, "wb") as fh: fh.write(data)

    def test_missing_file_is_no_pins_and_silent(self):
        with mock.patch("sys.stderr") as err:
            self.assertEqual(wk.load_pins(self.path), {})
        err.write.assert_not_called()

    def test_malformed_line_logged_with_file_and_line(self):
        self.write("\ufeffterm = Work\nbroken\n".encode())
        with mock.patch.object(wk, "log") as log:
            self.assertEqual(wk.load_pins(self.path), {"term": "Work"})
        msg = log.call_args[0][0]
        self.assertIn(f"{self.path}:2", msg); self.assertIn("broken", msg)

    def test_not_utf8_logged_no_pins(self):
        self.write(b"term = \xff\n")
        with mock.patch.object(wk, "log") as log:
            self.assertEqual(wk.load_pins(self.path), {})
        log.assert_called_once()

    def test_pins_reread_when_file_changes(self):
        with mock.patch.object(wk, "PINS", self.path):
            p = wk.Pins(); self.assertEqual(p.get(), {})
            self.write(b"term = Work\n"); self.assertEqual(p.get(), {"term": "Work"})
            self.write(b"term = Mail\n"); os.utime(self.path, ns=(1, 1))
            self.assertEqual(p.get(), {"term": "Mail"})
            with mock.patch.object(wk, "load_pins") as lp:
                p.get(); lp.assert_not_called()      # unchanged: not read again
            os.remove(self.path); self.assertEqual(p.get(), {})


class PinDecision(unittest.TestCase):
    RULES = {"org.example.Chat": "Work", "Handy": "Work", "gedit": "Nowhere"}

    def test_only_windows_that_appear_later_count(self):
        st = state(3, [("org.example.Chat", "chat", 1)]); seen = set(st.wins)
        self.assertEqual(wk.new_windows(st, seen), [])
        st.wins[2] = {"h": 2, "app_id": "org.example.Chat", "title": "call", "ws": {101}}
        self.assertEqual([w["h"] for w in wk.new_windows(st, seen)], [2])
        self.assertEqual(wk.new_windows(st, seen), [])     # decided once, a later hand move is kept

    def test_window_waits_for_app_id_and_workspace(self):
        st = state(2, []); seen = set()
        st.wins[1] = {"h": 1, "app_id": "", "title": "", "ws": set()}
        self.assertEqual(wk.new_windows(st, seen), [])
        st.wins[1]["app_id"] = "term"
        self.assertEqual(wk.new_windows(st, seen), [])
        st.wins[1]["ws"] = {101}
        self.assertEqual([w["h"] for w in wk.new_windows(st, seen)], [1])

    def test_moves_pinned_app_to_named_workspace(self):
        st = named(state(3, [("org.example.Chat", "chat", 1), ("term", "x", 1)]), "Main", "Work", "Mail")
        self.assertEqual([(w["h"], d["id"]) for w, d in wk.pin_moves(st, st.ordered_wins(), self.RULES, set())], [(1, 102)])

    def test_already_on_target_or_skipped_app_not_moved(self):
        st = named(state(2, [("org.example.Chat", "chat", 2), ("Handy", "h", 1)]), "Main", "Work")
        self.assertEqual(wk.pin_moves(st, st.ordered_wins(), self.RULES, set()), [])

    def test_lowest_coordinate_wins_when_names_repeat(self):
        st = named(state(3, [("org.example.Chat", "chat", 1)]), "Main", "Work", "Work")
        st.ws[102]["coords"], st.ws[103]["coords"] = [5], [2]
        self.assertEqual(wk.pin_moves(st, st.ordered_wins(), self.RULES, set())[0][1]["id"], 103)

    def test_missing_workspace_logged_once_and_window_left(self):
        st = named(state(2, [("gedit", "a", 1), ("gedit", "b", 1)]), "Main", "Work"); missed = set()
        with mock.patch.object(wk, "log") as log:
            self.assertEqual(wk.pin_moves(st, st.ordered_wins(), self.RULES, missed), [])
            wk.pin_moves(st, st.ordered_wins(), self.RULES, missed)
        log.assert_called_once(); self.assertIn("'Main', 'Work'", log.call_args[0][0])

    def test_follow_only_for_a_started_app_outside_grace_and_not_shown(self):
        st = named(state(2, [("org.example.Chat", "chat", 1), ("term", "x", 1)]), "Main", "Work")
        st.ws[101]["state"] = 1; w, dest = st.wins[1], st.ws[102]
        self.assertTrue(wk.follow(st, w, dest, False))
        self.assertFalse(wk.follow(st, w, dest, True))                  # login restore
        st.ws[102]["state"] = 1
        self.assertFalse(wk.follow(st, w, dest, False))                 # already shown
        st.ws[102]["state"] = 0; st.wins[3] = {"h": 3, "app_id": "org.example.Chat", "title": "main", "ws": {102}}
        self.assertFalse(wk.follow(st, w, dest, False))                 # app was already running

    def test_restore_pin_overrides_snapshot_and_needs_no_entry(self):
        st = named(state(3, [("org.example.Chat", "chat", 1), ("term", "build", 1), ("firefox", "x", 1)]),
                   "Main", "Work", "Mail")
        snap = [entry("org.example.Chat", "chat", 3), entry("term", "build", 3)]
        rules = {"org.example.Chat": "Work", "firefox": "Mail"}
        self.assertEqual(sorted(wk.plan(st, snap, set(), rules), key=str), [(1, "Work"), (2, 3), (3, "Mail")])

    def test_restore_pin_to_missing_workspace_falls_back_to_snapshot(self):
        st = named(state(3, [("gedit", "notes", 1)]), "Main", "Work")
        with mock.patch.object(wk, "log"):
            self.assertEqual(wk.plan(st, [entry("gedit", "notes", 2)], set(), self.RULES), [(1, 2)])


class ApplyByTitle(unittest.TestCase):
    def test_pinned_window_found_by_app_id_and_title(self):
        st = named(state(3, [("term", "Inbox", 1), ("org.example.Chat", "Inbox", 1)]), "Main", "Work", "Mail")
        st.move = mock.Mock()
        with mock.patch.object(wk, "State", return_value=st):
            wk.apply_by_title([("org.example.Chat", "Inbox", "Work"), ("term", "Inbox", 3)])
        self.assertEqual([(c.args[0]["h"], c.args[1]["id"]) for c in st.move.call_args_list], [(1, 103), (2, 102)])


class Main(unittest.TestCase):
    def test_watch_lost_connection_exits_non_zero(self):
        with mock.patch.object(sys, "argv", ["ws-keeper", "watch"]), mock.patch("sys.stderr"), \
             mock.patch.object(wk, "watch", side_effect=ConnectionError("closed")) as w:
            with self.assertRaises(SystemExit) as e:
                wk.main()
        w.assert_called_once_with(); self.assertEqual(e.exception.code, 1)

    def test_restore_watch_seconds(self):
        with mock.patch.object(sys, "argv", ["ws-keeper", "restore", "--watch", "180"]), mock.patch.object(wk, "restore") as r:
            wk.main()
        r.assert_called_once_with(180, False, False)


    def test_unknown_option_changes_nothing(self):
        for argv in (["restore", "--help"], ["restore", "--watch"], ["restore", "--watch", "x"],
                     ["save", "--latest"], ["bogus"]):
            with self.subTest(argv=argv), mock.patch.object(sys, "argv", ["ws-keeper", *argv]), \
                 mock.patch("sys.stderr"), mock.patch.object(wk, "restore") as r, \
                 mock.patch.object(wk, "save") as s:
                with self.assertRaises(SystemExit) as e:
                    wk.main()
                self.assertEqual(e.exception.code, 2); r.assert_not_called(); s.assert_not_called()

    def test_help_prints_usage(self):
        for flag in ("--help", "-h", "help"):
            with self.subTest(flag=flag), mock.patch.object(sys, "argv", ["ws-keeper", flag]), \
                 mock.patch("sys.stdout") as out, mock.patch.object(wk, "restore") as r:
                wk.main()
            r.assert_not_called(); self.assertTrue(out.write.called)

    def test_pins_command(self):
        with mock.patch.object(sys, "argv", ["ws-keeper", "pins"]), mock.patch.object(wk, "show_pins") as sp:
            wk.main()
        sp.assert_called_once_with()

    def test_restore_latest_dry_run(self):
        with mock.patch.object(sys, "argv", ["ws-keeper", "restore", "--latest", "--dry-run"]), \
             mock.patch.object(wk, "restore") as r:
            wk.main()
        r.assert_called_once_with(0, True, True)


class WriteFiles(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.old_dir, wk.DIR = wk.DIR, os.path.join(self.tmp.name, "s")
        self.addCleanup(setattr, wk, "DIR", self.old_dir)

    def test_write_newest_and_prune(self):
        self.assertIsNone(wk.newest())
        os.makedirs(wk.DIR)
        for i in range(4):
            with open(os.path.join(wk.DIR, f"2000010{i}-000000.json"), "w") as fh: fh.write(wk.snapshot_json([entry("a", str(i), 2)], 2, i))
        with mock.patch.object(wk, "KEEP", 3):
            wk.write([entry("a", "new", 3)], 3)
        files = sorted(os.listdir(wk.DIR))
        self.assertEqual(len(files), 3)
        self.assertEqual(files[:2], ["20000102-000000.json", "20000103-000000.json"])
        self.assertEqual(wk.newest(), [entry("a", "new", 3)])


class PickSnapshot(unittest.TestCase):
    def snap(self, t, *ws):
        return {"time": t, "windows": [entry("a", "t", w) for w in ws]}

    def test_newest_before_t0_with_window_on_workspace_two(self):
        snaps = [("c", self.snap(30, 2)), ("b", self.snap(20, 3)), ("a", self.snap(10, 2))]
        self.assertEqual(wk.pick_snapshot(snaps, 25)[0], "b")

    def test_skips_snapshots_with_everything_on_workspace_one(self):
        snaps = [("b", self.snap(20, 1, 1)), ("a", self.snap(10, 1, 2))]
        self.assertEqual(wk.pick_snapshot(snaps, 100)[0], "a")

    def test_none_when_nothing_fits(self):
        self.assertEqual(wk.pick_snapshot([("a", self.snap(10, 2))], 10), (None, None))
        self.assertEqual(wk.pick_snapshot([("a", self.snap(5)), ("b", self.snap(4, 1))], 10), (None, None))
        self.assertEqual(wk.pick_snapshot([], 10), (None, None))


class LoadBefore(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.old_dir, wk.DIR = wk.DIR, self.tmp.name
        self.addCleanup(setattr, wk, "DIR", self.old_dir)

    def write(self, name, text):
        with open(os.path.join(self.tmp.name, name), "w") as fh: fh.write(text)

    def test_skips_empty_and_corrupt_files(self):
        self.write("20240101-000000.json", wk.snapshot_json([entry("a", "t", 2)], 2, 10))
        self.write("20240101-000100.json", "")
        self.write("20240101-000200.json", '{"time": 30, "windows": [')
        self.write(".20240101-000300.json", wk.snapshot_json([entry("a", "t", 3)], 3, 40))
        f, d = wk.load_before(100)
        self.assertEqual((f, d["windows"]), ("20240101-000000.json", [entry("a", "t", 2)]))

    def test_missing_dir(self):
        wk.DIR = os.path.join(self.tmp.name, "nope")
        self.assertEqual(wk.load_before(100), (None, None))


class Plan(unittest.TestCase):
    def test_matches_by_app_id_and_similar_title(self):
        st = state(3, [("firefox", "(2) Inbox — Mozilla Firefox", 1), ("term", "build", 1)])
        snap = [entry("term", "build", 3), entry("firefox", "Inbox — Mozilla Firefox", 2)]
        self.assertEqual(sorted(wk.plan(st, snap, set())), [(1, 2), (2, 3)])

    def test_same_title_other_app_is_not_a_match(self):
        st = state(2, [("gedit", "notes", 1)])
        self.assertEqual(wk.plan(st, [entry("term", "notes", 2)], set()), [])

    def test_title_below_threshold_is_not_a_match(self):
        st = state(2, [("firefox", "Weather", 1), ("firefox", "Project plan", 1)])
        snap = [entry("firefox", "Bank statement", 2), entry("firefox", "Project notes", 2)]
        self.assertEqual(wk.plan(st, snap, set()), [])

    def test_best_match_wins(self):
        st = state(3, [("firefox", "Project plan v2", 1), ("firefox", "Project plan", 1)])
        snap = [entry("firefox", "Project plan", 2), entry("firefox", "Project plan v2", 3)]
        self.assertEqual(sorted(wk.plan(st, snap, set())), [(1, 3), (2, 2)])

    def test_duplicate_titles_each_entry_used_once(self):
        st = state(3, [("term", "bash", 1), ("term", "bash", 1), ("term", "bash", 1)])
        snap = [entry("term", "bash", 2), entry("term", "bash", 3)]
        moves = wk.plan(st, snap, set())
        self.assertEqual(len(moves), 2)
        self.assertEqual(len({h for h, _ in moves}), 2)
        self.assertEqual(sorted(t for _, t in moves), [2, 3])

    def test_window_closed_since_snapshot_leaves_entry_unmatched(self):
        st = state(3, [("term", "build", 1)])
        snap = [entry("term", "build", 2), entry("firefox", "Inbox", 3)]
        self.assertEqual(wk.plan(st, snap, set()), [(1, 2)])

    def test_skipped_apps_and_used_windows_not_moved(self):
        st = state(2, [("Handy", "h", 1), ("term", "a", 1)])
        snap = [entry("Handy", "h", 2), entry("term", "a", 2)]
        self.assertEqual(wk.plan(st, snap, {2}), [])


class Remaining(unittest.TestCase):
    def test_drops_entries_of_moved_titles_after_normalising(self):
        snap = [entry("firefox", "Inbox — Mozilla Firefox", 2), entry("term", "build", 3)]
        self.assertEqual(wk.remaining(snap, ["(1) Inbox — Mozilla Firefox"]), [entry("term", "build", 3)])

    def test_duplicate_titles_all_dropped(self):
        snap = [entry("term", "bash", 2), entry("term", "bash", 3)]
        self.assertEqual(wk.remaining(snap, ["bash"]), [])
        self.assertEqual(wk.remaining(snap, []), snap)


class TargetWs(unittest.TestCase):
    def test_existing_workspace(self):
        self.assertEqual(wk.target_ws(state(4, []), 3)["id"], 103)

    def test_workspace_that_no_longer_exists_goes_to_last(self):
        self.assertEqual(wk.target_ws(state(2, []), 5)["id"], 102)


if __name__ == "__main__":
    unittest.main()
