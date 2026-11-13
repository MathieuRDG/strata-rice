# Phase 3 — terminal

- `kitty/kitty.conf` → `~/.config/kitty/` : palette Strata, CozetteVector 9.75 pt (= 13 px, grille native ;
  19.5 pt pour ×2), `background_opacity 0.80`, `background_blur 1`, padding 16 px, onglets carrés.
  Raccourcis opacité : `ctrl+shift+a` puis `m` (+) / `l` (−) / `d` (défaut).
- **Police** : kitty n'accepte que les polices vectorielles déclarées monospace. `cozette.otb` (bitmap) est
  refusé et `CozetteVector` n'annonce pas `spacing=mono` → règle `fonts/fontconfig/50-strata-cozette.conf`
  → `~/.config/fontconfig/conf.d/` puis `fc-cache -f`.
- `fish/functions/fish_prompt.fish` : deux lignes — chemin (ciel), branche git (or), code d'erreur ;
  puis `❯` violet, rouge si la dernière commande a échoué.
- `fish/conf.d/strata-colors.fish` : coloration syntaxique Strata (variables globales, pas universelles).
- `fastfetch/config.jsonc` + `logo.txt` → `~/.config/fastfetch/` : logo original (arbre sur herbe/terre/pierre
  à minerais), clés en or. Lancé par le `fish_greeting` de CachyOS.
- kitty = terminal par défaut : `kdeglobals [General] TerminalApplication=kitty`, `TerminalService=kitty.desktop`.
