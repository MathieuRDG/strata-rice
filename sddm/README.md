# Phase 10 — écran de connexion SDDM

- Thème QML Qt 6 `sddm/strata/` → `/usr/share/sddm/themes/strata/` (sudo) ;
  activation : `sddm/strata.conf` → `/etc/sddm.conf.d/strata.conf` (`[Theme] Current=strata`).
- Polices **embarquées** (`fonts/`, chargées par `FontLoader`) : le greeter tourne sous l'utilisateur `sddm`,
  qui ne voit pas `~/.local/share/fonts`.
- Fond de nuit (1920×1080 ou 2560×1440 selon l'écran, sans lissage) ; « STRATA » en CozetteVector 104 px avec
  relief herbe / terre / ombre ; sous-titre (`theme.conf` : `subtitle=cachyos · plasma 6`).
- Panneau bois : avatar = slot en creux avec l'**initiale** de l'utilisateur (« S » pour suzanne), nom
  (flèches si plusieurs comptes), mot de passe en creux (focus accent), gros bouton accent « Se connecter »
  → « Chargement du monde… » pendant la connexion, secousse + message rouge en cas d'échec ;
  session et disposition clavier (clic = suivant).
- Bas gauche : éteindre / redémarrer / veille (icônes pixel, libellé au survol, grisés si indisponibles) ;
  bas droite : heure CozetteVector 52 px + date.
- Test : `sddm-greeter-qt6 --test-mode --theme ~/strata-rice/sddm/strata`.

## ⚠️ Gestionnaire de connexion
La VM utilise **Plasma Login Manager** (`plasmalogin.service`, nouveau gestionnaire de KDE depuis Plasma 6.8),
pas SDDM. Le paquet `sddm` a été installé **uniquement pour tester le thème** ; il n'est pas activé.
Sur la machine cible, vérifier `systemctl status display-manager` :
- SDDM actif → le thème s'applique tel quel ;
- Plasma Login Manager actif → soit basculer vers SDDM
  (`sudo systemctl disable plasmalogin && sudo systemctl enable sddm`), soit porter le thème vers Plasma Login Manager.
