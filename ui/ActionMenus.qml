pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "components"
import "../domain/Folders.js" as Folders
import "../domain/Launch.js" as Launch

Item {
    required property var panel
    required property var keyboard
    property alias appMenu: appMenu
    property alias folderMenu: folderMenu
    Menu {
        id: appMenu
        property var entry: null
        popupType: Popup.Item
        width: Style.space(280)
        font.family: Style.font.family
        palette.window: Color.background
        palette.windowText: panel.barForeground
        palette.text: panel.barForeground
        palette.highlight: Color.accent
        background: Rectangle {
            color: Color.background
            border.color: Color.accent
            border.width: 1
        }
        ActionMenuItem {
            text: "Open"
            enabled: !!appMenu.entry && !appMenu.entry.missing
            onTriggered: panel.launch(appMenu.entry, "")
        }
        Instantiator {
            model: appMenu.entry && !appMenu.entry.missing && appMenu.entry.kind !== "command" && appMenu.entry.kind !== "location" ? appMenu.entry.actions || [] : []
            delegate: ActionMenuItem {
                required property var modelData
                text: modelData.name || modelData.id
                onTriggered: panel.launch(appMenu.entry, modelData.id)
            }
            onObjectAdded: function (index, object) {
                appMenu.insertItem(index + 1, object);
            }
            onObjectRemoved: function (index, object) {
                appMenu.removeItem(object);
            }
        }
        MenuSeparator {
            contentItem: Rectangle {
                implicitHeight: 1
                color: Color.muted
            }
        }
        ActionMenuItem {
            text: "Move to group…"
            onTriggered: {
                panel.movingId = Folders.key(appMenu.entry);
                keyboard.forceActiveFocus();
            }
        }
        ActionMenuItem {
            visible: !!appMenu.entry && appMenu.entry.kind === "command"
            height: visible ? implicitHeight : 0
            text: "Edit command"
            onTriggered: panel.editCommand(appMenu.entry, panel.pinFolder(Folders.key(appMenu.entry)))
        }
        ActionMenuItem {
            visible: !!appMenu.entry && appMenu.entry.kind === "location"
            height: visible ? implicitHeight : 0
            text: "Rename shortcut"
            onTriggered: panel.editShortcut(appMenu.entry)
        }
        ActionMenuItem {
            text: "Unpin"
            onTriggered: {
                var id = Folders.key(appMenu.entry);
                panel.save(panel.pins.filter(function (pin) {
                    return Folders.key(pin) !== id;
                }));
            }
        }
    }
    Menu {
        id: folderMenu
        property var entry: null
        popupType: Popup.Item
        width: Style.space(240)
        background: Rectangle {
            color: Color.background
            border.color: Color.accent
            border.width: 1
        }
        ActionMenuItem {
            text: "Add app"
            onTriggered: panel.addApp(folderMenu.entry.id)
        }
        ActionMenuItem {
            text: "Add folder"
            onTriggered: panel.addLocation(folderMenu.entry.id)
        }
        ActionMenuItem {
            text: "Add command"
            onTriggered: panel.editCommand(null, folderMenu.entry.id)
        }
        ActionMenuItem {
            text: "Rename group"
            onTriggered: panel.editFolder(folderMenu.entry.id)
        }
        ActionMenuItem {
            text: "Delete group and its pins"
            onTriggered: {
                var next = Folders.remove(panel.pins, panel.folders, folderMenu.entry.id);
                panel.save(next.pins, next.folders);
            }
        }
    }
}
