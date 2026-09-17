import QtQuick
import qs.Ui

BarWidget {
    id: root
    moduleName: "chyld.pindeck"
    readonly property bool opened: popup.opened
    readonly property bool popoutSwitchClosing: popup.popoutSwitchClosing
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function open() { popup.open() }
    function close() { popup.close() }
    function toggle() { popup.toggle() }
    function closeForPopoutSwitch() { popup.closeForPopoutSwitch() }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰐃"
        tooltipText: "PinDeck"
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.LeftButton) root.toggle()
        }
    }
    AppsPanel {
        id: popup
        bar: root.bar
        settings: root.settings
        anchorItem: button
        hostWidget: root
    }
}
