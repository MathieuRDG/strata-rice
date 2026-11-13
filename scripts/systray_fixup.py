#!/usr/bin/env python3
"""Strata : retire l'applet de notifications standard des zones de notification (popups maison à la place)
et passe tous les panneaux en mode translucide. À lancer plasmashell ARRÊTÉ.
Usage : systray_fixup.py ~/.config/plasma-org.kde.plasma.desktop-appletsrc ~/.config/plasmashellrc
"""
import re, sys

appletsrc, shellrc = sys.argv[1], sys.argv[2]
s = open(appletsrc).read()
# 1) supprimer les groupes d'applet org.kde.plasma.notifications (zone de notification)
blocks = re.split(r'(?m)^(?=\[)', s)
out = []
skip_prefix = None
for b in blocks:
    head = b.split('\n', 1)[0]
    if skip_prefix and head.startswith(skip_prefix):
        continue
    if re.search(r'(?m)^plugin=org\.kde\.plasma\.notifications$', b) and '[Applets]' in head:
        skip_prefix = head[:-1]          # ignore aussi ses sous-groupes
        continue
    skip_prefix = None
    out.append(b)
s = ''.join(out)
# 2) retirer de extraItems (le garder dans knownItems, sinon la zone de notification le réajoute)
s = re.sub(r'(?m)^(extraItems=.*)$',
           lambda m: 'extraItems=' + ','.join(x for x in m.group(1)[11:].split(',') if x != 'org.kde.plasma.notifications'), s)
open(appletsrc, 'w').write(s)

# 3) panneaux translucides (le fond translucide du Plasma Style est vide)
ids = sorted(set(re.findall(r'(?m)^\[Containments\]\[(\d+)\]$', s)))
panel_ids = [i for i in ids if re.search(r'(?ms)^\[Containments\]\[%s\]\n(?:[^\[].*\n)*?plugin=org\.kde\.panel$' % i, s)]
r = open(shellrc).read() if __import__('os').path.exists(shellrc) else ''
for i in panel_ids:
    grp = '[PlasmaViews][Panel %s]' % i
    if grp in r:
        body_start = r.index(grp) + len(grp)
        nxt = r.find('\n[', body_start)
        body = r[body_start: nxt if nxt >= 0 else len(r)]
        body = re.sub(r'(?m)^panelOpacity=.*\n?', '', body)
        body = body.rstrip('\n') + '\npanelOpacity=2\n'
        r = r[:body_start] + body + (r[nxt:] if nxt >= 0 else '')
    else:
        r += '\n%s\npanelOpacity=2\nfloating=0\n' % grp
open(shellrc, 'w').write(r)
print('strata: notifications standard retirées, %d panneaux translucides' % len(panel_ids))
