pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "components"
import "../domain/Folders.js" as Folders
import "../domain/Launch.js" as Launch

Column {
    required property var panel
    required property var keyboard
    property alias folderInput: folderInput
    property alias commandName: commandName
    property alias commandText: commandText
    property alias commandTerminal: commandTerminal
    property alias search: search
    spacing: Style.space(5)
    Row {
        width: parent.width
        Text {
            textFormat: Text.PlainText
            width: parent.width - back.width
            text: panel.commandEditing ? (panel.editingCommand ? "Edit command" : "Add command") : panel.movingId ? "Move to group" : panel.picking ? "Add app · " + panel.folderName(panel.targetFolder) : "PinDeck"
            elide: Text.ElideRight
            color: panel.barForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
        }
        Button {
            id: back
            height: Style.space(24)
            visible: panel.picking || !!panel.movingId
            text: "Back"
            onClicked: {
                panel.picking = false;
                panel.movingId = "";
                keyboard.forceActiveFocus();
            }
        }
    }
    Row {
        visible: panel.naming
        width: parent.width
        spacing: Style.space(5)
        TextField {
            id: folderInput
            maximumLength: 256
            width: parent.width - folderSave.width - folderCancel.width - 2 * parent.spacing
            placeholderText: panel.editingShortcut ? "Shortcut name" : panel.editingFolder ? "Rename group" : "Group name"
            color: panel.barForeground
            background: Rectangle {
                color: Color.background
                border.color: Color.muted
                radius: Style.space(5)
            }
            Keys.onReturnPressed: function (event) {
                event.accepted = true;
                panel.submitFolder();
            }
            Keys.onEnterPressed: function (event) {
                event.accepted = true;
                panel.submitFolder();
            }
            Keys.onEscapePressed: {
                panel.naming = false;
                panel.errorMessage = "";
                keyboard.forceActiveFocus();
            }
        }
        Button {
            id: folderSave
            text: "Save"
            onClicked: panel.submitFolder()
        }
        Button {
            id: folderCancel
            text: "Cancel"
            onClicked: {
                panel.naming = false;
                panel.errorMessage = "";
                keyboard.forceActiveFocus();
            }
        }
    }
    Column {
        visible: panel.commandEditing
        width: parent.width
        spacing: Style.space(5)
        TextField {
            id: commandName
            maximumLength: 256
            width: parent.width
            placeholderText: "Name (e.g. List downloads)"
            color: panel.barForeground
            background: Rectangle {
                color: Color.background
                border.color: Color.muted
                radius: Style.space(5)
            }
            Keys.onReturnPressed: function (event) {
                event.accepted = true;
                commandText.forceActiveFocus();
            }
        }
        TextField {
            id: commandText
            maximumLength: 16384
            width: parent.width
            placeholderText: "eza -a -l ~/Downloads"
            selectByMouse: true
            color: panel.barForeground
            background: Rectangle {
                color: Color.background
                border.color: Color.muted
                radius: Style.space(5)
            }
            Keys.onReturnPressed: function (event) {
                event.accepted = true;
                panel.saveCommand();
            }
            Keys.onEnterPressed: function (event) {
                event.accepted = true;
                panel.saveCommand();
            }
        }
        CheckBox {
            id: commandTerminal
            text: "Run in terminal"
            font.family: Style.font.family
            palette.windowText: panel.barForeground
            palette.buttonText: panel.barForeground
            palette.highlight: Color.accent
        }
        Text {
            textFormat: Text.PlainText
            width: parent.width
            text: commandTerminal.checked
                ? "Runs in Bash from your home folder. The terminal stays open until you press Enter."
                : "Runs in Bash from your home folder without opening a terminal."
            wrapMode: Text.WordWrap
            color: Color.muted
            font.pixelSize: Style.font.body * 0.85
        }
        Row {
            spacing: Style.space(5)
            Button {
                text: "Save"
                onClicked: panel.saveCommand()
            }
            Button {
                text: "Cancel"
                onClicked: {
                    panel.commandEditing = false;
                    panel.errorMessage = "";
                    keyboard.forceActiveFocus();
                }
            }
        }
    }
    TextField {
        id: search
        maximumLength: 256
        visible: panel.picking
        width: parent.width
        placeholderText: "Search apps…"
        selectByMouse: true
        color: panel.barForeground
        font.family: Style.font.family
        background: Rectangle {
            color: Color.background
            radius: Style.space(5)
            border.color: Color.muted
        }
        Keys.onPressed: function (event) {
            panel.handleKey(event);
        }
    }
}
