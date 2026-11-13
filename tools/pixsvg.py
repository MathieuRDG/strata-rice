"""Strata — petit moteur SVG « pixel net » partagé par les générateurs de thèmes.

Une forme est une fonction f(x, y, w, h) -> couleur | (couleur, alpha) | None,
évaluée pixel par pixel ; les séries identiques sont fusionnées en rectangles.
"""

# Palette Strata
C, L, D = '#1A130D', '#8B6A47', '#4A3420'        # contour, biseau clair, biseau sombre
S, B = '#3A2C20', '#2B2118'                       # surface, bois
SL, SH = '#1F1812', '#120D08'                     # slot, ombre de slot
A, AF, SEL = '#7CCB4A', '#5D9B3A', '#2F3A1F'      # accent, herbe foncée, sélection
HOV = '#4A3828'
T, T2 = '#EDE3CF', '#B8A88C'
TERRE, PIERRE, CIEL = '#7A5232', '#6E6E6E', '#7FB2E5'
OR, GEMME, ROUGE, VIOLET = '#E8B23A', '#5ED6D0', '#C8553D', '#B58AD6'
SHADOW = ('#120D08', 0.55)


def mix(a, b, t):
    a, b = [int(a[i:i + 2], 16) for i in (1, 3, 5)], [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#%02X%02X%02X' % tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def bevel(contour, cw, light, dark, bw, inner):
    """Cadre : contour de cw px, biseau de bw px (clair haut/gauche), intérieur."""
    def f(x, y, w, h):
        d = min(x, y, w - 1 - x, h - 1 - y)
        if d < cw:
            return contour
        if d < cw + bw:
            dt, dl, db, dr = y - cw, x - cw, h - 1 - cw - y, w - 1 - cw - x
            m = min(dt, dl, db, dr)
            if (m == dt and m == dr) or (m == dl and m == db):
                return light if dt + dl < db + dr else dark
            return light if m in (dt, dl) else dark
        return inner
    return f


def raised(inner=S, cw=3, bw=3, contour=C):
    return bevel(contour, cw, L, D, bw, inner)


def sunken(inner=SL, cw=0, bw=3, contour=C):
    return bevel(contour, cw, SH, D, bw, inner)


def outline(col, cw=3, inner=None):
    return bevel(col, cw, None, None, 0, inner)


def flat(col):
    return lambda x, y, w, h: col


def empty():
    return lambda x, y, w, h: None


class SVG:
    def __init__(self, width=1200):
        self.out, self.x, self.y, self.rowh, self.W = [], 0, 0, 0, width

    def _place(self, w, h):
        if self.x + w > self.W:
            self.x, self.y, self.rowh = 0, self.y + self.rowh + 4, 0
        p = (self.x, self.y)
        self.x += w + 4
        self.rowh = max(self.rowh, h)
        return p

    def piece(self, ident, fn, W, H, x0=0, y0=0, x1=None, y1=None):
        """Rend la région [x0,x1)×[y0,y1) d'une forme W×H sous l'id donné."""
        x1 = W if x1 is None else x1
        y1 = H if y1 is None else y1
        w, h = x1 - x0, y1 - y0
        ox, oy = self._place(max(w, 1), max(h, 1))
        rects, open_ = [], {}
        for yy in range(y0, y1):
            runs, run = [], None
            for xx in range(x0, x1 + 1):
                c = fn(xx, yy, W, H) if xx < x1 else 'END'
                if run and c != run[1]:
                    if run[1]:
                        runs.append((run[0] - x0, xx - run[0], run[1]))
                    run = None
                if run is None and c != 'END':
                    run = (xx, c)
            new = {}
            for rx, rw, c in runs:
                k = (rx, rw, c)
                if k in open_:
                    r = open_.pop(k); r[3] += 1; new[k] = r
                else:
                    r = [rx, yy - y0, rw, 1, c]; rects.append(r); new[k] = r
            open_ = new
        parts = [f'<rect x="{ox}" y="{oy}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>']
        for rx, ry, rw, rh, c in rects:
            col, op = c if isinstance(c, tuple) else (c, 1)
            o = '' if op == 1 else f' fill-opacity="{op}"'
            parts.append(f'<rect x="{ox + rx}" y="{oy + ry}" width="{rw}" height="{rh}" fill="{col}"{o}/>')
        self.out.append(f'<g id="{ident}">' + ''.join(parts) + '</g>')

    def hint(self, ident, w, h):
        """Élément « hint » : seule sa taille compte."""
        ox, oy = self._place(max(w, 1), max(h, 1))
        self.out.append(f'<rect id="{ident}" x="{ox}" y="{oy}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>')

    def frame(self, prefix, fn, m, inner=8, W=None, H=None, skip=()):
        """9-slice FrameSvg. m = marge (int) ou (gauche, haut, droite, bas)."""
        ml, mt, mr, mb = (m, m, m, m) if isinstance(m, int) else m
        W = W or ml + mr + inner
        H = H or mt + mb + inner
        xs, ys = (0, ml, W - mr, W), (0, mt, H - mb, H)
        names = [['topleft', 'top', 'topright'], ['left', 'center', 'right'], ['bottomleft', 'bottom', 'bottomright']]
        pre = f'{prefix}-' if prefix else ''
        for j in range(3):
            for i in range(3):
                n = names[j][i]
                if n in skip or xs[i + 1] <= xs[i] or ys[j + 1] <= ys[j]:
                    continue
                self.piece(pre + n, fn, W, H, xs[i], ys[j], xs[i + 1], ys[j + 1])

    def text(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" '
                f'width="{self.W}" height="{self.y + self.rowh + 4}" shape-rendering="crispEdges">\n'
                + '\n'.join(self.out) + '\n</svg>\n')
