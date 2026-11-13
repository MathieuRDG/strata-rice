// Barre « boss bar » : titre centré + jauge de N segments
import QtQuick

Item {
    id: bar
    property string label: ""
    property real percent: 0          // 0..100
    property bool available: true
    property color tint: "#7CCB4A"
    property int segments: 20
    property int segW: 13
    property int segH: 9
    property int gap: 2
    readonly property int border: 3
    readonly property int filled: available ? Math.max(0, Math.min(segments, Math.round(percent / 100 * segments))) : 0

    implicitWidth: gauge.width
    implicitHeight: title.height + 3 + gauge.height

    ShadowText {
        id: title
        anchors.horizontalCenter: parent.horizontalCenter
        text: bar.label
        color: bar.available ? "#EDE3CF" : "#B8A88C"
        font.family: "Pixelify Sans"
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    // contour 3 px, segments séparés par le contour
    Rectangle {
        id: gauge
        y: title.height + 3
        width: bar.segments * bar.segW + (bar.segments - 1) * bar.gap + 2 * bar.border
        height: bar.segH + 2 * bar.border
        color: "#1A130D"

        Row {
            x: bar.border; y: bar.border
            spacing: bar.gap
            Repeater {
                model: bar.segments
                delegate: Item {
                    width: bar.segW; height: bar.segH
                    readonly property bool on: index < bar.filled
                    Rectangle { anchors.fill: parent; color: on ? bar.tint : (bar.available ? "#1F1812" : "#2B2118") }
                    // reflet clair en haut, ombre en bas (segment plein) ; ombre interne (creux)
                    Rectangle { visible: on; width: parent.width; height: 2; color: Qt.lighter(bar.tint, 1.3) }
                    Rectangle { visible: on; y: parent.height - 2; width: parent.width; height: 2; color: Qt.darker(bar.tint, 1.45) }
                    Rectangle { visible: !on; width: parent.width; height: 2; color: "#120D08" }
                    Rectangle { visible: !on; width: 2; height: parent.height; color: "#120D08" }
                }
            }
        }
    }
}
