// Contenu de l'inventaire (1040×780 + ombre dure 8 px)
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid

FocusScope {
    id: view
    readonly property int pw: width - 8
    readonly property int ph: height - 8
    readonly property int tabH: 40
    readonly property int pad: 24
    readonly property int cols: 9
    readonly property int slotW: 104
    readonly property int gap: 4

    function forceSearch() { search.text = ""; search.forceActiveFocus() }
    function tabIndex() { for (let i = 0; i < root.tabs.length; i++) if (root.tabs[i].id === root.currentTab) return i; return 0 }
    function shiftTab(d) { const n = root.tabs.length; root.currentTab = root.tabs[(tabIndex() + d + n) % n].id }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) { inv.visible = false; e.accepted = true }
        else if ((e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_PageDown || e.key === Qt.Key_Tab)) { shiftTab(1); e.accepted = true }
        else if ((e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_PageUp || e.key === Qt.Key_Backtab)) { shiftTab(-1); e.accepted = true }
    }

    // ombre dure du panneau
    Rectangle { x: 8; y: view.tabH + 8 - 3; width: view.pw; height: view.ph - view.tabH + 3; color: "#120D08"; opacity: 0.55 }

    // ---------- panneau principal
    Bevel {
        id: panel
        y: view.tabH - 3
        width: view.pw; height: view.ph - view.tabH + 3
        fill: "#3A2C20"
    }

    // ---------- onglets (l'actif se fond dans le panneau)
    Row {
        x: 16; spacing: 4
        Repeater {
            model: root.tabs
            delegate: Item {
                required property var modelData
                readonly property bool active: root.currentTab === modelData.id
                width: 128; height: view.tabH + (active ? 3 : 0)
                y: active ? 0 : 4
                Bevel {
                    anchors.fill: parent
                    fill: active ? "#3A2C20" : "#2B2118"
                    light: active ? "#8B6A47" : "#5C4630"
                    openBottom: active
                }
                Rectangle {   // pastille de couleur de catégorie
                    x: 12; anchors.verticalCenter: label.verticalCenter
                    width: 8; height: 8; color: modelData.color
                    border.width: 1; border.color: "#1A130D"
                }
                Text {
                    id: label
                    x: 26; y: 10
                    text: modelData.label
                    color: active ? "#EDE3CF" : "#B8A88C"
                    font.family: "Pixelify Sans"; font.pixelSize: 15; font.weight: active ? Font.DemiBold : Font.Normal
                }
                MouseArea { anchors.fill: parent; onClicked: root.currentTab = modelData.id }
            }
        }
    }

    // ---------- recherche (creux)
    Bevel {
        id: searchBox
        x: view.pad; y: view.tabH + 18
        width: view.pw - 2 * view.pad; height: 40
        cw: search.activeFocus ? 2 : 0; contour: "#7CCB4A"
        light: "#120D08"; dark: "#4A3420"; bw: 3; fill: "#1F1812"
        Text {
            x: 14; anchors.verticalCenter: parent.verticalCenter
            visible: search.text === ""
            text: "Rechercher…"
            color: "#6E6E6E"
            font.family: "Pixelify Sans"; font.pixelSize: 15
        }
        TextInput {
            id: search
            x: 14; width: parent.width - 28
            anchors.verticalCenter: parent.verticalCenter
            color: "#EDE3CF"
            selectionColor: "#3E5A26"
            font.family: "Pixelify Sans"; font.pixelSize: 15
            focus: true
            onTextChanged: { root.query = text; grid.currentIndex = 0 }
            Keys.onReturnPressed: if (filtered.count > 0) root.launch(Math.max(0, grid.currentIndex))
            Keys.onDownPressed: grid.moveCurrentIndexDown()
            Keys.onUpPressed: grid.moveCurrentIndexUp()
            Keys.onRightPressed: (e) => { if (cursorPosition === text.length) grid.moveCurrentIndexRight(); else e.accepted = false }
            Keys.onLeftPressed: (e) => { if (cursorPosition === 0) grid.moveCurrentIndexLeft(); else e.accepted = false }
        }
        Text {   // compteur
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: filtered.count + " objets"
            color: "#B8A88C"
            font.family: "CozetteVector"; font.pixelSize: 13
            renderType: Text.NativeRendering; antialiasing: false
        }
    }

    // ---------- grille 9 colonnes + barre de défilement en bois
    GridView {
        id: grid
        x: view.pad; y: searchBox.y + searchBox.height + 16
        width: view.cols * (view.slotW + view.gap)
        height: hotLabel.y - y - 14
        clip: true
        cellWidth: view.slotW + view.gap
        cellHeight: view.slotW + view.gap
        model: filtered
        currentIndex: 0
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: InvSlot {
            required property int index
            required property var model
            width: view.slotW; height: view.slotW
            name: model.display || ""
            icon: model.decoration || ""
            tint: root.tabColor(root.appTab[model.favoriteId] || "")
            selected: GridView.isCurrentItem && root.query !== ""
            url: model.favoriteId || ""
            onActivated: root.launch(index)
        }
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            id: sb
            parent: view
            x: view.pw - view.pad - 18 + 2; y: grid.y
            width: 18; height: grid.height
            policy: QQC2.ScrollBar.AlwaysOn
            background: Bevel { cw: 0; light: "#120D08"; dark: "#4A3420"; bw: 3; fill: "#1F1812" }
            contentItem: Bevel { implicitWidth: 18; cw: 2; bw: 2; fill: sb.pressed ? "#5D9B3A" : "#7A5232" }
        }
    }

    // ---------- rappel de la hotbar (déposer une app = l'épingler)
    Text {
        id: hotLabel
        x: view.pad; y: hotRow.y - 22
        text: "Hotbar — glisse une app sur un slot pour l'épingler"
        color: "#B8A88C"
        font.family: "Pixelify Sans"; font.pixelSize: 13
    }
    Row {
        id: hotRow
        x: view.pad; y: view.ph - view.pad - 80
        spacing: view.gap
        Repeater {
            model: 9
            delegate: InvSlot {
                required property int index
                readonly property string fav: index < root.hotbar.length ? root.hotbar[index] : ""
                readonly property var info: root.appInfo[fav]
                width: view.slotW; height: 80
                number: index + 1
                showName: false
                icon: info ? info.icon : (fav !== "" ? "application-x-executable" : "")
                tint: root.tabColor(root.appTab[fav] || "")
                onDropped: (url) => root.pinAt(url, index)
            }
        }
    }
}
