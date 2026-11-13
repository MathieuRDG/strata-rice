// Une notification Strata (420 px) : slot d'icône 56 px, app + heure, titre coloré, corps bitmap, jauge 24 segments
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Item {
    id: toast
    required property int index
    required property var model
    property var notifications                         // NotificationManager.Notifications
    readonly property int urgency: model.urgency
    readonly property bool critical: urgency === NotificationManager.Notifications.CriticalUrgency
    readonly property bool hasActions: (model.actionNames || []).length > 0
    readonly property color titleColor:
        critical ? "#C8553D"
        : urgency === NotificationManager.Notifications.LowUrgency ? "#7FB2E5"
        : hasActions ? "#E8B23A" : "#7CCB4A"
    readonly property int duration: model.timeout > 0 ? model.timeout : (critical ? 0 : 6000)
    property real remaining: 1

    width: 428
    height: body.y + body.height + 14 + (actionsRow.visible ? actionsRow.height + 8 : 0) + gauge.height + 16 + 8

    function idx() { return notifications.index(index, 0) }

    NumberAnimation on remaining {
        id: countdown
        running: toast.duration > 0 && !hover.hovered
        from: toast.remaining; to: 0
        duration: Math.max(1, toast.duration * toast.remaining)
        onFinished: if (toast.remaining <= 0) toast.notifications.expire(toast.idx())
    }
    HoverHandler { id: hover; onHoveredChanged: if (!hovered) countdown.restart() }

    // ombre dure + panneau en relief
    Rectangle { x: 8; y: 8; width: 420; height: toast.height - 8; color: "#120D08"; opacity: 0.55 }
    Bevel { width: 420; height: toast.height - 8; fill: "#3A2C20" }

    // slot d'icône 56 px en creux
    Bevel {
        x: 14; y: 14; width: 56; height: 56
        cw: 0; light: "#120D08"; dark: "#4A3420"; bw: 3; fill: "#1F1812"
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 36; height: 36
            source: toast.model.image || toast.model.iconName || toast.model.applicationIconName || "preferences-desktop-notification-bell"
        }
    }

    Text {   // app + heure
        id: meta
        x: 82; y: 14; width: 420 - 82 - 34
        elide: Text.ElideRight
        text: (toast.model.applicationName || "Système") + "  ·  " + Qt.formatTime(toast.model.created, "HH:mm")
        color: "#B8A88C"
        font.family: "Pixelify Sans"; font.pixelSize: 11
    }
    Rectangle {   // fermer : carré rouge 14 px
        x: 420 - 14 - 14; y: 12; width: 14; height: 14
        color: "#1A130D"
        Rectangle { x: 2; y: 2; width: 10; height: 10; color: closeMa.containsMouse ? "#E07A63" : "#C8553D" }
        MouseArea { id: closeMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                    onClicked: toast.notifications.close(toast.idx()) }
    }
    Text {   // titre
        id: title
        x: 82; y: meta.y + meta.height + 2; width: 420 - 82 - 14
        elide: Text.ElideRight
        text: toast.model.summary || ""
        color: toast.titleColor
        font.family: "Pixelify Sans"; font.pixelSize: 16; font.weight: Font.DemiBold
    }
    Text {   // corps en police bitmap
        id: body
        x: 82; y: title.y + title.height + 4; width: 420 - 82 - 14
        text: toast.model.body || ""
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: 5
        elide: Text.ElideRight
        color: "#EDE3CF"
        linkColor: "#7FB2E5"
        font.family: "CozetteVector"; font.pixelSize: 13
        renderType: Text.NativeRendering; antialiasing: false
        onLinkActivated: (l) => Qt.openUrlExternally(l)
    }
    Row {   // actions
        id: actionsRow
        visible: toast.hasActions
        x: 82; y: body.y + body.height + 10
        spacing: 6
        Repeater {
            model: toast.model.actionLabels || []
            delegate: Item {
                required property int index
                required property string modelData
                width: lbl.implicitWidth + 20; height: 26
                Bevel { anchors.fill: parent; cw: 2; bw: 2; fill: actMa.containsMouse ? "#4A3828" : "#2B2118" }
                Text { id: lbl; anchors.centerIn: parent; text: parent.modelData; color: "#EDE3CF"
                       font.family: "Pixelify Sans"; font.pixelSize: 12 }
                MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: toast.notifications.invokeAction(toast.idx(), toast.model.actionNames[parent.index]) }
            }
        }
    }
    Gauge {   // 24 segments qui se vident
        id: gauge
        x: 14; width: 420 - 28
        y: toast.height - 8 - 14 - height
        segments: 24
        fraction: toast.duration > 0 ? toast.remaining : 1
        tint: toast.titleColor
    }
    // clic sur le corps = action par défaut
    TapHandler {
        enabled: toast.model.hasDefaultAction === true
        onTapped: toast.notifications.invokeDefaultAction(toast.idx())
    }
}
