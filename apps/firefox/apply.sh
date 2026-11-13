#!/usr/bin/env bash
# Strata — applique user.js + chrome/userChrome.css à tous les profils Firefox existants (et aux web apps).
# Idempotent. Firefox doit être redémarré pour prendre en compte les changements.
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
n=0
for base in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [ -f "$base/profiles.ini" ] || continue
    while IFS= read -r p; do
        dir="$base/$p"; [ -d "$dir" ] || continue
        cp -f "$src/user.js" "$dir/user.js"
        mkdir -p "$dir/chrome" && cp -f "$src/chrome/userChrome.css" "$dir/chrome/userChrome.css"
        echo "  profil Firefox : $dir"; n=$((n + 1))
    done < <(sed -n 's/^Path=//p' "$base/profiles.ini" | sort -u)
done
# profils des web apps Strata (Jellyfin, Navidrome, Proxmox…), créés par install.sh
for dir in "$HOME/.local/share/strata-webapps"/*/; do
    [ -d "$dir" ] || continue
    cp -f "$src/user.js" "$dir/user.js"
    mkdir -p "$dir/chrome" && cp -f "$src/chrome/userChrome.css" "$dir/chrome/userChrome.css"
    echo "  web app : $dir"; n=$((n + 1))
done
[ "$n" -gt 0 ] || echo "  aucun profil Firefox (lance Firefox une fois, puis relance ce script)"
