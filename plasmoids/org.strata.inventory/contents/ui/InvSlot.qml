// Slot d'inventaire : creux, icône, nom ; bord coloré selon la catégorie
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: s
    property string name: ""
    property var icon: ""
    property color tint: "transparent"
    property bool selected: false
    property bool showName: true
    property int number: 0
    property string url: ""              // fichier .desktop (glisser-déposer)
    signal activated()
    signal dropped(string url)

    Bevel {
        anchors.fill: parent
        cw: s.selected ? 3 : 0
        contour: "#7CCB4A"
        light: "#120D08"; dark: "#4A3420"; bw: 3
        fill: s.selected ? "#2F3A1F" : (ma.containsMouse ? "#2A2118" : "#1F1812")
    }
    // liseré de catégorie (2 px) à l'intérieur du creux
    Rectangle {
        visible: s.tint !== Qt.color("transparent") && s.icon !== ""
        x: 3; y: 3; width: parent.width - 6; height: parent.height - 6
        color: "transparent"; border.width: 2; border.color: Qt.rgba(s.tint.r, s.tint.g, s.tint.b, 0.55)
    }
    Text {
        visible: s.number > 0
        x: 7; y: 4; text: s.number; color: "#B8A88C"
        font.family: "CozetteVector"; font.pixelSize: 13
        renderType: Text.NativeRendering; antialiasing: false
    }
    Kirigami.Icon {
        id: ic
        visible: s.icon !== ""
        source: s.icon
        width: 48; height: 48
        smooth: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: s.showName ? 12 : (parent.height - height) / 2
    }
    Text {
        visible: s.showName && s.name !== ""
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 7 }
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: s.name
        color: "#EDE3CF"
        font.family: "Pixelify Sans"; font.pixelSize: 12
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        drag.target: s.url !== "" ? dragItem : null
        onClicked: s.activated()
    }
    // glisser vers la hotbar (ou la rangée du bas) : uri-list du .desktop
    Item {
        id: dragItem
        Drag.active: ma.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: { "text/uri-list": s.url }
        Drag.imageSource: ""
    }
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => { if (drop.hasUrls) s.dropped(drop.urls[0].toString()) }
    }
}
