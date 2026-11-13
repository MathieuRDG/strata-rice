// Strata — thème SDDM (Qt 6) : paysage de nuit, titre en relief, panneau en bois, boutons pixel.
// Polices embarquées (le greeter tourne sous l'utilisateur sddm, qui ne voit pas ~/.local/share/fonts).
import QtQuick

Rectangle {
    id: root
    width: 1920; height: 1080
    color: "#1A130D"

    FontLoader { id: pixelify; source: "fonts/PixelifySans.ttf" }
    FontLoader { id: cozette;  source: "fonts/CozetteVector.ttf" }
    readonly property string fUI: pixelify.status === FontLoader.Ready ? pixelify.font.family : "sans-serif"
    readonly property string fBit: cozette.status === FontLoader.Ready ? cozette.font.family : "monospace"

    // ---------- état
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool loggingIn: false
    property string message: ""

    // modèles « lisibles » : Repeater invisibles qui exposent les rôles
    property var users: []
    property var sessions: []
    Repeater { model: userModel; delegate: Item { required property int index; required property string name; required property string realName
        Component.onCompleted: { const u = root.users.slice(); u[index] = { name: name, realName: realName }; root.users = u } } }
    Repeater { model: sessionModel; delegate: Item { required property int index; required property string name
        Component.onCompleted: { const s = root.sessions.slice(); s[index] = name; root.sessions = s } } }

    readonly property string userName: users[userIndex] ? users[userIndex].name : (userModel.lastUser || "")
    readonly property string displayName: users[userIndex] ? (users[userIndex].realName || users[userIndex].name) : userName
    readonly property string initial: displayName.length > 0 ? displayName.charAt(0).toUpperCase() : "?"

    function doLogin() {
        if (loggingIn) return
        loggingIn = true
        message = ""
        sddm.login(userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loggingIn = false
            root.message = "Mot de passe incorrect"
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
        function onLoginSucceeded() { root.message = "" }
    }

    // ---------- fond : paysage de nuit, sans lissage
    Image {
        anchors.fill: parent
        source: root.width > 1920 ? "images/night-2560x1440.png" : "images/night-1920x1080.png"
        fillMode: Image.PreserveAspectCrop
        smooth: false
    }

    // ---------- titre en relief + sous-titre
    Item {
        id: title
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.10)
        width: 900; height: 150
        Repeater {
            model: [ { d: 8, c: "#120D08" }, { d: 4, c: "#7A5232" }, { d: 0, c: "#7CCB4A" } ]
            delegate: Text {
                required property var modelData
                x: (title.width - width) / 2 + modelData.d; y: modelData.d
                text: "STRATA"; color: modelData.c
                font.family: root.fBit; font.pixelSize: 104; font.letterSpacing: 8
                renderType: Text.NativeRendering; antialiasing: false
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 122
            text: config.subtitle || "cachyos · plasma 6"
            color: "#B8A88C"
            font.family: root.fUI; font.pixelSize: 20
        }
    }

    // ---------- panneau central en bois
    Item {
        id: panel
        width: 460 + 8; height: 430 + 8
        anchors.horizontalCenter: parent.horizontalCenter
        y: title.y + title.height + 40

        SequentialAnimation {   // refus du mot de passe : secousse horizontale
            id: shake
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
            NumberAnimation { target: panel; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }

        Rectangle { x: 8; y: 8; width: 460; height: 430; color: "#120D08"; opacity: 0.55 }
        Bevel { width: 460; height: 430; fill: "#2B2118" }

        // avatar : slot en creux avec l'initiale
        Bevel {
            id: avatar
            x: (460 - 96) / 2; y: 32; width: 96; height: 96
            cw: 0; light: "#120D08"; dark: "#4A3420"; bw: 4; fill: "#1F1812"
            Text {
                anchors.centerIn: parent
                text: root.initial
                color: "#7CCB4A"
                font.family: root.fBit; font.pixelSize: 65
                renderType: Text.NativeRendering; antialiasing: false
            }
        }
        // nom + flèches si plusieurs utilisateurs
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -4
            y: 142; spacing: 14
            PixelArrow { pointsLeft: true; visible: userModel.count > 1; onClicked: root.userIndex = (root.userIndex + userModel.count - 1) % userModel.count }
            Text {
                text: root.displayName
                color: "#EDE3CF"
                font.family: root.fUI; font.pixelSize: 24; font.weight: Font.DemiBold
            }
            PixelArrow { visible: userModel.count > 1; onClicked: root.userIndex = (root.userIndex + 1) % userModel.count }
        }

        // mot de passe : champ en creux
        Bevel {
            id: field
            x: 40; y: 196; width: 380; height: 48
            cw: password.activeFocus ? 2 : 0; contour: "#7CCB4A"
            light: "#120D08"; dark: "#4A3420"; bw: 3; fill: "#1F1812"
            Text {
                x: 16; anchors.verticalCenter: parent.verticalCenter
                visible: password.text.length === 0
                text: "Mot de passe"
                color: "#6E6E6E"
                font.family: root.fUI; font.pixelSize: 17
            }
            TextInput {
                id: password
                x: 16; width: parent.width - 32
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "■"
                color: "#EDE3CF"
                font.family: root.fUI; font.pixelSize: 17
                focus: true
                clip: true
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
            }
        }
        Text {   // message d'erreur
            anchors.horizontalCenter: parent.horizontalCenter
            y: 252
            text: root.message
            color: "#C8553D"
            font.family: root.fUI; font.pixelSize: 15
        }

        // gros bouton accent
        Item {
            id: loginBtn
            x: 40; y: 280; width: 380; height: 56
            Bevel {
                anchors.fill: parent
                cw: 3; bw: 3
                light: loginMa.pressed ? "#3E5A26" : "#A6E07A"
                dark: loginMa.pressed ? "#A6E07A" : "#3E5A26"
                fill: root.loggingIn ? "#5D9B3A" : (loginMa.containsMouse ? "#8AD65A" : "#7CCB4A")
            }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: loginMa.pressed ? 2 : 0
                text: root.loggingIn ? "Chargement du monde…" : "Se connecter"
                color: "#1A130D"
                font.family: root.fUI; font.pixelSize: 21; font.weight: Font.Bold
            }
            MouseArea { id: loginMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.doLogin() }
        }

        // session + clavier (clic = suivant)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 358; spacing: 10
            Chip {
                label: "Session"
                value: root.sessions[root.sessionIndex] || "—"
                width: 230
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.count)
            }
            Chip {
                label: "Clavier"
                value: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : "—"
                width: 140
                onClicked: if (keyboard.layouts.length > 0) keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    // ---------- en bas à gauche : alimentation
    Row {
        x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        spacing: 10
        PowerButton { kind: "off";     label: "Éteindre";   enabled: sddm.canPowerOff; onClicked: sddm.powerOff() }
        PowerButton { kind: "reboot";  label: "Redémarrer"; enabled: sddm.canReboot;   onClicked: sddm.reboot() }
        PowerButton { kind: "suspend"; label: "Veille";     enabled: sddm.canSuspend;  onClicked: sddm.suspend() }
    }

    // ---------- en bas à droite : heure + date
    Column {
        anchors.right: parent.right; anchors.rightMargin: 28
        anchors.bottom: parent.bottom; anchors.bottomMargin: 20
        property date now: new Date()
        id: clock
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
        Item {
            anchors.right: parent.right
            width: t.implicitWidth + 4; height: t.implicitHeight + 4
            Text { x: 4; y: 4; text: t.text; font: t.font; color: "#120D08"; renderType: Text.NativeRendering; antialiasing: false }
            Text {
                id: t
                text: Qt.formatTime(clock.now, "HH:mm")
                color: "#EDE3CF"
                font.family: root.fBit; font.pixelSize: 52
                renderType: Text.NativeRendering; antialiasing: false
            }
        }
        Text {
            anchors.right: parent.right
            text: Qt.locale("fr_FR").toString(clock.now, "dddd d MMMM")
            color: "#EDE3CF"; style: Text.Outline; styleColor: "#120D08"
            font.family: root.fUI; font.pixelSize: 18
        }
    }

    Component.onCompleted: password.forceActiveFocus()

    // ---------- composants pixel
    component PixelArrow: Item {
        id: arr
        property bool pointsLeft: false
        signal clicked()
        width: 18; height: 24
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d"); c.fillStyle = arrMa.containsMouse ? "#7CCB4A" : "#B8A88C"
                for (let i = 0; i < 6; i++) {           // triangle en escalier de pixels 3×3
                    const h = (6 - i) * 2 - 1
                    const x = arr.pointsLeft ? (15 - i * 3) : i * 3
                    c.fillRect(x, 12 - h * 1.5 / 2 - 1, 3, Math.max(3, h * 1.5))
                }
            }
        }
        MouseArea { id: arrMa; anchors.fill: parent; hoverEnabled: true; onClicked: arr.clicked(); onContainsMouseChanged: parent.children[0].requestPaint() }
    }

    component Chip: Item {
        id: chip
        property string label
        property string value
        signal clicked()
        height: 44
        Bevel { anchors.fill: parent; cw: 2; bw: 2; fill: chipMa.containsMouse ? "#4A3828" : "#3A2C20" }
        Text { x: 12; y: 5; text: chip.label; color: "#B8A88C"; font.family: root.fUI; font.pixelSize: 11 }
        Text {
            x: 12; y: 19; width: chip.width - 24
            elide: Text.ElideRight
            text: "▸ " + chip.value
            color: "#EDE3CF"; font.family: root.fUI; font.pixelSize: 15
        }
        MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
    }

    component PowerButton: Item {
        id: pb
        property string kind
        property string label
        signal clicked()
        width: 64; height: 64
        opacity: enabled ? 1 : 0.4
        Bevel { anchors.fill: parent; cw: 3; bw: 3; fill: pbMa.containsMouse ? "#4A3828" : "#3A2C20" }
        // icône pixel dessinée (grille 3 px)
        Canvas {
            anchors.centerIn: parent; width: 30; height: 30
            onPaint: {
                const c = getContext("2d"); const P = 3
                c.fillStyle = pb.kind === "off" ? "#C8553D" : pb.kind === "reboot" ? "#E8B23A" : "#7FB2E5"
                const px = (x, y) => c.fillRect(x * P, y * P, P, P)
                if (pb.kind === "off") {          // cercle ouvert + barre
                    for (let y = 0; y < 5; y++) px(4, y); for (let y = 0; y < 5; y++) px(5, y)
                    ;[[2,2],[1,3],[1,4],[1,5],[1,6],[2,7],[3,8],[4,8],[5,8],[6,8],[7,7],[8,6],[8,5],[8,4],[8,3],[7,2]].forEach(p => px(p[0], p[1]))
                } else if (pb.kind === "reboot") { // flèche circulaire
                    ;[[3,1],[4,1],[5,1],[6,1],[2,2],[7,2],[1,3],[8,3],[1,4],[1,5],[8,5],[1,6],[8,6],[2,7],[7,7],[3,8],[4,8],[5,8],[6,8],[7,3],[8,3],[9,3],[8,4]].forEach(p => px(p[0], p[1]))
                } else {                           // lune
                    ;[[4,1],[5,1],[6,1],[3,2],[4,2],[2,3],[3,3],[2,4],[3,4],[2,5],[3,5],[2,6],[3,6],[4,6],[3,7],[4,7],[5,7],[6,7],[7,7],[4,8],[5,8],[6,8],[7,6],[8,5]].forEach(p => px(p[0], p[1]))
                }
            }
        }
        MouseArea { id: pbMa; anchors.fill: parent; hoverEnabled: true; enabled: pb.enabled; onClicked: pb.clicked() }
        Text {   // libellé au survol
            visible: pbMa.containsMouse
            anchors.horizontalCenter: parent.horizontalCenter
            y: -24
            text: pb.label
            color: "#EDE3CF"; style: Text.Outline; styleColor: "#120D08"
            font.family: root.fUI; font.pixelSize: 14
        }
    }
}
