# Portage de Strata vers la machine cible

Cible : utilisateur `suzanne`, CachyOS (linux-cachyos, btrfs), Ryzen 7 9800X3D, Radeon RX 9070 XT,
écran 1 = 27" 2560×1440 240 Hz HDR (principal), écran 2 = 16" 1920×1080 60 Hz. kitty 0.49, fish 4.9, fastfetch.

## 1. Avant
1. **Snapshot btrfs** (CachyOS : snapper) — `sudo snapper -c root create -d "avant Strata"`.
2. Mettre le système à jour et redémarrer (`sudo pacman -Syu`), pour que Better Blur DX soit compilé contre le KWin final.
3. Vérifier le gestionnaire de connexion : `systemctl status display-manager` (SDDM ou Plasma Login Manager, cf. § 5).
4. Copier le dépôt dans `~/strata-rice` (le chemin compte pour l'unité `strata-lockscreen-sync`) :
   `git clone <dépôt> ~/strata-rice` ou copie USB.

## 2. Réglages à adapter : `strata.conf`
| Clé | Rôle |
|---|---|
| `JELLYFIN_URL`, `NAVIDROME_URL`, `PROXMOX_URL` | web apps de la hotbar si aucun client natif n'est trouvé |
| `SECONDARY_POSITION` | `left` / `right` : position du 16" par rapport au 27" |
| `ENABLE_HDR`, `ENABLE_VRR` | HDR + gamut étendu et VRR automatique sur le 27" |
| `WALLPAPER` | `day` / `night` |

Clients natifs détectés automatiquement (sinon web app Firefox) : Jellyfin → `org.jellyfin.JellyfinDesktop`,
`com.github.iwalton3.jellyfin-media-player` ; Navidrome → `feishin`, `sonixd` ; Discord → `discord`, `vesktop` ;
VS Code → `code`, `visual-studio-code`, `code-oss`, `codium`.

## 3. Installation
Depuis la **session graphique** Plasma (pas en SSH), en `suzanne` :
```fish
cd ~/strata-rice
./install.sh                 # paquets (sudo), polices, thèmes, plasmoids, panneaux, écrans, verrouillage
./install.sh --with-sddm     # + thème SDDM (sudo)
```
Puis **se déconnecter / reconnecter** une fois (décoration Aurorae et police des titres lues au démarrage de KWin).
Le script est idempotent : le relancer met à jour sans recréer les panneaux (`--reset-layout` pour les recréer).
La configuration d'origine est sauvegardée une fois dans `~/.local/state/strata/backup-initial/`.

## 4. Deux écrans
- `scripts/screens.py` (appelé par `install.sh`) : le principal est la sortie qui propose 2560×1440 au taux le plus
  élevé → mode 2560×1440@240, priorité 1, échelle 1, HDR + WCG, VRR auto ; l'autre → 1920×1080@60, priorité 2,
  placé à gauche/droite. Aperçu sans rien changer : `python3 scripts/screens.py left yes yes --dry-run`.
- Panneaux (`scripts/layout.js`) :
  - écran principal : barre haute (inventaire, barres d'infos CPU/RAM/GPU, notifications, zone de notification) +
    hotbar en bas ;
  - second écran : **version réduite**, petit panneau haut de 36 px = bureaux virtuels + heure
    (`org.strata.bossbars` avec `showBars=false`), sans barres d'infos ni hotbar.
- Les notifications et l'OSD s'affichent sur l'écran principal.

## 5. HDR, 240 Hz, GPU
- HDR : réglé par `kscreen-doctor output.<sortie>.hdr.enable` + `wcg.enable`. Ajuster ensuite la luminosité SDR
  dans *Configuration du système → Affichage* (les couleurs Strata sont des couleurs SDR, à vérifier en HDR).
- GPU : la RX 9070 XT (amdgpu) expose `gpu/gpu0/usage` et `gpu/gpu0/temperature` → la 3e barre affichera la
  vraie charge (dans la VM : « GPU · N/D »). Vérifier avec `kstatsviewer --list | grep ^gpu`.
- Température CPU : `cpu/all/maximumTemperature` (k10temp) ; masquée si absente.
- Flou : Better Blur DX + flou standard. ⚠️ **Recompiler Better Blur DX après chaque mise à jour de KWin**
  (`paru -S kwin-effects-better-blur-dx-git --rebuild`), sinon l'effet ne se charge plus (pas de plantage,
  juste plus de flou forcé).
- Jeux : opacité 100 % (règle `strata-opaque` + script plein écran) et exclus du flou forcé.

## 6. Connexion (SDDM / Plasma Login Manager)
- Si SDDM est actif : `./install.sh --with-sddm` suffit ; test : `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/strata`.
- Si Plasma Login Manager est actif (cas par défaut sur CachyOS récent), `--with-sddm` désactive `plasmalogin`
  et active `sddm` (effectif au redémarrage). Sans cette bascule, le thème Strata n'apparaît jamais au démarrage.
  Manuellement : `sudo systemctl disable plasmalogin && sudo systemctl enable sddm`.

## 7. Après une mise à jour de Plasma
- Écran de verrouillage : resynchronisé automatiquement (`strata-lockscreen-sync.path`) ; si le patch ne
  s'applique plus, la surcharge est retirée → verrouillage Plasma par défaut (rien ne casse).
- Better Blur DX : recompiler (cf. § 5).
- Plasmoids maison : vérifier après une mise à jour majeure (modules privés `kicker`, `volume`, `taskmanager`).

## 8. Revenir en arrière
- Snapshot snapper, ou : restaurer `~/.local/state/strata/backup-initial/*` dans `~/.config/`, supprimer
  `~/.local/share/plasma/shells/org.kde.plasma.desktop` (surcharge du verrouillage), puis se reconnecter.

## 9. Ajouts
- **Barre DISQUE** (barres d'infos) : occupation de tous les disques via `df` (KSystemStats ne remonte rien pour
  btrfs), dédoublonnée par périphérique ; détail par disque + débits au survol ; rouge au-delà de 90 %.
- **Hotbar masquée en plein écran** : dès qu'une fenêtre plein écran (non réduite) est sur son écran/bureau, le
  panneau passe en masquage auto et la fenêtre superposée se cache ; retour à la normale ensuite.
- **Icônes pixel** : `tools/pixelicons.py` génère le thème `Strata-Pixel` (hérite de breeze-dark) ;
  `strata-pixelicons.path` le relance à chaque installation d'app (système, utilisateur, Flatpak).
  Désactiver : `PIXEL_ICONS="no"` ; exclure des apps : `PIXEL_ICONS_EXCLUDE`. Revenir aux icônes d'origine :
  `/usr/lib/plasma-changeicons breeze-dark`.
- Clients : Jellyfin Media Player (`com.github.iwalton3.jellyfin-media-player`) / Jellyfin Desktop
  (`org.jellyfin.JellyfinDesktop`), Feishin (`feishin`), Discord, Steam — détectés automatiquement.

## Firefox et web apps
- `apps/firefox/apply.sh` (appelé par `install.sh`) dépose `user.js` + `chrome/userChrome.css` dans chaque profil :
  barre de titre du système (décoration Strata), onglets en slots, barre d'adresse en creux, sans arrondis.
  Redémarrer Firefox après. Le lancer une fois avant `install.sh` pour que le profil existe.
- Web apps (Jellyfin, Navidrome, Proxmox sans client natif) : profil Firefox dédié dans `~/.local/share/strata-webapps/<app>`
  et `--name strata-<app>`, pour avoir leur propre slot dans la hotbar au lieu d'être confondues avec Firefox.

## Barre de titre Strata pour toutes les applis
`tools/titlebars.py` (lancé par `install.sh`, à chaque ouverture de session par `strata-titlebars.service` et à
chaque installation d'appli par `strata-titlebars.path`) bascule sur la décoration système Strata les applis qui
dessinent leur propre barre (CSD). `python3 tools/titlebars.py --check` affiche l'état sans rien modifier.

| Applis | Méthode |
|---|---|
| Qt / KDE | déjà décorées par KWin |
| GTK3, GTK4, libadwaita, libhandy (Meld, GNOME…) | `gtk-nocsd` (AUR) préchargé via `~/.config/environment.d/90-strata-nocsd.conf` — **effectif après reconnexion** |
| Firefox, LibreWolf | `apps/firefox/apply.sh` |
| Chrome, Chromium, Brave, Vivaldi, Edge, Thorium, Helium | `Preferences` : `browser.custom_chrome_frame = false` (navigateur fermé) |
| VS Code, Code - OSS, VSCodium, Cursor | `settings.json` : `window.titleBarStyle = native` |
| Vesktop, Obsidian | réglage « barre native » de l'appli |
| Steam, Discord officiel, Flatpak GTK | non modifiables (barre dessinée par le client / bac à sable) |

- Un fichier modifié est d'abord copié en `*.strata.bak`. Une appli ouverte n'est pas touchée : elle le sera au passage suivant.
- `gtk-nocsd` n'existe qu'en 64 bits : les programmes 32 bits (Steam, certains jeux) affichent un avertissement
  `ld.so: object … cannot be preloaded: wrong ELF class` sans conséquence.
- Désactiver pour GTK : supprimer `~/.config/environment.d/90-strata-nocsd.conf`, puis se reconnecter.
