# Phase 9 — splash et écran de verrouillage

## Look-and-feel `org.strata.desktop`
`lookandfeel/org.strata.desktop` → `~/.local/share/plasma/look-and-feel/`. Déclaré sans appliquer ses réglages
(`kdeglobals [KDE] LookAndFeelPackage=org.strata.desktop`) — `plasma-apply-lookandfeel` réécrirait la disposition.
- **Splash** (`contents/splash/Splash.qml`, `ksplashrc [KSplash] Theme=org.strata.desktop`, `Engine=KSplashQML`) :
  paysage de nuit (1920×1080 ou 2560×1440 selon l'écran, sans lissage), « STRATA » en CozetteVector 104 px
  (8× la grille) avec relief en couches herbe → terre (4 px) → ombre (8 px), « Chargement du monde… »,
  barre de 24 segments qui suit les étapes de ksplash + segment suivant pulsant. Test : `ksplashqml org.strata.desktop --test`.
- `contents/defaults` : jeu de couleurs, Kvantum, Plasma Style, Aurorae, splash (pour un futur `plasma-apply-lookandfeel`).

## Écran de verrouillage
Depuis Plasma 6, kscreenlocker charge le verrouillage depuis le **paquet shell** (`plasmashellrc [Shell] ShellPackage`,
partagé avec plasmashell), plus depuis le look-and-feel. Solution : surcharge utilisateur du shell
`org.kde.plasma.desktop` dans `~/.local/share/plasma/shells/` = copie du shell système + patch.
- `lockscreen/install-lockscreen.sh` : recopie `/usr/share/plasma/shells/org.kde.plasma.desktop`, ajoute `Bevel.qml`,
  applique `patch_lockscreen.py` sur `LockScreenUi.qml` (idempotent). Si l'ancre du patch n'existe plus (Plasma a
  changé), **la surcharge est retirée** pour garder un verrouillage fonctionnel.
- `lockscreen/systemd/strata-lockscreen-sync.{path,service}` (unités utilisateur) : relancent le script dès que
  Plasma met à jour le shell système → la copie ne devient jamais obsolète.
- Habillage : panneau bois en relief + ombre dure derrière avatar/mot de passe, « STRATA » en relief,
  heure CozetteVector 52 px + ombre dure, date Pixelify ; horloge Breeze masquée.
- Fond : `kscreenlockerrc [Greeter][Wallpaper][org.kde.image][General] Image=…/wallpapers/Strata-Nuit`.
- Test sans verrouiller : `/usr/lib/kscreenlocker_greet --testing` (bouger la souris pour afficher le panneau).
