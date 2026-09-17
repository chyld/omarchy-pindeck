import QtQuick
import QtQuick.Controls
import qs.Commons

ToolTip {
    id: root
    property real maximumWidth: Style.space(340)
    delay: 500
    padding: Style.space(6)
    width: Math.min(maximumWidth, label.implicitWidth + leftPadding + rightPadding)
    background: Rectangle {
        color: Color.background
        radius: Style.space(4)
        border.width: 1
        border.color: Qt.alpha(Color.muted, 0.6)
    }
    contentItem: Text {
        id: label
        textFormat: Text.PlainText
        text: String(root.text).slice(0, 2048)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 8
        elide: Text.ElideRight
    }
}
