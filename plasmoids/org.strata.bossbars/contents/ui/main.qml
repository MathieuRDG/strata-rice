// Strata — barres d'infos en haut : bureaux virtuels | CPU · RAM · GPU | heure
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // --- Palette Strata
    readonly property color cAccent: "#7CCB4A"
    readonly property color cGold: "#E8B23A"
    readonly property color cGem: "#5ED6D0"
    readonly property color cDirt: "#7A5232"
    readonly property color cText: "#EDE3CF"
    readonly property color cText2: "#B8A88C"
    readonly property string nbsp: " "

    // --- Capteurs (KSystemStats)
    Sensors.Sensor { id: cpuUse;  sensorId: "cpu/all/usage";              updateRateLimit: 1000 }
    Sensors.Sensor { id: cpuTemp; sensorId: "cpu/all/maximumTemperature"; updateRateLimit: 2000 }
    Sensors.Sensor { id: ramPct;  sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Sensors.Sensor { id: ramUsed; sensorId: "memory/physical/used";        updateRateLimit: 1000 }
    // GPU : agrégat puis premier GPU ; absent dans une VM sans pilote exposant ces capteurs
    Sensors.Sensor { id: gpuAll;  sensorId: "gpu/all/usage";               updateRateLimit: 1000 }
    Sensors.Sensor { id: gpu0;    sensorId: "gpu/gpu0/usage";              updateRateLimit: 1000 }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu0/temperature";        updateRateLimit: 2000 }

    function ok(s) { return s.status === Sensors.Sensor.Ready && s.value !== undefined && !isNaN(s.value) }
    function pct(v) { return Math.round(v) + root.nbsp + "%" }
    function deg(s) { return (ok(s) && s.value > 0) ? " · " + Math.round(s.value) + root.nbsp + "°C" : "" }

    readonly property var gpuSensor: ok(gpuAll) ? gpuAll : (ok(gpu0) ? gpu0 : null)

    // --- Bureaux virtuels
    TaskManager.VirtualDesktopInfo { id: vdi }
    readonly property int curIndex: vdi.desktopIds.indexOf(vdi.currentDesktop)

    function switchDesktop(i) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin", path: "/KWin", iface: "org.kde.KWin",
            member: "setCurrentDesktop", arguments: [new DBus.int32(i + 1)], signature: "(i)"
        })
    }

    // --- Horloge
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // --- Volume
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property string volText: !sink ? "vol —"
        : sink.muted ? "muet" : "vol " + Math.round(sink.volume / 65536 * 100) + root.nbsp + "%"

    fullRepresentation: Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 44
        Layout.preferredHeight: 48
        Layout.minimumWidth: Plasmoid.configuration.showBars ? 900 : 300

        // ---------- À gauche : bureaux
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: vdi.desktopIds
                delegate: Rectangle {     // carré 22 px en relief
                    width: 22; height: 22
                    color: "#1A130D"
                    readonly property bool active: index === root.curIndex
                    Rectangle {
                        x: 2; y: 2; width: 18; height: 18
                        color: active ? root.cAccent : root.cDirt
                        Rectangle { width: parent.width; height: 2; color: Qt.lighter(parent.color, 1.3) }
                        Rectangle { width: 2; height: parent.height; color: Qt.lighter(parent.color, 1.3) }
                        Rectangle { y: parent.height - 2; width: parent.width; height: 2; color: Qt.darker(parent.color, 1.45) }
                        Rectangle { x: parent.width - 2; width: 2; height: parent.height; color: Qt.darker(parent.color, 1.45) }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.switchDesktop(index) }
                }
            }
            Item { width: 4; height: 1 }
            ShadowText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.curIndex >= 0 ? vdi.desktopNames[root.curIndex] : ""
                font.family: "Pixelify Sans"; font.pixelSize: 16; font.weight: Font.DemiBold
            }
        }

        // ---------- Au centre : 3 barres (masquées en version réduite, second écran)
        Row {
            visible: Plasmoid.configuration.showBars
            anchors.centerIn: parent
            spacing: 28

            BossBar {
                label: "CPU · " + (root.ok(cpuUse) ? root.pct(cpuUse.value) : "N/D") + root.deg(cpuTemp)
                percent: root.ok(cpuUse) ? cpuUse.value : 0
                available: root.ok(cpuUse)
                tint: root.cAccent
            }
            BossBar {
                label: "RAM · " + (root.ok(ramPct) ? root.pct(ramPct.value) : "N/D")
                       + (root.ok(ramUsed) ? " · " + (ramUsed.value / 1073741824).toFixed(1).replace(".", ",") + root.nbsp + "Go" : "")
                percent: root.ok(ramPct) ? ramPct.value : 0
                available: root.ok(ramPct)
                tint: root.cGold
            }
            BossBar {
                label: "GPU · " + (root.gpuSensor ? root.pct(root.gpuSensor.value) + root.deg(gpuTemp) : "N/D")
                percent: root.gpuSensor ? root.gpuSensor.value : 0
                available: root.gpuSensor !== null
                tint: root.cGem
            }
        }

        // ---------- À droite : heure, date + volume
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            ShadowText {
                anchors.right: parent.right
                text: Qt.formatTime(root.now, "HH:mm")
                font.family: "CozetteVector"; font.pixelSize: 26
                pixel: true
            }
            ShadowText {
                anchors.right: parent.right
                offset: 1
                text: Qt.locale().toString(root.now, "ddd d MMM") + (Plasmoid.configuration.showBars ? "  ·  " + root.volText : "")
                color: root.cText2
                font.family: "Pixelify Sans"; font.pixelSize: 12
            }
        }

        WheelHandler {
            onWheel: (ev) => {
                const n = vdi.desktopIds.length
                if (n < 2) return
                root.switchDesktop((root.curIndex + (ev.angleDelta.y < 0 ? 1 : n - 1)) % n)
            }
        }
    }
}
