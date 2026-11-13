// Strata — splash : paysage de nuit, titre « STRATA » en pixels avec relief en couches, barre segmentée
import QtQuick

Rectangle {
    id: root
    color: "#1A130D"
    property int stage            // fourni par ksplash : 1 → 6

    Image {   // fond : paysage de nuit, agrandi sans lissage
        anchors.fill: parent
        source: root.width >= 2560 ? "images/night-2560x1440.png" : "images/night-1920x1080.png"
        fillMode: Image.PreserveAspectCrop
        smooth: false
    }

    Item {
        id: content
        anchors.centerIn: parent
        width: 720; height: 260
        opacity: 0
        OpacityAnimator on opacity { from: 0; to: 1; duration: 400; running: root.stage >= 1 }

        // titre en relief : ombre (8 px) → terre (4 px) → herbe
        Repeater {
            model: [
                { dx: 8, dy: 8, c: "#120D08" },
                { dx: 4, dy: 4, c: "#7A5232" },
                { dx: 0, dy: 0, c: "#7CCB4A" }
            ]
            delegate: Text {
                required property var modelData
                x: (content.width - width) / 2 + modelData.dx
                y: modelData.dy
                text: "STRATA"
                color: modelData.c
                font.family: "CozetteVector"; font.pixelSize: 104      // 8 × la grille de 13 px
                font.letterSpacing: 8
                renderType: Text.NativeRendering
                antialiasing: false
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 140
            text: "Chargement du monde…"
            color: "#EDE3CF"
            font.family: "Pixelify Sans"; font.pixelSize: 18
        }

        // barre de chargement : 24 segments, avance avec les étapes + pulsation du segment suivant
        Rectangle {
            id: bar
            anchors.horizontalCenter: parent.horizontalCenter
            y: 184
            readonly property int segs: 24
            readonly property int segW: 18
            readonly property int filled: Math.min(segs, Math.round(Math.max(0, root.stage) / 6 * segs))
            width: segs * segW + (segs - 1) * 3 + 8
            height: 12 + 8
            color: "#1A130D"
            Row {
                x: 4; y: 4; spacing: 3
                Repeater {
                    model: bar.segs
                    Rectangle {
                        required property int index
                        width: bar.segW; height: 12
                        color: index < bar.filled ? "#7CCB4A" : (index === bar.filled ? pulse.c : "#1F1812")
                        Rectangle { visible: index < bar.filled; width: parent.width; height: 3; color: "#A6E07A" }
                        Rectangle { visible: index < bar.filled; y: parent.height - 3; width: parent.width; height: 3; color: "#5D9B3A" }
                    }
                }
            }
            QtObject { id: pulse; property color c: "#1F1812" }
            SequentialAnimation {
                running: true; loops: Animation.Infinite
                ColorAnimation { target: pulse; property: "c"; to: "#3E5A26"; duration: 300 }
                ColorAnimation { target: pulse; property: "c"; to: "#1F1812"; duration: 300 }
            }
        }
    }
}
