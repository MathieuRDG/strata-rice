# Plasmoids maison

Installation : `kpackagetool6 -t Plasma/Applet -i plasmoids/<id>` (mise à jour : `-u`), puis
`systemctl --user restart plasma-plasmashell` pour recharger le QML.

## org.strata.bossbars (phase 5)
Panneau **haut**, 48 px, non flottant, `plasmashellrc [PlasmaViews][Panel N] panelOpacity=2` (translucide →
`translucent/widgets/panel-background.svg` vide = sans fond ; nécessite l'effet `blur` standard chargé).

- Gauche : bureaux virtuels (carrés 22 px, accent = actif, terre = autres) + nom ; clic = changer
  (DBus `org.kde.KWin /KWin setCurrentDesktop` via `org.kde.plasma.workspace.dbus`), molette = suivant/précédent.
- Centre : 3 barres de 20 segments 13×9 px, titre centré avec ombre dure 2 px :
  - CPU `cpu/all/usage` + `cpu/all/maximumTemperature` (température masquée si 0 / absente)
  - RAM `memory/physical/usedPercent` + `memory/physical/used`
  - GPU `gpu/all/usage` sinon `gpu/gpu0/usage` + `gpu/gpu0/temperature` ; **absent → « GPU · N/D », jauge vide**
    (cas de la VM virtio ; sur la RX 9070 XT, amdgpu expose `gpu/gpu0/*`)
- Droite : heure en CozetteVector 26 px sans anticrénelage (2× la grille 13 px), date + volume
  (`org.kde.plasma.private.volume` `PreferredDevice.sink`, 65536 = 100 %).
- Pixelify Sans reste anticrénelée : sans lissage ses glyphes se cassent aux tailles 12–16 px.

Bureaux virtuels créés : Surface, Cavernes, Atelier, Profondeurs (`kwinrc [Desktops]`).

## org.strata.hotbar (phase 6)
Panneau **bas**, centré, longueur « ajustée au contenu », 88 px (cadre 80 + ombre 8), non flottant.
Plasmoid maison plutôt que le gestionnaire de tâches standard : numéros 1–9, slots vides fixes, nom de l'app
et 2e rangée sont impossibles avec ce dernier.

- `TaskManager.TasksModel` : regroupement par application, tri manuel, `launchInPlace` (une app lancée prend la
  place de son lanceur), lanceurs en config (`launchers`, ordre : kitty, Dolphin, Firefox, Discord, Jellyfin,
  Navidrome, Steam, VS Code, Proxmox VE).
- Slots = `widgets/tasks` du Plasma Style (normal / hover / focus = actif / attention / minimized), numéro
  CozetteVector 13 px `#B8A88C`, trait accent 8×4 si l'app a une fenêtre.
- Cadre bois + ombre dure dessinés par le plasmoid (`widgets/hotbar.svg`) : tous les `panel-background` du thème
  sont transparents (le réglage d'opacité par panneau n'était pas fiable).
- Lignes 0–8 = rangée 1, lignes 9+ = rangée 2 (`KSortFilterProxyModel`), affichée **au-dessus**, atténuée, dans une
  fenêtre superposée (`PlasmaCore.Dialog`) avec le nom de l'app active ; indicateur `1/2`.
- Glisser un `.desktop` sur un slot l'épingle à cette position.
- Clic : lancer / activer / réduire si déjà active ; clic milieu : nouvelle instance.
- Lanceurs factices (VM) : `plasmoids/dummy-launchers/strata-*.desktop` → `~/.local/share/applications/`.

### Meta+1…9
Les raccourcis « Activer l'entrée N du gestionnaire de tâches » sont enregistrés par le C++ du gestionnaire standard
(module privé non importable). Remplacement :
- script KWin `kwin/strata-hotbar-keys` (`registerShortcut` Meta+1…9) ; à chaque appui il lit la liste des lanceurs
  de la hotbar via `plasmashell evaluateScript`, puis active / réduit / fait défiler les fenêtres de l'app
  (`desktopFileName`) ou la lance via l'unité utilisateur `kwin/systemd/app-strata-launch@.service`
  (`kstart --application %i`) ;
- `kglobalshortcutsrc [plasmashell] activate task manager entry N=none` pour libérer Meta+N.
