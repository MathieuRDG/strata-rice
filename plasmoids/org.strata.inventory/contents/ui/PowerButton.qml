// Bouton d'alimentation pixel (relief bois, glyphe dessiné sur une grille 10×10 de 3 px)
import QtQuick

Item {
    id: pb
    property string kind: "off"        // lock | suspend | logout | reboot | off
    property string label: ""
    signal clicked()
    width: 40; height: 40

    readonly property var glyphs: ({
        "lock":    { c: "#E8B23A", p: [[3,1],[4,1],[5,1],[6,1],[2,2],[7,2],[2,3],[7,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[8,4],
                                       [1,5],[8,5],[1,6],[4,6],[5,6],[8,6],[1,7],[4,7],[5,7],[8,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[8,8]] },
        "suspend": { c: "#7FB2E5", p: [[4,1],[5,1],[6,1],[3,2],[4,2],[2,3],[3,3],[2,4],[3,4],[2,5],[3,5],[2,6],[3,6],[4,6],[3,7],[4,7],[5,7],[6,7],[7,7],[4,8],[5,8],[6,8],[7,6],[8,5]] },
        "logout":  { c: "#B58AD6", p: [[1,1],[2,1],[3,1],[4,1],[1,2],[1,3],[1,4],[1,5],[1,6],[1,7],[1,8],[2,8],[3,8],[4,8],
                                       [4,4],[5,4],[6,4],[7,4],[8,4],[4,5],[5,5],[6,5],[7,5],[8,5],[6,2],[7,3],[7,6],[6,7]] },
        "reboot":  { c: "#E8B23A", p: [[3,1],[4,1],[5,1],[6,1],[2,2],[7,2],[1,3],[1,4],[1,5],[8,5],[1,6],[8,6],[2,7],[7,7],[3,8],[4,8],[5,8],[6,8],
                                       [7,1],[8,1],[8,2],[8,3],[7,3]] },
        "off":     { c: "#C8553D", p: [[4,0],[5,0],[4,1],[5,1],[4,2],[5,2],[4,3],[5,3],[2,2],[1,3],[1,4],[1,5],[1,6],[2,7],[3,8],[4,8],[5,8],[6,8],
                                       [7,7],[8,6],[8,5],[8,4],[8,3],[7,2]] }
    })

    Bevel { anchors.fill: parent; cw: 2; bw: 2; fill: ma.pressed ? "#2F3A1F" : (ma.containsMouse ? "#4A3828" : "#3A2C20") }
    Item {
        anchors.centerIn: parent
        width: 30; height: 30
        Repeater {
            model: pb.glyphs[pb.kind].p
            Rectangle {
                required property var modelData
                x: modelData[0] * 3; y: modelData[1] * 3; width: 3; height: 3
                color: pb.glyphs[pb.kind].c
            }
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pb.clicked() }
    Rectangle {   // libellé au survol
        visible: ma.containsMouse && pb.label !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height + 6; z: 10
        width: tip.implicitWidth + 14; height: tip.implicitHeight + 8
        color: "#1A130D"
        Text { id: tip; anchors.centerIn: parent; text: pb.label; color: "#EDE3CF"; font.family: "Pixelify Sans"; font.pixelSize: 13 }
    }
}
