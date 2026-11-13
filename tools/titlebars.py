#!/usr/bin/env python3
"""Strata — barre de titre système (décoration Aurorae Strata) pour toutes les applis.

Les applis Qt/KDE utilisent déjà la décoration de KWin. Les autres dessinent souvent
leur propre barre (CSD) ; ce script les bascule sur la barre système quand c'est possible :

  GTK3 / GTK4 / libadwaita   gtk-nocsd (AUR) préchargé dans la session (environment.d)
  Firefox, LibreWolf          apps/firefox/apply.sh (user.js + userChrome.css)
  Chrome, Chromium, Brave…    Preferences : browser.custom_chrome_frame = false
  VS Code, VSCodium, Cursor   settings.json : window.titleBarStyle = native
  Vesktop, Obsidian           réglage « barre de titre native » de l'appli

Idempotent, sans sudo. Lancé par install.sh, à l'ouverture de session et à chaque
installation d'appli (strata-titlebars.path). Les applis ouvertes ne sont pas modifiées :
elles le seront au prochain passage.
    titlebars.py            applique
    titlebars.py --check    affiche l'état sans rien modifier
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CONF = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
REPO = Path(__file__).resolve().parent.parent
CHECK = "--check" in sys.argv

ok, todo, nope = [], [], []   # appliqué / en attente / impossible


def running(*names):
    r = subprocess.run(["pgrep", "-x", "-u", str(os.getuid()), "|".join(names)],
                       capture_output=True)
    return r.returncode == 0


def load_jsonc(p: Path):
    """settings.json de VS Code accepte commentaires et virgules finales."""
    txt = p.read_text(encoding="utf-8")
    try:
        return json.loads(txt)
    except json.JSONDecodeError:
        pass
    out, i, n, s = [], 0, len(txt), False
    while i < n:                       # retire // et /* */ hors chaînes
        c = txt[i]
        if s:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(txt[i + 1]); i += 1
            elif c == '"':
                s = False
        elif c == '"':
            s = True; out.append(c)
        elif txt.startswith("//", i):
            i = txt.find("\n", i); i = n if i < 0 else i; continue
        elif txt.startswith("/*", i):
            i = txt.find("*/", i); i = n if i < 0 else i + 2; continue
        else:
            out.append(c)
        i += 1
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))


def set_json(p: Path, label: str, values: dict, apps=(), jsonc=False, create=False):
    """Fusionne `values` (clés pointées = objets imbriqués si nested) dans un fichier JSON."""
    if not p.exists() and not create:
        return
    try:
        data = (load_jsonc(p) if jsonc else json.loads(p.read_text(encoding="utf-8"))) if p.exists() else {}
    except (json.JSONDecodeError, OSError) as e:
        nope.append(f"{label} : {p} illisible ({e.__class__.__name__}), non modifié"); return
    changed = False
    for key, val in values.items():
        if jsonc:                      # VS Code : clés plates « window.titleBarStyle »
            node, k = data, key
        else:                          # Chromium : objets imbriqués
            *path, k = key.split(".")
            node = data
            for part in path:
                node = node.setdefault(part, {})
        if node.get(k) != val:
            node[k] = val; changed = True
    if not changed:
        ok.append(f"{label} (déjà réglé)"); return
    if apps and running(*apps):
        todo.append(f"{label} : à fermer, réglé au prochain passage"); return
    if CHECK:
        todo.append(f"{label} : à régler"); return
    if p.exists():
        shutil.copy2(p, p.with_name(p.name + ".strata.bak"))   # sauvegarde avant modification
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=4 if jsonc else None, ensure_ascii=False), encoding="utf-8")
    ok.append(f"{label} : barre système activée")


# ---------------------------------------------------------------- GTK (gtk-nocsd)
def gtk():
    lib = next((p for p in ("/usr/lib/libgtk-nocsd.so.0", "/usr/lib/libgtk-nocsd.so") if Path(p).exists()), None)
    envd = CONF / "environment.d" / "90-strata-nocsd.conf"
    if not lib:
        if envd.exists() and not CHECK:
            envd.unlink()               # bibliothèque désinstallée : ne pas précharger un fichier absent
        nope.append("GTK3/GTK4/libadwaita : paquet AUR gtk-nocsd absent (paru -S gtk-nocsd)"); return
    want = f"# Strata — barre de titre système pour les applis GTK (tools/titlebars.py)\nLD_PRELOAD={lib}\n"
    if envd.exists() and envd.read_text() == want:
        ok.append("GTK3/GTK4/libadwaita : gtk-nocsd (déjà actif)")
    elif CHECK:
        todo.append("GTK3/GTK4/libadwaita : gtk-nocsd à activer")
    else:
        envd.parent.mkdir(parents=True, exist_ok=True); envd.write_text(want)
        todo.append("GTK3/GTK4/libadwaita : gtk-nocsd activé, effectif à la prochaine ouverture de session")
    if shutil.which("flatpak"):
        r = subprocess.run(["flatpak", "list", "--app", "--columns=application,runtime"], capture_output=True, text=True)
        gnome = [a.split("\t")[0] for a in r.stdout.splitlines() if "org.gnome.Platform" in a]
        if gnome:
            nope.append("Flatpak GTK (bac à sable, gtk-nocsd non chargé) : " + ", ".join(gnome))


# ---------------------------------------------------------------- Firefox
def firefox():
    if not any(shutil.which(b) for b in ("firefox", "librewolf")):
        return
    if CHECK:
        ok.append("Firefox / LibreWolf : géré par apps/firefox/apply.sh"); return
    subprocess.run([str(REPO / "apps/firefox/apply.sh")], stdout=subprocess.DEVNULL, check=False)
    ok.append("Firefox / LibreWolf : user.js + userChrome.css")


# ---------------------------------------------------------------- Chromium et dérivés
CHROMIUMS = {   # dossier de config : (nom, processus)
    "google-chrome": ("Chrome", ("chrome",)),
    "google-chrome-beta": ("Chrome Beta", ("chrome",)),
    "chromium": ("Chromium", ("chromium",)),
    "BraveSoftware/Brave-Browser": ("Brave", ("brave",)),
    "vivaldi": ("Vivaldi", ("vivaldi-bin",)),
    "microsoft-edge": ("Edge", ("msedge",)),
    "thorium": ("Thorium", ("thorium",)),
    "net.imput.helium": ("Helium", ("helium",)),
}


def chromium():
    for d, (name, procs) in CHROMIUMS.items():
        root = CONF / d
        for pref in sorted(root.glob("*/Preferences")) if root.is_dir() else []:
            set_json(pref, f"{name} ({pref.parent.name})", {"browser.custom_chrome_frame": False}, apps=procs)


# ---------------------------------------------------------------- VS Code et forks
CODES = {"Code": ("code", "VS Code"), "Code - OSS": ("code-oss", "Code - OSS"),
         "VSCodium": ("codium", "VSCodium"), "Cursor": ("cursor", "Cursor")}


def vscode():
    native = {"window.titleBarStyle": "native", "window.customTitleBarVisibility": "never"}
    for d, (binary, name) in CODES.items():
        p = CONF / d / "User" / "settings.json"
        installed = shutil.which(binary) is not None
        set_json(p, name, native, apps=("code", "code-oss", "codium", "cursor", "electron"),
                 jsonc=True, create=installed or p.parent.exists())


# ---------------------------------------------------------------- Electron divers
def electron_misc():
    set_json(CONF / "vesktop" / "settings.json", "Vesktop", {"customTitleBar": False}, apps=("vesktop",))
    set_json(CONF / "obsidian" / "obsidian.json", "Obsidian", {"frame": "native"}, apps=("obsidian",))
    if shutil.which("steam") or (HOME / ".local/share/Steam").exists():
        nope.append("Steam : barre de titre dessinée par le client, aucun réglage")


for step in (gtk, firefox, chromium, vscode, electron_misc):
    step()

for items, mark in ((ok, "✓"), (todo, "…"), (nope, "✗")):
    for it in items:
        print(f"  {mark} {it}")
