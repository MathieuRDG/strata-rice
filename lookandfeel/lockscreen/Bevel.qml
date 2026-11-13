// Cadre pixel : contour + biseau (clair haut/gauche, sombre bas/droite) + intérieur
import QtQuick

Item {
    id: b
    property color contour: "#1A130D"
    property int cw: 3
    property color light: "#8B6A47"
    property color dark: "#4A3420"
    property int bw: 3
    property color fill: "#3A2C20"
    property bool openBottom: false     // onglet actif : pas de bas (se fond dans le panneau)

    Rectangle { anchors.fill: parent; color: b.contour; visible: b.cw > 0 }
    Item {
        x: b.cw; y: b.cw
        width: parent.width - 2 * b.cw
        height: parent.height - (b.openBottom ? b.cw : 2 * b.cw)
        Rectangle { anchors.fill: parent; color: b.fill }
        Rectangle { width: parent.width; height: b.bw; color: b.light }
        Rectangle { width: b.bw; height: parent.height; color: b.light }
        Rectangle { x: parent.width - b.bw; y: b.bw; width: b.bw; height: parent.height - b.bw; color: b.dark }
        Rectangle { visible: !b.openBottom; x: b.bw; y: parent.height - b.bw; width: parent.width - b.bw; height: b.bw; color: b.dark }
    }
    Rectangle {   // onglet ouvert : prolonge l'intérieur jusqu'au panneau
        visible: b.openBottom
        x: b.cw + b.bw; y: parent.height - b.cw
        width: parent.width - 2 * (b.cw + b.bw); height: b.cw + b.bw
        color: b.fill
    }
}
