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
