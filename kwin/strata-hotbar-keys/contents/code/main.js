// Strata : Meta+1…9 pour la hotbar (le plasmoid maison ne peut pas enregistrer
// les raccourcis « Activer l'entrée N du gestionnaire de tâches », réservés au
// gestionnaire de tâches standard).
// L'ordre des slots vient de la config du plasmoid org.strata.hotbar, lue via
// plasmashell (evaluateScript) à chaque appui : toujours synchronisé.

const DEFAULTS = ["kitty", "org.kde.dolphin", "firefox", "strata-discord", "strata-jellyfin",
                  "strata-navidrome", "strata-steam", "strata-vscode", "strata-proxmox"];

const QUERY = `
var out = "";
panels().forEach(function (p) {
  p.widgets("org.strata.hotbar").forEach(function (w) {
    w.currentConfigGroup = ["General"];
    var l = w.readConfig("launchers", "");
    out = (typeof l === "string") ? l : l.join(",");
  });
});
print(out);`;

function idOf(url) {   // "applications:org.kde.dolphin.desktop" -> "org.kde.dolphin"
    return url.replace(/^applications:/, "").replace(/^.*\//, "").replace(/\.desktop$/, "").trim();
}

function windowsOf(id) {
    return workspace.stackingOrder.filter(w =>
        w.normalWindow && !w.skipTaskbar &&
        (w.desktopFileName === id || w.resourceClass === id || w.resourceClass === id.toLowerCase()));
}

function launch(id) {
    // unité systemd utilisateur « app-strata-launch@<id>.service » → kstart --application <id>
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
             "org.freedesktop.systemd1.Manager", "StartUnit",
             "app-strata-launch@" + id + ".service", "replace");
}

function trigger(n) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", QUERY,
        function (reply) {
            let list = (reply || "").trim().split(",").filter(s => s.length).map(idOf);
            if (list.length === 0) list = DEFAULTS;
            const id = list[n - 1];
            if (!id) return;
            const wins = windowsOf(id);
            if (wins.length === 0) { launch(id); return; }
            const top = wins[wins.length - 1];               // la plus haute dans l'empilement
            if (workspace.activeWindow && wins.indexOf(workspace.activeWindow) >= 0 && wins.length === 1) {
                top.minimized = true;                          // déjà active → réduire
            } else if (workspace.activeWindow && wins.indexOf(workspace.activeWindow) >= 0) {
                workspace.activeWindow = wins[0];              // plusieurs fenêtres → cycler
            } else {
                top.minimized = false;
                workspace.activeWindow = top;
            }
        });
}

for (let i = 1; i <= 9; i++) {
    registerShortcut("Strata hotbar " + i, "Strata : slot " + i + " de la hotbar", "Meta+" + i,
                     function () { trigger(i); });
}
