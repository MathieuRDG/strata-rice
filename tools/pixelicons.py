#!/usr/bin/env python3
"""Strata — pixelise les icônes des applications installées dans un thème d'icônes « Strata-Pixel ».

Pour chaque application (.desktop système, utilisateur, Flatpak) :
  icône d'origine (cherchée dans le thème de BASE, jamais dans Strata-Pixel)
  → rendu 256 px → réduction sur une petite grille (16/22/24/32) → alpha tout-ou-rien
  → 12 couleurs réchauffées vers la palette Strata → contour sombre 1 px
  → agrandissement au plus proche voisin (24→48/96/192, 32→64/128/256).
Le thème hérite du thème de base : seules les icônes d'applications changent.

  pixelicons.py                 met à jour (rapide : seules les icônes nouvelles/modifiées sont refaites)
  pixelicons.py --apply         + active le thème d'icônes Strata-Pixel
  pixelicons.py --force         refait tout
  pixelicons.py --only firefox  (débogage) une seule icône
Exclusions : variable PIXEL_ICONS_EXCLUDE (ids .desktop séparés par des espaces) dans strata.conf.
"""
import configparser, glob, gzip, hashlib, io, json, os, re, shlex, subprocess, sys
from PIL import Image

HOME = os.path.expanduser("~")
THEME = "Strata-Pixel"
OUT = os.path.join(HOME, ".local/share/icons", THEME)
STATE = os.path.join(HOME, ".local/state/strata/pixelicons.json")
VERSION = 3                       # incrémenter pour forcer une régénération après changement d'algorithme
GRIDS = {16: [16], 22: [22], 24: [24, 48, 96, 192], 32: [32, 64, 128, 256]}

APP_DIRS = ["/usr/share/applications", os.path.join(HOME, ".local/share/applications"),
            "/var/lib/flatpak/exports/share/applications",
            os.path.join(HOME, ".local/share/flatpak/exports/share/applications")]
ICON_ROOTS = [os.path.join(HOME, ".local/share/icons"), os.path.join(HOME, ".icons"), "/usr/share/icons",
              "/var/lib/flatpak/exports/share/icons", os.path.join(HOME, ".local/share/flatpak/exports/share/icons")]
PIXMAPS = ["/usr/share/pixmaps"]

# Palette Strata (+ quelques nuances) vers laquelle les couleurs sont légèrement attirées
PALETTE = ["#2B2118", "#3A2C20", "#1F1812", "#8B6A47", "#4A3420", "#EDE3CF", "#B8A88C", "#7CCB4A", "#5D9B3A",
           "#7A5232", "#6E6E6E", "#7FB2E5", "#E8B23A", "#5ED6D0", "#C8553D", "#B58AD6", "#2A3550", "#A6E07A",
           "#4F7FB5", "#D9D0BC", "#9A9A9A", "#3E5A26"]
PAL = [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in PALETTE]
OUTLINE = (0x1A, 0x13, 0x0D, 255)
PULL = 0.22                        # 0 = couleurs d'origine, 1 = palette Strata stricte


def log(*a):
    print("pixelicons:", *a, file=sys.stderr)


# ------------------------------------------------------------------ thèmes et recherche d'icônes
def theme_chain(base):
    chain, todo = [], [base]
    while todo:
        t = todo.pop(0)
        if t in chain or t == THEME:
            continue
        chain.append(t)
        for r in ICON_ROOTS:
            idx = os.path.join(r, t, "index.theme")
            if os.path.exists(idx):
                cp = configparser.ConfigParser(interpolation=None, strict=False)
                cp.read(idx)
                inh = cp.get("Icon Theme", "Inherits", fallback="")
                todo += [x.strip() for x in inh.split(",") if x.strip()]
                break
    if "hicolor" not in chain:
        chain.append("hicolor")
    return chain


