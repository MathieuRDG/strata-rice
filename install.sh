#!/usr/bin/env bash
# Strata — installation idempotente du rice (KDE Plasma 6, Wayland, CachyOS).
# À lancer depuis une session graphique Plasma, en utilisateur normal, depuis le dépôt :
#     ./install.sh                 installation / mise à jour
#     ./install.sh --reset-layout  recrée aussi les panneaux (sinon seulement à la 1re installation)
#     ./install.sh --with-sddm     installe aussi le thème SDDM (sudo)
#     ./install.sh --no-packages   saute pacman / paru
#     ./install.sh --no-snapshot   saute le snapshot snapper de départ
# Les étapes système (paquets, SDDM) demandent sudo. Relancer le script ne casse rien.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"
# shellcheck source=strata.conf
source "$REPO/strata.conf"

RESET_LAYOUT=0; WITH_SDDM=0; PACKAGES=1; SNAPSHOT=1
for a in "$@"; do
    case "$a" in
        --reset-layout) RESET_LAYOUT=1 ;;
        --with-sddm) WITH_SDDM=1 ;;
        --no-packages) PACKAGES=0 ;;
        --no-snapshot) SNAPSHOT=0 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "option inconnue : $a" >&2; exit 2 ;;
    esac
done

C="$HOME/.config"; D="$HOME/.local/share"
say()  { printf '\033[1;32m▸ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
kw()   { kwriteconfig6 "$@"; }

# ---------------------------------------------------------------- 0. vérifications
say "Vérification de la session"
[ "${XDG_SESSION_TYPE:-}" = "wayland" ] || warn "session non Wayland (${XDG_SESSION_TYPE:-?}) : Strata est pensé pour Wayland"
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || { echo "pas de bus DBus de session : lancer depuis la session graphique (pas en SSH)" >&2; exit 1; }
qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || { echo "plasmashell injoignable" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "ne pas lancer en root" >&2; exit 1; }

# ---------------------------------------------------------------- 1a. snapshot btrfs (à chaque lancement)
# Snapper : / (config « root ») et /home (config « home » si elle existe — le rice vit surtout dans /home).
# Nettoyage « number » : les anciens snapshots sont purgés par snapper comme ceux de snap-pac.
if [ "$SNAPSHOT" = 1 ]; then
    if command -v snapper >/dev/null 2>&1; then
        say "Snapshot snapper avant modification (sudo)"
        cfgs="$(sudo snapper --no-headers --csvout list-configs --columns config 2>/dev/null || true)"
        snapped=""
        for cfg in root home; do
            if printf '%s\n' "$cfgs" | grep -qx "$cfg"; then
                if n=$(sudo snapper -c "$cfg" create --cleanup-algorithm number --print-number \
                         --description "avant Strata install.sh $(date '+%F %T')"); then
                    snapped="$snapped $cfg#$n"
                else
                    warn "snapshot snapper « $cfg » échoué"
                fi
            fi
        done
        [ -n "$snapped" ] && say "Snapshots créés :$snapped (liste : sudo snapper -c <config> list)"
        printf '%s\n' "$cfgs" | grep -qx home || \
            warn "pas de config snapper pour /home : seule l'archive ci-dessous protège la configuration utilisateur"
        [ -n "$snapped" ] || {
            warn "aucun snapshot créé."
            read -r -p "Continuer quand même ? [o/N] " r </dev/tty || r=n
            case "$r" in o|O|y|Y) ;; *) echo "abandon" >&2; exit 1 ;; esac
        }
    else
        warn "snapper absent : pas de snapshot btrfs (seule l'archive ci-dessous sera faite)"
    fi
fi

