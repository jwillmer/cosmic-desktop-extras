# Generates the README mockup SVGs. Run: python3 -I gen.py <outdir>
import sys, os
OUT = sys.argv[1]
FONT = "Inter, 'Open Sans', 'Noto Sans', sans-serif"
TXT = "#e6e6e6"; MUTED = "#a3a3a3"; ACC = "#0067B8"; FOC = "#004881"; ACC_TXT = "#5aa9f0"
PANEL = "#1e1e1e"

ICONS = {
 "browser": '''<symbol id="i-browser" viewBox="0 0 32 32"><circle cx="16" cy="16" r="14" fill="url(#gBrowser)"/><g fill="none" stroke="#fff" stroke-width="1.6" opacity=".95"><circle cx="16" cy="16" r="9"/><ellipse cx="16" cy="16" rx="4" ry="9"/><path d="M7 16h18M8.6 11.5h14.8M8.6 20.5h14.8"/></g></symbol>''',
 "term": '''<symbol id="i-term" viewBox="0 0 32 32"><rect x="3" y="4" width="26" height="24" rx="5" fill="#2d323a" stroke="#4b525c"/><path d="M9 12l4.5 4L9 20" fill="none" stroke="#7ee787" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M16 21h7" stroke="#7ee787" stroke-width="2.2" stroke-linecap="round"/></symbol>''',
 "folder": '''<symbol id="i-folder" viewBox="0 0 32 32"><path d="M3 8a2 2 0 0 1 2-2h7l3 3h12a2 2 0 0 1 2 2v2H3z" fill="#d99a2b"/><rect x="3" y="11" width="26" height="16" rx="2.5" fill="#f4bf4f"/></symbol>''',
 "music": '''<symbol id="i-music" viewBox="0 0 32 32"><rect x="3" y="3" width="26" height="26" rx="7" fill="url(#gMusic)"/><path d="M13 21.5V10l9-2v11.5" fill="none" stroke="#fff" stroke-width="2" stroke-linejoin="round"/><circle cx="11" cy="21.5" r="2.6" fill="#fff"/><circle cx="20" cy="19.5" r="2.6" fill="#fff"/></symbol>''',
 "mail": '''<symbol id="i-mail" viewBox="0 0 32 32"><rect x="3" y="3" width="26" height="26" rx="7" fill="#4f6bed"/><rect x="8" y="10.5" width="16" height="11" rx="1.8" fill="none" stroke="#fff" stroke-width="1.8"/><path d="M8.5 11.5l7.5 5.5 7.5-5.5" fill="none" stroke="#fff" stroke-width="1.8" stroke-linejoin="round"/></symbol>''',
 "chat": '''<symbol id="i-chat" viewBox="0 0 32 32"><rect x="3" y="3" width="26" height="26" rx="7" fill="#23a46f"/><path d="M9 10.5h14a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1-1.5 1.5h-7.5l-4 3v-3H9A1.5 1.5 0 0 1 7.5 19v-7A1.5 1.5 0 0 1 9 10.5z" fill="#fff"/></symbol>''',
 "code": '''<symbol id="i-code" viewBox="0 0 32 32"><rect x="3" y="3" width="26" height="26" rx="7" fill="#2b7bd0"/><path d="M12 11l-5 5 5 5M20 11l5 5-5 5M17.5 9.5l-3 13" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></symbol>''',
}
GRADS = '''<linearGradient id="gBrowser" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5fb4f5"/><stop offset="1" stop-color="#1c63b8"/></linearGradient><linearGradient id="gMusic" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff8a5c"/><stop offset="1" stop-color="#e0447a"/></linearGradient>'''
WALL = '''<linearGradient id="gWall" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1d2433"/><stop offset=".55" stop-color="#1a1d2b"/><stop offset="1" stop-color="#2a1f33"/></linearGradient><radialGradient id="gGlow1" cx=".18" cy=".2" r=".55"><stop offset="0" stop-color="#2f5d8a" stop-opacity=".55"/><stop offset="1" stop-color="#2f5d8a" stop-opacity="0"/></radialGradient><radialGradient id="gGlow2" cx=".85" cy=".1" r=".5"><stop offset="0" stop-color="#6b3f7a" stop-opacity=".45"/><stop offset="1" stop-color="#6b3f7a" stop-opacity="0"/></radialGradient>'''

