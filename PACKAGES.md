# Paquets et ressources installés — Strata

## Polices (espace utilisateur, sans paquet — `~/.local/share/fonts/strata/`, sources dans `fonts/`)
| Ressource | Version | Source | Licence |
|---|---|---|---|
| Pixelify Sans (variable, wght) | google/fonts main | github.com/google/fonts/ofl/pixelifysans | OFL 1.1 |
| Cozette (`.otb` bitmap 13 px + hidpi) | 1.30.0 | github.com/the-moonwitch/Cozette | MIT |
| CozetteVector / Bold (`.ttf`) | 1.30.0 | idem | MIT |

## Paquets pacman / AUR
| Paquet | Dépôt | Version | Usage |
|---|---|---|---|
| kitty | extra | 0.50.0-1 | terminal (phase 3) |
| kvantum | extra | 1.1.9-1 | moteur de thème Qt (phase 1) |
| paru | cachyos | 2.2.0-2 | assistant AUR |
| cmake, extra-cmake-modules, qt6-tools, vulkan-headers | extra | — | dépendances de compilation (Better Blur DX) |
| sddm | cachyos | 0.21.0-6 | greeter de test du thème (non activé dans la VM, qui utilise plasmalogin) |
| ydotool | extra | — | tests visuels uniquement (simuler la souris dans la VM) — inutile sur la machine cible |
| kwin-effects-better-blur-dx-git | AUR | r1137.811bce8-1 | flou forcé (phase 2) — **à recompiler après chaque mise à jour de KWin** |
| gtk-nocsd | AUR | 4.8-1 | barre de titre système (Strata) pour les applis GTK3/GTK4/libadwaita (`tools/titlebars.py`) |
