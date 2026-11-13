// Strata — notifications empilées en haut à droite + OSD de volume.
// Remplace les popups de l'applet de notifications standard (retirée de la zone de notification).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as Vol

PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property rect screen: Plasmoid.containment.screenGeometry
    readonly property int topOffset: 48 + 8      // sous le panneau du haut

    NotificationManager.Settings { id: nsettings }
    function syncStack() { stack.visible = notifs.count > 0 }

    NotificationManager.Notifications {
        id: notifs
        limit: 5
        showNotifications: true
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        showJobs: false
        blacklistedDesktopEntries: nsettings.popupBlacklistedApplications
        blacklistedNotifyRcNames: nsettings.popupBlacklistedServices
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder           // la plus récente en haut
        groupMode: NotificationManager.Notifications.GroupDisabled
        // Plasma 6.8 : countChanged part avant l'insertion réelle (count lu = 0) → on relit après coup
        onCountChanged: Qt.callLater(root.syncStack)
        onRowsInserted: Qt.callLater(root.syncStack)
        onRowsRemoved: Qt.callLater(root.syncStack)
        onModelReset: Qt.callLater(root.syncStack)
        urgencies: NotificationManager.Server.inhibited
            ? NotificationManager.Notifications.CriticalUrgency
            : (NotificationManager.Notifications.CriticalUrgency | NotificationManager.Notifications.NormalUrgency
               | (nsettings.lowPriorityPopups ? NotificationManager.Notifications.LowUrgency : 0))
    }

    // ---------- pile de notifications
    PlasmaCore.Dialog {
        id: stack
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.Notification
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: false            // piloté impérativement (une liaison est écrasée par Dialog)
        x: root.screen.x + root.screen.width - 428 - 12
        y: root.screen.y + root.topOffset

        mainItem: Item {
            width: 428
            // hauteur calculée sans attendre le « polish » de Column (fenêtre cachée = jamais rendue)
            height: {
                let h = 0
                for (let i = 0; i < rep.count; i++) { const it = rep.itemAt(i); if (it) h += it.height + (i > 0 ? 6 : 0) }
                return Math.max(1, h)
            }
            Column {
                id: toastColumn
                width: 428
                spacing: 6
                Repeater {
                    id: rep
                    model: notifs
                    delegate: Toast { notifications: notifs }
                }
            }
        }
    }

    // ---------- OSD de volume (panneau en relief, icône, jauge 16 segments, valeur)
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property int volPct: sink ? Math.round(sink.volume / 65536 * 100) : 0
    property bool volReady: false
    Timer { interval: 1500; running: true; onTriggered: root.volReady = true }   // pas d'OSD au démarrage
    onVolPctChanged: if (volReady) osd.show(sink && sink.muted ? "audio-volume-muted" : volIcon(volPct), volPct, "Volume")
    Connections {
        target: root.sink
        function onMutedChanged() { if (root.volReady) osd.show(root.sink.muted ? "audio-volume-muted" : root.volIcon(root.volPct), root.sink.muted ? 0 : root.volPct, root.sink.muted ? "Muet" : "Volume") }
    }
    function volIcon(p) { return p <= 0 ? "audio-volume-muted" : p < 34 ? "audio-volume-low" : p < 67 ? "audio-volume-medium" : "audio-volume-high" }

    Timer { id: hideTimer; interval: 1600; onTriggered: osd.visible = false }
    PlasmaCore.Dialog {
        id: osd
        property string iconName: "audio-volume-high"
        property int value: 0
        property string label: ""
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.OnScreenDisplay
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        backgroundHints: PlasmaCore.Dialog.NoBackground
        outputOnly: true
        visible: false
        x: root.screen.x + Math.round((root.screen.width - 368) / 2)
        y: root.screen.y + root.screen.height - 88 - 24 - 84 - 40      // au-dessus de la hotbar

        function show(i, v, l) { iconName = i; value = Math.max(0, Math.min(150, v)); label = l; visible = true; hideTimer.restart() }

        mainItem: Item {
            width: 368; height: 84
            Rectangle { x: 8; y: 8; width: 360; height: 76; color: "#120D08"; opacity: 0.55 }
            Bevel { width: 360; height: 76; fill: "#3A2C20" }
            Bevel {
                x: 14; y: 14; width: 48; height: 48
                cw: 0; light: "#120D08"; dark: "#4A3420"; bw: 3; fill: "#1F1812"
                Kirigami.Icon { anchors.centerIn: parent; width: 32; height: 32; smooth: false; source: osd.iconName }
            }
            Text {
                x: 74; y: 14
                text: osd.label
                color: "#B8A88C"
                font.family: "Pixelify Sans"; font.pixelSize: 12
            }
            Gauge {
                x: 74; y: 38; width: 216
                segments: 16; segH: 12
                fraction: osd.value / 100
                tint: osd.value > 100 ? "#C8553D" : "#7CCB4A"
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 14 + 8
                y: 30
                text: osd.value + "%"
                color: "#EDE3CF"
                font.family: "CozetteVector"; font.pixelSize: 26
                renderType: Text.NativeRendering; antialiasing: false
            }
        }
    }

    // icône discrète dans le panneau : compteur de notifications actives (clic = ne pas déranger)
    fullRepresentation: Item { Layout.preferredWidth: 1; Layout.preferredHeight: 1 }
    onExpandedChanged: if (expanded) expanded = false
    compactRepresentation: MouseArea {
        Layout.minimumWidth: 26; Layout.preferredWidth: 26; Layout.maximumWidth: 26
        Layout.minimumHeight: 26
        onClicked: NotificationManager.Server.inhibited = !NotificationManager.Server.inhibited
        Rectangle {   // cloche pixel (simplifiée : bloc + battant)
            anchors.centerIn: parent
            width: 16; height: 16; color: "transparent"
            Rectangle { x: 3; y: 2; width: 10; height: 10; color: NotificationManager.Server.inhibited ? "#6E6E6E" : "#E8B23A"; border.width: 1; border.color: "#1A130D" }
            Rectangle { x: 1; y: 11; width: 14; height: 3; color: "#1A130D" }
            Rectangle { x: 7; y: 14; width: 2; height: 2; color: "#1A130D" }
        }
    }
}
