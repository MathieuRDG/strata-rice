#!/usr/bin/env bash
# Strata — installateur en une ligne (KDE Plasma 6, Wayland, CachyOS / Arch) :
#
#     curl -fsSL https://raw.githubusercontent.com/MathieuRDG/strata-rice/main/boot.sh | bash
#     curl -fsSL …/boot.sh | bash -s -- --with-sddm      (options transmises à install.sh)
#
# Clone (ou met à jour) le dépôt dans ~/.local/share/strata puis lance install.sh.
# Relancer la même commande = mise à jour de Strata.
set -euo pipefail

STRATA_REPO="${STRATA_REPO:-https://github.com/MathieuRDG/strata-rice.git}"
STRATA_REF="${STRATA_REF:-main}"
STRATA_DIR="${STRATA_DIR:-$HOME/.local/share/strata}"

G=$'\033[38;2;124;203;74m'; T=$'\033[38;2;122;82;50m'; P=$'\033[38;2;110;110;110m'
Y=$'\033[38;2;232;178;58m'; R=$'\033[38;2;200;85;61m'; N=$'\033[0m'
cat <<EOF

  ${G} ███  █████  ███    ██   █████   ██ 
  ${G}█       █    █  █  █  █    █    █  █
  ${T} ██     █    ███   ████    █    ████
  ${T}   █    █    █ █   █  █    █    █  █
  ${P}███     █    █  █  █  █    █    █  █${N}
          ${Y}rice KDE Plasma 6 · blocs & couches${N}

EOF

die() { printf '%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# Les étapes Plasma (kwriteconfig6, qdbus6, plasmashell) exigent la session graphique
[ "$(id -u)" -ne 0 ] || die "ne pas lancer en root (sudo est demandé quand il faut)"
command -v pacman >/dev/null || die "Strata vise CachyOS / Arch (pacman introuvable)"
command -v plasmashell >/dev/null || die "KDE Plasma 6 n'est pas installé"
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] \
    || die "lancer depuis un terminal de la session Plasma (pas en SSH ni en TTY)"

command -v git >/dev/null || { echo "▸ installation de git"; sudo pacman -S --needed --noconfirm git; }

if [ -d "$STRATA_DIR/.git" ]; then
    echo "▸ mise à jour de $STRATA_DIR"
    git -C "$STRATA_DIR" fetch --quiet origin "$STRATA_REF"
    git -C "$STRATA_DIR" checkout --quiet "$STRATA_REF"
    git -C "$STRATA_DIR" merge --ff-only --quiet "origin/$STRATA_REF" \
        || die "modifications locales dans $STRATA_DIR : les valider ou les annuler, puis relancer"
else
    [ -e "$STRATA_DIR" ] && die "$STRATA_DIR existe déjà et n'est pas un dépôt git"
    echo "▸ téléchargement de Strata → $STRATA_DIR"
    git clone --quiet --branch "$STRATA_REF" "$STRATA_REPO" "$STRATA_DIR"
fi

# curl | bash : stdin est le script ; on rend le terminal à install.sh (sudo, paru)
cd "$STRATA_DIR"
if [ ! -t 0 ] && { : </dev/tty; } 2>/dev/null; then exec ./install.sh "$@" </dev/tty; fi
exec ./install.sh "$@"
