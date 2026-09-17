// Narrow host-control stub: no processes, shell access, or production styling claims.
import QtQuick
Item {
    property string text: ""
    property string iconText: ""
    property color foreground: "white"
    property color accent: "white"
    property color background: "transparent"
    property real radius: 0
    property real fontSize: 12
    readonly property bool hot: mouse.containsMouse
    signal clicked()
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
}