def svg(w, h, body, icons=(), wall=False, title=""):
    defs = GRADS + (WALL if wall else "") + "".join(ICONS[i] for i in icons)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="{title}">'
            f'<title>{title}</title><defs>{defs}<clipPath id="cAll"><rect width="{w}" height="{h}" rx="14"/></clipPath></defs>'
            f'<style>text{{font-family:{FONT}}}</style>'
            f'<g clip-path="url(#cAll)"><rect width="{w}" height="{h}" fill="#141414"/>'
            + (f'<rect width="{w}" height="{h}" fill="url(#gWall)"/><rect width="{w}" height="{h}" fill="url(#gGlow1)"/><rect width="{w}" height="{h}" fill="url(#gGlow2)"/>' if wall else "")
            + body + '</g></svg>\n')

def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
def t(x, y, s, size=14, fill=TXT, weight=400, anchor="start", op=None, extra=""):
    o = f' opacity="{op}"' if op is not None else ""
    a = f' text-anchor="{anchor}"' if anchor != "start" else ""
    wgt = f' font-weight="{weight}"' if weight != 400 else ""
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}"{wgt}{a}{o}{extra}>{esc(s)}</text>'
def icon(name, x, y, s): return f'<use href="#i-{name}" x="{x}" y="{y}" width="{s}" height="{s}"/>'

def item(x, y, w, ic, title, sub, focused=False, hover=False, h=40):
    out = ""
    if focused: out += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{FOC}"/>'
    elif hover: out += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#ffffff" fill-opacity=".1"/>'
    out += icon(ic, x + 8, y + (h - 26) / 2, 26)
    col = "#ffffff" if focused else TXT
    out += t(x + 42, y + 17, title, 14, col, 500 if focused else 400)
    out += t(x + 42, y + 33, sub, 12, col, op=.75)
    return out

def launcher(x, y, s=36):
    g = ""
    for r in range(3):
        for c in range(3):
            g += f'<rect x="{x + 9 + c*7}" y="{y + 9 + r*7}" width="4" height="4" rx="1.2" fill="{TXT}"/>'
    return f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="8" fill="#ffffff" fill-opacity=".06"/>' + g

def overflow(x, y, h=40):
    return (f'<rect x="{x}" y="{y}" width="28" height="{h}" rx="8" fill="#ffffff" fill-opacity=".06"/>'
            f'<path d="M{x+9} {y+h/2+3}l5-5 5 5" fill="none" stroke="{TXT}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>')

# tray glyphs, 20x20 box at (x,y); colour None = coloured
def tray(kind, x, y, mono=None):
    c = lambda col: mono or col
    if kind == "mail":
        return (f'<g transform="translate({x},{y})"><rect x="1.5" y="4" width="17" height="12" rx="2" fill="{c("#f5c542")}"/>'
                f'<path d="M2.5 5.2l7.5 5.6 7.5-5.6" fill="none" stroke="#1e1e1e" stroke-width="1.5" stroke-linejoin="round"/>'
                f'<circle cx="16.5" cy="4.5" r="3.6" fill="{c("#e5484d")}" stroke="#1e1e1e" stroke-width="1.2"/></g>')
    if kind == "chat":
        return (f'<g transform="translate({x},{y})"><path d="M3.5 3h13a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H9l-4 3.2V15H3.5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z" fill="{c("#3fb950")}"/>'
                f'<circle cx="6.5" cy="9" r="1.3" fill="#1e1e1e"/><circle cx="10" cy="9" r="1.3" fill="#1e1e1e"/><circle cx="13.5" cy="9" r="1.3" fill="#1e1e1e"/></g>')
    if kind == "rec":
        return (f'<g transform="translate({x},{y})"><circle cx="10" cy="10" r="8" fill="none" stroke="{c("#e5484d")}" stroke-width="1.8"/>'
                f'<circle cx="10" cy="10" r="4.6" fill="{c("#e5484d")}"/></g>')
    if kind == "cloud":
        return (f'<g transform="translate({x},{y})"><path d="M5.5 16a4 4 0 0 1-.6-7.95A5.5 5.5 0 0 1 15.4 7.2 4.4 4.4 0 0 1 15 16z" fill="{c("#4c9aff")}"/>'
                f'<path d="M7.5 11.8l2 2 3.6-3.8" fill="none" stroke="#1e1e1e" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></g>')
    if kind == "vol":
        return (f'<g transform="translate({x},{y})" fill="none" stroke="{TXT}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
                f'<path d="M3 7.5h3l4-3.5v12l-4-3.5H3z" fill="{TXT}"/><path d="M13 7a4 4 0 0 1 0 6M15.5 4.8a7 7 0 0 1 0 10.4"/></g>')
    if kind == "net":
        return (f'<g transform="translate({x},{y})" fill="none" stroke="{TXT}" stroke-width="1.6" stroke-linecap="round">'
                f'<path d="M2.5 8a11 11 0 0 1 15 0M5 11a7.2 7.2 0 0 1 10 0M7.6 14a3.4 3.4 0 0 1 4.8 0"/><circle cx="10" cy="16.6" r="1.1" fill="{TXT}" stroke="none"/></g>')

