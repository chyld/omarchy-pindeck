pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../domain/Search.js" as Search
import "../domain/Launch.js" as Launch
import "../domain/Folders.js" as Folders
import "../domain/Config.js" as Config

Panel {
    id: root
    moduleName: "chyld.pindeck"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property bool picking: false
    property bool keyboardNavigation: false
    property string errorMessage: ""
    property var service: null
    property var list: null
    property var keyboard: null
    property var search: null
    property var folderInput: null
    property var commandName: null
    property var commandText: null
    property var appMenu: null
    property var folderMenu: null
    property var dragFooter: null
    readonly property var configData: service ? service.configData : ({
            version: 1,
            pinnedApps: [],
            folders: [],
            rootOrder: []
        })
    readonly property bool configReady: !!service && service.ready
    readonly property string configError: service ? service.error : "Loading PinDeck…"
    readonly property var pins: configData.pinnedApps
    readonly property var applications: DesktopEntries.applications.values.slice(0, 5000)
    readonly property var folders: configData.folders
    readonly property var ordering: configData.rootOrder
    readonly property var configuredHiddenIds: service ? service.configuredHiddenIds : ({})
    readonly property var desktopHiddenIds: service ? service.hiddenIds : ({})
    readonly property string visibilityError: service ? service.visibilityError : ""
    readonly property bool visibilityReady: !!service && service.visibilityReady
    onServiceChanged: initializeService()
    Component.onCompleted: initializeService()
    function initializeService() {
        if (service)
            service.initialize({
                version: 1,
                pinnedApps: setting("pinnedApps", []),
                folders: setting("folders", []),
                rootOrder: setting("rootOrder", [])
            });
    }
    property var draggedEntry: null
    property var dropEntry: null
    property string dropZone: ""
    property real dragY: 0
    property real dragX: 0
    function cancelDrag() {
        draggedEntry = null;
        dropEntry = null;
        dropZone = "";
    }
    function updateDrop(x, y) {
        dragX = x;
        dragY = y;
        dropEntry = null;
        dropZone = "";
        if (!draggedEntry || x < 0 || x > list.width)
            return;
        var footerPoint = list.mapToItem(dragFooter, x, y);
        if (footerPoint.y >= 0 && footerPoint.y <= dragFooter.height) {
            dropZone = "end";
            return;
        }
        if (y < 0 || y > list.height)
            return;
        var index = list.indexAt(x, y + list.contentY);
        if (index < 0) {
            dropZone = "end";
            return;
        }
        var item = list.itemAtIndex(index);
        if (!item)
            return;
        dropEntry = rows[index];
        var fraction = (y + list.contentY - item.y) / item.height;
        dropZone = dropEntry.folder && !draggedEntry.folder && fraction > 0.25 && fraction < 0.75 ? "inside" : fraction < 0.5 ? "before" : "after";
    }
    function finishDrag() {
        if (!draggedEntry)
            return;
        var next = dropZone ? Folders.drop(pins, folders, ordering, draggedEntry, dropEntry, dropZone) : null;
        if (dropZone && !next)
            errorMessage = "Cannot move here: duplicate pins or nested groups are not allowed.";
        cancelDrag();
        if (next)
            save(next.pins, next.folders, next.order);
    }
    property string targetFolder: ""
    property string movingId: ""
    property bool naming: false
    property string editingFolder: ""
    property string editingShortcut: ""
    property bool commandEditing: false
    property string editingCommand: ""
    property string commandGroup: ""
    property string editingRevision: ""
    function editCommand(entry, groupId) {
        editingRevision = service ? service.revision : "";
        commandEditing = true;
        editingCommand = entry ? Folders.key(entry) : "";
        commandGroup = groupId || "";
        naming = false;
        picking = false;
        movingId = "";
        errorMessage = "";
        commandName.text = entry ? entry.name : "";
        commandText.text = entry ? entry.commandText : "";
        Qt.callLater(function () {
            commandName.forceActiveFocus();
        });
    }
    function saveCommand() {
        if (service && editingRevision !== service.revision) {
            errorMessage = "Configuration changed while editing. Reopen the editor and try again.";
            return;
        }
        var name = commandName.text.trim(), value = commandText.text.trim();
        if (!name || !value) {
            errorMessage = "Enter a name and a command.";
            return;
        }
        var next;
        var id = editingCommand || "command-" + Date.now() + "-" + Math.random().toString(36).slice(2);
        if (editingCommand)
            next = pins.map(function (pin) {
                return Folders.key(pin) === editingCommand ? Object.assign({}, pin, {
                    name: name,
                    commandText: value
                }) : pin;
            });
        else
            next = pins.concat([
                {
                    id: id,
                    pinId: id,
                    kind: "command",
                    name: name,
                    commandText: value,
                    icon: "utilities-terminal",
                    runInTerminal: true,
                    folderId: commandGroup
                }
            ]);
        if (save(next)) {
            commandEditing = false;
            errorMessage = "";
            reveal(id);
        }
    }
    property string locationTarget: ""
    property int locationRequest: -1
    function addLocation(groupId) {
        if (!service || service.helperBusy) {
            errorMessage = "Please wait for the folder operation.";
            return;
        }
        locationTarget = groupId || "";
        locationRequest = service.requestHelper("choose", {});
        if (locationRequest >= 0)
            close();
    }
    Connections {
        target: root.service
        function onHelperCompleted(id, response) {
            if (id !== root.locationRequest)
                return;
            root.locationRequest = -1;
            root.open();
            var result = response.result || {};
            if (result.cancelled)
                return;
            if (!response.ok || result.error || !result.path) {
                root.errorMessage = response.error || result.error || "Could not choose folder.";
                return;
            }
            var groupId = root.folders.some(function (f) {
                return f.id === root.locationTarget;
            }) ? root.locationTarget : "";
            var existing = root.pins.find(function (p) {
                return p.kind === "location" && p.path === result.path && (p.folderId || "") === groupId;
            });
            if (existing) {
                root.reveal(Folders.key(existing));
                return;
            }
            var pinId = "pin-" + Date.now() + "-" + Math.random().toString(36).slice(2);
            if (root.save(root.pins.concat([
                {
                    id: "location:" + result.path,
                    pinId: pinId,
                    kind: "location",
                    path: result.path,
                    name: result.name,
                    icon: "folder",
                    folderId: groupId
                }
            ])))
                root.reveal(pinId);
        }
        function onLaunchFailed(owner, message) {
            if (owner === root) {
                root.errorMessage = message;
                root.controller.show();
            }
        }
    }
    Component.onDestruction: if (service && locationRequest >= 0)
        service.cancelHelper(locationRequest)
    function editShortcut(entry) {
        editingRevision = service ? service.revision : "";
        editingShortcut = Folders.key(entry);
        editingFolder = "";
        folderInput.text = entry.name;
        naming = true;
        Qt.callLater(function () {
            folderInput.forceActiveFocus();
            folderInput.selectAll();
        });
    }
    readonly property var rows: movingId ? [
        {
            id: "",
            name: "Top level",
            folder: true
        }
    ].concat(folders.map(function (f) {
        return {
            id: f.id,
            name: f.name,
            folder: true
        };
    })) : picking ? (visibilityReady ? Search.search(applications, search.text, configuredHiddenIds, desktopHiddenIds) : []) : Folders.rows(pins, folders, applications, ordering)

    function folderName(id) {
        var folder = folders.find(function (f) {
            return f.id === id;
        });
        return folder ? folder.name : "Top level";
    }
    function pinFolder(id) {
        var pin = pins.find(function (p) {
            return Folders.key(p) === id;
        });
        return pin ? pin.folderId || "" : "";
    }
    function reveal(id) {
        var folderId = pinFolder(id);
        if (folders.some(function (f) {
            return f.id === folderId && f.expanded === false;
        }) && !save(pins, folders.map(function (f) {
            return f.id === folderId ? Object.assign({}, f, {
                expanded: true
            }) : f;
        })))
            return;
        picking = false;
        Qt.callLater(function () {
            list.currentIndex = rows.findIndex(function (r) {
                return !r.folder && Folders.key(r) === id;
            });
            list.positionViewAtIndex(list.currentIndex, ListView.Contain);
            keyboard.forceActiveFocus();
        });
    }
    function toggleFolder(id) {
        if (save(pins, folders.map(function (f) {
            return f.id === id ? Object.assign({}, f, {
                expanded: f.expanded === false
            }) : f;
        }))) {
            list.currentIndex = rows.findIndex(function (r) {
                return r.folder && r.id === id;
            });
        }
    }
    function editFolder(id) {
        editingRevision = service ? service.revision : "";
        editingShortcut = "";
        editingFolder = id;
        folderInput.text = id ? folderName(id) : "";
        naming = true;
        Qt.callLater(function () {
            folderInput.forceActiveFocus();
            folderInput.selectAll();
        });
    }
    function submitFolder() {
        if (service && editingRevision !== service.revision) {
            errorMessage = "Configuration changed while editing. Reopen the editor and try again.";
            return;
        }
        var name = folderInput.text.trim();
        if (!name) {
            errorMessage = "Enter a name.";
            return;
        }
        if (editingShortcut) {
            if (save(pins.map(function (pin) {
                return Folders.key(pin) === editingShortcut ? Object.assign({}, pin, {
                    name: name
                }) : pin;
            }))) {
                naming = false;
                errorMessage = "";
                keyboard.forceActiveFocus();
            }
            return;
        }
        if (folders.some(function (f) {
            return f.id !== editingFolder && f.name.toLowerCase() === name.toLowerCase();
        })) {
            errorMessage = "A group with that name already exists.";
            return;
        }
        var next = editingFolder ? folders.map(function (f) {
            return f.id === editingFolder ? Object.assign({}, f, {
                name: name
            }) : f;
        }) : folders.concat([
            {
                id: "folder-" + Date.now() + "-" + Math.random().toString(36).slice(2),
                name: name,
                expanded: true
            }
        ]);
        if (save(pins, next)) {
            naming = false;
            errorMessage = "";
            keyboard.forceActiveFocus();
        }
    }

    function open() {
        keyboardNavigation = false;
        commandEditing = false;
        picking = false;
        movingId = "";
        naming = false;
        errorMessage = "";
        controller.show();
        list.currentIndex = 0;
    }
    function close() {
        cancelDrag();
        appMenu.close();
        folderMenu.close();
        controller.hide();
    }
    function isPinned(id) {
        return pins.some(function (pin) {
            return pin.id === id && (pin.folderId || "") === targetFolder;
        });
    }
    function save(next, nextFolders, nextOrder) {
        var targetFolders = nextFolders === undefined ? folders : nextFolders;
        targetFolders = targetFolders.map(function (folder) {
            var gained = next.some(function (pin) {
                return pin.folderId === folder.id && !pins.some(function (old) {
                    return Folders.key(old) === Folders.key(pin) && old.folderId === folder.id;
                });
            });
            return gained ? Object.assign({}, folder, {
                expanded: true
            }) : folder;
        });
        var targetOrder = Folders.rootOrder(next, targetFolders, nextOrder === undefined ? ordering : nextOrder);
        if (JSON.stringify(targetOrder) === JSON.stringify(ordering) && JSON.stringify(next) === JSON.stringify(pins) && JSON.stringify(targetFolders) === JSON.stringify(folders))
            return true;
        if (!configReady || configError) {
            errorMessage = "Fix pindeck.json before saving changes.";
            return false;
        }
        var entry = Object.assign(Object.create(null), configData, {
            version: 1,
            pinnedApps: next,
            folders: targetFolders,
            rootOrder: targetOrder
        });
        try {
            Config.parse(JSON.stringify(entry));
        } catch (error) {
            errorMessage = String(error);
            return false;
        }
        if (!service.save(entry)) {
            errorMessage = "Configuration is busy. Try again.";
            return false;
        }
        return true;
    }
    function addApp(folderId) {
        targetFolder = folderId || "";
        naming = false;
        movingId = "";
        if (service)
            service.refreshVisibility();
        picking = true;
        search.text = "";
        list.currentIndex = 0;
        Qt.callLater(function () {
            search.forceActiveFocus();
        });
    }
    function activate(entry) {
        if (!entry)
            return;
        errorMessage = "";
        if (movingId) {
            var next = Folders.move(pins, movingId, entry.id);
            if (!next) {
                errorMessage = "This item is already pinned in that group.";
                return;
            }
            if (!save(next))
                return;
            var moved = movingId;
            movingId = "";
            reveal(moved);
        } else if (entry.folder) {
            toggleFolder(entry.id);
        } else if (picking) {
            var existing = pins.find(function (pin) {
                return pin.id === entry.id && (pin.folderId || "") === targetFolder;
            });
            if (existing) {
                reveal(Folders.key(existing));
                return;
            }
            var pinId = "pin-" + Date.now() + "-" + Math.random().toString(36).slice(2);
            if (!save(pins.concat([
                {
                    id: entry.id,
                    pinId: pinId,
                    name: entry.name,
                    icon: entry.icon,
                    folderId: targetFolder
                }
            ])))
                return;
            reveal(pinId);
        } else {
            launch(entry, "");
        }
    }
    function launchGroup(groupId) {
        var entries = Launch.groupEntries(pins, applications, groupId);
        if (!service || !service.launch(entries, "", root)) {
            errorMessage = "Nothing to launch, or a launch is already in progress.";
            return;
        }
        close();
    }
    function launch(entry, actionId) {
        if (!entry || entry.missing) {
            errorMessage = "This app is no longer installed.";
            return;
        }
        if (!service || !service.launch([entry], actionId, root)) {
            errorMessage = "Please wait for the current operation.";
            return;
        }
        close();
    }
    function showActions(entry, item, x, y) {
        if (picking || movingId || naming)
            return;
        if (entry.folder) {
            folderMenu.entry = entry;
            folderMenu.popup(item, x, y);
            return;
        }
        appMenu.entry = entry;
        appMenu.popup(item, x, y);
    }
    function move(delta) {
        keyboardNavigation = true;
        list.currentIndex = Math.max(0, Math.min(rows.length - 1, list.currentIndex + delta));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function handleKey(event) {
        if (commandEditing) {
            if (event.key === Qt.Key_Escape) {
                commandEditing = false;
                errorMessage = "";
                keyboard.forceActiveFocus();
                event.accepted = true;
            }
            return;
        }
        if (draggedEntry) {
            if (event.key === Qt.Key_Escape)
                cancelDrag();
            event.accepted = true;
            return;
        }
        if (appMenu.opened || folderMenu.opened)
            return;
        if (naming) {
            if (event.key === Qt.Key_Escape) {
                naming = false;
                errorMessage = "";
                keyboard.forceActiveFocus();
                event.accepted = true;
            }
            return;
        }
        if (!picking && !movingId && event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
            editCommand(null, "");
            event.accepted = true;
            return;
        }
        if (!picking && !movingId && event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
            addLocation("");
            event.accepted = true;
            return;
        }
        if (!picking && !movingId && event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
            editFolder("");
            event.accepted = true;
            return;
        }
        if (!picking && (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)))) {
            if (list.currentItem)
                showActions(rows[list.currentIndex], list.currentItem, 20, list.currentItem.height);
        } else if (event.key === Qt.Key_Escape) {
            if (picking || movingId) {
                picking = false;
                movingId = "";
                keyboard.forceActiveFocus();
            } else
                close();
        } else if (event.key === Qt.Key_Down)
            move(1);
        else if (event.key === Qt.Key_Up)
            move(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!picking && !rows.length)
                addApp();
            else
                activate(rows[list.currentIndex]);
        } else
            return;
        event.accepted = true;
    }
    function iconSource(value) {
        // Desktop paths are not reopened in the shell; use theme icons only.
        if (!/^[A-Za-z0-9_.-]{1,128}$/.test(String(value || "")))
            value = "application-x-executable";
        return Quickshell.iconPath(value || "application-x-executable", "application-x-executable");
    }
    onRowsChanged: if (list)
        list.currentIndex = 0
    onOpenedChanged: {
        if (!opened)
            cancelDrag();
    }

    Timer {
        interval: 40
        repeat: true
        running: !!root.draggedEntry
        onTriggered: {
            if (root.dragX < 0 || root.dragX > list.width || root.dragY < 0 || root.dragY > list.height)
                return;
            var amount = root.dragY < Style.space(28) ? -Style.space(8) : root.dragY > list.height - Style.space(28) ? Style.space(8) : 0;
            if (amount) {
                list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + amount));
                root.updateDrop(root.dragX, root.dragY);
            }
        }
    }
}
