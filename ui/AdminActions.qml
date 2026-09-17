pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "components"
import "../domain/Folders.js" as Folders
import "../domain/Launch.js" as Launch

Grid {
    required property var panel
    columns: 2
    visible: !panel.commandEditing && !panel.picking && !panel.movingId
    width: parent.width
    spacing: Style.space(6)
    Button {
        width: (parent.width - parent.spacing) / 2
        height: Style.space(22)
        text: "+ Add app"
        foreground: Color.accent
        background: Qt.alpha(Color.accent, 0.1)
        radius: Style.space(4)
        onClicked: panel.addApp("")
    }
    Button {
        width: (parent.width - parent.spacing) / 2
        height: Style.space(22)
        text: "+ Add folder"
        foreground: Color.accent
        background: Qt.alpha(Color.accent, 0.1)
        radius: Style.space(4)
        onClicked: panel.addLocation("")
    }
    Button {
        width: (parent.width - parent.spacing) / 2
        height: Style.space(22)
        text: "+ Add command"
        foreground: Color.accent
        background: Qt.alpha(Color.accent, 0.1)
        radius: Style.space(4)
        onClicked: panel.editCommand(null, "")
    }
    Button {
        width: (parent.width - parent.spacing) / 2
        height: Style.space(22)
        text: "+ Add group"
        foreground: Color.accent
        background: Qt.alpha(Color.accent, 0.1)
        radius: Style.space(4)
        onClicked: panel.editFolder("")
    }
}
