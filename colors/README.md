# Phase 1 — couleurs, polices, Kvantum

- `Strata.colors` → `~/.local/share/color-schemes/`, `plasma-apply-colorscheme Strata`
- Kvantum : `kvantum/build.py` génère `kvantum/Strata/` → `~/.config/Kvantum/Strata/` ;
  `~/.config/Kvantum/kvantum.kvconfig` : `[General] theme=Strata` ;
  `kdeglobals [KDE] widgetStyle=kvantum`
- Polices (`kdeglobals`) : `font`, `menuFont`, `toolBarFont` = Pixelify Sans 10 ;
  `smallestReadableFont` = Pixelify Sans 8 ; `fixed` = CozetteVector 11 ;
  `[WM] activeFont` = Pixelify Sans 10 (600)
- Fonds : `wallpaper/generate.py L H` → paquets `~/.local/share/wallpapers/Strata{,-Nuit}`
- `tools/pngzoom.py` : recadrage/zoom de captures pour vérifier les pixels
