// Strata — hotbar : 9 slots fixes, Meta+1…9, 2e rangée au-delà de 9 apps, nom de l'app active
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import org.kde.kitemmodels as KItemModels
import org.kde.ksvg as KSvg

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    readonly property int slotSize: Plasmoid.configuration.slotSize
    readonly property int spacing: 4
    readonly property int perRow: 9

    TaskManager.VirtualDesktopInfo { id: vdi }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity
        virtualDesktop: vdi.currentDesktop
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: true
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true            // une app lancée prend la place de son lanceur épinglé
        separateLaunchers: false
        hideActivatedLaunchers: true
        onLauncherListChanged: if (String(Plasmoid.configuration.launchers) !== String(launcherList))
                                   Plasmoid.configuration.launchers = launcherList
        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
    }
    // l'inventaire peut réécrire la liste (épinglage depuis sa rangée du bas)
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            if (String(Plasmoid.configuration.launchers) !== String(tasksModel.launcherList))
                tasksModel.launcherList = Plasmoid.configuration.launchers
        }
    }

    readonly property int total: tasksModel.count
    readonly property bool overflow: total > perRow
    readonly property string activeName: activeProxy.count > 0 ? (activeProxy.name || "") : ""

    // Rangée 1 = lignes 0..8, rangée 2 = lignes 9+ (rôles vivants via les proxys)
    KItemModels.KSortFilterProxyModel {
        id: firstRow
        sourceModel: tasksModel
        filterRowCallback: (row, parent) => row < root.perRow
    }
    KItemModels.KSortFilterProxyModel {
        id: secondRow
        sourceModel: tasksModel
        filterRowCallback: (row, parent) => row >= root.perRow
    }
    KItemModels.KSortFilterProxyModel {      // tâche active → son nom
        id: activeProxyModel
        sourceModel: tasksModel
        filterRowCallback: (row, parent) => tasksModel.data(tasksModel.index(row, 0), TaskManager.AbstractTasksModel.IsActive) === true
    }
    Instantiator {
        id: activeProxy
        property string name: ""
        model: activeProxyModel
        delegate: QtObject {
            required property var model
            readonly property string n: model.AppName || model.display || ""
            onNChanged: activeProxy.name = n
            Component.onCompleted: activeProxy.name = n
        }
    }
    Connections {
        target: tasksModel
        function onRowsInserted() { root.refilter() }
        function onRowsRemoved() { root.refilter() }
        function onRowsMoved() { root.refilter() }
        function onLayoutChanged() { root.refilter() }
        function onDataChanged() { activeProxyModel.invalidateFilter() }
        function onActiveTaskChanged() { activeProxyModel.invalidateFilter() }
    }
    function refilter() { firstRow.invalidateFilter(); secondRow.invalidateFilter(); activeProxyModel.invalidateFilter() }

    function activate(row, mouse) {
        const idx = tasksModel.makeModelIndex(row)
        const isLauncher = tasksModel.data(idx, TaskManager.AbstractTasksModel.IsLauncher)
        if (mouse && mouse.button === Qt.MiddleButton) {
            tasksModel.requestNewInstance(idx)
        } else if (isLauncher) {
            tasksModel.requestActivate(idx)          // lance l'app
        } else if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive)
                   && !tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent)) {
            tasksModel.requestToggleMinimized(idx)
        } else {
            tasksModel.requestActivate(idx)
        }
    }

    // Appelée par le raccourci global « Activer l'entrée N du gestionnaire de tâches » (Meta+1…9)
    function activateTaskAtIndex(index) {
        if (index >= 0 && index < tasksModel.count) activate(index, null)
    }

    function pin(url, row) {
        if (!url.endsWith(".desktop")) return
        const launcher = url.startsWith("applications:") ? url : url
        if (tasksModel.requestAddLauncher(launcher)) {
            const from = tasksModel.launcherPosition(launcher)
            if (from >= 0 && row >= 0 && from !== row) tasksModel.move(from, row)
        }
    }

    component SlotRow: Row {
        id: srow
        property var rowModel
        property int first: 0
        property bool dimmed: false
        property bool fixed: true          // complète jusqu'à 9 slots vides
        spacing: root.spacing
        Repeater {
            model: srow.rowModel
            delegate: Slot {
                required property int index
                required property var model
                size: root.slotSize
                number: srow.first === 0 ? index + 1 : 0
                empty: false
                dimmed: srow.dimmed
                icon: model.decoration
                active: model.IsActive === true
                open: model.IsLauncher !== true
                attention: model.IsDemandingAttention === true
                minimized: model.IsMinimized === true
                onClicked: (m) => root.activate(srow.first + index, m)
                onDropped: (url) => root.pin(url, srow.first + index)
            }
        }
        Repeater {   // slots vides
            model: srow.fixed ? Math.max(0, root.perRow - (srow.rowModel ? srow.rowModel.count : 0)) : 0
            delegate: Slot {
                required property int index
                readonly property int pos: (srow.rowModel ? srow.rowModel.count : 0) + index
                size: root.slotSize
                number: srow.first === 0 ? pos + 1 : 0
                onDropped: (url) => root.pin(url, -1)
            }
        }
    }

    fullRepresentation: Item {
        id: bar
        readonly property int pad: 8          // marge intérieure du cadre
        readonly property int shadow: 8       // ombre dure décalée
        readonly property int frameW: mainRow.width + 2 * pad
        readonly property int frameH: root.slotSize + 2 * pad
        Layout.minimumWidth: frameW + shadow
        Layout.preferredWidth: frameW + shadow
        Layout.maximumWidth: frameW + shadow
        Layout.minimumHeight: frameH + shadow
        Layout.preferredHeight: frameH + shadow

        Rectangle {   // ombre portée dure 8×8
            x: bar.shadow; y: bar.shadow
            width: bar.frameW; height: bar.frameH
            color: "#120D08"; opacity: 0.55
        }
        KSvg.FrameSvgItem {   // cadre bois en relief (Plasma Style : widgets/hotbar)
            id: frameItem
            width: bar.frameW; height: bar.frameH
            imagePath: "widgets/hotbar"
        }

        Row {
            id: mainRow
            x: bar.pad; y: bar.pad
            spacing: 8
            SlotRow { id: row1; rowModel: firstRow; first: 0 }
            Text {   // indicateur de rangées
                anchors.verticalCenter: parent.verticalCenter
                visible: root.overflow
                text: "1/2"
                color: "#B8A88C"
                font.family: "CozetteVector"; font.pixelSize: 13
                renderType: Text.NativeRendering
                antialiasing: false
            }
        }

        // Au-dessus de la barre : nom de l'app active + 2e rangée (fenêtre superposée)
        PlasmaCore.Dialog {
            id: overlay
            visualParent: frameItem
            location: PlasmaCore.Types.BottomEdge
            type: PlasmaCore.Dialog.Dock
            flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: false
            outputOnly: !root.overflow
            visible: root.activeName !== "" || root.overflow

            mainItem: Column {
                spacing: 6
                Item {
                    width: Math.max(label.width, root.overflow ? row2.width : 0)
                    height: label.height
                    Item {
                        id: label
                        visible: root.activeName !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: t.implicitWidth + 2; height: t.implicitHeight + 2
                        Text { x: 2; y: 2; text: t.text; font: t.font; color: "#120D08" }
                        Text {
                            id: t
                            text: root.activeName
                            color: "#EDE3CF"
                            font.family: "Pixelify Sans"; font.pixelSize: 16; font.weight: Font.DemiBold
                        }
                    }
                }
                SlotRow {
                    id: row2
                    rowModel: secondRow
                    visible: root.overflow
                    first: root.perRow
                    fixed: false
                    dimmed: true
                }
            }
        }
    }
}
