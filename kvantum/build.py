#!/usr/bin/env python3
"""Génère le thème Kvantum « Strata » (SVG pixel net + kvconfig).

Chaque élément 9-slice est calculé pixel par pixel (contour, biseau, intérieur)
puis découpé en 9 pièces : <elem>-<état>[-top|-bottom|-left|-right|-topleft…].
Sortie : ./Strata/Strata.svg et ./Strata/Strata.kvconfig
"""
import os

C = '#1A130D'   # contour
L = '#8B6A47'   # biseau clair
D = '#4A3420'   # biseau sombre
S = '#3A2C20'   # surface
B = '#2B2118'   # bois (fond)
SL = '#1F1812'  # slot
SH = '#120D08'  # ombre de slot
A = '#7CCB4A'   # accent
AF = '#5D9B3A'  # herbe foncée
SEL = '#2F3A1F'  # fond sélection
HOV = '#4A3828'  # survol
T = '#EDE3CF'   # texte
T2 = '#B8A88C'
P = '#6E6E6E'   # pierre (désactivé)
OR = '#E8B23A'
NONE = None
STATES = ('normal', 'focused', 'pressed', 'toggled', 'disabled')


def style(contour, cw, light, dark, bw, inner):
    """Retourne f(x, y, w, h) -> couleur | None."""
    def f(x, y, w, h):
        d = min(x, y, w - 1 - x, h - 1 - y)
        if d < cw:
            return contour
        if d < cw + bw:
            dt, dl, db, dr = y - cw, x - cw, h - 1 - cw - y, w - 1 - cw - x
            m = min(dt, dl, db, dr)
            # coin haut-droit / bas-gauche : diagonale nette
            if m == dt or m == dl:
                if (m == dt and m == dr) or (m == dl and m == db):
                    return light if (dt + dl) < (db + dr) else dark
                return light
            return dark
        return inner
    return f


raised = lambda inner, c=C: style(c, 2, L, D, 2, inner)
sunken = lambda inner=SL, c=C: style(c, 2, SH, D, 2, inner)
select = lambda inner=SEL: style(A, 2, inner, inner, 2, inner)
flat = lambda col, cw=2: style(col, cw, col, col, 0, col)
empty = lambda: style(None, 0, None, None, 0, None)