def panel(x, y, w, h=52): return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{PANEL}" stroke="#ffffff" stroke-opacity=".07"/>'
def shadow_rect(x, y, w, h, rx=12, fill="#262626"):
    return (f'<rect x="{x}" y="{y+6}" width="{w}" height="{h}" rx="{rx}" fill="#000" opacity=".35"/>'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="#ffffff" stroke-opacity=".09"/>')
def clock(xr, y):
    return t(xr, y + 22, "14:32", 14, TXT, 500, "end") + t(xr, y + 38, "Thu, Nov 12", 12, TXT, anchor="end", op=.75)

def write(name, s):
    with open(os.path.join(OUT, name), "w") as f: f.write(s)

ALL = list(ICONS)

# 1 hero ---------------------------------------------------------------
def hero():
    W, H = 1280, 220
    b = ""
    # faint window behind
    b += t(40, 62, "COSMIC Desktop Extras", 26, "#ffffff", 600)
    b += t(40, 90, "A Windows-style taskbar, coloured tray icons, Super+D and windows", 14, TXT, op=.8)
    b += t(40, 110, "that stay on their workspace, for the COSMIC desktop.", 14, TXT, op=.8)
    b += hero_panel(W, 150)
    return svg(W, H, b, ALL, wall=True, title="COSMIC panel with the taskbar, coloured tray icons and clock")

def hero_panel(W, py):
    b = ""
    b += panel(16, py, W - 32, 56)
    b += launcher(28, py + 10)
    x = 76; y = py + 8
    items = [("browser", "Release notes", "4 tabs", 170, 0),
             ("music", "Music", "▶ Song Title – Artist", 206, 0),
             ("chat", "(3) Team chat", "3 unread", 168, 0),
             ("term", "build.sh", "~/projects/demo", 172, 1),
             ("folder", "Downloads", "12 items", 150, 0)]
    for ic, ti, su, w, f in items:
        b += item(x, y, w, ic, ti, su, focused=bool(f)); x += w + 6
    b += overflow(x, y)
    tx = x + 28 + 26
    b += f'<rect x="{tx-13}" y="{py+16}" width="1" height="24" fill="#ffffff" opacity=".12"/>'
    for k in ("mail", "chat", "rec", "cloud", "vol"):
        b += tray(k, tx, py + 18); tx += 30
    b += clock(W - 32, py + 8)
    return b

# 1b social preview (Open Graph, 1200x630) --------------------------------
def social():
    W, H = 1200, 630
    b = t(W / 2, 245, "COSMIC Desktop Extras", 64, "#ffffff", 700, anchor="middle")
    b += t(W / 2, 305, "A Windows-style taskbar and more for the COSMIC desktop on Pop!_OS", 26, TXT, anchor="middle", op=.85)
    # the hero panel (1280 wide) scaled to fit with equal margins
    b += f'<g transform="translate(24 405) scale(.9)">{hero_panel(1280, 0)}</g>'
    return svg(W, H, b, ALL, wall=True, title="COSMIC Desktop Extras: a Windows-style taskbar for the COSMIC desktop")

# 2 taskbar close-up -----------------------------------------------------
def taskbar():
    W, H = 880, 140
    b = ""
    py = 66
    b += panel(16, py, W - 32, 56)
    y = py + 8; x = 28
    spec = [("browser", "Release notes", "4 tabs", 168, 0),
            ("music", "Music", "▶ Song Title – Artist", 206, 0),
            ("chat", "(3) Team chat", "3 unread", 166, 0),
            ("term", "build.sh", "~/projects/demo", 172, 1)]
    pos = []
    for ic, ti, su, w, f in spec:
        b += item(x, y, w, ic, ti, su, focused=bool(f)); pos.append((x, w)); x += w + 6
    b += overflow(x, y); ax = x + 14
    def call(lx, label, tx, ty):
        return (t(lx, 26, label, 12, MUTED, anchor="middle")
                + f'<path d="M{lx} 33V{(33+ty)/2-4}Q{lx} {(33+ty)/2} {lx+(tx-lx)*0.15} {(33+ty)/2}H{tx-(tx-lx)*0.15}Q{tx} {(33+ty)/2} {tx} {(33+ty)/2+4}V{ty}" fill="none" stroke="#8a8a8a" stroke-width="1"/>'
                + f'<circle cx="{tx}" cy="{ty}" r="2.4" fill="#8a8a8a"/>')
    bx, bw = pos[0]; b += call(bx + 60, "tab count", bx + 60, y - 3)
    bx, bw = pos[1]; b += call(bx + 100, "now playing", bx + 100, y - 3)
    bx, bw = pos[2]; b += call(bx + 70, "unread count", bx + 70, y - 3)
    bx, bw = pos[3]; b += call(bx + bw/2, "focused window", bx + bw/2, y - 3)
    b += call(ax + 40, "more windows", ax, y - 3)
    # tray hint at right
    return svg(W, H, b, ALL, title="Taskbar items with tab count, now playing, unread count, focused window and overflow")

# 3 preview ---------------------------------------------------------------
def preview():
    W, H = 880, 360
    b = ""
    py = 286
    b += panel(16, py, W - 32, 56)
    y = py + 8; x = 28
    spec = [("browser", "Release notes", "4 tabs", 168, 0, 0),
            ("term", "build.sh", "~/projects/demo", 172, 1, 0),
            ("code", "main.rs", "demo-project", 160, 0, 1),
            ("folder", "Downloads", "12 items", 150, 0, 0),
            ("mail", "Inbox", "5 unread", 140, 0, 0)]
    hx = 0
    for ic, ti, su, w, f, hv in spec:
        b += item(x, y, w, ic, ti, su, focused=bool(f), hover=bool(hv))
        if hv: hx = x + w / 2
        x += w + 6
    # popup
    pw, ph = 320, 236; px = hx - pw / 2; pyy = py - ph - 14
    b += shadow_rect(px, pyy, pw, ph, 14, "#262626")
    # miniature window (code editor)
    mx, my, mw, mh = px + 14, pyy + 14, pw - 28, 176
    b += f'<rect x="{mx}" y="{my}" width="{mw}" height="{mh}" rx="8" fill="#1b1d22" stroke="#ffffff" stroke-opacity=".08"/>'
    b += f'<path d="M{mx} {my+8}a8 8 0 0 1 8-8h{mw-16}a8 8 0 0 1 8 8v12H{mx}z" fill="#2c2f36"/>'
    for i, c in enumerate(("#5c5f66", "#5c5f66", "#5c5f66")):
        b += f'<circle cx="{mx+mw-14-i*14}" cy="{my+10}" r="3.5" fill="{c}"/>'
    b += f'<rect x="{mx+10}" y="{my+7}" width="70" height="6" rx="3" fill="#ffffff" fill-opacity=".25"/>'
    b += f'<rect x="{mx}" y="{my+20}" width="56" height="{mh-20}" fill="#22252b"/>'
    for i in range(6):
        b += f'<rect x="{mx+8}" y="{my+32+i*14}" width="{36 - (i%3)*8}" height="5" rx="2.5" fill="#ffffff" fill-opacity=".18"/>'
    cols = ["#c792ea", "#82aaff", "#c3e88d", "#ffcb6b", "#89ddff", "#f78c6c"]
    lines = [(0, 40, 0), (0, 90, 1), (14, 60, 2), (14, 120, 3), (28, 80, 4), (28, 50, 2), (14, 100, 1), (0, 20, 5), (0, 0, 0), (0, 70, 0), (14, 110, 3)]
    for i, (ind, ln, c) in enumerate(lines):
        if ln == 0: continue
        b += f'<rect x="{mx+66+ind}" y="{my+30+i*12.5}" width="{ln}" height="5" rx="2.5" fill="{cols[c]}" fill-opacity=".8"/>'
        b += f'<rect x="{mx+70+ind+ln}" y="{my+30+i*12.5}" width="{ln*0.5}" height="5" rx="2.5" fill="#ffffff" fill-opacity=".22"/>'
    b += t(hx, pyy + ph - 20, "main.rs — demo-project", 14, TXT, anchor="middle")
    # hover pointer
    cx, cy = hx + 62, y + 14
    b += f'<path d="M{cx} {cy}l0 17 4.5-4.2 3 6.6 2.6-1.2-3-6.4 6-.4z" fill="#fff" stroke="#111" stroke-width="1.2" stroke-linejoin="round"/>'
    b += t(36, 36, "Hover a window: live preview", 14, TXT, 600)
    b += t(36, 56, "Up to 5 frames/s while hovered,", 12, MUTED)
    b += t(36, 72, "stopped when you move away.", 12, MUTED)
    return svg(W, H, b, ALL, wall=True, title="Hover preview popup above a taskbar item")

# 4 menus ------------------------------------------------------------------
def menus():
    W, H = 880, 360
    b = ""
    mw, rh = 280, 36
    def menu(x, y, rows, heading):
        n_sep = sum(1 for r in rows if r[0] == "sep")
        n = len(rows) - n_sep
        h = 12 + n * rh + n_sep * 13
        out = t(x + 4, y - 14, heading, 13, MUTED, 500)
        out += shadow_rect(x, y, mw, h, 12, "#262626")
        cy = y + 6
        for r in rows:
            kind = r[0]
            if kind == "sep":
                out += f'<rect x="{x+12}" y="{cy+6}" width="{mw-24}" height="1" fill="#ffffff" fill-opacity=".1"/>'; cy += 13; continue
            label = r[1]
            if kind == "hover":
                out += f'<rect x="{x+6}" y="{cy}" width="{mw-12}" height="{rh}" rx="8" fill="#ffffff" fill-opacity=".09"/>'
            col = ACC_TXT if kind == "cur" else TXT
            if kind == "cur":
                out += f'<path d="M{x+18} {cy+18}l4 4 8-9" fill="none" stroke="{ACC_TXT}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
                out += t(x + 40, cy + 23, label, 14, col, 500)
                out += t(x + mw - 18, cy + 23, "current", 12, ACC_TXT, anchor="end", op=.8)
            elif kind == "back":
                out += f'<path d="M{x+25} {cy+12}l-6 6 6 6" fill="none" stroke="{TXT}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>'
                out += t(x + 40, cy + 23, label, 14, col)
            else:
                out += t(x + 18 if kind != "ws" else x + 40, cy + 23, label, 14, col)
            if len(r) > 2 and r[2] == "sub":
                out += f'<path d="M{x+mw-24} {cy+12}l6 6-6 6" fill="none" stroke="{TXT}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>'
            if len(r) > 2 and r[2] == "key":
                out += t(x + mw - 18, cy + 23, r[3], 12, MUTED, anchor="end")
            cy += rh
        return out, h
    m1 = [("n", "New window"), ("sep",), ("n", "Minimize"), ("n", "Maximize"), ("hover", "Move to workspace", "sub"), ("sep",), ("n", "Close window", "key", "middle-click")]
    m2 = [("back", "Back"), ("sep",), ("ws", "Workspace 1"), ("cur", "Work"), ("ws", "Music"), ("ws", "Workspace 4")]
    x1, x2, y0 = 80, 520, 70
    s1, h1 = menu(x1, y0, m1, "Right-click a window in the taskbar")
    s2, h2 = menu(x2, y0, m2, "Move to workspace")
    b += s1 + s2
    # connector arrow from the hovered row to menu 2
    ay = y0 + 6 + 36 + 13 + 36 * 3 / 1 + 18 - 36  # middle of hover row
    ay = y0 + 6 + rh + 13 + rh * 2 + rh / 2
    b += f'<path d="M{x1+mw+16} {ay}H{x2-22}" stroke="{ACC_TXT}" stroke-width="2" stroke-dasharray="1 0" fill="none"/><path d="M{x2-28} {ay-6}l7 6-7 6" fill="none" stroke="{ACC_TXT}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    b += t((x1 + mw + x2) / 2, ay - 12, "switches the menu", 12, MUTED, anchor="middle")
    b += t(x2 + 4, y0 + h2 + 26, "The current workspace keeps its place,", 12, MUTED)
    b += t(x2 + 4, y0 + h2 + 42, "so the entries never shift.", 12, MUTED)
    return svg(W, H, b, (), wall=True, title="Taskbar right-click menu and the Move to workspace page")

# 5 tray colours -------------------------------------------------------------
def traycol():
    W, H = 880, 150
    b = ""
    def strip(x, label, sub, mono):
        out = t(x, 34, label, 15, "#ffffff", 600) + t(x, 54, sub, 12, MUTED)
        pw = 340
        out += panel(x, 72, pw, 52)
        tx = x + 20
        for k in ("mail", "chat", "rec", "cloud"):
            out += tray(k, tx, 88, mono); tx += 34
        out += f'<rect x="{tx+2}" y="{86}" width="1" height="24" fill="#ffffff" opacity=".12"/>'
        tx += 18
        out += tray("net", tx, 88) + tray("vol", tx + 34, 88)
        out += clock(x + pw - 16, 72 + 4)
        return out
    b += strip(40, "Before", "Upstream: every icon in one flat colour", TXT)
    b += f'<path d="M{400} 98H{474}" stroke="{MUTED}" stroke-width="2"/><path d="M{468} 92l7 6-7 6" fill="none" stroke="{MUTED}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    b += strip(500, "After", "tray-color: icons keep their own colours", None)
    return svg(W, H, b, (), title="Tray icons before and after the tray-color patch")

# 6 ws-keeper ---------------------------------------------------------------
def wsk():
    W, H = 880, 300
    b = ""
    cw = 264; gap = 24; x0 = 16
    def win(x, y, ic, w=56, h=36):
        return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="#2f3238" stroke="#ffffff" stroke-opacity=".14"/>'
                f'<rect x="{x}" y="{y}" width="{w}" height="7" rx="3" fill="#3b3f46"/>' + icon(ic, x + w/2 - 9, y + 11, 18))
    layouts = [
        ("Before", "your windows on workspaces 1–3", [["browser", "term"], ["code", "chat"], ["music", "mail"]], None),
        ("Login / compositor restart", "everything lands on workspace 1", [["browser", "term", "code", "chat", "music", "mail"], [], []], "#e5484d"),
        ("Workspace Keeper", "puts them back", [["browser", "term"], ["code", "chat"], ["music", "mail"]], "#3fb950"),
    ]
    for i, (h1, h2, wss, mark) in enumerate(layouts):
        cx = x0 + i * (cw + gap)
        b += f'<rect x="{cx}" y="16" width="{cw}" height="268" rx="12" fill="#1e1e1e" stroke="#ffffff" stroke-opacity=".07"/>'
        b += t(cx + 16, 44, h1, 14, "#ffffff", 600) + t(cx + 16, 63, h2, 12, MUTED)
        for j, ws in enumerate(wss):
            by = 84 + j * 64; bx = cx + 40; bw = cw - 56; bh = 54
            active = j == 0
            b += t(cx + 22, by + bh/2 + 5, str(j + 1), 13, TXT if ws else MUTED, 600, "middle")
            b += f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="6" fill="#171a22" stroke="#ffffff" stroke-opacity="{.16 if ws else .07}"/>'
            if len(ws) > 3:
                for k, ic in enumerate(ws):
                    b += win(bx + 10 + k * 24, by + 8 + (k % 3) * 4, ic, 46, 30)
            else:
                for k, ic in enumerate(ws):
                    b += win(bx + 10 + k * 64, by + 9, ic)
            if not ws:
                b += t(bx + bw/2, by + bh/2 + 4, "empty", 12, MUTED, anchor="middle", op=.7)
        if mark == "#3fb950":
            b += f'<circle cx="{cx+cw-24}" cy="40" r="10" fill="{mark}"/><path d="M{cx+cw-29} 40l3.5 3.5 6.5-7" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
        elif mark:
            b += f'<circle cx="{cx+cw-24}" cy="40" r="10" fill="{mark}"/><path d="M{cx+cw-24} 34.5v6.5" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/><circle cx="{cx+cw-24}" cy="45" r="1.3" fill="#fff"/>'
        if i < 2:
            ax = cx + cw + 3
            b += f'<circle cx="{ax+gap/2-3}" cy="150" r="13" fill="#2a2a2a" stroke="#ffffff" stroke-opacity=".12"/><path d="M{ax+gap/2-7} 145l5 5-5 5" fill="none" stroke="{TXT}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    return svg(W, H, b, ALL, title="Workspace Keeper moves windows back to their workspaces after a login or compositor restart")

