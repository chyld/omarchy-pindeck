pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "components"
import "../domain/Folders.js" as Folders
import "../domain/Launch.js" as Launch
import "../controllers" as Controllers

Controllers.PanelController {
    id: root
    list: listView
    keyboard: keyboardItem
    folderInput: editors.folderInput
    commandName: editors.commandName
    commandText: editors.commandText
    search: editors.search
    appMenu: menus.appMenu
    folderMenu: menus.folderMenu
    dragFooter: footer
    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyboardItem
        padding: Style.space(10)
        contentWidth: popup.fittedContentWidth(Style.space(360))
        contentHeight: popup.fittedContentHeight(content.implicitHeight)

        Item {
            id: keyboardItem
            anchors.fill: parent
            focus: true
            Keys.onPressed: function (event) {
                root.handleKey(event);
            }
            ActionMenus {
                id: menus
                panel: root
                keyboard: keyboardItem
            }
            Column {
                id: content
                width: parent.width
                spacing: Style.space(5)
                PinEditors {
                    id: editors
                    width: parent.width
                    panel: root
                    keyboard: keyboardItem
                }
                ListView {
                    id: listView
                    visible: !root.commandEditing
                    width: parent.width
                    height: visible ? Math.min(Style.space(320), contentHeight) : 0
                    clip: true
                    interactive: !root.draggedEntry
                    model: root.rows
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: PinRow {
                        panel: root
                        list: listView
                    }
                }
                Text {
                    textFormat: Text.PlainText
                    visible: !root.commandEditing && root.rows.length === 0
                    width: parent.width
                    text: root.picking ? (root.visibilityReady ? "No apps match your search." : "Loading apps…") : "Your favorites belong here. Add your first app."
                    wrapMode: Text.WordWrap
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }
                Text {
                    textFormat: Text.PlainText
                    visible: root.errorMessage !== "" || root.configError !== "" || (root.picking && root.visibilityError !== "")
                    width: parent.width
                    text: root.configError || root.errorMessage || (root.picking ? root.visibilityError : "")
                    wrapMode: Text.WordWrap
                    color: Color.urgent
                    font.pixelSize: Style.font.body
                }
                Item {
                    visible: !root.commandEditing && !root.picking && !root.movingId
                    width: parent.width
                    height: Style.space(5)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Qt.alpha(Color.muted, 0.5)
                    }
                }
                AdminActions {
                    width: parent.width
                    panel: root
                }
                Rectangle {
                    id: footer
                    width: parent.width
                    height: Style.space(18)
                    color: root.draggedEntry ? Qt.alpha(Color.accent, 0.15) : "transparent"
                    border.width: root.dropZone === "end" ? 1 : 0
                    border.color: Color.accent
                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: root.draggedEntry ? "Drop here to move to top level · Esc cancel" : root.movingId ? "Choose a destination · Esc back" : root.picking ? "↑ ↓ select · Enter pin · Esc back" : "Drag to organize · Right-click for options"
                        color: root.draggedEntry ? root.barForeground : Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body * 0.85
                    }
                }
            }
        }
    }
}
