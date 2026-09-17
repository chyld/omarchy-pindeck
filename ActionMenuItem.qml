import QtQuick
import QtQuick.Controls
import qs.Commons

MenuItem {
    id: root
    implicitHeight: Style.space(36)
    leftPadding: Style.space(12)
    rightPadding: Style.space(12)
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        color: Color.foreground
        opacity: root.enabled ? 1 : 0.45
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        color: root.highlighted ? Qt.alpha(Color.accent, 0.2) : "transparent"
    }
}
