#!/usr/bin/env python3
"""Strata : habille l'écran de verrouillage officiel de Plasma (LockScreenUi.qml) sans toucher à la logique.

Usage : patch_lockscreen.py <LockScreenUi.qml>   (modifie le fichier en place, idempotent)
- panneau bois en relief + ombre dure derrière l'utilisateur et le mot de passe ;
- titre « STRATA » en relief (herbe / terre / ombre), heure en CozetteVector, date en Pixelify ;
- horloge Breeze conservée (référencée par WallpaperFader) mais masquée, sans ombre floue.
"""
import sys

p = sys.argv[1]
s = open(p).read()
if "strataPanel" in s:
    sys.exit(0)

anchor = """        DropShadow {
            id: clockShadow"""
if anchor not in s:
    sys.exit("patch_lockscreen: ancre « clockShadow » introuvable — LockScreenUi.qml a changé, patch à mettre à jour")

add = '''        // ===== Strata : panneau bois derrière l'utilisateur + mot de passe (suit l'apparition de l'UI)
        Item {
            id: strataPanel
            readonly property int pw: 440
            readonly property int ph: mainBlock.userList.height + 170
            x: (parent.width - pw) / 2
            y: mainStack.y + mainBlock.userList.y - 34
            width: pw + 8; height: ph + 8
            opacity: mainStack.opacity
            visible: opacity > 0
            Rectangle { x: 8; y: 8; width: strataPanel.pw; height: strataPanel.ph; color: "#120D08"; opacity: 0.55 }
            Bevel { width: strataPanel.pw; height: strataPanel.ph; fill: "#2B2118" }
        }
        // ===== Strata : titre en relief + horloge bitmap
        Item {
            id: strataTitle
            anchors.horizontalCenter: parent.horizontalCenter
            y: lockScreenRoot.uiVisible ? Math.max(24, strataPanel.y - 230) : (parent.height - height) / 2 - 80
            Behavior on y { NumberAnimation { duration: 250 } }
            width: 560; height: 200
            Repeater {
                model: [ { d: 6, c: "#120D08" }, { d: 3, c: "#7A5232" }, { d: 0, c: "#7CCB4A" } ]
                delegate: Text {
                    required property var modelData
                    x: (strataTitle.width - width) / 2 + modelData.d; y: modelData.d
                    text: "STRATA"; color: modelData.c
                    font.family: "CozetteVector"; font.pixelSize: 65; font.letterSpacing: 6
                    renderType: Text.NativeRendering; antialiasing: false
                }
            }
            Text {   // ombre dure de l'heure
                x: strataClock.x + 4; y: strataClock.y + 4
                text: strataClock.text; font: strataClock.font; color: "#120D08"
                renderType: Text.NativeRendering; antialiasing: false
            }
            Text {
                id: strataClock
                property date now: new Date()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: strataClock.now = new Date() }
                anchors.horizontalCenter: parent.horizontalCenter
                y: 88
                text: Qt.formatTime(now, "HH:mm")
                color: "#EDE3CF"
                font.family: "CozetteVector"; font.pixelSize: 52; font.bold: true
                renderType: Text.NativeRendering; antialiasing: false
            }
            Text {
                x: strataDate.x + 2; y: strataDate.y + 2
                text: strataDate.text; font: strataDate.font; color: "#120D08"
            }
            Text {
                id: strataDate
                anchors.horizontalCenter: parent.horizontalCenter
                y: 158
                text: Qt.locale().toString(strataClock.now, "dddd d MMMM")
                color: "#EDE3CF"
                font.family: "Pixelify Sans"; font.pixelSize: 24; font.weight: Font.DemiBold
            }
        }

'''
s = s.replace(anchor, add + anchor, 1)
s = s.replace("""            visible: y > 0 && config.alwaysShowClock
            anchors.horizontalCenter: parent.horizontalCenter""", """            visible: false  // Strata : remplacée par strataClock
            anchors.horizontalCenter: parent.horizontalCenter""", 1)
s = s.replace("""            visible: !lockScreenUi.softwareRendering && config.alwaysShowClock
            radius: 7""", """            visible: false      // Strata : pas d'ombre floue
            radius: 7""", 1)
open(p, "w").write(s)
