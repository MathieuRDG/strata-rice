// Jauge segmentée (fraction 0..1)
import QtQuick

Rectangle {
    id: g
    property int segments: 24
    property real fraction: 1
    property color tint: "#7CCB4A"
    property int segH: 6
    readonly property int gap: 2
    readonly property int segW: Math.floor((width - 4 - (segments - 1) * gap) / segments)
    readonly property int filled: Math.round(Math.max(0, Math.min(1, fraction)) * segments)
    height: segH + 4
    color: "#1A130D"
    Row {
        x: 2 + Math.floor((g.width - 4 - (g.segments * g.segW + (g.segments - 1) * g.gap)) / 2); y: 2
        spacing: g.gap
        Repeater {
            model: g.segments
            Rectangle {
                required property int index
                width: g.segW; height: g.segH
                color: index < g.filled ? g.tint : "#1F1812"
                Rectangle { visible: index < g.filled; width: parent.width; height: 2; color: Qt.lighter(g.tint, 1.3) }
            }
        }
    }
}