def build_index(chain):
    """nom → liste de (rang du thème, priorité de format, taille, chemin)."""
    idx = {}
    for rank, t in enumerate(chain):
        for r in ICON_ROOTS:
            base = os.path.join(r, t)
            if not os.path.isdir(base):
                continue
            for dp, _, files in os.walk(base):
                m = re.search(r"/(\d+)x\d+(?:@\d)?/|/(\d+)/", dp + "/")
                size = int(m.group(1) or m.group(2)) if m else (512 if "scalable" in dp else 0)
                for f in files:
                    n, ext = os.path.splitext(f)
                    if ext not in (".svg", ".svgz", ".png"):
                        continue
                    fmt = 0 if ext in (".svg", ".svgz") else 1
                    idx.setdefault(n, []).append((rank, fmt, -size, os.path.join(dp, f)))
    for p in PIXMAPS:
        for f in glob.glob(os.path.join(p, "*")):
            n, ext = os.path.splitext(os.path.basename(f))
            if ext in (".svg", ".png", ".xpm"):
                idx.setdefault(n, []).append((99, 0 if ext == ".svg" else 1, 0, f))
    return idx


def lookup(idx, name):
    c = idx.get(name)
    return sorted(c)[0][3] if c else None


# ------------------------------------------------------------------ rendu et pixelisation
def load(path, px=256):
    if path.endswith((".svg", ".svgz")):
        data = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-a", path],
                              capture_output=True, check=True).stdout
        img = Image.open(io.BytesIO(data))
    else:
        img = Image.open(path)
    img = img.convert("RGBA")
    # recentre dans un carré
    w, h = img.size
    s = max(w, h)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(img, ((s - w) // 2, (s - h) // 2))
    return sq.resize((px, px), Image.LANCZOS) if s != px else sq


def nearest_pal(c):
    return min(PAL, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def pixelize(src, grid):
    # 1) recadrage sur la zone visible, marge homogène
    bbox = src.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    if bbox:
        src = src.crop(bbox)
    w, h = src.size
    s = max(w, h)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(src, ((s - w) // 2, (s - h) // 2))
    inner = grid - 2                                   # 1 px de contour de chaque côté
    small = sq.resize((inner, inner), Image.BOX)
    # 2) alpha tout-ou-rien
    a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    # 3) réduction des couleurs puis attraction vers la palette Strata
    rgb = Image.new("RGB", small.size, (0, 0, 0))
    rgb.paste(small.convert("RGB"), mask=a)
    q = rgb.quantize(colors=12, method=Image.Quantize.MEDIANCUT).convert("RGB")
    px = q.load()
    for y in range(inner):
        for x in range(inner):
            c = px[x, y]
            p = nearest_pal(c)
            px[x, y] = tuple(round(c[i] + (p[i] - c[i]) * PULL) for i in range(3))
    out = Image.new("RGBA", (grid, grid), (0, 0, 0, 0))
    q.putalpha(a)
    out.paste(q, (1, 1))
    # 4) contour sombre de 1 px autour des pixels opaques
    o = out.load()
    edge = []
    for y in range(grid):
        for x in range(grid):
            if o[x, y][3] == 0 and any(0 <= x + dx < grid and 0 <= y + dy < grid and o[x + dx, y + dy][3] == 255
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for x, y in edge:
        o[x, y] = OUTLINE
    return out


# ------------------------------------------------------------------ applications
def desktop_entries(exclude):
    seen = {}
    for d in APP_DIRS:
        for f in sorted(glob.glob(os.path.join(d, "*.desktop"))):
            did = os.path.basename(f)[:-8]
            if did in seen or did in exclude:
                continue
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            if e.get("Hidden", "false").lower() == "true" or e.get("Type", "Application") != "Application":
                continue
            icon = e.get("Icon", "").strip()
            if icon:
                seen[did] = (f, icon, e.get("X-Strata-PixelIcon", "") == "true")
    return seen


def write_index(base):
    dirs = []
    for sizes in GRIDS.values():
        dirs += [f"{s}x{s}/apps" for s in sizes]
    lines = ["[Icon Theme]", f"Name={THEME}", "Comment=Icônes d'applications pixelisées (Strata)",
             f"Inherits={base},hicolor", "Example=firefox", "Directories=" + ",".join(dirs), ""]
    for d in dirs:
        s = int(d.split("x")[0])
        lines += [f"[{d}]", f"Size={s}", "Context=Applications", "Type=Fixed", ""]
    open(os.path.join(OUT, "index.theme"), "w").write("\n".join(lines))


def main():
    args = sys.argv[1:]
    force, apply_theme = "--force" in args, "--apply" in args
    only = args[args.index("--only") + 1] if "--only" in args else None
    exclude = set(os.environ.get("PIXEL_ICONS_EXCLUDE", "").split())

    state = {}
    if os.path.exists(STATE):
        try:
            state = json.load(open(STATE))
        except Exception:
            state = {}
    current = subprocess.run(["kreadconfig6", "--file", "kdeglobals", "--group", "Icons", "--key", "Theme"],
                             capture_output=True, text=True).stdout.strip() or "breeze-dark"
    base = state.get("base") if current == THEME else current
    base = base or "breeze-dark"
    if state.get("version") != VERSION or state.get("base") != base:
        force = True
    state.update(version=VERSION, base=base)
    icons = state.setdefault("icons", {})

    os.makedirs(OUT, exist_ok=True)
    write_index(base)
    idx = build_index(theme_chain(base))
    apps_dir = os.path.join(HOME, ".local/share/applications")

    done = skipped = failed = 0
    for did, (path, icon, ours) in desktop_entries(exclude).items():
        if only and only not in (did, icon):
            continue
        if os.path.isabs(icon):                         # icône en chemin absolu → nom dédié + .desktop local
            src, name = icon, "strata-pixel-" + re.sub(r"[^A-Za-z0-9_.-]", "_", did)
        else:
            if icon.startswith("strata-pixel-"):
                continue
            name = icon
            src = lookup(idx, icon)
        if not src or not os.path.exists(src):
            continue
        key = hashlib.sha1(f"{src}:{os.path.getmtime(src)}".encode()).hexdigest()
        if not force and icons.get(name) == key and os.path.exists(os.path.join(OUT, "32x32/apps", name + ".png")):
            skipped += 1
        else:
            try:
                big = load(src)
                for grid, sizes in GRIDS.items():
                    g = pixelize(big, grid)
                    for s in sizes:
                        d = os.path.join(OUT, f"{s}x{s}/apps")
                        os.makedirs(d, exist_ok=True)
                        g.resize((s, s), Image.NEAREST).save(os.path.join(d, name + ".png"), optimize=True)
                icons[name] = key
                done += 1
            except Exception as e:                      # icône illisible : on garde l'originale
                log(f"échec {did} ({src}) : {e}")
                failed += 1
                continue
        if os.path.isabs(icon) and not ours:
            # copie locale du .desktop pointant vers l'icône nommée (seulement si l'utilisateur n'en a pas déjà une)
            local = os.path.join(apps_dir, did + ".desktop")
            if not os.path.exists(local):
                txt = open(path, encoding="utf-8").read()
                txt = re.sub(r"(?m)^Icon=.*$", f"Icon={name}", txt, count=1)
                txt = txt.replace("[Desktop Entry]\n", "[Desktop Entry]\nX-Strata-PixelIcon=true\n", 1)
                os.makedirs(apps_dir, exist_ok=True)
                open(local, "w", encoding="utf-8").write(txt)

    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    json.dump(state, open(STATE, "w"), indent=1)
    log(f"{done} icône(s) générée(s), {skipped} inchangée(s), {failed} échec(s) — thème {OUT} (base : {base})")

    if done or apply_theme:
        os.utime(OUT, None)
        subprocess.run(["gtk-update-icon-cache", "-qf", OUT], capture_output=True)
        subprocess.run(["kbuildsycoca6"], capture_output=True)
    if apply_theme and current != THEME:
        subprocess.run(["/usr/lib/plasma-changeicons", THEME], capture_output=True)
        log("thème d'icônes Strata-Pixel activé")
    elif done:
        # prévient les applications KDE que les icônes ont changé
        subprocess.run(["dbus-send", "--session", "--type=signal", "/KIconLoader",
                        "org.kde.KIconLoader.iconChanged", "int32:0"], capture_output=True)


if __name__ == "__main__":
    main()
