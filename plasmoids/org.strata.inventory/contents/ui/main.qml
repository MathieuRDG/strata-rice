// Strata — lanceur « inventaire » : onglets, recherche, grille 9 colonnes, rappel de la hotbar.
// Source des apps : modèles de Kicker (menu freedesktop tenu à jour par KService), filtrés ici.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ---------- Onglets : catégories du menu (noms FR + EN) → onglet
    readonly property var tabs: [
        { id: "all",   label: "Tout",       color: "#EDE3CF" },
        { id: "sys",   label: "Système",    color: "#7CCB4A" },
        { id: "net",   label: "Internet",   color: "#7FB2E5" },
        { id: "media", label: "Multimédia", color: "#E8B23A" },
        { id: "games", label: "Jeux",       color: "#C8553D" },
        { id: "dev",   label: "Dev",        color: "#5ED6D0" },
        { id: "tools", label: "Outils",     color: "#B58AD6" }
    ]
    readonly property var catMap: ({
        "Système": "sys", "System": "sys", "Paramètres": "sys", "Settings": "sys", "Aide": "sys", "Help": "sys",
        "Internet": "net",
        "Multimédia": "media", "Multimedia": "media", "Graphisme": "media", "Graphics": "media",
        "Jeux": "games", "Games": "games",
        "Développement": "dev", "Development": "dev", "Science et mathématiques": "dev", "Science": "dev",
        "Éducation": "dev", "Education": "dev",
        "Utilitaires": "tools", "Utilities": "tools", "Bureautique": "tools", "Office": "tools"
    })
    function tabColor(id) { for (const t of tabs) if (t.id === id) return t.color; return "#EDE3CF" }

    property string currentTab: "all"
    property string query: ""
    property var appTab: ({})          // favoriteId -> id d'onglet
    property var appInfo: ({})         // favoriteId -> { name, icon }

    Kicker.RootModel {
        id: rootModel
        autoPopulate: true; flat: true; sorted: true; showSeparators: false
        showAllApps: true; showRecentApps: false; showRecentDocs: false; showPowerSession: false
        onCountChanged: indexTimer.restart()
        onRefreshed: indexTimer.restart()
    }
    readonly property var allModel: rootModel.count > 0 ? rootModel.modelForRow(0) : null

    // table app → onglet (à partir des sous-modèles de catégories)
    Timer {
        id: indexTimer
        interval: 300
        onTriggered: {
            const map = {}, info = {}
            for (let r = 1; r < rootModel.count; r++) {
                const sub = rootModel.modelForRow(r)
                const cat = rootModel.data(rootModel.index(r, 0), Qt.DisplayRole)
                const tab = root.catMap[cat] || "tools"
                if (!sub) continue
                for (let i = 0; i < sub.count; i++) {
                    const ix = sub.index(i, 0)
                    const fav = sub.data(ix, Qt.UserRole + 3)
                    if (fav && !map[fav]) map[fav] = tab
                }
            }
            if (root.allModel) for (let i = 0; i < root.allModel.count; i++) {
                const ix = root.allModel.index(i, 0)
                info[root.allModel.data(ix, Qt.UserRole + 3)] = {
                    name: root.allModel.data(ix, Qt.DisplayRole), icon: root.allModel.data(ix, Qt.DecorationRole) }
            }
            root.appTab = map
            root.appInfo = info
            filtered.invalidateFilter()
        }
    }

    function norm(s) { return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }

    KItemModels.KSortFilterProxyModel {
        id: filtered
        sourceModel: root.allModel
        filterRowCallback: (row, parent) => {
            const ix = sourceModel.index(row, 0, parent)
            const fav = sourceModel.data(ix, Qt.UserRole + 3)
            if (!fav) return false
            if (root.query !== "") {
                const hay = root.norm(sourceModel.data(ix, Qt.DisplayRole) + " " + (sourceModel.data(ix, Qt.ToolTipRole) || ""))
                if (hay.indexOf(root.norm(root.query)) < 0) return false
            }
            return root.currentTab === "all" || root.appTab[fav] === root.currentTab
        }
    }
    onCurrentTabChanged: filtered.invalidateFilter()
    onQueryChanged: filtered.invalidateFilter()

    function launch(proxyRow) {
        const src = filtered.mapToSource(filtered.index(proxyRow, 0)).row
        root.allModel.trigger(src, "", null)
        inv.visible = false
    }

    // ---------- Rappel de la hotbar (lecture / écriture de sa config via plasmashell)
    property var hotbar: []
    readonly property string readScript: `
var out = "";
panels().forEach(function (p) { p.widgets("org.strata.hotbar").forEach(function (w) {
  w.currentConfigGroup = ["General"]; var l = w.readConfig("launchers", "");
  out = (typeof l === "string") ? l : l.join(","); }); });
print(out);`
    function refreshHotbar() {
        DBus.SessionBus.asyncCall({ service: "org.kde.plasmashell", path: "/PlasmaShell",
            iface: "org.kde.PlasmaShell", member: "evaluateScript",
            arguments: [new DBus.string(readScript)], signature: "(s)" },
            (reply) => {
                let l = String(reply.value || "").trim().split(",").filter(s => s.length)
                if (l.length === 0) l = ["applications:kitty.desktop", "applications:org.kde.dolphin.desktop",
                    "applications:firefox.desktop", "applications:strata-discord.desktop",
                    "applications:strata-jellyfin.desktop", "applications:strata-navidrome.desktop",
                    "applications:strata-steam.desktop", "applications:strata-vscode.desktop",
                    "applications:strata-proxmox.desktop"]
                root.hotbar = l
            }, (err) => {})
    }
    function pinAt(url, slot) {
        let fav = url
        const m = url.match(/([^\/]+\.desktop)$/)
        if (m) fav = "applications:" + m[1]
        // déposer sur un slot = y placer l'app (remplace l'occupant, comme un objet d'inventaire)
        const l = root.hotbar.map(x => x === fav ? "" : x)
        if (slot < l.length) l[slot] = fav; else l.push(fav)
        const list = l.filter(x => x !== "").slice(0, 18)
        const js = `panels().forEach(function (p) { p.widgets("org.strata.hotbar").forEach(function (w) {
  w.currentConfigGroup = ["General"]; w.writeConfig("launchers", ${JSON.stringify(list)}); w.reloadConfig(); }); });`
        DBus.SessionBus.asyncCall({ service: "org.kde.plasmashell", path: "/PlasmaShell",
            iface: "org.kde.PlasmaShell", member: "evaluateScript",
            arguments: [new DBus.string(js)], signature: "(s)" }, () => refreshHotbar(), () => {})
        root.hotbar = list
    }

    // Actions de session. Déconnexion / redémarrage / arrêt passent par la confirmation KDE (LogoutPrompt).
    function session(action) {
        inv.visible = false
        const call = (bus, service, path, iface, member, args, sig) =>
            bus.asyncCall({ service: service, path: path, iface: iface, member: member,
                            arguments: args || [], signature: sig || "" }, () => {}, () => {})
        if (action === "lock")
            call(DBus.SessionBus, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock")
        else if (action === "suspend")
            call(DBus.SystemBus, "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
                 "Suspend", [new DBus.bool(true)], "(b)")
        else {
            const m = { logout: "promptLogout", reboot: "promptReboot", off: "promptShutDown" }[action]
            call(DBus.SessionBus, "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", m)
        }
    }

    // Meta (activateLauncherMenu) et clic sur l'icône du panneau
    property double lastToggle: 0
    function toggle() {
        // Meta déclenche à la fois « activated » et « expanded » : un seul basculement
        const t = Date.now()
        if (t - lastToggle < 300) return
        lastToggle = t
        if (inv.visible) { inv.visible = false; return }
        root.query = ""
        root.currentTab = "all"
        refreshHotbar()
        const g = Plasmoid.containment.screenGeometry
        inv.x = g.x + Math.round((g.width - inv.width) / 2)
        inv.y = g.y + Math.round((g.height - inv.height) / 2)
        inv.visible = true
        inv.requestActivate()
        content.forceSearch()
    }

    // la vraie fenêtre est le Dialog centré ci-dessous ; la popup standard est neutralisée
    fullRepresentation: Item { Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
    // Meta / clic : Plasma bascule « expanded » ; on mémorise l'état visible à cet instant
    // (le repli de la popup standard désactive notre fenêtre, qui se masque aussitôt)
    property bool wasOpen: false
    onExpandedChanged: if (root.expanded) { wasOpen = inv.visible; root.expanded = false; openTimer.restart() }
    Timer { id: openTimer; interval: 120; onTriggered: { if (root.wasOpen) inv.visible = false; else root.toggle() } }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: 30; Layout.preferredWidth: 30; Layout.maximumWidth: 30
        Layout.minimumHeight: 30; Layout.preferredHeight: 30
        onClicked: { root.wasOpen = inv.visible; openTimer.restart() }
        // icône : coffre 3×3 slots (pixel)
        Rectangle {
            anchors.centerIn: parent
            width: 22; height: 22
            color: "#1A130D"
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    x: 2 + (index % 3) * 7; y: 2 + Math.floor(index / 3) * 7
                    width: 4 + 1; height: 5
                    color: index === 4 ? "#7CCB4A" : "#7A5232"
                }
            }
        }
    }

    PlasmaCore.Dialog {
        id: inv
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.Normal
        flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        visible: false
        width: 1048; height: 788

        mainItem: InventoryView {
            id: content
            width: 1048; height: 788
            focus: true
        }
    }
}
