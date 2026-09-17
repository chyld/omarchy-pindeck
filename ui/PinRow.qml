pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "components"
import "../domain/Folders.js" as Folders
import "../domain/Launch.js" as Launch

Rectangle {
    id: row
    required property var panel
    required property var list
    function requestIcon() {
        if (panel.service)
            panel.service.requestIcon(modelData.icon || "");
    }
    Component.onCompleted: requestIcon()
    onModelDataChanged: requestIcon()
    required property var modelData
    required property int index
    width: list.width
    PinToolTip {
        visible: panel.opened && mouse.containsMouse && (row.modelData.kind === "location" || row.modelData.kind === "command") && !panel.draggedEntry
        text: row.modelData.commandText || row.modelData.path || ""
        maximumWidth: row.width
    }
    readonly property var appActions: modelData.kind !== "location" && modelData.kind !== "command" && !modelData.folder && !panel.movingId && !panel.picking && !modelData.missing ? modelData.actions || [] : []
    height: Math.max(Style.space(32), actionButtons.implicitHeight + Style.space(8))
    readonly property bool dropTarget: !!panel.dropEntry && Folders.key(panel.dropEntry) === Folders.key(modelData) && !!panel.dropEntry.folder === !!modelData.folder
    opacity: panel.draggedEntry && Folders.key(panel.draggedEntry) === Folders.key(modelData) && !!panel.draggedEntry.folder === !!modelData.folder ? 0.45 : 1
    border.width: dropTarget && panel.dropZone === "inside" ? 2 : 0
    border.color: Color.accent
    Rectangle {
        z: 5
        visible: row.dropTarget && (panel.dropZone === "before" || panel.dropZone === "after")
        width: parent.width
        height: 2
        y: panel.dropZone === "after" ? parent.height - height : 0
        color: Color.accent
    }
    radius: Style.space(5)
    color: (panel.keyboardNavigation ? ListView.isCurrentItem : rowHover.hovered) ? Qt.alpha(Color.accent, 0.16) : "transparent"
    HoverHandler {
        id: rowHover
        onHoveredChanged: {
            if (hovered && !panel.draggedEntry) {
                panel.keyboardNavigation = false;
                list.currentIndex = row.index;
            }
        }
    }
    Image {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Style.space(!panel.picking && !row.modelData.folder && panel.pinFolder(Folders.key(row.modelData)) ? 26 : 10)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        height: width
        source: row.modelData.folder ? "" : (panel.service && panel.service.iconCache[row.modelData.icon]) || panel.iconSource(row.modelData.icon)
        sourceSize.width: Style.space(44)
        sourceSize.height: Style.space(44)
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
        textFormat: Text.PlainText
        anchors.left: icon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: actionButtons.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: (row.modelData.folder && !panel.movingId ? (row.modelData.expanded === false ? "▸ " : "▾ ") : "") + row.modelData.name + (row.modelData.folder && !panel.movingId ? " (" + row.modelData.count + ")" : "") + (row.modelData.missing ? " (unavailable)" : "")
        elide: Text.ElideRight
        color: panel.barForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: action.width + openGroup.width + actionButtons.width
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: panel.draggedEntry ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: !panel.picking && !panel.movingId && !panel.naming
        property real pressX: 0
        property real pressY: 0
        property bool didDrag: false
        onPressed: function (event) {
            pressX = event.x;
            pressY = event.y;
            didDrag = false;
        }
        onPositionChanged: function (event) {
            if (!pressedButtons) {
                panel.keyboardNavigation = false;
                list.currentIndex = row.index;
            }
            if (!(pressedButtons & Qt.LeftButton) || panel.picking || panel.movingId || panel.naming)
                return;
            if (!didDrag && Math.hypot(event.x - pressX, event.y - pressY) >= Style.space(8)) {
                didDrag = true;
                panel.draggedEntry = row.modelData;
            }
            if (panel.draggedEntry) {
                var point = mapToItem(list, event.x, event.y);
                panel.updateDrop(point.x, point.y);
            }
        }
        onReleased: {
            if (didDrag)
                panel.finishDrag();
        }
        onCanceled: panel.cancelDrag()
        onClicked: function (event) {
            if (didDrag)
                return;
            if (event.button === Qt.RightButton) {
                list.currentIndex = row.index;
                panel.showActions(row.modelData, row, event.x, event.y);
            } else
                panel.activate(row.modelData);
        }
    }
    Flow {
        id: actionButtons
        visible: row.appActions.length > 0
        anchors.right: openGroup.left
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Math.min(parent.width / 2, row.appActions.length * Style.space(21) + (row.appActions.length - 1) * spacing) : 0
        spacing: Style.space(5)
        Repeater {
            model: row.appActions
            delegate: TinyActionButton {
                required property var modelData
                required property int index
                actionName: modelData.name || modelData.id
                actionNumber: index + 1
                onClicked: panel.launch(row.modelData, modelData.id)
            }
        }
    }
    Button {
        id: openGroup
        visible: !!row.modelData.folder && !panel.movingId && !panel.picking
        anchors.right: action.left
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Style.space(28) : 0
        height: Style.space(26)
        iconText: "⚡"
        enabled: visible && Launch.groupEntries(panel.pins, panel.applications, row.modelData.id).length > 0
        Accessible.name: "Open everything in " + row.modelData.name
        PinToolTip {
            visible: panel.opened && openGroup.hot && openGroup.visible && !panel.draggedEntry
            text: "Open everything in “" + row.modelData.name + "”"
        }
        onClicked: panel.launchGroup(row.modelData.id)
    }
    Button {
        id: action
        visible: panel.picking || !!panel.movingId
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Style.space(48) : 0
        height: Style.space(26)
        text: panel.movingId ? "Move" : (panel.isPinned(row.modelData.id) ? "✓" : "Pin")
        foreground: Color.accent
        accent: foreground
        background: Qt.alpha(foreground, 0.14)
        radius: Style.space(4)
        enabled: true
        Accessible.name: panel.movingId ? "Move to " + row.modelData.name : "Pin " + row.modelData.name
        PinToolTip {
            visible: panel.opened && action.hot && action.visible
            text: panel.movingId ? "Move here" : (panel.isPinned(row.modelData.id) ? "Pinned in " + panel.folderName(panel.targetFolder) + " · Click to reveal" : "Pin app")
        }
        onClicked: panel.activate(row.modelData)
    }
}
