#!/usr/bin/env python3
"""Strata : configuration des écrans via kscreen-doctor (Wayland/KWin).

- principal = sortie qui propose 2560×1440 avec le meilleur taux (240 Hz attendus) → priorité 1, HDR + WCG, VRR auto ;
- secondaire = autre sortie connectée → 1920×1080@60, placée à gauche ou à droite (SECONDARY_POSITION).
Usage : screens.py [left|right] [hdr yes|no] [vrr yes|no] [--dry-run]
"""
import json, subprocess, sys

args = [a for a in sys.argv[1:] if a != '--dry-run']
dry = '--dry-run' in sys.argv
side = args[0] if len(args) > 0 else 'left'
hdr = (args[1] if len(args) > 1 else 'yes') == 'yes'
vrr = (args[2] if len(args) > 2 else 'yes') == 'yes'

data = json.loads(subprocess.run(['kscreen-doctor', '-j'], capture_output=True, text=True, check=True).stdout)
outs = [o for o in data.get('outputs', []) if o.get('connected')]
if not outs:
    sys.exit('aucune sortie connectée')

def best(o, w, h):
    ms = [m for m in o.get('modes', []) if m['size']['width'] == w and m['size']['height'] == h]
    return max(ms, key=lambda m: m['refreshRate']) if ms else None

cands = [(o, best(o, 2560, 1440)) for o in outs]
cands = [c for c in cands if c[1]]
if not cands:
    print('aucune sortie 2560×1440 : écrans laissés tels quels'); sys.exit(0)
primary, pmode = max(cands, key=lambda c: c[1]['refreshRate'])
others = [o for o in outs if o['id'] != primary['id']]

cmd = []
pn = primary['name']
cmd += [f'output.{pn}.enable', f'output.{pn}.mode.{pmode["id"]}', f'output.{pn}.priority.1', f'output.{pn}.scale.1']
if hdr:
    cmd += [f'output.{pn}.hdr.enable', f'output.{pn}.wcg.enable']
if vrr:
    cmd += [f'output.{pn}.vrrpolicy.automatic']

if others:
    sec = others[0]; sn = sec['name']
    smode = best(sec, 1920, 1080)
    cmd += [f'output.{sn}.enable', f'output.{sn}.priority.2', f'output.{sn}.scale.1']
    if smode:
        cmd += [f'output.{sn}.mode.{smode["id"]}']
    if side == 'left':
        cmd += [f'output.{sn}.position.0,0', f'output.{pn}.position.1920,0']
    else:
        cmd += [f'output.{pn}.position.0,0', f'output.{sn}.position.2560,0']
else:
    cmd += [f'output.{pn}.position.0,0']

print('kscreen-doctor ' + ' '.join(cmd))
print(f'principal : {pn} {pmode["size"]["width"]}×{pmode["size"]["height"]} @ {pmode["refreshRate"]:.0f} Hz')
if not dry:
    subprocess.run(['kscreen-doctor'] + cmd, check=True)
