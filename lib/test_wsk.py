import importlib.util, os, struct, unittest
from unittest import mock

spec = importlib.util.spec_from_file_location(
    "wsk_under_test", os.path.join(os.path.dirname(os.path.abspath(__file__)), "wsk.py"))
wsk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wsk)


def msg(obj, op, payload=b""):
    return struct.pack("<IHH", obj, op, 8 + len(payload)) + payload


def arr(*vals):
    return struct.pack("<I", 4 * len(vals)) + b"".join(struct.pack("<I", v) for v in vals)


class Sock:
    def __init__(self): self.sent = []; self.inbox = []
    def sendall(self, b): self.sent.append(b)
    def recv(self, _n): return self.inbox.pop(0) if self.inbox else b""


IFACES = ["wl_output", "ext_workspace_manager_v1", "zcosmic_toplevel_info_v1",
          "zcosmic_toplevel_manager_v1", "ext_foreign_toplevel_list_v1"]


class FakeConn(wsk.Conn):
    def __init__(self, wait=0):
        self.s = Sock(); self.next_id = 2; self.objs = {1: "wl_display"}; self.buf = b""; self.handlers = {}
        self.registry = self.new("wl_registry")
        self.globals = {name: (n, 9) for n, name in enumerate(IFACES, 1)}
    def roundtrip(self): pass
    def feed(self, *msgs): self.s.inbox.append(b"".join(msgs)); self.dispatch()


class Wire(unittest.TestCase):
    def test_pad(self):
        self.assertEqual([wsk.pad(n) for n in range(9)], [0, 4, 4, 4, 4, 8, 8, 8, 8])

    def test_enc_str_length_includes_nul_and_pads_to_four(self):
        self.assertEqual(wsk.enc_str("abc"), b"\x04\x00\x00\x00abc\x00")
        self.assertEqual(wsk.enc_str("abcd"), b"\x05\x00\x00\x00abcd\x00\x00\x00\x00")
        self.assertEqual(wsk.enc_str(""), b"\x01\x00\x00\x00\x00\x00\x00\x00")

    def test_enc_str_utf8(self):
        b = wsk.enc_str("ß")
        self.assertEqual((wsk.u32(b), len(b)), (3, 8))
        self.assertEqual(wsk.rd_str(b), "ß")

    def test_rd_str_and_u32(self):
        self.assertEqual(wsk.rd_str(wsk.enc_str("hello") + b"tail"), "hello")
        self.assertEqual(wsk.u32(b"\x01\x00\x00\x00\x02\x01\x00\x00", 4), 258)

    def test_rd_str_bad_utf8_replaced(self):
        self.assertEqual(wsk.rd_str(b"\x02\x00\x00\x00\xff\x00\x00\x00"), "�")


class Dispatch(unittest.TestCase):
    def test_registry_global_parsed(self):
        c = FakeConn(); c.globals = {}
        c.feed(msg(c.registry, 0, struct.pack("<I", 7) + wsk.enc_str("wl_output") + struct.pack("<I", 4)))
        self.assertEqual(c.globals, {"wl_output": (7, 4)})

    def test_message_split_across_reads(self):
        c = FakeConn(); got = []
        c.handlers[(5, 1)] = got.append
        m = msg(5, 1, b"abcdefgh")
        c.feed(m[:6]); self.assertEqual(got, [])
        c.feed(m[6:] + msg(5, 1, b"xy\0\0")[:3]); self.assertEqual(got, [b"abcdefgh"])
        self.assertEqual(len(c.buf), 3)

    def test_object_handler_gets_body_interface_handler_gets_object_too(self):
        c = FakeConn(); calls = []
        c.objs[9] = "thing"
        c.handlers[("thing", 2)] = lambda o, b: calls.append(("iface", o, b))
        c.handlers[(10, 2)] = lambda b: calls.append(("obj", b))
        c.objs[10] = "thing"
        c.feed(msg(9, 2, b"aaaa"), msg(10, 2, b"bbbb"), msg(9, 3, b"cccc"))
        self.assertEqual(calls, [("iface", 9, b"aaaa"), ("obj", b"bbbb")])

    def test_closed_connection_raises(self):
        with self.assertRaises(ConnectionError):
            FakeConn().dispatch()

    def test_req_frames_header(self):
        c = FakeConn(); c.req(3, 13, b"\1\0\0\0")
        self.assertEqual(c.s.sent[-1], b"\3\0\0\0\x0d\0\x0c\0\1\0\0\0")


