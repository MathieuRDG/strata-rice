# Phase 2 — décoration Aurorae, transparence, flou

## Décoration
- `aurorae/build.py [NOM]` génère `aurorae/<NOM>/` → `~/.local/share/aurorae/themes/<NOM>/`
- `kwinrc [org.kde.kdecoration2]` :
  - `library=org.kde.kwin.aurorae.v2` (Plasma ≥ 6.8 : les thèmes **SVG** passent par v2 ; `org.kde.kwin.aurorae` = QML seulement)
  - `theme=__aurorae__svg__Strata`
  - `BorderSizeAuto=false`, `BorderSize=Large` (v2 borne les bordures : Normal = 4–6 px, Large = 6–8 px ; Strata en veut 8)
  - `ButtonsOnLeft=` · `ButtonsOnRight=IAX`
- Le SVG a une marge haute = barre de titre entière (34 px) : le creux autour du client est dessiné dans le cadre
  (l'élément `innerborder` de v2 est mal positionné en haut, on ne l'utilise pas).
- **Pièges** : KWin met le thème en cache pour toute la session (changer le rc n'a aucun effet avant reconnexion →
  pendant le dev, installer sous un autre nom, ex. `StrataV2`). La police du titre (`[WM] activeFont`) n'est lue
  qu'au démarrage de KWin.
- Si le DPI forcé de KWin ≠ 96 (`QT_WAYLAND_FORCE_DPI`), v2 multiplie les tailles du rc et elles ne collent plus au SVG.

## Transparence
- `kwin/kwinrulesrc` → `~/.config/kwinrulesrc` (2 règles, ordre important) :
  1. `strata-opaque` : 100 % pour Steam, jeux (`steam_app_*`, `*.exe`, gamescope…), lecteurs vidéo, Jellyfin
  2. `strata-opacity` : 95 % actif / 85 % inactif pour `^(?!kitty$).*$` (kitty exclu), fenêtres normales + dialogues
- Plein écran : les règles ne peuvent pas le cibler → script KWin `kwin/strata-fullscreen-opacity`
  (`kpackagetool6 --type KWin/Script -i …`, `kwinrc [Plugins] strata-fullscreen-opacityEnabled=true`).

## Flou — Better Blur DX + flou standard
- AUR `kwin-effects-better-blur-dx-git` (construit avec makepkg, installé avec `pacman -U`).
- ⚠️ **À recompiler après chaque mise à jour de KWin** (`paru -S kwin-effects-better-blur-dx-git --rebuild`), sinon l'effet ne se charge plus.
- Better Blur DX **n'implémente pas** le protocole de flou KDE : sans l'effet `blur` standard, Plasma croit le flou
  indisponible (pas de panneau translucide) et kitty n'est pas flouté. On garde donc **les deux**, sans doublon :
  - `kwinrc [Plugins] blurEnabled=true` : flou standard pour les fenêtres qui le demandent (kitty `background_blur`) ;
    `[Effect-blur] BlurStrength=6`, `NoiseStrength=0`
  - `kwinrc [Plugins] better_blur_dxEnabled=true`, `[Effect-better-blur-dx]` : `BlurNonMatching=true`,
    `BlurMatching=false` (flou forcé partout sauf la liste), `WindowClasses` = kitty, steam, steamwebhelper,
    gamescope, mpv, vlc, org.kde.haruna, plasmashell, spectacle, xwaylandvideobridge ;
    `BlurDecorations=true`, `BlurMenus=true`, `BlurStrength=6`.
- Le Plasma Style ne demande pas de flou (`plasmarc [BlurBehindEffect] enabled=false`) : panneau du haut vraiment transparent.
