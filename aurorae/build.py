#!/usr/bin/env python3
"""Génère la décoration Aurorae « Strata » (SVG pixel net).

Bordure 8 px = contour 3 + biseau 3 + 2 px de surface ; ombre dure décalée
8×8 sans flou (padding droite/bas) ; client posé dans un liseré en creux
(innerborder). Boutons carrés 14 px : or = réduire, accent = agrandir,
rouge = fermer ; gris pierre quand la fenêtre est inactive.
Sortie : ./Strata/
"""
import os

C, L, D = '#1A130D', '#8B6A47', '#4A3420'
S, B, SH = '#3A2C20', '#2B2118', '#120D08'
SHADOW = ('#120D08', 0.55)
CW, BW, PAD, SOFF = 3, 3, 2, 8          # contour, biseau, surface, ombre
BORDER = CW + BW + PAD                  # 8
TITLE_H = 26


def mix(a, b, t):
    a, b = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#%02X%02X%02X' % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


class SVG:
    def __init__(self, width=900):
        self.out, self.x, self.y, self.rowh, self.W = [], 0, 0, 0, width

    def place(self, w, h):
        if self.x + w > self.W:
            self.x, self.y, self.rowh = 0, self.y + self.rowh + 4, 0
        p = (self.x, self.y)
        self.x += w + 4
        self.rowh = max(self.rowh, h)
        return p

    def piece(self, ident, fn, x0, y0, x1, y1):
        """Rend la région [x0,x1)×[y0,y1) ; séries fusionnées en rectangles."""
        w, h = x1 - x0, y1 - y0
        ox, oy = self.place(w, h)
        rects, open_ = [], {}
        for yy in range(y0, y1):
            runs, run = [], None
            for xx in range(x0, x1 + 1):
                c = fn(xx, yy) if xx < x1 else 'END'
                if run and c != run[1]:
                    if run[1]:
                        runs.append((run[0] - x0, xx - run[0], run[1]))
                    run = None
                if run is None and c != 'END':
                    run = (xx, c)
            new = {}
            for rx, rw, c in runs:
                key = (rx, rw, c)
                if key in open_:
                    r = open_.pop(key); r[3] += 1; new[key] = r
                else:
                    r = [rx, yy - y0, rw, 1, c]; rects.append(r); new[key] = r
            open_ = new
        parts = [f'<rect x="{ox}" y="{oy}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>']
        for rx, ry, rw, rh, c in rects:
            col, op = c if isinstance(c, tuple) else (c, 1)
            o = '' if op == 1 else f' fill-opacity="{op}"'
            parts.append(f'<rect x="{ox + rx}" y="{oy + ry}" width="{rw}" height="{rh}" fill="{col}"{o}/>')
        self.out.append(f'<g id="{ident}">' + ''.join(parts) + '</g>')

    def frame(self, prefix, fn, W, H, ml, mt, mr, mb):
        """Découpe une boîte W×H (fonction fn) en 9 pièces FrameSvg."""
        xs, ys = (0, ml, W - mr, W), (0, mt, H - mb, H)
        names = [['topleft', 'top', 'topright'], ['left', 'center', 'right'], ['bottomleft', 'bottom', 'bottomright']]
        for j in range(3):
            for i in range(3):
                if xs[i + 1] > xs[i] and ys[j + 1] > ys[j]:
                    self.piece(f'{prefix}-{names[j][i]}', fn, xs[i], ys[j], xs[i + 1], ys[j + 1])

    def text(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" '
                f'width="{self.W}" height="{self.y + self.rowh + 4}" shape-rendering="crispEdges">\n'
                + '\n'.join(self.out) + '\n</svg>\n')


TOPM = BORDER + TITLE_H   # marge haute du SVG = toute la barre de titre


def window_fn(W, H, surface, light, dark, contour, ring_tl=SH, ring_br=D):
    """Fenêtre W×H dont SOFF px à droite/en bas servent à l'ombre.

    Le client occupe [BORDER, w-BORDER) × [TOPM, h-BORDER) ; un liseré de
    PAD px en creux l'entoure (sombre en haut/gauche, biseau sombre en bas/droite).
    """
    w, h = W - SOFF, H - SOFF

    def f(x, y):
        if x >= w or y >= h:   # zone d'ombre
            return SHADOW if (x >= SOFF and y >= SOFF) else None
        d = min(x, y, w - 1 - x, h - 1 - y)
        if d < CW:
            return contour
        if d < CW + BW:
            dt, dl, db, dr = y - CW, x - CW, h - 1 - CW - y, w - 1 - CW - x
            m = min(dt, dl, db, dr)
            if (m == dt and m == dr) or (m == dl and m == db):
                return light if dt + dl < db + dr else dark
            return light if m in (dt, dl) else dark
        # liseré en creux autour du client
        cx0, cy0, cx1, cy1 = BORDER, TOPM, w - BORDER, h - BORDER
        if cx0 - PAD <= x < cx1 + PAD and cy0 - PAD <= y < cy1 + PAD and not (cx0 <= x < cx1 and cy0 <= y < cy1):
            if y < cy0 and x < cx1 or x < cx0 and y < cy1:
                return ring_tl
            return ring_br
        return surface
    return f


