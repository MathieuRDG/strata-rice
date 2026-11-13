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

## org.strata.inventory (phase 7)
Icône « coffre » 3×3 en tête du panneau haut (`AppletOrder` de la containment). `X-Plasma-Provides:
org.kde.plasma.launchermenu` → la touche **Meta** (`activateLauncherMenu`) l'ouvre/ferme.

- **Source des apps : modèles Kicker** (`org.kde.plasma.private.kicker` `RootModel`) — ils suivent le menu
  freedesktop tenu à jour par KService (installations/désinstallations comprises), sans parser les `.desktop` à la main.
  Un seul modèle « toutes les apps » filtré (`KSortFilterProxyModel`) par onglet et par recherche (insensible
  à la casse et aux accents) ; table app → onglet construite depuis les catégories du menu (noms FR + EN).
- Onglets : Tout, Système (accent), Internet (ciel), Multimédia (or), Jeux (rouge), Dev (gemme), Outils (violet) ;
  l'onglet actif n'a pas de bord bas et se fond dans le panneau. Ctrl+Tab / Ctrl+PgSuiv pour changer.
- Recherche en creux, focus automatique ; Entrée = lancer la sélection, flèches = naviguer, Échap = fermer.
- Grille 9 colonnes de slots 104 px (icône + nom, liseré de la couleur de catégorie), barre de défilement en bois.
- Rangée du bas = rappel de la hotbar : y **déposer** une app (glisser depuis la grille) la place dans ce slot ;
  écriture via `plasmashell evaluateScript` (`writeConfig("launchers")` sur le widget hotbar, qui suit les
  changements de sa config). On peut aussi glisser directement sur la vraie hotbar.
- Fenêtre : `PlasmaCore.Dialog` centré (1040×780 + ombre dure 8 px), sans fond Plasma (dessin QML).
  La popup standard du plasmoid est neutralisée (`expanded` → remis à false, état figé avant repli).

## org.strata.toasts (phase 8) — notifications + OSD de volume
Icône cloche dans le panneau haut (or = actif, pierre = « ne pas déranger » ; clic pour basculer).

**Notifications** — popups maison sur le modèle public `org.kde.notificationmanager` (`Notifications`) :
pile en haut à droite sous le panneau, 420 px, plus récente en haut, 5 max ; panneau en relief + ombre dure ;
icône dans un slot de 56 px ; app + heure ; titre coloré (ciel = faible, accent = normale, or = avec actions,
rouge = critique) ; corps en CozetteVector 13 px ; boutons d'action ; jauge de 24 segments qui se vide
(pause au survol, critique sans délai = jauge pleine). Clic = action par défaut, carré rouge = fermer.
- L'applet standard `org.kde.plasma.notifications` est **retirée** de la zone de notification
  (absente de `extraItems`, mais conservée dans `knownItems`, sinon Plasma la réajoute) → plus de doublons.
  Contrepartie : plus d'historique des notifications dans la barre.
- Piège : la hauteur de la pile est calculée à la main (une `Column` dans une fenêtre cachée n'est jamais
  « polie » → hauteur 0 → la fenêtre refuse de s'ouvrir) ; visibilité pilotée impérativement.

**OSD de volume** — panneau en relief, icône dans un slot, jauge de 16 segments, valeur en CozetteVector 26 px,
au-dessus de la hotbar. OSD standard coupé : `plasmaparc [General] VolumeOsd=false` (copie : `kwin/plasmaparc`),
lu par le module kded `audioshortcutsservice` (le recharger : `qdbus6 org.kde.kded6 /kded unloadModule/loadModule`).

### Stylable / non stylable
| Élément | Statut |
|---|---|
| Popups de notification | ✅ maison (QML) — mise en page libre |
| OSD volume / muet | ✅ maison |
| OSD luminosité, micro, clavier, changement de sortie | ⚠️ OSD standard de plasmashell (QML compilé, non remplaçable) : seulement habillé par le Plasma Style (cadre bois `dialogs/background`, jauge segmentée `bar_meter_horizontal`) |
| Historique des notifications | ❌ non fourni (applet standard retirée) |

### Actions de session (inventaire)
5 boutons pixel à droite de la recherche : verrouiller (`org.freedesktop.ScreenSaver.Lock`), veille
(logind `Suspend`, bus système), déconnexion / redémarrer / éteindre (`org.kde.LogoutPrompt` → confirmation KDE).
