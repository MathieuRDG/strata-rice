#!/usr/bin/env python3
"""Strata — générateur de fond d'écran pixel original (jour / nuit).

Python pur (zlib), aucune dépendance. Rendu sur une grille logique basse
résolution puis agrandi au plus proche voisin (net, sans lissage).

  ./generate.py 1920 1080            -> strata-day-1920x1080.png + strata-night-1920x1080.png
  ./generate.py 2560 1440 --seed 7
"""
import argparse, math, random, struct, zlib, os


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


P = {k: hx(v) for k, v in dict(
    bois='#2B2118', surface='#3A2C20', slot='#1F1812', ombre='#120D08',
    contour='#1A130D', biseau_c='#8B6A47', biseau_s='#4A3420', texte='#EDE3CF',
    texte2='#B8A88C', herbe='#7CCB4A', herbe_f='#5D9B3A', terre='#7A5232',
    pierre='#6E6E6E', ciel='#7FB2E5', or_='#E8B23A', gemme='#5ED6D0',
    rouge='#C8553D', violet='#B58AD6', nuit='#2A3550').items()}


def write_png(path, w, h, rows):
    raw = b''.join(b'\x00' + r for r in rows)

    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)

    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))


def ridge(rng, w, base, amps):
    """Profil 1D : somme de sinusoïdes à phases aléatoires."""
    comps = [(a, rng.uniform(0, math.tau), p) for a, p in amps]
    return [round(base + sum(a * math.sin(x * math.tau / p + ph) for a, ph, p in comps)) for x in range(w)]


def disc(cx, cy, r):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                yield x, y


