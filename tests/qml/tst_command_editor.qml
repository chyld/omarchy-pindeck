import QtQuick
import QtTest
import "../../ui" as Ui

TestCase {
    id: test
    name: "CommandEditor"
    when: windowShown
    visible: true
    width: 400
    height: 300

    QtObject {
        id: fakePanel
        property bool commandEditing: true
        property string editingCommand: ""
        property string movingId: ""
        property bool picking: false
        property bool naming: false
        property string editingShortcut: ""
        property string editingFolder: ""
        property color barForeground: "white"
    }
    Component {
        id: editorFactory
        Ui.PinEditors { width: 360; panel: fakePanel; keyboard: test }
    }
    function test_checkbox_supports_mouse_and_keyboard() {
        var editor = createTemporaryObject(editorFactory, test)
        verify(editor)
        var checkbox = editor.commandTerminal
        verify(checkbox.visible)
        compare(checkbox.text, "Run in terminal")
        checkbox.checked = true
        mouseClick(checkbox, checkbox.width / 2, checkbox.height / 2)
        compare(checkbox.checked, false)
        checkbox.forceActiveFocus()
        keyClick(Qt.Key_Space)
        compare(checkbox.checked, true)
    }
}
