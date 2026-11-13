#!/usr/bin/env bash
# Strata : surcharge utilisateur du paquet shell org.kde.plasma.desktop pour habiller l'écran de verrouillage.
# Depuis Plasma 6, kscreenlocker charge le verrouillage depuis le paquet *shell* (plus depuis le look-and-feel).
# On recopie le shell système puis on réapplique le patch : relancé automatiquement après chaque mise à jour
# de Plasma par strata-lockscreen-sync.path.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC=/usr/share/plasma/shells/org.kde.plasma.desktop
DST="$HOME/.local/share/plasma/shells/org.kde.plasma.desktop"
[ -f "$SRC/contents/lockscreen/LockScreenUi.qml" ] || { echo "shell système introuvable : $SRC" >&2; exit 1; }
TMP="$(mktemp -d)"
cp -a "$SRC/." "$TMP/"
cp "$HERE/Bevel.qml" "$TMP/contents/lockscreen/Bevel.qml"
if python3 "$HERE/patch_lockscreen.py" "$TMP/contents/lockscreen/LockScreenUi.qml"; then
    mkdir -p "$(dirname "$DST")"
    rm -rf "$DST"
    mv "$TMP" "$DST"
    echo "écran de verrouillage Strata installé ($DST)"
else
    # patch impossible (Plasma a changé) : on retire la surcharge pour garder un verrouillage fonctionnel
    rm -rf "$TMP" "$DST"
    echo "patch impossible : surcharge retirée, écran de verrouillage par défaut" >&2
    exit 1
fi