class StateEvents(unittest.TestCase):
    def setUp(self):
        with mock.patch.object(wsk, "Conn", FakeConn), mock.patch.object(wsk.State, "settle"):
            self.st = wsk.State()
        self.c = self.st.c

    def test_binds_with_lower_of_wanted_and_offered_version(self):
        bind = self.c.s.sent[0]
        self.assertEqual(struct.unpack("<IHH", bind[:8]), (self.c.registry, 0, len(bind)))
        self.assertEqual(wsk.u32(bind, 8), 1)
        self.assertEqual(wsk.rd_str(bind[12:]), "wl_output")
        self.assertEqual(struct.unpack("<II", bind[-8:]), (1, self.st.out))
        self.assertIsNone(self.st.cwm)

    def add_ws(self, wid, coord):
        self.c.feed(msg(self.st.wsm, 1, struct.pack("<I", wid)), msg(wid, 2, arr(coord)), msg(wid, 1, wsk.enc_str(f"ws{coord}")))

    def add_win(self, f, title, app, wid, states=()):
        self.c.feed(msg(self.st.ftl, 0, struct.pack("<I", f)))
        h = self.st.f2h[f]
        self.c.feed(msg(f, 2, wsk.enc_str(title)), msg(f, 3, wsk.enc_str(app)), msg(f, 4, wsk.enc_str(f"id{f}")),
                    msg(h, 8, arr(*states)), *([msg(h, 10, struct.pack("<I", wid))] if wid else []))
        return h

    def test_workspaces_ordered_by_coordinates_then_id(self):
        self.add_ws(0xff000002, 1); self.add_ws(0xff000001, 0); self.add_ws(0xff000003, 1)
        self.assertEqual([w["id"] for w in self.st.ordered_ws()], [0xff000001, 0xff000002, 0xff000003])
        self.assertEqual(self.st.ws_no(0xff000003), 3)
        self.assertEqual(self.st.ws[0xff000001]["name"], "ws0")
        self.assertIsNone(self.st.ws_no(42))

    def test_window_events_and_workspace_number(self):
        self.add_ws(0xff000001, 0); self.add_ws(0xff000002, 1)
        h = self.add_win(0xff000010, "Inbox", "firefox", 0xff000002, states=(wsk.MINIMIZED,))
        w = self.st.wins[h]
        self.assertEqual((w["title"], w["app_id"], w["ident"], w["states"]), ("Inbox", "firefox", "id4278190096", {1}))
        self.assertEqual(self.st.win_ws(w), 2)
        self.assertEqual(self.c.s.sent[-1], msg(self.st.tli, 1, struct.pack("<II", h, 0xff000010)))

    def test_window_on_two_workspaces_uses_lowest_and_unknown_is_99(self):
        self.add_ws(0xff000001, 0); self.add_ws(0xff000002, 1)
        h = self.add_win(0xff000010, "a", "x", 0xff000002)
        self.c.feed(msg(h, 10, struct.pack("<I", 0xff000001)))
        self.assertEqual(self.st.win_ws(self.st.wins[h]), 1)
        self.c.feed(msg(h, 11, struct.pack("<I", 0xff000001)), msg(h, 11, struct.pack("<I", 0xff000002)),
                    msg(h, 10, struct.pack("<I", 0xff0000ff)))
        self.assertEqual(self.st.win_ws(self.st.wins[h]), 99)

    def test_removed_workspace_and_closed_window(self):
        self.add_ws(0xff000001, 0)
        h = self.add_win(0xff000010, "a", "x", 0xff000001)
        self.c.feed(msg(0xff000001, 5), msg(h, 0))
        self.assertEqual((self.st.ws, self.st.wins), ({}, {}))

    def test_closed_window_removed_and_both_handles_destroyed(self):
        self.add_ws(0xff000001, 0)
        h = self.add_win(0xff000010, "a", "x", 0xff000001)
        keep = self.add_win(0xff000011, "b", "x", 0xff000001)
        self.c.feed(msg(0xff000010, 0))
        self.assertEqual(list(self.st.wins), [keep])
        self.assertEqual(self.c.s.sent[-2:], [msg(h, 0), msg(0xff000010, 0)])
        self.assertNotIn(0xff000010, self.st.f2h)

    def test_events_after_close_are_ignored(self):
        self.add_ws(0xff000001, 0)
        h = self.add_win(0xff000010, "a", "x", 0xff000001)
        self.c.feed(msg(0xff000010, 0), msg(0xff000010, 2, wsk.enc_str("late")),
                    msg(h, 8, arr()), msg(h, 11, struct.pack("<I", 0xff000001)), msg(h, 2, wsk.enc_str("late")))
        self.assertEqual(self.st.wins, {})

    def test_removed_workspace_destroyed_and_late_events_ignored(self):
        self.st.cwm = 99
        self.add_ws(0xff000001, 0); self.add_ws(0xff000002, 1)
        h = self.st.cws[0xff000001]["h"]
        self.c.feed(msg(0xff000001, 5))
        self.assertEqual(self.c.s.sent[-2:], [msg(h, 0), msg(0xff000001, 0)])
        self.assertEqual((list(self.st.ws), list(self.st.cws)), ([0xff000002], [0xff000002]))
        self.c.feed(msg(0xff000001, 3, struct.pack("<I", 1)), msg(0xff000001, 1, wsk.enc_str("x")), msg(h, 2, struct.pack("<I", 1)))
        self.assertEqual(list(self.st.ws), [0xff000002])

    def test_complete(self):
        self.assertFalse(self.st.complete())
        self.add_ws(0xff000001, 0)
        h = self.add_win(0xff000010, "a", "x", 0xff000001)
        self.assertTrue(self.st.complete())
        self.c.feed(msg(self.st.ftl, 0, struct.pack("<I", 0xff000011)))
        self.assertFalse(self.st.complete())
        self.st.wins.popitem()
        for key in ("states", "ident"):
            with self.subTest(missing=key):
                saved = self.st.wins[h].pop(key); self.assertFalse(self.st.complete())
                self.st.wins[h][key] = saved
        self.st.wins[h]["ws"].clear(); self.assertFalse(self.st.complete())

    def test_ordered_wins_by_handle(self):
        a = self.add_win(0xff000011, "a", "x", None); b = self.add_win(0xff000010, "b", "x", None)
        self.assertEqual([w["h"] for w in self.st.ordered_wins()], [a, b])


