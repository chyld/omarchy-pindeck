pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Search.js" as Search
import "Launch.js" as Launch
import "Folders.js" as Folders
import "Config.js" as Config

Panel {
    id: root
    moduleName: "chyld.pindeck"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    property bool picking: false
    property string errorMessage: ""
    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    property var configuredHiddenIds: ({})
    property var desktopHiddenIds: ({})
    property bool visibilityReady: false
    readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/pinned.json"
    property var configData: ({version:1, pinnedApps:[], folders:[], rootOrder:[]})
    property bool configReady: false
    property string configError: ""
    readonly property var pins: configData.pinnedApps
    readonly property var applications: DesktopEntries.applications.values
    readonly property var folders: configData.folders
    readonly property var ordering: configData.rootOrder
    property var draggedEntry: null
    property var dropEntry: null
    property string dropZone: ""
    property real dragY: 0
    property real dragX: 0
    function cancelDrag() { draggedEntry = null; dropEntry = null; dropZone = "" }
    function updateDrop(x, y) {
        dragX = x; dragY = y
        dropEntry = null; dropZone = ""
        if (!draggedEntry || x < 0 || x > list.width) return
        var footerPoint = list.mapToItem(dragFooter, x, y)
        if (footerPoint.y >= 0 && footerPoint.y <= dragFooter.height) { dropZone = "end"; return }
        if (y < 0 || y > list.height) return
        var index = list.indexAt(x, y + list.contentY)
        if (index < 0) { dropZone = "end"; return }
        var item = list.itemAtIndex(index)
        if (!item) return
        dropEntry = rows[index]
        var fraction = (y + list.contentY - item.y) / item.height
        dropZone = dropEntry.folder && !draggedEntry.folder && fraction > 0.25 && fraction < 0.75 ? "inside" : fraction < 0.5 ? "before" : "after"
    }
    function finishDrag() {
        if (!draggedEntry) return
        var next = dropZone ? Folders.drop(pins, folders, ordering, draggedEntry, dropEntry, dropZone) : null
        if (dropZone && !next) errorMessage = "Cannot move here: duplicate pins or nested groups are not allowed."
        cancelDrag()
        if (next) save(next.pins, next.folders, next.order)
    }
    property string targetFolder: ""
    property string movingId: ""
    property bool naming: false
    property string editingFolder: ""
    property string editingShortcut: ""
    property bool commandEditing: false
    property string editingCommand: ""
    property string commandGroup: ""
    function editCommand(entry, groupId) {
        commandEditing = true
        editingCommand = entry ? Folders.key(entry) : ""
        commandGroup = groupId || ""
        naming = false; picking = false; movingId = ""; errorMessage = ""
        commandName.text = entry ? entry.name : ""
        commandText.text = entry ? entry.commandText : ""
        Qt.callLater(function() { commandName.forceActiveFocus() })
    }
    function saveCommand() {
        var name = commandName.text.trim(), value = commandText.text.trim()
        if (!name || !value) { errorMessage = "Enter a name and a command."; return }
        var next
        var id = editingCommand || "command-" + Date.now() + "-" + Math.random().toString(36).slice(2)
        if (editingCommand) next = pins.map(function(pin) { return Folders.key(pin) === editingCommand ? Object.assign({}, pin, {name:name, commandText:value}) : pin })
        else next = pins.concat([{id:id, pinId:id, kind:"command", name:name, commandText:value, icon:"utilities-terminal", runInTerminal:true, folderId:commandGroup}])
        if (save(next)) { commandEditing = false; errorMessage = ""; reveal(id) }
    }
    property string locationTarget: ""
    property string locationMode: ""
    property var locationResult: ({})
    function addLocation(groupId) {
        if (locationProcess.running) return
        locationTarget = groupId || ""
        locationMode = "choose"
        locationResult = ({})
        locationProcess.command = ["python3", decodeURIComponent(String(Qt.resolvedUrl("bin/locations.py")).replace(/^file:\/\//, "")), "choose"]
        close()
        locationProcess.running = true
    }
    function openLocation(entry) {
        if (locationProcess.running) return
        locationMode = "open"
        locationResult = ({})
        locationProcess.command = ["python3", decodeURIComponent(String(Qt.resolvedUrl("bin/locations.py")).replace(/^file:\/\//, "")), "check", entry.path]
        locationProcess.running = true
    }
    function editShortcut(entry) {
        editingShortcut = Folders.key(entry)
        editingFolder = ""
        folderInput.text = entry.name
        naming = true
        Qt.callLater(function() { folderInput.forceActiveFocus(); folderInput.selectAll() })
    }
    readonly property var rows: movingId ? [{id: "", name: "Top level", folder: true}].concat(folders.map(function(f) { return {id:f.id, name:f.name, folder:true} })) : picking ? (visibilityReady ? Search.search(applications, search.text, configuredHiddenIds, desktopHiddenIds) : []) : Folders.rows(pins, folders, applications, ordering)

    function folderName(id) {
        var folder = folders.find(function(f) { return f.id === id })
        return folder ? folder.name : "Top level"
    }
    function pinFolder(id) {
        var pin = pins.find(function(p) { return Folders.key(p) === id })
        return pin ? pin.folderId || "" : ""
    }
    function reveal(id) {
        var folderId = pinFolder(id)
        if (folders.some(function(f) { return f.id === folderId && f.expanded === false }) && !save(pins, folders.map(function(f) { return f.id === folderId ? Object.assign({}, f, {expanded:true}) : f }))) return
        picking = false
        Qt.callLater(function() {
            list.currentIndex = rows.findIndex(function(r) { return !r.folder && Folders.key(r) === id })
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)
            keyboard.forceActiveFocus()
        })
    }
    function toggleFolder(id) {
        if (save(pins, folders.map(function(f) { return f.id === id ? Object.assign({}, f, {expanded:f.expanded === false}) : f }))) {
            list.currentIndex = rows.findIndex(function(r) { return r.folder && r.id === id })
        }
    }
    function editFolder(id) {
        editingShortcut = ""
        editingFolder = id
        folderInput.text = id ? folderName(id) : ""
        naming = true
        Qt.callLater(function() { folderInput.forceActiveFocus(); folderInput.selectAll() })
    }
    function submitFolder() {
        var name = folderInput.text.trim()
        if (!name) { errorMessage = "Enter a name."; return }
        if (editingShortcut) {
            if (save(pins.map(function(pin) { return Folders.key(pin) === editingShortcut ? Object.assign({}, pin, {name:name}) : pin }))) {
                naming = false; errorMessage = ""; keyboard.forceActiveFocus()
            }
            return
        }
        if (folders.some(function(f) { return f.id !== editingFolder && f.name.toLowerCase() === name.toLowerCase() })) {
            errorMessage = "A group with that name already exists."; return
        }
        var next = editingFolder ? folders.map(function(f) { return f.id === editingFolder ? Object.assign({}, f, {name:name}) : f }) : folders.concat([{id:"folder-" + Date.now() + "-" + Math.random().toString(36).slice(2), name:name, expanded:true}])
        if (save(pins, next)) { naming = false; errorMessage = ""; keyboard.forceActiveFocus() }
    }

    function open() {
        commandEditing = false
        picking = false
        movingId = ""
        naming = false
        errorMessage = ""
        controller.show()
        list.currentIndex = 0
    }
    function close() { cancelDrag(); appMenu.close(); folderMenu.close(); controller.hide() }
    function isPinned(id) { return pins.some(function(pin) { return pin.id === id && (pin.folderId || "") === targetFolder }) }
    function save(next, nextFolders, nextOrder) {
        var targetFolders = nextFolders === undefined ? folders : nextFolders
        var targetOrder = Folders.rootOrder(next, targetFolders, nextOrder === undefined ? ordering : nextOrder)
        if (JSON.stringify(targetOrder) === JSON.stringify(ordering) && JSON.stringify(next) === JSON.stringify(pins) && JSON.stringify(targetFolders) === JSON.stringify(folders)) return true
        if (!configReady || configError) { errorMessage = "Fix pinned.json before saving changes."; return false }
        var entry = Object.assign({}, configData, {version:1, pinnedApps:next, folders:targetFolders, rootOrder:targetOrder})
        try { Config.parse(JSON.stringify(entry)) }
        catch (error) { errorMessage = String(error); return false }
        configData = entry
        pinnedFile.setText(JSON.stringify(entry, null, 2) + "\n")
        return true
    }
    function addApp(folderId) {
        targetFolder = folderId || ""
        naming = false
        movingId = ""
        visibilityReady = false
        visibilityRefresh.restart()
        picking = true
        search.text = ""
        list.currentIndex = 0
        Qt.callLater(function() { search.forceActiveFocus() })
    }
    function activate(entry) {
        if (!entry) return
        errorMessage = ""
        if (movingId) {
            var next = Folders.move(pins, movingId, entry.id)
            if (!next) { errorMessage = "This item is already pinned in that group."; return }
            if (!save(next)) return
            var moved = movingId
            movingId = ""
            reveal(moved)
        } else if (entry.folder) {
            toggleFolder(entry.id)
        } else if (picking) {
            var existing = pins.find(function(pin) { return pin.id === entry.id && (pin.folderId || "") === targetFolder })
            if (existing) { reveal(Folders.key(existing)); return }
            var pinId = "pin-" + Date.now() + "-" + Math.random().toString(36).slice(2)
            if (!save(pins.concat([{id:entry.id, pinId:pinId, name:entry.name, icon:entry.icon, folderId:targetFolder}]))) return
            reveal(pinId)
        } else {
            launch(entry, "")
        }
    }
    property var groupLocations: []
    function openNextGroupLocation() {
        if (!groupLocations.length) return
        var entry = groupLocations[0]
        groupLocations = groupLocations.slice(1)
        openLocation(entry)
        locationMode = "group"
    }
    function launchGroup(groupId) {
        var entries = Launch.groupEntries(pins, applications, groupId)
        if (!entries.length) { errorMessage = "This group has nothing to open."; return }
        if (locationProcess.running) { errorMessage = "Please wait for the folder operation to finish."; return }
        var apps = entries.filter(function(entry) { return entry.kind !== "location" })
        groupLocations = entries.filter(function(entry) { return entry.kind === "location" })
        if (apps.length && !groupLocations.length) launchFocus.begin(apps[apps.length - 1], false)
        close()
        apps.forEach(function(entry) { Util.execArgv(Launch.command(entry, "")) })
        openNextGroupLocation()
    }
    function launch(entry, actionId) {
        if (entry && entry.kind === "location") { openLocation(entry); return }
        if (!entry || entry.missing) { errorMessage = "This app is no longer installed. You can unpin it."; return }
        var command = Launch.command(entry, actionId)
        if (!command) { errorMessage = "This app action is no longer available."; return }
        // An action may open a new window or do background work. Never move
        // focus to an old window merely because the action was selected.
        launchFocus.begin(entry, !!actionId)
        close()
        // Match Omarchy's detached login-shell launch environment while keeping
        // desktop IDs and action IDs as literal argv values.
        Util.execArgv(command)
    }
    function showActions(entry, item, x, y) {
        if (picking || movingId || naming) return
        if (entry.folder) { folderMenu.entry = entry; folderMenu.popup(item, x, y); return }
        appMenu.entry = entry
        appMenu.popup(item, x, y)
    }
    function move(delta) {
        list.currentIndex = Math.max(0, Math.min(rows.length - 1, list.currentIndex + delta))
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }
    function handleKey(event) {
        if (commandEditing) {
            if (event.key === Qt.Key_Escape) { commandEditing = false; errorMessage = ""; keyboard.forceActiveFocus(); event.accepted = true }
            return
        }
        if (draggedEntry) {
            if (event.key === Qt.Key_Escape) cancelDrag()
            event.accepted = true
            return
        }
        if (appMenu.opened || folderMenu.opened) return
        if (naming) {
            if (event.key === Qt.Key_Escape) { naming = false; errorMessage = ""; keyboard.forceActiveFocus(); event.accepted = true }
            return
        }
        if (!picking && !movingId && event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
            editCommand(null, ""); event.accepted = true; return
        }
        if (!picking && !movingId && event.key === Qt.Key_O && (event.modifiers & Qt.ControlModifier)) {
            addLocation(""); event.accepted = true; return
        }
        if (!picking && !movingId && event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
            editFolder("")
            event.accepted = true
            return
        }
        if (!picking && (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)))) {
            if (list.currentItem) showActions(rows[list.currentIndex], list.currentItem, 20, list.currentItem.height)
        } else if (event.key === Qt.Key_Escape) {
            if (picking || movingId) { picking = false; movingId = ""; keyboard.forceActiveFocus() } else close()
        } else if (event.key === Qt.Key_Down) move(1)
        else if (event.key === Qt.Key_Up) move(-1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!picking && !rows.length) addApp()
            else activate(rows[list.currentIndex])
        } else return
        event.accepted = true
    }
    function iconSource(value) {
        if (String(value || "").charAt(0) === "/") return "file://" + value
        return Quickshell.iconPath(value || "application-x-executable", "application-x-executable")
    }
    onRowsChanged: list.currentIndex = 0
    onOpenedChanged: { if (!opened) cancelDrag() }

    FileView {
        id: pinnedFile
        path: root.configPath
        preload: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var parsed = Config.parse(text())
                if (JSON.stringify(parsed) !== JSON.stringify(root.configData)) root.configData = parsed
                root.configReady = true
                root.configError = ""
            } catch (error) {
                root.configError = "pinned.json: " + String(error)
            }
        }
        onFileChanged: reload()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound && !root.configReady) {
                // First use: preserve legacy inline widget data.
                root.configData = {version:1, pinnedApps:root.setting("pinnedApps", []), folders:root.setting("folders", []), rootOrder:root.setting("rootOrder", [])}
                setText(JSON.stringify(root.configData, null, 2) + "\n")
            } else root.configError = "Cannot read pinned.json. Restore the file or check its permissions."
        }
        onSaved: { root.configReady = true; root.configError = "" }
        onSaveFailed: root.configError = "Could not save pinned.json. Check its permissions."
    }

    // Use the same exclusion file and desktop visibility scanner as Omarchy's
    // AppLibrary. Keep this filtering in the picker, so existing pins survive.
    FileView {
        id: launcherHides
        path: root.omarchyPath + "/default/omarchy/launcher.hides"
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: root.configuredHiddenIds = Search.hiddenIds(text())
        onFileChanged: reload()
        onLoadFailed: root.configuredHiddenIds = ({})
    }
    Timer {
        id: visibilityRefresh
        interval: 100
        onTriggered: {
            if (visibilityScan.running) restart()
            else visibilityScan.running = true
        }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { visibilityRefresh.restart() }
    }
    Process {
        id: visibilityScan
        command: [root.omarchyPath + "/shell/services/hidden-entries.sh",
            [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"),
                Quickshell.env("DESKTOP_SESSION")].filter(function(value) { return !!value }).join(":")]
        stdout: StdioCollector {
            onStreamFinished: root.desktopHiddenIds = Search.hiddenIds(text)
        }
        onExited: function(code) {
            // Omarchy's scanner returns 1 when its optional final Nix directory
            // is absent, even after successfully producing the hidden IDs.
            root.visibilityReady = code === 0 || code === 1
            if (!root.visibilityReady) root.errorMessage = "Could not load the app visibility rules. Reopen Add app to retry."
        }
    }

    Process {
        id: locationProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.locationResult = JSON.parse(text) }
                catch (error) { root.locationResult = {error:"Could not read the folder selection."} }
            }
        }
        onExited: function(code) {
            var result = root.locationResult
            if (root.locationMode === "group") {
                if (code === 0 && result.path && !result.error) {
                    if (!root.groupLocations.length) {
                        var managerId = String(result.desktopId || "").replace(/\.desktop$/, "")
                        var manager = root.applications.find(function(a) { return a.id === managerId })
                        if (manager) launchFocus.begin(manager, false)
                    }
                    Util.execArgv(["xdg-open", result.uri])
                } else Util.execArgv(["notify-send", "PinDeck", result.error || "Could not open folder."])
                Qt.callLater(function() { root.openNextGroupLocation() })
                return
            }
            if (root.locationMode === "choose") root.open()
            if (result.cancelled) return
            if (code !== 0 || result.error || !result.path) {
                root.errorMessage = result.error || "Could not open the folder chooser."
                return
            }
            if (root.locationMode === "choose") {
                var groupId = root.folders.some(function(f) { return f.id === root.locationTarget }) ? root.locationTarget : ""
                var existing = root.pins.find(function(pin) { return pin.kind === "location" && pin.path === result.path && (pin.folderId || "") === groupId })
                if (existing) { root.reveal(Folders.key(existing)); return }
                var id = "location:" + result.path
                var pinId = "pin-" + Date.now() + "-" + Math.random().toString(36).slice(2)
                if (root.save(root.pins.concat([{id:id, pinId:pinId, kind:"location", path:result.path, name:result.name, icon:"folder", folderId:groupId}]))) root.reveal(pinId)
            } else {
                var desktopId = String(result.desktopId || "").replace(/\.desktop$/, "")
                var app = root.applications.find(function(a) { return a.id === desktopId })
                if (app) launchFocus.begin(app, false)
                root.close()
                Util.execArgv(["xdg-open", result.uri])
            }
        }
    }

    LaunchFocus { id: launchFocus }
    Timer {
        interval: 40
        repeat: true
        running: !!root.draggedEntry
        onTriggered: {
            if (root.dragX < 0 || root.dragX > list.width || root.dragY < 0 || root.dragY > list.height) return
            var amount = root.dragY < Style.space(28) ? -Style.space(8) : root.dragY > list.height - Style.space(28) ? Style.space(8) : 0
            if (amount) {
                list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + amount))
                root.updateDrop(root.dragX, root.dragY)
            }
        }
    }

    KeyboardPanel {
        id: popup
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyboard
        padding: Style.space(10)
        contentWidth: popup.fittedContentWidth(Style.space(360))
        contentHeight: popup.fittedContentHeight(content.implicitHeight)

        Item {
            id: keyboard
            anchors.fill: parent
            focus: true
            Keys.onPressed: function(event) { root.handleKey(event) }
            Menu {
                id: appMenu
                property var entry: null
                popupType: Popup.Item
                width: Style.space(280)
                font.family: Style.font.family
                palette.window: Color.background
                palette.windowText: root.barForeground
                palette.text: root.barForeground
                palette.highlight: Color.accent
                background: Rectangle {
                    color: Color.background
                    border.color: Color.accent
                    border.width: 1
                }
                ActionMenuItem {
                    text: "Open"
                    enabled: !!appMenu.entry && !appMenu.entry.missing
                    onTriggered: root.launch(appMenu.entry, "")
                }
                Instantiator {
                    model: appMenu.entry && !appMenu.entry.missing ? appMenu.entry.actions || [] : []
                    delegate: ActionMenuItem {
                        required property var modelData
                        text: modelData.name || modelData.id
                        onTriggered: root.launch(appMenu.entry, modelData.id)
                    }
                    onObjectAdded: function(index, object) { appMenu.insertItem(index + 1, object) }
                    onObjectRemoved: function(index, object) { appMenu.removeItem(object) }
                }
                MenuSeparator {
                    contentItem: Rectangle { implicitHeight: 1; color: Color.muted }
                }
                ActionMenuItem {
                    text: "Move to group…"
                    onTriggered: { root.movingId = Folders.key(appMenu.entry); keyboard.forceActiveFocus() }
                }
                ActionMenuItem {
                    visible: !!appMenu.entry && appMenu.entry.kind === "command"
                    height: visible ? implicitHeight : 0
                    text: "Edit command"
                    onTriggered: root.editCommand(appMenu.entry, root.pinFolder(Folders.key(appMenu.entry)))
                }
                ActionMenuItem {
                    visible: !!appMenu.entry && appMenu.entry.kind === "location"
                    height: visible ? implicitHeight : 0
                    text: "Rename shortcut"
                    onTriggered: root.editShortcut(appMenu.entry)
                }
                ActionMenuItem {
                    text: "Unpin"
                    onTriggered: {
                        var id = Folders.key(appMenu.entry)
                        root.save(root.pins.filter(function(pin) { return Folders.key(pin) !== id }))
                    }
                }
            }
            Menu {
                id: folderMenu
                property var entry: null
                popupType: Popup.Item
                width: Style.space(240)
                background: Rectangle { color: Color.background; border.color: Color.accent; border.width: 1 }
                ActionMenuItem { text: "Add app"; onTriggered: root.addApp(folderMenu.entry.id) }
                ActionMenuItem { text: "Add folder"; onTriggered: root.addLocation(folderMenu.entry.id) }
                ActionMenuItem { text: "Add command"; onTriggered: root.editCommand(null, folderMenu.entry.id) }
                ActionMenuItem { text: "Rename group"; onTriggered: root.editFolder(folderMenu.entry.id) }
                ActionMenuItem {
                    text: "Delete group (keep pins)"
                    onTriggered: {
                        var next = Folders.remove(root.pins, root.folders, folderMenu.entry.id)
                        root.save(next.pins, next.folders)
                    }
                }
            }
            Column {
                id: content
                width: parent.width
                spacing: Style.space(5)
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - back.width
                        text: root.commandEditing ? (root.editingCommand ? "Edit command" : "Add command") : root.movingId ? "Move to group" : root.picking ? "Add app · " + root.folderName(root.targetFolder) : "PinDeck"
                        elide: Text.ElideRight
                        color: root.barForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                    }
                    Button {
                        id: back
                        height: Style.space(24)
                        visible: root.picking || !!root.movingId
                        text: "Back"
                        onClicked: { root.picking = false; root.movingId = ""; keyboard.forceActiveFocus() }
                    }
                }
                Row {
                    visible: root.naming
                    width: parent.width
                    spacing: Style.space(5)
                    TextField {
                        id: folderInput
                        width: parent.width - folderSave.width - folderCancel.width - 2 * parent.spacing
                        placeholderText: root.editingShortcut ? "Shortcut name" : root.editingFolder ? "Rename group" : "Group name"
                        color: root.barForeground
                        background: Rectangle { color: Color.background; border.color: Color.muted; radius: Style.space(5) }
                        Keys.onReturnPressed: function(event) { event.accepted = true; root.submitFolder() }
                        Keys.onEnterPressed: function(event) { event.accepted = true; root.submitFolder() }
                        Keys.onEscapePressed: { root.naming = false; root.errorMessage = ""; keyboard.forceActiveFocus() }
                    }
                    Button { id: folderSave; text: "Save"; onClicked: root.submitFolder() }
                    Button { id: folderCancel; text: "Cancel"; onClicked: { root.naming = false; root.errorMessage = ""; keyboard.forceActiveFocus() } }
                }
                Column {
                    visible: root.commandEditing
                    width: parent.width
                    spacing: Style.space(5)
                    TextField {
                        id: commandName
                        width: parent.width
                        placeholderText: "Name (e.g. List downloads)"
                        color: root.barForeground
                        background: Rectangle { color: Color.background; border.color: Color.muted; radius: Style.space(5) }
                        Keys.onReturnPressed: function(event) { event.accepted = true; commandText.forceActiveFocus() }
                    }
                    TextField {
                        id: commandText
                        width: parent.width
                        placeholderText: "eza -a -l ~/Downloads"
                        selectByMouse: true
                        color: root.barForeground
                        background: Rectangle { color: Color.background; border.color: Color.muted; radius: Style.space(5) }
                        Keys.onReturnPressed: function(event) { event.accepted = true; root.saveCommand() }
                        Keys.onEnterPressed: function(event) { event.accepted = true; root.saveCommand() }
                    }
                    Text {
                        width: parent.width
                        text: "Runs in Bash from your home folder. The terminal stays open until you press Enter."
                        wrapMode: Text.WordWrap
                        color: Color.muted
                        font.pixelSize: Style.font.body * 0.85
                    }
                    Row {
                        spacing: Style.space(5)
                        Button { text: "Save"; onClicked: root.saveCommand() }
                        Button { text: "Cancel"; onClicked: { root.commandEditing = false; root.errorMessage = ""; keyboard.forceActiveFocus() } }
                    }
                }
                TextField {
                    id: search
                    visible: root.picking
                    width: parent.width
                    placeholderText: "Search apps…"
                    selectByMouse: true
                    color: root.barForeground
                    font.family: Style.font.family
                    background: Rectangle { color: Color.background; radius: Style.space(5); border.color: Color.muted }
                    Keys.onPressed: function(event) { root.handleKey(event) }
                }
                ListView {
                    id: list
                    visible: !root.commandEditing
                    width: parent.width
                    height: visible ? Math.min(Style.space(320), contentHeight) : 0
                    clip: true
                    interactive: !root.draggedEntry
                    model: root.rows
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        ToolTip.visible: mouse.containsMouse && (modelData.kind === "location" || modelData.kind === "command") && !root.draggedEntry
                        ToolTip.text: modelData.commandText || modelData.path || ""
                        ToolTip.delay: 400
                        readonly property var appActions: modelData.kind !== "location" && !modelData.folder && !root.movingId && !root.picking && !modelData.missing ? modelData.actions || [] : []
                        height: row.appActions.length > 0 ? Math.max(Style.space(32), appName.implicitHeight + actionButtons.implicitHeight + Style.space(8)) : Style.space(32)
                        readonly property bool dropTarget: !!root.dropEntry && Folders.key(root.dropEntry) === Folders.key(modelData) && !!root.dropEntry.folder === !!modelData.folder
                        opacity: root.draggedEntry && Folders.key(root.draggedEntry) === Folders.key(modelData) && !!root.draggedEntry.folder === !!modelData.folder ? 0.45 : 1
                        border.width: dropTarget && root.dropZone === "inside" ? 2 : 0
                        border.color: Color.accent
                        Rectangle {
                            z: 5
                            visible: row.dropTarget && (root.dropZone === "before" || root.dropZone === "after")
                            width: parent.width
                            height: 2
                            y: root.dropZone === "after" ? parent.height - height : 0
                            color: Color.accent
                        }
                        radius: Style.space(5)
                        color: ListView.isCurrentItem || mouse.containsMouse ? Qt.alpha(Color.accent, 0.16) : "transparent"
                        Image {
                            id: icon
                            anchors.left: parent.left
                            anchors.leftMargin: Style.space(!root.picking && !row.modelData.folder && root.pinFolder(Folders.key(row.modelData)) ? 26 : 10)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Style.space(22)
                            height: width
                            source: row.modelData.folder ? "" : root.iconSource(row.modelData.icon)
                            fillMode: Image.PreserveAspectFit
                            // Groups use a theme-colored grid; filesystem shortcuts
                            // retain their conventional folder icon.
                            Repeater {
                                model: row.modelData.folder ? 4 : 0
                                delegate: Rectangle {
                                    required property int index
                                    x: Style.space(2 + (index % 2) * 10)
                                    y: Style.space(2 + Math.floor(index / 2) * 10)
                                    width: Style.space(8)
                                    height: width
                                    radius: Style.space(2)
                                    color: Color.accent
                                }
                            }
                        }
                        Text {
                            id: appName
                            anchors.left: icon.right
                            anchors.leftMargin: Style.space(10)
                            anchors.right: openGroup.left
                            y: row.appActions.length > 0 ? Style.space(3) : (parent.height - height) / 2
                            text: (row.modelData.folder && !root.movingId ? (row.modelData.expanded === false ? "▸ " : "▾ ") : "") + row.modelData.name + (row.modelData.folder && !root.movingId ? " (" + row.modelData.count + ")" : "") + (row.modelData.missing ? " (unavailable)" : "")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: root.barForeground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                        }
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            anchors.rightMargin: action.width + openGroup.width
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: root.draggedEntry ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            preventStealing: !root.picking && !root.movingId && !root.naming
                            property real pressX: 0
                            property real pressY: 0
                            property bool didDrag: false
                            onPressed: function(event) { pressX = event.x; pressY = event.y; didDrag = false }
                            onPositionChanged: function(event) {
                                if (!(pressedButtons & Qt.LeftButton) || root.picking || root.movingId || root.naming) return
                                if (!didDrag && Math.hypot(event.x - pressX, event.y - pressY) >= Style.space(8)) {
                                    didDrag = true
                                    root.draggedEntry = row.modelData
                                }
                                if (root.draggedEntry) {
                                    var point = mapToItem(list, event.x, event.y)
                                    root.updateDrop(point.x, point.y)
                                }
                            }
                            onReleased: { if (didDrag) root.finishDrag() }
                            onCanceled: root.cancelDrag()
                            onClicked: function(event) {
                                if (didDrag) return
                                if (event.button === Qt.RightButton) {
                                    list.currentIndex = row.index
                                    root.showActions(row.modelData, row, event.x, event.y)
                                } else root.activate(row.modelData)
                            }
                        }
                        Flow {
                            id: actionButtons
                            visible: row.appActions.length > 0
                            anchors.left: appName.left
                            anchors.right: action.left
                            anchors.rightMargin: Style.space(6)
                            y: appName.y + appName.height + Style.space(2)
                            spacing: Style.space(5)
                            Repeater {
                                model: row.appActions
                                delegate: TinyActionButton {
                                    required property var modelData
                                    required property int index
                                    actionName: modelData.name || modelData.id
                                    actionNumber: index + 1
                                    onClicked: root.launch(row.modelData, modelData.id)
                                }
                            }
                        }
                        Button {
                            id: openGroup
                            visible: !!row.modelData.folder && !root.movingId && !root.picking
                            anchors.right: action.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: visible ? Style.space(28) : 0
                            height: Style.space(26)
                            iconText: "󰑣"
                            enabled: visible && Launch.groupEntries(root.pins, root.applications, row.modelData.id).length > 0
                            Accessible.name: "Open everything in " + row.modelData.name
                            tooltipText: "Open everything in “" + row.modelData.name + "”"
                            onClicked: root.launchGroup(row.modelData.id)
                        }
                        Button {
                            id: action
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Style.space(48)
                            height: Style.space(26)
                            text: root.movingId ? "Move" : row.modelData.folder ? "+" : root.picking ? (root.isPinned(row.modelData.id) ? "✓" : "Pin") : "×"
                            enabled: true
                            Accessible.name: root.movingId ? "Move to " + row.modelData.name : row.modelData.folder ? "Add app to " + row.modelData.name : root.picking ? "Pin " + row.modelData.name : "Unpin " + row.modelData.name
                            ToolTip.visible: hovered
                            ToolTip.text: root.movingId ? "Move here" : row.modelData.folder ? "Add app to group" : root.picking ? (root.isPinned(row.modelData.id) ? "Pinned in " + root.folderName(root.targetFolder) + " · Click to reveal" : "Pin app") : "Unpin app"
                            onClicked: {
                                if (root.picking || root.movingId) root.activate(row.modelData)
                                else if (row.modelData.folder) root.addApp(row.modelData.id)
                                else root.save(root.pins.filter(function(pin) { return Folders.key(pin) !== Folders.key(row.modelData) }))
                            }
                        }
                    }
                }
                Text {
                    visible: !root.commandEditing && root.rows.length === 0
                    width: parent.width
                    text: root.picking ? (root.visibilityReady ? "No apps match your search." : "Loading apps…") : "Your favorites belong here. Add your first app."
                    wrapMode: Text.WordWrap
                    color: Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                }
                Text {
                    visible: root.errorMessage !== "" || root.configError !== ""
                    width: parent.width
                    text: root.configError || root.errorMessage
                    wrapMode: Text.WordWrap
                    color: Color.urgent
                    font.pixelSize: Style.font.body
                }
                Grid {
                    columns: 2
                    visible: !root.commandEditing && !root.picking && !root.movingId
                    width: parent.width
                    spacing: Style.space(5)
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        height: Style.space(28)
                        text: "+ Add app"
                        onClicked: root.addApp("")
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        height: Style.space(28)
                        text: "+ Add folder"
                        onClicked: root.addLocation("")
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        height: Style.space(28)
                        text: "+ Add command"
                        onClicked: root.editCommand(null, "")
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        height: Style.space(28)
                        text: "+ New group"
                        onClicked: root.editFolder("")
                    }
                }
                Button {
                    visible: !root.commandEditing && !root.picking && !root.movingId
                    width: parent.width
                    height: Style.space(28)
                    text: "Edit config"
                    tooltipText: root.configPath
                    onClicked: { root.close(); Util.execArgv(["omarchy", "launch", "editor", root.configPath]) }
                }
                Rectangle {
                    id: dragFooter
                    width: parent.width
                    height: Style.space(22)
                    color: root.draggedEntry ? Qt.alpha(Color.accent, 0.15) : "transparent"
                    border.width: root.dropZone === "end" ? 1 : 0
                    border.color: Color.accent
                    Text {
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
