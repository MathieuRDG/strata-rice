# Phase 4 — Plasma Style Strata

`plasma/build.py` génère `plasma/Strata/` → `~/.local/share/plasma/desktoptheme/Strata/`, puis
`plasma-apply-desktoptheme Strata`. Moteur pixel commun : `tools/pixsvg.py`.

| Fichier | Rendu |
|---|---|
| `dialogs/background`, `widgets/background` | panneau en relief bois (contour 3 + biseau 3) + ombre dure 8×8 |
| `widgets/tooltip` | idem, surface `#3A2C20` |
| `widgets/panel-background` | relief bois (hotbar) ; `translucent/…` = **sans fond** (barre du haut en mode « translucide ») |
| `widgets/tasks` | slot en creux ; actif = contour accent 3 px + `#2F3A1F` ; attention = contour or ; réduit = atténué |
| `widgets/viewitem`, `listitem`, `menubaritem` | survol = liseré bois ; sélection = contour accent |
| `widgets/button`, `lineedit`, `scrollbar`, `frame`, `tabbar` | relief / creux ; focus = contour accent ; curseur de défilement en terre |
| `widgets/bar_meter_horizontal` | jauge **segmentée** (centre tuilé : 10 px plein + 3 px vide) |
| `widgets/plasmoidheading` | en-tête/pied de popup **avec** contour et biseau (ils recouvrent la bordure du dialogue) |

Non fournis → repli sur le thème par défaut recoloré par `Strata.colors` : cases à cocher, boutons radio,
interrupteurs, curseurs (slider), flèches, calendrier, indicateur d'activité.

## Ombre dure décalée (8, 8)
Plasma passe des tuiles à KWin (`shadow-*`). Astuces nécessaires :
- tuiles d'au moins 8 px (des tuiles de 1 px ne sont pas rendues) et longues (128 px) pour les côtés étirés,
  sinon le filtrage bilinéaire crée un dégradé ;
- décalage obtenu par `shadow-hint-{top,left}-margin` = 1 px et `{right,bottom}` = 8 px, avec les coins
  haut-droit (8×9) et bas-gauche (9×8) transparents ;
- aucune tuile 100 % transparente (alpha 0,01).
- Après modification : vider `~/.cache/ksvg-elements` et `~/.cache/plasma_theme_Strata.kcache`, rebasculer de thème.

## Stylable / non stylable
- Stylable par SVG : fonds de popups, panneaux, infobulles, fonds de tâches, sélections, champs, jauges.
- Non stylable par le Plasma Style : position des éléments, numéros 1–9 sur les slots, trait 8×4 des apps ouvertes,
  textes des notifications → plasmoids/QML maison (phases 5–8).
