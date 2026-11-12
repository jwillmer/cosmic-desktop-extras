import importlib.util, os, unittest

spec = importlib.util.spec_from_file_location(
    "show_desktop", os.path.join(os.path.dirname(os.path.abspath(__file__)), "show-desktop.py"))
sd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sd)

MIN, ACT = sd.MINIMIZED, sd.ACTIVATED


def win(h, ident=None, app="app", ws=1, states=()):
    return {"h": h, "app_id": app, "ident": f"id{h}" if ident is None else ident,
            "ws": {ws}, "states": set(states)}


def press(wins, last, active=frozenset({1})):
    """One press: apply decide()'s result to wins like the compositor would."""
    minimize, restore, focus, new_state = sd.decide(wins, set(active), last)
    for w in minimize: w["states"] = (w["states"] - {ACT}) | {MIN}
    for w in restore + ([focus] if focus else []): w["states"] = w["states"] - {MIN}
    if focus: focus["states"] = focus["states"] | {ACT}
    return minimize, restore, focus, new_state


class Decide(unittest.TestCase):
    def test_minimizes_open_windows_and_records_focus(self):
        a, b = win(1), win(2, states={ACT})
        minimize, restore, focus, state = sd.decide([a, b], {1}, {})
        self.assertEqual(minimize, [a, b])
        self.assertEqual((restore, focus), ([], None))
        self.assertEqual(state, {"minimized": ["id1", "id2"], "focused": "id2"})

    def test_other_workspaces_untouched(self):
        a, other = win(1), win(2, ws=2)
        minimize, _, _, state = sd.decide([a, other], {1}, {})
        self.assertEqual(minimize, [a])
        self.assertEqual(state["minimized"], ["id1"])

    def test_skips_panel_and_empty_app_id(self):
        a = win(1)
        minimize, _, _, _ = sd.decide([win(2, app="com.system76.CosmicPanel"), win(3, app=""), a],
                                      {1}, {})
        self.assertEqual(minimize, [a])

    def test_skips_windows_without_ident(self):
        a = win(1)
        minimize, _, _, _ = sd.decide([win(2, ident=""), a], {1}, {})
        self.assertEqual(minimize, [a])

    def test_second_press_restores_ours_focus_last(self):
        a, b, c = win(1, states={ACT}), win(2), win(3)
        _, _, _, last = press([a, b, c], {})
        minimize, restore, focus, state = sd.decide([a, b, c], {1}, last)
        self.assertEqual(minimize, [])
        self.assertEqual(restore, [b, c])
        self.assertIs(focus, a)
        self.assertEqual(state, {})

    def test_user_minimized_window_stays_minimized(self):
        a, mine = win(1, states={ACT}), win(2, states={MIN})
        _, _, _, last = press([a, mine], {})
        self.assertEqual(last["minimized"], ["id1"])
        _, restore, focus, _ = sd.decide([a, mine], {1}, last)
        self.assertEqual(restore, [])
        self.assertIs(focus, a)

    def test_new_window_in_between_minimizes_again(self):
        a = win(1, states={ACT})
        _, _, _, last = press([a], {})
        new = win(2, states={ACT})
        minimize, restore, focus, state = sd.decide([a, new], {1}, last)
        self.assertEqual(minimize, [new])
        self.assertEqual((restore, focus), ([], None))
        self.assertEqual(state, {"minimized": ["id2"], "focused": "id2"})

    def test_nothing_open_and_empty_state_is_noop(self):
        self.assertEqual(sd.decide([win(1, states={MIN})], {1}, {}), ([], [], None, None))
        self.assertEqual(sd.decide([], {1}, {}), ([], [], None, None))

    def test_state_with_closed_windows_is_noop(self):
        last = {"minimized": ["gone1", "gone2"], "focused": "gone1"}
        self.assertEqual(sd.decide([win(1, states={MIN})], {1}, last), ([], [], None, None))


if __name__ == "__main__":
    unittest.main()
