// Un slot de la hotbar : fond du Plasma Style (widgets/tasks), numéro, icône, trait « ouvert »
import QtQuick
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami

Item {
    id: slot
    property int number: 0              // 1..9, 0 = pas de numéro
    property var icon: null
    property bool empty: true
    property bool active: false
    property bool open: false           // au moins une fenêtre
    property bool attention: false
    property bool minimized: false
    property bool dimmed: false
    property int size: 64
    signal clicked(var mouse)
    signal dropped(string url)

    width: size; height: size
    opacity: dimmed ? 0.65 : 1

    KSvg.FrameSvgItem {
        anchors.fill: parent
        imagePath: "widgets/tasks"
        prefix: slot.active ? "focus"
              : slot.attention ? "attention"
              : (mouse.containsMouse && !slot.empty) ? "hover"
              : (slot.minimized ? "minimized" : "normal")
    }

    Kirigami.Icon {
        visible: !slot.empty
        anchors.centerIn: parent
        width: slot.size >= 64 ? 48 : 32; height: width   // tailles exactes du thème Strata-Pixel (net)
        smooth: false
        source: slot.icon
        opacity: slot.minimized ? 0.6 : 1
    }

    Text {   // numéro en police bitmap
        visible: slot.number > 0
        x: 6; y: 3
        text: slot.number
        color: "#B8A88C"
        font.family: "CozetteVector"; font.pixelSize: 13
        renderType: Text.NativeRendering
        antialiasing: false
    }

    Rectangle {   // trait 8×4 : app ouverte
        visible: slot.open
        width: 8; height: 4
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 5
        color: "#7CCB4A"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (m) => slot.clicked(m)
    }

    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (drop) => { if (drop.hasUrls) slot.dropped(drop.urls[0].toString()) }
    }
}
