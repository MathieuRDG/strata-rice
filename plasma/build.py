#!/usr/bin/env python3
"""Génère le Plasma Style « Strata » (desktoptheme) en SVG pixel net.

Fichiers fournis (le reste retombe sur le thème par défaut, recoloré par
le jeu de couleurs) :
  dialogs/background, widgets/background, widgets/tooltip,
  widgets/panel-background (+ translucent/ = panneau sans fond),
  widgets/tasks, widgets/viewitem, widgets/listitem, widgets/button,
  widgets/lineedit, widgets/scrollbar, widgets/bar_meter_horizontal,
  widgets/frame, widgets/plasmoidheading, widgets/tabbar,
  widgets/menubaritem, widgets/margins-highlight
Sortie : ./Strata/
"""
import json, os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'tools'))
from pixsvg import *  # noqa


def shadows(s, off=8):
    """Ombre dure décalée (off, off) sans flou, via les tuiles d'ombre KWin.

    Tuiles haut/gauche de 1 px transparentes ; le coin haut-droit (off × off+1)
    et le coin bas-gauche (off+1 × off) transparents décalent la bande d'ombre.
    """
    none = flat((SHADOW[0], 0.01))  # tuile « vide » : jamais 100 % transparente (sinon ignorée)
    sh = flat(SHADOW)
    # tuiles d'au moins off px (les tuiles de 1 px ne sont pas rendues) ;
    # le décalage vient des hints : 1 px en haut/à gauche, off px à droite/en bas
    s.piece('shadow-topleft', none, off, off)
    s.piece('shadow-top', none, 128, off)
    s.piece('shadow-left', none, off, 128)
    s.piece('shadow-topright', none, off, off + 1)
    s.piece('shadow-right', sh, off, 128)   # longues : limite le flou de filtrage à l'étirement
    s.piece('shadow-bottomright', sh, off, off)
    s.piece('shadow-bottom', sh, 128, off)
    s.piece('shadow-bottomleft', none, off + 1, off)
    s.hint('shadow-hint-top-margin', 1, 1)
    s.hint('shadow-hint-left-margin', 1, 1)
    s.hint('shadow-hint-right-margin', off, 1)
    s.hint('shadow-hint-bottom-margin', 1, off)


def hints(s, prefix, l, t=None, r=None, b=None):
    t = l if t is None else t
    r = l if r is None else r
    b = l if b is None else b
    p = f'{prefix}-' if prefix else ''
    s.hint(p + 'hint-left-margin', l, 1)
    s.hint(p + 'hint-top-margin', 1, t)
    s.hint(p + 'hint-right-margin', r, 1)
    s.hint(p + 'hint-bottom-margin', 1, b)


def panel_like(inner, margin=10, shadow=True):
    s = SVG()
    s.frame('', raised(inner), 6)
    hints(s, '', margin)
    if shadow:
        shadows(s)
    return s.text()


def tasks():
    s = SVG()
    slot = sunken(SL)
    states = {
        'normal': slot,
        'hover': bevel(L, 1, SH, D, 2, mix(SL, S, .5)),
        'focus': outline(A, 3, SEL),
        'attention': outline(OR, 3, mix(SL, OR, .12)),
        'minimized': sunken(mix(SL, B, .5)),
        'progress': flat((A, 0.30)),
    }
    for st, fn in states.items():
        s.frame(st, fn, 3)
        for edge in ('north', 'south', 'east', 'west'):
            pass  # mêmes visuels quelle que soit l'orientation : on laisse le repli sur l'état sans préfixe
    hints(s, 'normal', 4)
    return s.text()


def viewitem():
    s = SVG()
    s.frame('hover', bevel(L, 1, HOV, HOV, 1, HOV), 2)
    s.frame('selected', outline(A, 2, SEL), 2)
    s.frame('selected+hover', outline(A, 2, mix(SEL, A, .15)), 2)
    s.frame('normal', empty(), 2)
    return s.text()


def listitem():
    s = SVG()
    s.frame('normal', empty(), 2)
    s.frame('hover', bevel(L, 1, HOV, HOV, 1, HOV), 2)
    s.frame('pressed', outline(A, 2, SEL), 2)
    s.frame('section', bevel(C, 0, B, D, 2, B), 2)
    hints(s, 'normal', 4)
    hints(s, 'pressed', 4)
    s.piece('separator', flat(D), 8, 2)
    return s.text()


def button():
    s = SVG()
    s.frame('normal', raised(S, 2, 2), 4)
    s.frame('hover', raised(HOV, 2, 2), 4)
    s.frame('pressed', sunken(SEL, 2, 2), 4)
    s.frame('focus', outline(A, 2), 4)
    s.frame('toolbutton-hover', raised(HOV, 2, 2), 4)
    s.frame('toolbutton-pressed', sunken(SEL, 2, 2), 4)
    s.frame('toolbutton-focus', outline(A, 2), 4)
    for p in ('normal', 'hover', 'pressed', 'focus', 'toolbutton-hover', 'toolbutton-pressed', 'toolbutton-focus'):
        hints(s, p, 6)
    return s.text()


def lineedit():
    s = SVG()
    s.frame('base', sunken(SL, 2, 2), 4)
    s.frame('hover', outline(L, 2), 4)
    s.frame('focus', outline(A, 2), 4)
    s.hint('hint-focus-over-base', 1, 1)
    hints(s, 'base', 6)
    return s.text()


def scrollbar():
    s = SVG()
    s.frame('background-vertical', sunken(SL, 0, 2), 2)
    s.frame('background-horizontal', sunken(SL, 0, 2), 2)
    s.frame('slider', raised(TERRE, 2, 2), 4)
    s.frame('mouseover-slider', raised(mix(TERRE, L, .4), 2, 2), 4)
    s.hint('hint-scrollbar-size', 14, 14)
    return s.text()