def render(W, H, night, seed):
    s = max(1, round(H / 135))            # taille d'un « pixel » logique
    w, h = -(-W // s), -(-H // s)
    rng = random.Random(seed)
    g = [[(0, 0, 0)] * w for _ in range(h)]

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            g[y][x] = c

    def get(x, y):
        return g[y][x] if 0 <= x < w and 0 <= y < h else None

    # ---- ciel en bandes
    if night:
        top, bot = mix(P['nuit'], (0, 0, 0), .35), mix(P['nuit'], P['violet'], .18)
    else:
        top, bot = mix(P['ciel'], (40, 80, 160), .25), mix(P['ciel'], P['texte'], .45)
    sky_h = int(h * .72)
    bands = 9
    for y in range(h):
        b = min(bands - 1, int(y / sky_h * bands))
        # bord de bande tramé (damier) pour un dégradé pixel
        edge = (y / sky_h * bands) % 1
        c1 = mix(top, bot, b / (bands - 1))
        c2 = mix(top, bot, min(1, (b + 1) / (bands - 1)))
        for x in range(w):
            g[y][x] = c2 if (edge > .8 and (x + y) % 2 == 0) else c1

    # ---- astres / étoiles / nuages
    if night:
        for _ in range(w * sky_h // 120):
            x, y = rng.randrange(w), int(sky_h * .78 * rng.random() ** 1.4)
            c = mix(P['texte'], P['gemme'], rng.random() * .3)
            put(x, y, c)
            if rng.random() < .07:     # étoile en croix
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    put(x + dx, y + dy, mix(c, g[y][x] if get(x, y) else c, .5) if False else mix(c, top, .5))
        mx, my, mr = int(w * .78), int(h * .16), 7
        for x, y in disc(mx, my, mr + 2):
            put(x, y, mix(get(x, y) or top, P['texte'], .12))
        for x, y in disc(mx, my, mr):
            put(x, y, mix(P['texte'], P['texte2'], .15))
        for x, y in disc(mx + 3, my - 2, mr - 1):   # croissant
            if get(x, y) and (x - mx) ** 2 + (y - my) ** 2 <= mr * mr:
                put(x, y, mix(top, bot, .25))
        for cx, cy in ((mx - 3, my + 2), (mx - 1, my - 3), (mx - 5, my - 1)):
            put(cx, cy, P['texte2'])
    else:
        sx, sy = int(w * .8), int(h * .17)
        for x, y in disc(sx, sy, 10):
            put(x, y, mix(get(x, y), P['texte'], .25))
        for x, y in disc(sx, sy, 7):
            put(x, y, mix(P['or_'], P['texte'], .55))
        for x, y in disc(sx - 1, sy - 1, 4):
            put(x, y, mix(P['or_'], P['texte'], .8))
        cl, cs = P['texte'], mix(P['texte'], P['ciel'], .45)
        for i in range(6):
            while True:
                cx, cy = rng.randrange(w), rng.randrange(8, int(sky_h * .55))
                if not (sx - 40 < cx < sx + 14 and cy < sy + 14):
                    break
            puffs = [(cx + dx, cy + rng.randint(-1, 1), rng.randint(2, 4)) for dx in range(0, rng.randint(14, 30), 4)]
            pts = set()
            for px, py, r in puffs:
                pts |= set(disc(px, py - r // 2, r))
            base = max(y for _, y in pts)
            for x, y in pts:
                put(x % w, y, cs if y >= base - 1 else cl)

    # ---- collines (lointaines -> proches)
    hill_sets = [
        (h * .56, [(6, 61), (3, 23), (1.5, 9)], .55),
        (h * .63, [(5, 47), (2, 17)], .3),
    ]
    for base, amps, haze in hill_sets:
        prof = ridge(rng, w, base, amps)
        if night:
            col = mix(mix(P['herbe_f'], P['nuit'], .6), (10, 12, 24), .35 + haze * .3)
            hi = mix(col, P['ciel'], .12)
        else:
            col = mix(mix(P['herbe_f'], (20, 40, 30), .25), bot, haze)
            hi = mix(col, P['herbe'], .25)
        for x in range(w):
            for y in range(prof[x], h):
                put(x, y, hi if y - prof[x] < 1 else col)

    # ---- sol en coupe : herbe / terre / pierre
    surf = ridge(rng, w, h * .70, [(2.2, 53), (1.2, 19)])
    dirt_end = ridge(rng, w, h * .80, [(2, 31), (1, 7)])
    nf = .55 if night else 0  # assombrissement nocturne
    dark = (14, 18, 34)
    herbe = mix(P['herbe'], dark, nf)
    herbe_f = mix(P['herbe_f'], dark, nf)
    terre = mix(P['terre'], dark, nf)
    terre_s = mix(P['terre'], P['biseau_s'], .6)
    terre_s = mix(terre_s, dark, nf)
    terre_c = mix(mix(P['terre'], P['biseau_c'], .35), dark, nf)
    pierre = mix(P['pierre'], dark, nf)
    pierre_s = mix(mix(P['pierre'], (40, 40, 44), .45), dark, nf)
    pierre_c = mix(mix(P['pierre'], P['texte'], .15), dark, nf)
    deep = mix(mix(P['pierre'], P['ombre'], .55), dark, nf * .5)

    for x in range(w):
        for y in range(surf[x], h):
            d = y - surf[x]
            r = rng.random()
            if d < 2:
                c = herbe if r > .12 else herbe_f
            elif d < 4:
                # frange herbe/terre irrégulière
                c = herbe_f if r < (.7 if d == 2 else .3) else terre
            elif y < dirt_end[x]:
                c = terre_s if r < .14 else terre_c if r < .22 else terre
            elif y < dirt_end[x] + 2:
                c = pierre_s if r < .5 else terre_s
            else:
                t = (y - dirt_end[x]) / max(1, h - dirt_end[x])
                c = pierre_s if r < .16 else pierre_c if r < .24 else pierre
                if t > .65 and rng.random() < (t - .65) * 2:
                    c = deep
            put(x, y, c)

    # touffes d'herbe au-dessus de la surface
    for x in range(w):
        if rng.random() < .22:
            put(x, surf[x] - 1, herbe if rng.random() < .6 else herbe_f)

    # ---- minerais (amas de 2-5 pixels avec reflet)
    ores = [(P['or_'], 9), (P['gemme'], 6), (P['violet'], 4), (P['rouge'], 4), (P['ombre'], 10)]
    for col, n in ores:
        for _ in range(int(n * w / 240)):
            x = rng.randrange(w)
            y = rng.randrange(dirt_end[x] + 4, h - 2) if dirt_end[x] + 4 < h - 2 else h - 3
            c = mix(col, dark, nf * .5) if col != P['ombre'] else mix(pierre_s, P['ombre'], .5)
            cells = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            cells = [c for c in cells if rng.random() < .8] or [(x, y)]
            if rng.random() < .5:
                cells.append((x + rng.choice((-1, 2)), y + rng.randint(0, 1)))
            for cx, cy in cells:
                put(cx, cy, c)
            if col != P['ombre']:
                put(*min(cells), mix(c, P['texte'], .45))

    # ---- arbres originaux : tronc fin + houppier arrondi en deux tons
    trunk = mix(mix(P['terre'], P['contour'], .35), dark, nf)
    leaf, leaf_d, leaf_c = (mix(c, dark, nf * 1.25) for c in (P['herbe_f'], mix(P['herbe_f'], P['contour'], .35), P['herbe']))
    xs, x = [], rng.randint(4, 14)
    while x < w - 6:
        if not (w * .3 < x < w * .7) or rng.random() < .35:   # dégager le centre (hotbar)
            xs.append(x)
        x += rng.randint(12, 34)
    for tx in xs:
        ty = surf[tx]
        th = rng.randint(6, 10)
        for y in range(ty - th, ty):
            put(tx, y, trunk)
            put(tx + 1, y, mix(trunk, P['contour'], .3))
        r = rng.randint(4, 6)
        cy = ty - th - r + 2
        for px, py in disc(tx + .5, cy, r):
            dd = (px - tx - .5 + 1.5) ** 2 + (py - cy + 1.5) ** 2
            c = leaf_c if dd < (r * .55) ** 2 else leaf
            if (px - tx - .5) + (py - cy) > r * .8:
                c = leaf_d
            put(px, py, c)
        for px, py in disc(tx - r * .7, cy + 2, r * .6):
            put(px, py, leaf_d if py > cy + 2 else leaf)
        if night:
            for _ in range(2):
                put(tx + rng.randint(-r + 1, r - 1), cy + rng.randint(-r + 2, r - 2), leaf_d)

    # ---- torches (nuit) : piquet + flamme + halo tramé
    if night:
        stick = mix(P['terre'], P['biseau_c'], .2)
        txs = [int(w * f) for f in (.12, .31, .5, .69, .9)]
        lights = []
        for tx in txs:
            while any(abs(tx - t) < 4 for t in xs):
                tx += 3
            ty = surf[tx] - 1
            put(tx, ty, stick); put(tx, ty - 1, stick); put(tx, ty - 2, stick)
            put(tx, ty - 3, P['or_']); put(tx, ty - 4, mix(P['or_'], P['texte'], .5))
            lights.append((tx, ty - 3, 9))
        # deux torches dans la pierre (galerie)
        for f in (.22, .79):
            tx = int(w * f); ty = dirt_end[tx] + int((h - dirt_end[tx]) * .45)
            for px, py in disc(tx, ty, 4):
                put(px, py, mix(P['ombre'], pierre_s, .2))
            put(tx, ty + 1, stick); put(tx, ty, P['or_']); put(tx, ty - 1, mix(P['or_'], P['texte'], .5))
            lights.append((tx, ty, 8))
        warm = mix(P['or_'], P['texte'], .3)
        for lx, ly, R in lights:
            for y in range(ly - R, ly + R + 1):
                for x in range(lx - R, lx + R + 1):
                    c = get(x, y)
                    if c is None or (x, y) == (lx, ly):
                        continue
                    d = math.hypot(x - lx, y - ly) / R
                    if d >= 1:
                        continue
                    level = 3 if d < .35 else 2 if d < .65 else 1
                    if level == 1 and (x + y) % 2:   # bord tramé
                        continue
                    put(x, y, mix(c, warm, .07 * level))

    # ---- agrandissement au plus proche voisin + recadrage
    rows = []
    for y in range(H):
        row = g[y // s]
        rows.append(b''.join(bytes(row[x // s]) for x in range(W)))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('width', type=int, nargs='?', default=1920)
    ap.add_argument('height', type=int, nargs='?', default=1080)
    ap.add_argument('--seed', type=int, default=42)
    ap.add_argument('--out', default=os.path.dirname(os.path.abspath(__file__)))
    a = ap.parse_args()
    for night in (False, True):
        name = f"strata-{'night' if night else 'day'}-{a.width}x{a.height}.png"
        path = os.path.join(a.out, name)
        write_png(path, a.width, a.height, render(a.width, a.height, night, a.seed))
        print(path)


if __name__ == '__main__':
    main()