def build_decoration():
    s = SVG()
    W, H = 2 * BORDER + SOFF + 12, TOPM + BORDER + SOFF + 12
    m = (BORDER, TOPM, BORDER + SOFF, BORDER + SOFF)
    s.frame('decoration', window_fn(W, H, S, L, D, C), W, H, *m)
    s.frame('decoration-inactive', window_fn(W, H, B, mix(L, B, .45), mix(D, B, .3), C, SH, mix(D, B, .5)), W, H, *m)
    # agrandie : barre de titre plate, sans bordure ni ombre
    s.piece('decoration-maximized-center', lambda x, y: S, 0, 0, 8, 8)
    s.piece('decoration-maximized-inactive-center', lambda x, y: B, 0, 0, 8, 8)
    return s.text()


GLYPHS = {
    'minimize': ['..........', '..........', '..........', '..........', '..........', '..........', '..........', '.########.', '.########.', '..........'],
    'maximize': ['..........', '.########.', '.########.', '.#......#.', '.#......#.', '.#......#.', '.#......#.', '.########.', '..........', '..........'],
    'restore':  ['..........', '...######.', '...#....#.', '.######.#.', '.######.#.', '.#....###.', '.#....#...', '.######...', '..........', '..........'],
    'close':    ['..........', '.##....##.', '..##..##..', '...####...', '....##....', '...####...', '..##..##..', '.##....##.', '..........', '..........'],
}
COLORS = {'minimize': '#E8B23A', 'maximize': '#7CCB4A', 'restore': '#7CCB4A', 'close': '#C8553D'}
STONE = '#6E6E6E'


def button_fn(base, glyph=None, pressed=False, dim=False):
    n = 14
    hi, lo = mix(base, '#FFFFFF', .35), mix(base, '#000000', .35)
    if pressed:
        hi, lo = lo, hi
    if dim:
        base, hi, lo = mix(base, B, .5), mix(hi, B, .5), mix(lo, B, .5)

    def f(x, y):
        d = min(x, y, n - 1 - x, n - 1 - y)
        if d < 2:
            return C
        if glyph and 2 <= x - 0 < 12 and 2 <= y < 12 and glyph[y - 2][x - 2] == '#':
            return C
        if d < 3:
            return hi if (y == 2 or x == 2) else lo
        return base
    return f


def build_button(kind):
    s = SVG(200)
    col, g = COLORS[kind], GLYPHS[kind]
    s.piece('active-center', button_fn(col), 0, 0, 14, 14)
    s.piece('hover-center', button_fn(mix(col, '#FFFFFF', .2), g), 0, 0, 14, 14)
    s.piece('pressed-center', button_fn(mix(col, '#000000', .15), g, pressed=True), 0, 0, 14, 14)
    s.piece('deactivated-center', button_fn(col, dim=True), 0, 0, 14, 14)
    s.piece('inactive-center', button_fn(STONE), 0, 0, 14, 14)
    s.piece('hover-inactive-center', button_fn(col, g), 0, 0, 14, 14)
    s.piece('pressed-inactive-center', button_fn(mix(col, '#000000', .15), g, pressed=True), 0, 0, 14, 14)
    s.piece('deactivated-inactive-center', button_fn(STONE, dim=True), 0, 0, 14, 14)
    return s.text()


RC = f"""[General]
ActiveTextColor=237,227,207
InactiveTextColor=138,124,102
UseTextShadow=true
ActiveTextShadowColor=18,13,8
InactiveTextShadowColor=18,13,8
TextShadowOffsetX=2
TextShadowOffsetY=2
TitleAlignment=Left
TitleVerticalAlignment=Center
Animation=0
Shadow=false
DecorationPosition=0

[Layout]
BorderLeft={BORDER}
BorderRight={BORDER}
BorderBottom={BORDER}
TitleEdgeTop={BORDER}
TitleEdgeBottom=0
TitleEdgeLeft={BORDER}
TitleEdgeRight={BORDER}
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=0
TitleEdgeRightMaximized=0
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TITLE_H}
ButtonWidth=14
ButtonHeight=14
ButtonSpacing=6
ButtonMarginTop={(TITLE_H - 14) // 2}
ButtonMarginTopMaximized={(TITLE_H - 14) // 2}
ExplicitButtonSpacer=8
PaddingTop=0
PaddingLeft=0
PaddingRight={SOFF}
PaddingBottom={SOFF}
"""

METADATA = """{
    "KPackageStructure": "KWin/Aurorae",
    "KPlugin": {
        "Authors": [{"Name": "Strata"}],
        "Description": "Décoration pixel Strata : bois, biseaux, ombre dure",
        "Id": "Strata",
        "License": "GPL-2.0-or-later",
        "Name": "Strata",
        "Version": "1.0"
    }
}
"""

if __name__ == '__main__':
    import sys
    NAME = sys.argv[1] if len(sys.argv) > 1 else 'Strata'
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), NAME)
    METADATA = METADATA.replace('"Strata"', f'"{NAME}"')
    os.makedirs(out, exist_ok=True)
    files = {'decoration.svg': build_decoration(), f'{NAME}rc': RC, 'metadata.json': METADATA}
    for k in GLYPHS:
        files[f'{k}.svg'] = build_button(k)
    for name, content in files.items():
        with open(os.path.join(out, name), 'w') as f:
            f.write(content)
    print(out)