# 7 show desktop -------------------------------------------------------------
def showd():
    W, H = 880, 260
    b = ""
    sw, sh = 220, 138; gap = 90; x0 = 20; y0 = 30
    def screen(x, state):
        cid = f"cS{int(x)}"
        out = f'<clipPath id="{cid}"><rect x="{x}" y="{y0}" width="{sw}" height="{sh}" rx="10"/></clipPath><g clip-path="url(#{cid})">'
        out += f'<rect x="{x}" y="{y0}" width="{sw}" height="{sh}" fill="url(#gWall)"/><rect x="{x}" y="{y0}" width="{sw}" height="{sh}" fill="url(#gGlow1)"/>'
        wins = [("browser", 14, 12, 118, 82), ("code", 84, 30, 120, 78)]
        if state != "min":
            for ic, wx, wy, ww, wh in wins:
                out += (f'<rect x="{x+wx}" y="{y0+wy}" width="{ww}" height="{wh}" rx="5" fill="#2a2d33" stroke="#ffffff" stroke-opacity=".15"/>'
                        f'<rect x="{x+wx}" y="{y0+wy}" width="{ww}" height="12" rx="4" fill="#383c44"/>' + icon(ic, x + wx + ww/2 - 12, y0 + wy + 30, 24))
        # mini panel
        out += f'<rect x="{x}" y="{y0+sh-22}" width="{sw}" height="22" fill="#1e1e1e"/>'
        for k, ic in enumerate(("browser", "code")):
            ix = x + 8 + k * 54
            foc = state != "min" and k == 1
            if foc: out += f'<rect x="{ix}" y="{y0+sh-19}" width="50" height="16" rx="4" fill="{FOC}"/>'
            out += icon(ic, ix + 3, y0 + sh - 17, 12)
            out += f'<rect x="{ix+19}" y="{y0+sh-13}" width="26" height="4" rx="2" fill="#ffffff" fill-opacity="{.8 if foc else .4}"/>'
        out += f'<rect x="{x+sw-34}" y="{y0+sh-13}" width="26" height="4" rx="2" fill="#ffffff" fill-opacity=".4"/>'
        out += '</g>' + f'<rect x="{x}" y="{y0}" width="{sw}" height="{sh}" rx="10" fill="none" stroke="#ffffff" stroke-opacity=".12"/>'
        return out
    def keys(cx, cy, label):
        out = ""
        # Super cap 46, plus, D cap 24
        sx = cx - 40
        for kx, kw, kt in ((sx, 46, "Super"), (sx + 56, 24, "D")):
            out += (f'<rect x="{kx}" y="{cy+2}" width="{kw}" height="24" rx="5" fill="#0d0d0d"/>'
                    f'<rect x="{kx}" y="{cy}" width="{kw}" height="23" rx="5" fill="#33363b" stroke="#ffffff" stroke-opacity=".18"/>'
                    + t(kx + kw/2, cy + 16, kt, 11, "#ffffff", 600, "middle"))
        out += t(sx + 51, cy + 16, "+", 12, MUTED, anchor="middle")
        out += f'<path d="M{cx-32} {cy+44}H{cx+28}" stroke="{ACC_TXT}" stroke-width="2"/><path d="M{cx+22} {cy+38}l7 6-7 6" fill="none" stroke="{ACC_TXT}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
        out += t(cx, cy + 70, label, 12, MUTED, anchor="middle")
        return out
    caps = [("Windows open", "you are working"), ("Desktop visible", "windows wait in the taskbar"), ("Windows back", "same window in focus")]
    for i, st in enumerate(("open", "min", "back")):
        x = x0 + i * (sw + gap)
        b += screen(x, st)
        b += t(x + sw/2, y0 + sh + 30, caps[i][0], 14, "#ffffff", 600, "middle")
        b += t(x + sw/2, y0 + sh + 49, caps[i][1], 12, MUTED, anchor="middle")
        if i < 2:
            b += keys(x + sw + gap/2, y0 + 34, "press" if i == 0 else "press again")
    return svg(W, H, b, ("browser", "code"), wall=False, title="Super+D minimizes the windows of the workspace, a second press brings them back").replace('<defs>', '<defs>' + WALL, 1)

write("hero.svg", hero()); write("social.svg", social()); write("taskbar.svg", taskbar()); write("taskbar-preview.svg", preview())
write("taskbar-menu.svg", menus()); write("tray-colors.svg", traycol()); write("ws-keeper.svg", wsk()); write("show-desktop.svg", showd())