if __name__ == "__main__":
    unittest.main()


class ConnectRetry(unittest.TestCase):
    def setUp(self):
        self.t = [0.0]; self.attempts = 0
    def clock(self): return self.t[0]
    def sleep(self, s): self.t[0] += s

    def fake_socket(self, fail_times, exc=ConnectionRefusedError):
        test = self
        class S:
            def __init__(self, *_): pass
            def connect(self, path):
                test.attempts += 1
                if test.attempts <= fail_times: raise exc()
            def close(self): pass
        return S

    def test_retries_until_compositor_is_up(self):
        with mock.patch.object(wsk.socket, "socket", self.fake_socket(3)):
            wsk.connect("/x", wait=60, sleep=self.sleep, clock=self.clock)
        self.assertEqual(self.attempts, 4)

    def test_missing_socket_is_retried_too(self):
        with mock.patch.object(wsk.socket, "socket", self.fake_socket(2, FileNotFoundError)):
            wsk.connect("/x", wait=60, sleep=self.sleep, clock=self.clock)
        self.assertEqual(self.attempts, 3)

    def test_gives_up_after_wait(self):
        with mock.patch.object(wsk.socket, "socket", self.fake_socket(1000)):
            with self.assertRaises(ConnectionRefusedError):
                wsk.connect("/x", wait=5, sleep=self.sleep, clock=self.clock)
        self.assertEqual(self.attempts, 6)

    def test_no_wait_fails_at_once(self):
        with mock.patch.object(wsk.socket, "socket", self.fake_socket(1)):
            with self.assertRaises(ConnectionRefusedError):
                wsk.connect("/x", sleep=self.sleep, clock=self.clock)
        self.assertEqual(self.attempts, 1)
