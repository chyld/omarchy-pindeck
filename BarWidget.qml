import QtQuick
import qs.Ui
import qs.Commons
import "ui"
import "ui/components"

BarWidget {
    id: root
    readonly property var backend: bar && bar.shell ? bar.shell.serviceFor("chyld.pindeck") : null
    moduleName: "chyld.pindeck"
    readonly property bool opened: popup.opened
    readonly property bool popoutSwitchClosing: popup.popoutSwitchClosing
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function open() {
        popup.open();
    }
    function close() {
        popup.close();
    }
    function toggle() {
        popup.toggle();
    }
    function closeForPopoutSwitch() {
        popup.closeForPopoutSwitch();
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        hasVisualContent: true
        labelVisible: false
        implicitWidth: vertical ? barSize : deckIcon.implicitWidth + scaledHorizontalMargin * 2
        implicitHeight: vertical ? deckIcon.implicitHeight + scaledVerticalPadding * 2 : barSize
        tooltipText: "PinDeck"
        DeckIcon {
            id: deckIcon
            anchors.centerIn: parent
            width: implicitWidth
            height: implicitHeight
            outline: root.opened || button.tooltipHovered ? Color.accent : button.foreground
        }
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.LeftButton)
                root.toggle();
        }
    }
    PinPanel {
        id: popup
        service: root.backend
        bar: root.bar
        settings: root.settings
        anchorItem: button
        hostWidget: root
    }
}
