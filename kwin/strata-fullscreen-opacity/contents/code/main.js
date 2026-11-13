// Strata : opacité 1.0 pour toute fenêtre en plein écran.
// Les règles « Forcer » réappliquent leur opacité à chaque (dés)activation :
// on repasse après elles, et on restaure l'opacité d'origine en sortie.
const saved = new Map();
function fix(w) {
    if (w && w.fullScreen && w.opacity !== 1.0) {
        if (!saved.has(w.internalId.toString())) saved.set(w.internalId.toString(), w.opacity);
        w.opacity = 1.0;
    }
}
function watch(w) {
    w.fullScreenChanged.connect(() => {
        const id = w.internalId.toString();
        if (w.fullScreen) fix(w);
        else if (saved.has(id)) { w.opacity = saved.get(id); saved.delete(id); }
    });
    w.closed.connect(() => saved.delete(w.internalId.toString()));
}
workspace.windowList().forEach(watch);
workspace.windowAdded.connect(watch);
workspace.windowActivated.connect(() => workspace.windowList().forEach(fix));