# ---------------------------------------------------------------- 1b. sauvegarde de la configuration (une seule fois)
# État d'origine, avant la toute première installation : copie lisible des fichiers clés + archive complète
# de ~/.config (sans les caches), des dossiers de ~/.local/share que Strata modifie et des profils Firefox/LibreWolf
# (user.js, chrome/).
BK="$HOME/.local/state/strata/backup-initial"
if [ ! -e "$BK/home-config.tar.zst" ]; then
    say "Sauvegarde de la configuration d'origine → $BK"
    mkdir -p "$BK"
    for f in kdeglobals kwinrc kwinrulesrc kglobalshortcutsrc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc \
             kscreenlockerrc ksplashrc plasmaparc kcminputrc fish kitty fastfetch Kvantum fontconfig; do
        [ -e "$C/$f" ] && [ ! -e "$BK/$f" ] && cp -a "$C/$f" "$BK/" || true
    done
    items=(.config)
    for d in plasma aurorae color-schemes fonts icons wallpapers applications strata-webapps kxmlgui5; do
        [ -e "$D/$d" ] && items+=(".local/share/$d")
    done
    for b in .mozilla/firefox .librewolf; do          # (les profils sous ~/.config sont déjà dans .config)
        [ -d "$HOME/$b" ] || continue
        while IFS= read -r -d '' x; do items+=("${x#"$HOME"/}"); done < <(
            find "$HOME/$b" -mindepth 2 -maxdepth 2 \( -name user.js -o -name chrome -o -name prefs.js \) -print0)
    done
    if tar -C "$HOME" --zstd -cf "$BK/home-config.tar.zst" \
           --exclude='*/Cache' --exclude='*/Code Cache' --exclude='*/GPUCache' --exclude='*/CachedData' \
           --exclude='*/Service Worker' --exclude='*/IndexedDB' --exclude='*/blob_storage' \
           --exclude='*/ShaderCache' --exclude='*/GrShaderCache' --exclude='*/DawnCache' --exclude='*/logs' \
           --exclude='.local/share/flatpak' --warning=no-file-changed --ignore-failed-read "${items[@]}"; then
        say "Archive : $BK/home-config.tar.zst ($(du -h "$BK/home-config.tar.zst" | cut -f1))"
    else
        rm -f "$BK/home-config.tar.zst"
        warn "archive de la configuration échouée"
        read -r -p "Continuer quand même ? [o/N] " r </dev/tty || r=n
        case "$r" in o|O|y|Y) ;; *) echo "abandon" >&2; exit 1 ;; esac
    fi
fi

# ---------------------------------------------------------------- 2. paquets
if [ "$PACKAGES" = 1 ]; then
    say "Paquets (pacman)"
    sudo pacman -S --needed --noconfirm kitty kvantum paru fish fastfetch python python-pillow librsvg >/dev/null || warn "pacman a échoué"
    if ! pacman -Q kwin-effects-better-blur-dx-git >/dev/null 2>&1; then
        say "Better Blur DX (AUR, compilation)"
        paru -S --needed --noconfirm --skipreview kwin-effects-better-blur-dx-git || warn "Better Blur DX non installé"
    fi
    if ! pacman -Q gtk-nocsd >/dev/null 2>&1; then
        say "gtk-nocsd (AUR) : barre de titre système pour les applis GTK"
        paru -S --needed --noconfirm --skipreview gtk-nocsd || warn "gtk-nocsd non installé"
    fi
fi