def bar_meter():
    """Jauge segmentée : centre tuilé (segment 10 px + 3 px de vide)."""
    s = SVG()
    s.frame('bar-inactive', sunken(SL, 0, 2), 2)
    seg = lambda col: (lambda x, y, w, h: None if x >= 10 else col)
    for name, col in (('bar-active', A),):
        s.piece(f'{name}-center', seg(col), 13, 8)
        for side, (w, h) in {'top': (13, 2), 'bottom': (13, 2)}.items():
            s.piece(f'{name}-{side}', empty(), w, h)
        for side in ('left', 'right', 'topleft', 'topright', 'bottomleft', 'bottomright'):
            s.piece(f'{name}-{side}', empty(), 2, 2)
    s.hint('hint-tile-center', 1, 1)
    s.hint('hint-bar-size', 12, 12)
    return s.text()


def frame_svg():
    s = SVG()
    s.frame('plain', flat(B), 2)
    s.frame('raised', raised(S, 2, 2), 4)
    s.frame('sunken', sunken(SL, 0, 3), 3)
    for p in ('plain', 'raised', 'sunken'):
        hints(s, p, 4)
    return s.text()


def plasmoidheading():
    """En-tête / pied de popup : ils recouvrent la bordure du dialogue
    (hint-stretch-borders), donc ils portent eux-mêmes contour et biseau."""
    s = SVG()
    def head(x, y, w, h):
        if x < 3 or y < 3 or x >= w - 3:
            return C
        if y >= h - 2:
            return C
        if y < 6 or x < 6:
            return L if not (x >= w - 6) or y < 6 and (w - 1 - x) > (y - 3) else D
        if x >= w - 6:
            return D
        return S
    s.frame('header', head, (6, 6, 6, 2))
    def foot(x, y, w, h):
        if x < 3 or x >= w - 3 or y >= h - 3:
            return C
        if y < 2:
            return C
        if y >= h - 6 or x >= w - 6:
            return D if not (x < 6) or (y >= h - 6 and (x - 3) > (h - 1 - 3 - y)) else L
        if x < 6:
            return L
        return S
    s.frame('footer', foot, (6, 2, 6, 6))
    s.hint('hint-stretch-borders', 1, 1)
    hints(s, '', 8)
    return s.text()


def tabbar():
    s = SVG()
    # onglet actif : relief ouvert en bas, se fond dans le panneau
    def north(x, y, w, h):
        d = min(x, y, w - 1 - x)
        if d < 2:
            return C
        if d < 4:
            return L if (y < 4 and x < w - 4) or x < 4 else D
        return S
    s.frame('north-active-tab', north, (4, 4, 4, 0))
    def south(x, y, w, h):
        return north(x, h - 1 - y, w, h)
    s.frame('south-active-tab', south, (4, 0, 4, 4))
    hints(s, 'north-active-tab', 6, 6, 6, 4)
    hints(s, 'south-active-tab', 6, 4, 6, 6)
    return s.text()


def menubaritem():
    s = SVG()
    s.frame('normal', empty(), 2)
    s.frame('hover', bevel(L, 1, HOV, HOV, 1, HOV), 2)
    s.frame('pressed', outline(A, 2, SEL), 2)
    for p in ('normal', 'hover', 'pressed'):
        hints(s, p, 4)
    return s.text()


def margins_highlight():
    s = SVG()
    s.frame('', outline(A, 2), 2)
    s.piece('fill', flat((A, 0.25)), 8, 8)
    return s.text()


def transparent_panel():
    s = SVG()
    s.frame('', empty(), 2)
    hints(s, '', 0)
    return s.text()


METADATA = {
    "KPlugin": {
        "Authors": [{"Name": "Strata"}],
        "Category": "Plasma Theme",
        "Description": "Plasma Style pixel Strata : bois, biseaux, slots en creux",
        "Id": "Strata",
        "License": "GPL-3.0-or-later",
        "Name": "Strata",
        "Version": "1.0"
    },
    "X-Plasma-API-Minimum-Version": "6.0"
}

PLASMARC = """[ContrastEffect]
enabled=false

[AdaptiveTransparency]
enabled=false

[BlurBehindEffect]
enabled=true
"""

if __name__ == '__main__':
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Strata')
    files = {
        'dialogs/background.svg': panel_like(B),
        'widgets/background.svg': panel_like(B),
        'widgets/tooltip.svg': panel_like(S, 8),
        'widgets/panel-background.svg': panel_like(B, 8),
        'translucent/widgets/panel-background.svg': transparent_panel(),
        'widgets/tasks.svg': tasks(),
        'widgets/viewitem.svg': viewitem(),
        'widgets/listitem.svg': listitem(),
        'widgets/button.svg': button(),
        'widgets/lineedit.svg': lineedit(),
        'widgets/scrollbar.svg': scrollbar(),
        'widgets/bar_meter_horizontal.svg': bar_meter(),
        'widgets/frame.svg': frame_svg(),
        'widgets/plasmoidheading.svg': plasmoidheading(),
        'widgets/tabbar.svg': tabbar(),
        'widgets/menubaritem.svg': menubaritem(),
        'widgets/margins-highlight.svg': margins_highlight(),
        'plasmarc': PLASMARC,
        'metadata.json': json.dumps(METADATA, indent=4, ensure_ascii=False) + '\n',
    }
    for rel, content in files.items():
        p = os.path.join(out, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'w') as f:
            f.write(content)
    print(out)