class SVG:
    def __init__(self):
        self.out, self.x, self.y, self.rowh = [], 0, 0, 0

    def place(self, w, h):
        if self.x + w > 1600:
            self.x, self.y, self.rowh = 0, self.y + self.rowh + 6, 0
        pos = (self.x, self.y)
        self.x += w + 6
        self.rowh = max(self.rowh, h)
        return pos

    def piece(self, ident, fn, W, H, x0, y0, x1, y1):
        """Rend la région [x0,x1)×[y0,y1) d'une boîte W×H."""
        w, h = x1 - x0, y1 - y0
        ox, oy = self.place(w, h)
        rects = []
        for yy in range(y0, y1):
            run = None
            for xx in range(x0, x1 + 1):
                c = fn(xx, yy, W, H) if xx < x1 else '#END'
                if run and c != run[1]:
                    if run[1]:
                        rects.append((run[0] - x0, yy - y0, xx - run[0], run[1]))
                    run = None
                if run is None and c != '#END':
                    run = (xx, c)
        body = ''.join(f'<rect x="{ox+x}" y="{oy+y}" width="{rw}" height="1" fill="{c}"/>' for x, y, rw, c in rects)
        # rectangle invisible pour fixer la boîte englobante
        self.out.append(f'<g id="{ident}"><rect x="{ox}" y="{oy}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>{body}</g>')

    def frame(self, name, fn, F, inner=8):
        N = 2 * F + inner
        cuts = {'topleft': (0, 0, F, F), 'top': (F, 0, N - F, F), 'topright': (N - F, 0, N, F),
                'left': (0, F, F, N - F), 'right': (N - F, F, N, N - F),
                'bottomleft': (0, N - F, F, N), 'bottom': (F, N - F, N - F, N), 'bottomright': (N - F, N - F, N, N)}
        self.piece(name, fn, N, N, F, F, N - F, N - F)
        for side, (a, b, c, d) in cuts.items():
            self.piece(f'{name}-{side}', fn, N, N, a, b, c, d)

    def whole(self, name, fn, W, H):
        self.piece(name, fn, W, H, 0, 0, W, H)

    def bitmap(self, name, rows, colors, scale=1):
        h, w = len(rows), len(rows[0])
        def fn(x, y, W, H):
            ch = rows[y // scale][x // scale]
            return colors.get(ch)
        self.piece(name, fn, w * scale, h * scale, 0, 0, w * scale, h * scale)

    def text(self):
        return ('<?xml version="1.0" encoding="UTF-8"?>\n'
                '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="%d" shape-rendering="crispEdges">\n'
                % (self.y + self.rowh + 10) + '\n'.join(self.out) + '\n</svg>\n')


def build():
    s = SVG()
    F = 4
    frames = {
        # élément: {état: style}
        'button': dict(normal=raised(S), focused=raised(HOV), pressed=sunken(SEL), toggled=select(), disabled=raised(B, C)),
        'tbutton': dict(normal=empty(), focused=raised(HOV), pressed=sunken(SEL), toggled=select(), disabled=empty()),
        'lineedit': dict(normal=sunken(), focused=sunken(SL, A), pressed=sunken(SL, A), toggled=sunken(SL, A), disabled=sunken(B)),
        'common': dict(normal=sunken(B), focused=sunken(B), pressed=sunken(B), toggled=sunken(B), disabled=sunken(B)),
        'group': dict(normal=raised(B), focused=raised(B), pressed=raised(B), toggled=raised(B), disabled=raised(B)),
        'tab': dict(normal=sunken(B), focused=raised(HOV), pressed=raised(S), toggled=raised(S), disabled=sunken(B)),
        'tabframe': dict(normal=raised(S), focused=raised(S), pressed=raised(S), toggled=raised(S), disabled=raised(S)),
        'menu': dict(normal=raised(B), focused=raised(B), pressed=raised(B), toggled=raised(B), disabled=raised(B)),
        'tooltip': dict(normal=raised(S), focused=raised(S), pressed=raised(S), toggled=raised(S), disabled=raised(S)),
        'progress': dict(normal=sunken(), focused=sunken(), pressed=sunken(), toggled=sunken(), disabled=sunken(B)),
        'progress-pattern': dict(normal=style(AF, 0, A, AF, 2, A), focused=style(AF, 0, A, AF, 2, A),
                                 pressed=style(AF, 0, A, AF, 2, A), toggled=style(AF, 0, A, AF, 2, A), disabled=flat(P, 0)),
        'scrollbargroove': dict(normal=sunken(), focused=sunken(), pressed=sunken(), toggled=sunken(), disabled=sunken(B)),
        'scrollbarslider': dict(normal=raised('#7A5232'), focused=raised('#8F6440'), pressed=raised(AF), toggled=raised(AF), disabled=raised(B)),
        'slider': dict(normal=sunken(), focused=sunken(), pressed=sunken(), toggled=style(C, 2, A, AF, 2, AF), disabled=sunken(B)),
        'header': dict(normal=raised(S), focused=raised(HOV), pressed=sunken(SEL), toggled=raised(S), disabled=raised(B)),
    }
    for el, states in frames.items():
        for st in STATES:
            s.frame(f'{el}-{st}', states[st], F)

    # éléments à frame fin (2 px)
    thin = {
        'itemview': dict(normal=empty(), focused=flat(HOV), pressed=select(), toggled=select(), disabled=empty()),
        'menuitem': dict(normal=empty(), focused=select(), pressed=select(), toggled=select(), disabled=empty()),
        'menubaritem': dict(normal=empty(), focused=select(), pressed=select(), toggled=select(), disabled=empty()),
    }
    for el, states in thin.items():
        for st in STATES:
            fn = states[st]
            s.frame(f'{el}-{st}', fn, 2)

    # curseur de slider : bloc 16×16 en relief, accent au survol
    for st, inner in dict(normal=S, focused=HOV, pressed=AF, toggled=AF, disabled=B).items():
        s.whole(f'slidercursor-{st}', style(C, 2, L, D, 2, inner), 16, 16)

    # cases à cocher / boutons radio (16×16)
    for st in STATES:
        dis = st == 'disabled'
        box = sunken(B if dis else SL, A if st in ('focused',) else C)
        s.whole(f'checkbox-{st}', box, 16, 16)
        mark = P if dis else A
        s.whole(f'checkbox-checked-{st}', lambda x, y, w, h, box=box, mark=mark:
                mark if 5 <= x <= 10 and 5 <= y <= 10 else box(x, y, w, h), 16, 16)
        s.whole(f'checkbox-tristate-{st}', lambda x, y, w, h, box=box:
                OR if 5 <= x <= 10 and 7 <= y <= 8 else box(x, y, w, h), 16, 16)
        # radio : losange pixel
        def rad(x, y, w, h, st=st, dis=dis, checked=False):
            d = abs(x - 7.5) + abs(y - 7.5)
            if d > 8:
                return None
            if d > 6:
                return A if st == 'focused' else C
            if d > 5:
                return SH if (x + y) < 15 else D
            if checked and d <= 3:
                return P if dis else A
            return B if dis else SL
        s.whole(f'radio-{st}', rad, 16, 16)
        s.whole(f'radio-checked-{st}', lambda x, y, w, h, r=rad: r(x, y, w, h, checked=True), 16, 16)

    # flèches pixel (9×9)
    arrow_down = ['.........', '.........', '#########', '.#######.', '..#####..', '...###...', '....#....', '.........', '.........']
    rot = lambda rows: [''.join(rows[len(rows) - 1 - c][r] for c in range(len(rows))) for r in range(len(rows[0]))]
    arrows = {'down': arrow_down}
    arrows['left'] = rot(arrow_down)
    arrows['up'] = rot(arrows['left'])
    arrows['right'] = rot(arrows['up'])
    acol = dict(normal=T, focused=A, pressed=A, toggled=A, disabled=P)
    for d, rows in arrows.items():
        for st in STATES:
            s.bitmap(f'arrow-{d}-{st}', rows, {'#': acol[st]})
    plus = ['.........', '....#....', '....#....', '....#....', '#########', '....#....', '....#....', '....#....', '.........']
    minus = ['.........'] * 4 + ['#########'] + ['.........'] * 4
    for st in STATES:
        s.bitmap(f'arrow-plus-{st}', plus, {'#': acol[st]})
        s.bitmap(f'arrow-minus-{st}', minus, {'#': acol[st]})

    # poignées
    grip = ['.........', '.#..#..#.', '.........', '.........', '.#..#..#.', '.........', '.........', '.#..#..#.', '.........']
    for st in STATES:
        s.bitmap(f'splitter-grip-{st}', grip, {'#': L})
        s.bitmap(f'resize-grip-{st}', ['......#', '.......', '....#.#', '.......', '..#.#.#', '.......', '#.#.#.#'], {'#': L})
    return s.text()


KVCONFIG = r"""[%General]
author=Strata
comment=Strata — thème pixel original, bois / herbe / pierre
x11drag=menubar_and_primary_toolbar
alt_mnemonic=true
left_tabs=true
attach_active_tab=false
group_toolbar_buttons=false
spread_progressbar=true
progressbar_thickness=12
composite=true
menu_shadow_depth=0
tooltip_shadow_depth=0
spread_menuitems=true
splitter_width=7
scroll_width=14
scroll_min_extent=40
scroll_arrows=false
combo_as_lineedit=false
combo_menu=true
inline_spin_indicators=true
vertical_spin_indicators=false
slider_width=8
slider_handle_width=16
slider_handle_length=16
check_size=16
tooltip_delay=-1
toolbar_icon_size=22
small_icon_size=16
large_icon_size=32
button_icon_size=16
animate_states=false
no_inactiveness=false
transient_scrollbar=false
transient_groove=false
translucent_windows=false
blurring=false
popup_blurring=false
reduce_window_opacity=0
reduce_menu_opacity=0
menu_separator_height=7
fill_rubberband=true
respect_DE=true
dialog_button_layout=0
click_behavior=0
contrast=1.00
intensity=1.00
saturation=1.00

[GeneralColors]
window.color=#2B2118
base.color=#1F1812
alt.base.color=#241C14
button.color=#3A2C20
light.color=#8B6A47
mid.light.color=#5C4630
dark.color=#120D08
mid.color=#4A3420
shadow.color=#120D08
highlight.color=#3E5A26
inactive.highlight.color=#2F3A1F
tooltip.base.color=#3A2C20
text.color=#EDE3CF
window.text.color=#EDE3CF
button.text.color=#EDE3CF
disabled.text.color=#7D6E58
tooltip.text.color=#EDE3CF
highlight.text.color=#EDE3CF
link.color=#7FB2E5
link.visited.color=#B58AD6
progress.indicator.text.color=#120D08

[Hacks]
respect_darkness=true
transparent_ktitle_label=true
transparent_dolphin_view=false
blur_konsole=false
transparent_menutitle=true
middle_click_scroll=true
normal_default_pushbutton=true
iconless_pushbutton=false
tint_on_mouseover=0
no_selection_tint=true
disabled_icon_opacity=60
lxqtmainmenu_iconsize=0
style_vertical_toolbars=false

[PanelButtonCommand]
frame=true
frame.element=button
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
interior=true
interior.element=button
indicator.size=9
text.normal.color=#EDE3CF
text.focus.color=#EDE3CF
text.press.color=#7CCB4A
text.toggle.color=#7CCB4A
text.disabled.color=#7D6E58
text.shadow=0
text.margin=1
text.iconspacing=5
indicator.element=arrow
text.margin.top=2
text.margin.bottom=2
text.margin.left=6
text.margin.right=6
min_height=+4
min_width=+8

[PanelButtonTool]
inherits=PanelButtonCommand
frame.element=tbutton
interior.element=tbutton
text.margin.left=3
text.margin.right=3

[ToolbarButton]
inherits=PanelButtonTool
text.normal.color=#EDE3CF
text.focus.color=#EDE3CF

[Dock]
inherits=PanelButtonCommand
frame=false
interior=false

[DockTitle]
inherits=PanelButtonCommand
frame=false
interior=false
text.bold=true
text.normal.color=#B8A88C
text.focus.color=#EDE3CF

[IndicatorSpinBox]
inherits=PanelButtonCommand
frame=true
interior=true
frame.element=tbutton
interior.element=tbutton
indicator.element=arrow
indicator.size=9

[RadioButton]
inherits=PanelButtonCommand
frame=false
interior.element=radio
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF
text.margin.left=2
text.margin.right=2

[CheckBox]
inherits=PanelButtonCommand
frame=false
interior.element=checkbox
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF
text.margin.left=2
text.margin.right=2

[GenericFrame]
inherits=PanelButtonCommand
frame=true
interior=false
frame.element=common
interior.element=common
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4

[LineEdit]
inherits=PanelButtonCommand
frame.element=lineedit
interior.element=lineedit
text.margin.left=4
text.margin.right=4
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF

[DropDownButton]
inherits=PanelButtonCommand
indicator.element=arrow

[IndicatorArrow]
indicator.element=arrow
indicator.size=9

[ToolboxTab]
inherits=PanelButtonCommand

[Tab]
inherits=PanelButtonCommand
frame.element=tab
interior.element=tab
indicator.element=arrow
text.normal.color=#B8A88C
text.focus.color=#EDE3CF
text.press.color=#EDE3CF
text.toggle.color=#7CCB4A
text.margin.left=10
text.margin.right=10
text.margin.top=3
text.margin.bottom=3
min_height=+6
min_width=+8

[TabFrame]
inherits=PanelButtonCommand
frame.element=tabframe
interior.element=tabframe
interior=true

[TabBarFrame]
inherits=GenericFrame
frame=false
interior=false

[TreeExpander]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.size=9
indicator.element=arrow

[HeaderSection]
inherits=PanelButtonCommand
frame.element=header
interior.element=header
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF
text.bold=true

[SizeGrip]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.element=resize-grip
indicator.size=7

[Toolbar]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.element=toolbar
indicator.size=5
text.margin=0

[MenuBar]
inherits=PanelButtonCommand
frame=false
interior=false

[MenuBarItem]
inherits=PanelButtonCommand
frame.element=menubaritem
interior.element=menubaritem
frame.top=2
frame.bottom=2
frame.left=2
frame.right=2
text.margin.left=6
text.margin.right=6
text.focus.color=#EDE3CF
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF

[Menu]
inherits=PanelButtonCommand
frame.element=menu
interior.element=menu
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF

[MenuItem]
inherits=PanelButtonCommand
frame=true
frame.element=menuitem
interior.element=menuitem
indicator.element=menuitem
frame.top=2
frame.bottom=2
frame.left=2
frame.right=2
text.margin.top=2
text.margin.bottom=2
text.margin.left=6
text.margin.right=6
text.focus.color=#EDE3CF
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF
min_height=+4

[Slider]
inherits=PanelButtonCommand
frame.element=slider
interior.element=slider
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4

[SliderCursor]
inherits=PanelButtonCommand
frame=false
interior.element=slidercursor

[Progressbar]
inherits=PanelButtonCommand
frame.element=progress
interior.element=progress
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
text.margin=0
text.normal.color=#EDE3CF
text.focus.color=#EDE3CF
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF
text.bold=true

[ProgressbarContents]
inherits=PanelButtonCommand
frame=true
frame.element=progress-pattern
interior.element=progress-pattern
frame.top=2
frame.bottom=2
frame.left=2
frame.right=2

[ItemView]
inherits=PanelButtonCommand
frame.element=itemview
interior.element=itemview
frame.top=2
frame.bottom=2
frame.left=2
frame.right=2
text.margin.top=2
text.margin.bottom=2
text.margin.left=4
text.margin.right=4
text.normal.color=#EDE3CF
text.focus.color=#EDE3CF
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF
min_width=+4
min_height=+4

[Splitter]
inherits=PanelButtonCommand
frame=false
interior=false
indicator.element=splitter-grip
indicator.size=9

[Scrollbar]
inherits=PanelButtonCommand
indicator.element=arrow
indicator.size=9

[ScrollbarSlider]
inherits=PanelButtonCommand
frame.element=scrollbarslider
interior.element=scrollbarslider
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
indicator.element=grip
indicator.size=0

[ScrollbarGroove]
inherits=PanelButtonCommand
frame.element=scrollbargroove
interior.element=scrollbargroove
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4

[TitleBar]
inherits=PanelButtonCommand
frame=false
interior=false
text.bold=true

[ComboBox]
inherits=PanelButtonCommand
text.press.color=#EDE3CF
text.toggle.color=#EDE3CF

[GroupBox]
inherits=GenericFrame
frame=true
frame.element=group
interior=true
interior.element=group
text.shadow=0
text.margin=0
text.bold=true
text.normal.color=#E8B23A
text.focus.color=#E8B23A

[ToolTip]
inherits=GenericFrame
frame.top=4
frame.bottom=4
frame.left=4
frame.right=4
interior=true
text.shadow=0
text.margin=2
frame.element=tooltip
interior.element=tooltip

[StatusBar]
inherits=GenericFrame
frame=false
interior=false

[Window]
interior=false
frame=false
"""


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, 'Strata')
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'Strata.svg'), 'w') as f:
        f.write(build())
    with open(os.path.join(out, 'Strata.kvconfig'), 'w') as f:
        f.write(KVCONFIG)
    print(out)
