// Strata — disposition des panneaux (plasmashell evaluateScript).
// Variables injectées par install.sh : LAUNCHERS (tableau d'URL applications:*.desktop)
// Écran 0 (principal) : haut = inventaire | barres d'infos | notifications | zone de notification ; bas = hotbar
// Autres écrans : petit panneau haut = bureaux + heure (bossbars en version réduite)
panels().forEach(function (p) { p.remove(); });

for (var s = 0; s < screenCount; ++s) {
    var top = new Panel;
    top.screen = s;
    top.location = "top";
    top.floating = false;
    top.hiding = "none";
    if (s === 0) {
        top.height = 48;
        top.addWidget("org.strata.inventory");
        top.addWidget("org.strata.bossbars");
        top.addWidget("org.strata.toasts");
        top.addWidget("org.kde.plasma.systemtray");
    } else {
        top.height = 36;
        var bb = top.addWidget("org.strata.bossbars");
        bb.currentConfigGroup = ["General"];
        bb.writeConfig("showBars", false);
    }
    if (s === 0) {
        var bottom = new Panel;
        bottom.screen = 0;
        bottom.location = "bottom";
        bottom.alignment = "center";
        bottom.floating = false;
        bottom.hiding = "none";
        bottom.height = 88;
        bottom.lengthMode = "fit";
        var hb = bottom.addWidget("org.strata.hotbar");
        hb.currentConfigGroup = ["General"];
        hb.writeConfig("launchers", LAUNCHERS);
    }
}
print("strata: " + panels().length + " panneaux");
