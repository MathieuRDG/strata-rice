// Texte avec ombre dure décalée (sans flou), rendu pixel net
import QtQuick

Item {
    id: st
    property alias text: main.text
    property alias font: main.font
    property alias color: main.color
    property color shadowColor: "#120D08"
    property int offset: 2
    // true = rendu sans anticrénelage (polices bitmap type Cozette, tailles multiples de 13 px)
    property bool pixel: false
    implicitWidth: main.implicitWidth + offset
    implicitHeight: main.implicitHeight + offset

    Text {
        x: st.offset; y: st.offset
        text: main.text; font: main.font; color: st.shadowColor
        renderType: Text.NativeRendering
        antialiasing: !st.pixel
    }
    Text {
        id: main
        color: "#EDE3CF"
        renderType: Text.NativeRendering
        antialiasing: !st.pixel
    }
}
