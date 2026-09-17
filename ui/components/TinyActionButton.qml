import QtQuick
import QtQuick.Controls
import qs.Commons

Button {
    id: root
    property string actionName: ""
    property int actionNumber: 1
    implicitWidth: Style.space(21)
    implicitHeight: Style.space(21)
    padding: Style.space(3)
    Accessible.name: actionName
    PinToolTip {
        visible: root.hovered || root.activeFocus
        text: root.actionName
    }
    background: Rectangle {
        radius: Style.space(4)
        color: Qt.alpha(Color.accent, root.down ? 0.35 : (root.hovered || root.activeFocus ? 0.24 : 0.1))
        border.width: 1
        border.color: Qt.alpha(Color.foreground, root.hovered || root.activeFocus ? 0.65 : 0.25)
    }
    contentItem: Item {
        Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: root.actionNumber
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body * 0.85
        }
    }
}