# ---------------------------------------------------------------- 3. polices
say "Polices (Pixelify Sans, Cozette)"
mkdir -p "$D/fonts/strata" "$C/fontconfig/conf.d"
cp -f fonts/*.ttf fonts/*.otb "$D/fonts/strata/"
cp -f fonts/fontconfig/50-strata-cozette.conf "$C/fontconfig/conf.d/"
fc-cache -f "$D/fonts" >/dev/null

# ---------------------------------------------------------------- 4. fonds d'écran
say "Fonds d'écran (jour / nuit)"
for v in day night; do
    name=Strata; [ $v = night ] && name=Strata-Nuit
    for res in 1920x1080 2560x1440; do
        [ -f "wallpaper/strata-$v-$res.png" ] || python3 wallpaper/generate.py "${res%x*}" "${res#*x}" --out wallpaper >/dev/null
    done
    rm -rf "$D/wallpapers/$name"; mkdir -p "$D/wallpapers"
    cp -r "wallpaper/packages/$name" "$D/wallpapers/"
done
WP="$D/wallpapers/Strata"; [ "$WALLPAPER" = night ] && WP="$D/wallpapers/Strata-Nuit"
plasma-apply-wallpaperimage "$WP" >/dev/null || warn "fond non appliqué"

# ---------------------------------------------------------------- 5. couleurs, Kvantum, polices de l'interface
say "Jeu de couleurs, Kvantum, polices"
mkdir -p "$D/color-schemes" "$C/Kvantum"
cp -f colors/Strata.colors "$D/color-schemes/"
plasma-apply-colorscheme Strata >/dev/null || true
python3 kvantum/build.py >/dev/null
rm -rf "$C/Kvantum/Strata"; cp -r kvantum/Strata "$C/Kvantum/"
printf '[General]\ntheme=Strata\n' > "$C/Kvantum/kvantum.kvconfig"
kw --file kdeglobals --group KDE --key widgetStyle kvantum
F='Pixelify Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
for k in font menuFont toolBarFont; do kw --file kdeglobals --group General --key $k "$F"; done
kw --file kdeglobals --group General --key smallestReadableFont 'Pixelify Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kw --file kdeglobals --group General --key fixed 'CozetteVector,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kw --file kdeglobals --group WM --key activeFont 'Pixelify Sans,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1'
kw --file kdeglobals --group General --key TerminalApplication kitty
kw --file kdeglobals --group General --key TerminalService kitty.desktop

# ---------------------------------------------------------------- 6. décoration Aurorae
say "Décoration de fenêtres Aurorae"
python3 aurorae/build.py Strata >/dev/null
mkdir -p "$D/aurorae/themes"; rm -rf "$D/aurorae/themes/Strata"; cp -r aurorae/Strata "$D/aurorae/themes/"
G=org.kde.kdecoration2
kw --file kwinrc --group $G --key library org.kde.kwin.aurorae.v2
kw --file kwinrc --group $G --key theme __aurorae__svg__Strata
kw --file kwinrc --group $G --key BorderSizeAuto false
kw --file kwinrc --group $G --key BorderSize Large
kw --file kwinrc --group $G --key ButtonsOnLeft ""
kw --file kwinrc --group $G --key ButtonsOnRight IAX

# ---------------------------------------------------------------- 7. KWin : règles, scripts, flou, bureaux
say "KWin : transparence, flou, scripts, bureaux virtuels"
cp -f kwin/kwinrulesrc "$C/kwinrulesrc"
for s in strata-fullscreen-opacity strata-hotbar-keys; do
    kpackagetool6 --type KWin/Script -u "kwin/$s" >/dev/null 2>&1 || kpackagetool6 --type KWin/Script -i "kwin/$s" >/dev/null
    kw --file kwinrc --group Plugins --key "${s}Enabled" true
done
kw --file kwinrc --group Plugins --key blurEnabled true
kw --file kwinrc --group Effect-blur --key BlurStrength 6
kw --file kwinrc --group Effect-blur --key NoiseStrength 0
if pacman -Q kwin-effects-better-blur-dx-git >/dev/null 2>&1; then
    E=Effect-better-blur-dx
    kw --file kwinrc --group Plugins --key better_blur_dxEnabled true
    kw --file kwinrc --group $E --key BlurMatching false
    kw --file kwinrc --group $E --key BlurNonMatching true
    kw --file kwinrc --group $E --key BlurDecorations true
    kw --file kwinrc --group $E --key BlurMenus true
    kw --file kwinrc --group $E --key BlurDocks false
    kw --file kwinrc --group $E --key BlurStrength 6
    kw --file kwinrc --group $E --key WindowClasses "$(printf 'kitty\nsteam\nsteamwebhelper\ngamescope\nmpv\nvlc\norg.kde.haruna\nplasmashell\nspectacle\nxwaylandvideobridge')"
fi
# Meta+1…9 : libérés côté plasmashell (gérés par strata-hotbar-keys)
for i in 1 2 3 4 5 6 7 8 9; do
    kw --file kglobalshortcutsrc --group plasmashell --key "activate task manager entry $i" "none,Meta+$i,Activer l'entrée $i du gestionnaire de tâches"
done
# 4 bureaux virtuels
M=org.kde.KWin.VirtualDesktopManager
NAMES=(Surface Cavernes Atelier Profondeurs)
n=$(qdbus6 org.kde.KWin /VirtualDesktopManager $M.count)
while [ "$n" -lt 4 ]; do qdbus6 org.kde.KWin /VirtualDesktopManager $M.createDesktop "$n" "${NAMES[$n]}" >/dev/null; n=$((n + 1)); done
i=0
for id in $(qdbus6 --literal org.kde.KWin /VirtualDesktopManager $M.desktops | grep -oE '[0-9a-f]{8}-[0-9a-f-]{27}'); do
    [ $i -lt 4 ] && qdbus6 org.kde.KWin /VirtualDesktopManager $M.setDesktopName "$id" "${NAMES[$i]}" >/dev/null
    i=$((i + 1))
done

# ---------------------------------------------------------------- 8. terminal
say "kitty, fish, fastfetch"
mkdir -p "$C/kitty" "$C/fastfetch" "$C/fish/functions" "$C/fish/conf.d"
cp -f terminal/kitty/kitty.conf "$C/kitty/"
cp -f terminal/fastfetch/* "$C/fastfetch/"
cp -f terminal/fish/functions/fish_prompt.fish "$C/fish/functions/"
cp -f terminal/fish/conf.d/strata-colors.fish "$C/fish/conf.d/"

# ---------------------------------------------------------------- 8b. Firefox : barre de titre système + userChrome Strata
say "Firefox (barre de titre Strata)"
apps/firefox/apply.sh

# ---------------------------------------------------------------- 9. Plasma Style
say "Plasma Style"
python3 plasma/build.py >/dev/null
mkdir -p "$D/plasma/desktoptheme"; rm -rf "$D/plasma/desktoptheme/Strata"; cp -r plasma/Strata "$D/plasma/desktoptheme/"
rm -rf "$HOME/.cache/ksvg-elements" "$HOME/.cache/plasma_theme_Strata.kcache"
plasma-apply-desktoptheme Strata >/dev/null

# ---------------------------------------------------------------- 10. plasmoids + lanceurs
say "Plasmoids Strata"
for p in org.strata.bossbars org.strata.hotbar org.strata.inventory org.strata.toasts; do
    kpackagetool6 -t Plasma/Applet -u "plasmoids/$p" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i "plasmoids/$p" >/dev/null
done

# lanceurs : premier .desktop trouvé parmi les candidats, sinon web app (URL de strata.conf) ou lanceur factice
mkdir -p "$D/applications"
have() { for d in "$@"; do for dir in "$D/applications" /usr/share/applications /var/lib/flatpak/exports/share/applications "$D/flatpak/exports/share/applications"; do
            [ -f "$dir/$d.desktop" ] && { echo "$d"; return 0; }; done; done; return 1; }
webapp() {  # id nom icône url catégories
    cat > "$D/applications/strata-$1.desktop" <<EOD
[Desktop Entry]
Type=Application
Name=$2
Comment=Web app Strata ($4)
Icon=$3
Exec=firefox --profile $D/strata-webapps/$1 --name strata-$1 --class strata-$1 $4
Categories=$5
StartupWMClass=strata-$1
EOD
    # profil Firefox dédié : fenêtre identifiée « strata-$1 » → slot propre dans la hotbar (pas confondue avec Firefox)
    mkdir -p "$D/strata-webapps/$1"
    echo "strata-$1"
}
dummy() { cp -f "plasmoids/dummy-launchers/strata-$1.desktop" "$D/applications/"; echo "strata-$1"; }
L=()
L+=("$(have kitty || echo kitty)")
L+=("$(have org.kde.dolphin)")
L+=("$(have firefox)")
L+=("$(have discord vesktop dev.vencord.Vesktop com.discordapp.Discord || dummy discord)")
L+=("$(have org.jellyfin.JellyfinDesktop com.github.iwalton3.jellyfin-media-player jellyfin-desktop jellyfin-media-player || webapp jellyfin Jellyfin applications-multimedia "$JELLYFIN_URL" 'AudioVideo;Video;')")
L+=("$(have feishin io.github.jeffvli.Feishin org.jeffvli.feishin sonixd || webapp navidrome Navidrome audio-x-generic "$NAVIDROME_URL" 'AudioVideo;Audio;')")
L+=("$(have steam com.valvesoftware.Steam || dummy steam)")
L+=("$(have code visual-studio-code code-oss codium com.visualstudio.code || dummy vscode)")
L+=("$(webapp proxmox 'Proxmox VE' network-server "$PROXMOX_URL" 'Network;System;')")
apps/firefox/apply.sh >/dev/null   # profils des web apps fraîchement créés
kbuildsycoca6 >/dev/null 2>&1 || true
LAUNCHERS_JS="[$(printf '"applications:%s.desktop",' "${L[@]}" | sed 's/,$//')]"
echo "  hotbar : ${L[*]}"

# ---------------------------------------------------------------- 11. disposition des panneaux
if [ "$RESET_LAYOUT" = 1 ] || ! grep -q 'plugin=org.strata.hotbar' "$C/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null; then
    say "Disposition des panneaux (haut + hotbar ; second écran : version réduite)"
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
        "var LAUNCHERS = $LAUNCHERS_JS;
$(cat scripts/layout.js)" || warn "disposition non appliquée"
    sleep 2
    systemctl --user stop plasma-plasmashell
    python3 scripts/systray_fixup.py "$C/plasma-org.kde.plasma.desktop-appletsrc" "$C/plasmashellrc"
    systemctl --user start plasma-plasmashell
else
    say "Panneaux déjà en place (--reset-layout pour les recréer)"
fi

# ---------------------------------------------------------------- 12. OSD, splash, verrouillage
say "OSD, splash, écran de verrouillage"
kw --file plasmaparc --group General --key VolumeOsd false
qdbus6 org.kde.kded6 /kded org.kde.kded6.unloadModule audioshortcutsservice >/dev/null 2>&1 || true
qdbus6 org.kde.kded6 /kded org.kde.kded6.loadModule audioshortcutsservice >/dev/null 2>&1 || true
mkdir -p "$D/plasma/look-and-feel"; rm -rf "$D/plasma/look-and-feel/org.strata.desktop"
cp -r lookandfeel/org.strata.desktop "$D/plasma/look-and-feel/"
kw --file kdeglobals --group KDE --key LookAndFeelPackage org.strata.desktop
kw --file ksplashrc --group KSplash --key Theme org.strata.desktop
kw --file ksplashrc --group KSplash --key Engine KSplashQML
kw --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$D/wallpapers/Strata-Nuit"
kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key FillMode 2
lookandfeel/lockscreen/install-lockscreen.sh || warn "écran de verrouillage par défaut conservé"

# ---------------------------------------------------------------- 13. unités systemd utilisateur
say "Unités systemd utilisateur"
mkdir -p "$C/systemd/user"
cp -f kwin/systemd/app-strata-launch@.service "$C/systemd/user/"
sed "s#%h/strata-rice#$REPO#" lookandfeel/lockscreen/systemd/strata-lockscreen-sync.service > "$C/systemd/user/strata-lockscreen-sync.service"
cp -f lookandfeel/lockscreen/systemd/strata-lockscreen-sync.path "$C/systemd/user/"
rm -f "$C/systemd/user/default.target.wants/strata-titlebars.service"   # ancien emplacement
systemctl --user daemon-reload
systemctl --user enable --now strata-lockscreen-sync.path >/dev/null 2>&1

# ---------------------------------------------------------------- 13b. icônes pixel (Strata-Pixel)
if [ "${PIXEL_ICONS:-yes}" = yes ]; then
    say "Icônes d'applications pixelisées"
    mkdir -p "$C/strata"; printf 'PIXEL_ICONS_EXCLUDE="%s"\n' "${PIXEL_ICONS_EXCLUDE:-}" > "$C/strata/pixelicons.env"
    PIXEL_ICONS_EXCLUDE="${PIXEL_ICONS_EXCLUDE:-}" python3 tools/pixelicons.py --apply || warn "icônes pixel non générées"
    sed "s#STRATA_REPO#$REPO#" tools/systemd/strata-pixelicons.service > "$C/systemd/user/strata-pixelicons.service"
    cp -f tools/systemd/strata-pixelicons.path "$C/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable --now strata-pixelicons.path >/dev/null 2>&1
fi

# ---------------------------------------------------------------- 13c. barre de titre système pour toutes les applis
say "Barre de titre Strata pour les applis GTK, Chromium, Electron"
python3 tools/titlebars.py || warn "barres de titre non réglées"
for u in service path; do
    sed "s#STRATA_REPO#$REPO#" "tools/systemd/strata-titlebars.$u" > "$C/systemd/user/strata-titlebars.$u"
done
rm -f "$C/systemd/user/default.target.wants/strata-titlebars.service"   # ancien emplacement
systemctl --user daemon-reload
systemctl --user enable strata-titlebars.service >/dev/null 2>&1      # à chaque ouverture de session
systemctl --user enable --now strata-titlebars.path >/dev/null 2>&1   # à chaque installation d'appli

# ---------------------------------------------------------------- 14. écrans (machine cible)
say "Écrans"
python3 scripts/screens.py "$SECONDARY_POSITION" "$ENABLE_HDR" "$ENABLE_VRR" || warn "écrans non configurés"

# ---------------------------------------------------------------- 15. SDDM (optionnel)
if [ "$WITH_SDDM" = 1 ]; then
    say "Thème SDDM"
    sudo pacman -S --needed --noconfirm sddm >/dev/null
    sudo rm -rf /usr/share/sddm/themes/strata
    sudo cp -r sddm/strata /usr/share/sddm/themes/strata
    sudo chmod -R a+rX /usr/share/sddm/themes/strata
    sudo mkdir -p /etc/sddm.conf.d && sudo cp -f sddm/strata.conf /etc/sddm.conf.d/strata.conf
    dm=$(systemctl show -p Id --value display-manager 2>/dev/null || true)
    # CachyOS récent démarre sur Plasma Login Manager : sans bascule, le thème Strata n'est jamais affiché au boot
    if [ "$dm" != "sddm.service" ]; then
        say "bascule du gestionnaire de connexion : ${dm:-aucun} → sddm (effectif au prochain démarrage)"
        [ -n "$dm" ] && sudo systemctl disable "${dm%.service}" >/dev/null 2>&1 || true
        sudo systemctl enable sddm >/dev/null 2>&1 || sudo systemctl enable -f sddm >/dev/null
    fi
fi

# ---------------------------------------------------------------- 16. rechargement
say "Rechargement de KWin et plasmashell"
qdbus6 org.kde.KWin /KWin reconfigure >/dev/null
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:0 int32:0
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:1 int32:0
dbus-send --session --type=signal /KGlobalSettings org.kde.KGlobalSettings.notifyChange int32:2 int32:0
systemctl --user restart plasma-plasmashell

say "Terminé. Se déconnecter / reconnecter une fois : KWin ne relit la décoration et la police des titres qu'au démarrage."
