import QtQuick
import QtTest
import "../../ui" as Ui
import "../../ui/components" as Components

TestCase {
    id: test
    name: "PinDeckComponents"
    when: windowShown
    visible: true
    width: 400
    height: 200
    Item { id: fakeList; width: 360; property int currentIndex: -1 }
    QtObject {
        id: fakePanel
        property var service: null
        property bool opened: true
        property bool picking: false
        property bool keyboardNavigation: false
        property bool naming: false
        property string movingId: ""
        property var draggedEntry: null
        property var dropEntry: null
        property string dropZone: ""
        property color barForeground: "white"
        property var pins: []
        property var applications: []
        property int activations: 0
        property int launches: 0
        function pinFolder(id) { return "" }
        function iconSource(icon) { return "" }
        function isPinned(id) { return false }
        function folderName(id) { return "Top level" }
        function activate(entry) { activations++ }
        function launch(entry, action) { launches++ }
        function launchGroup(id) { launches++ }
        function showActions(entry, item, x, y) {}
        function cancelDrag() { draggedEntry = null }
        function updateDrop(x,y) {}
        function finishDrag() { draggedEntry = null }
    }
    Component { id: rowFactory; Ui.PinRow { panel: fakePanel; list: fakeList; index: 0 } }
    Component { id: tooltipFactory; Components.PinToolTip {} }
    function init() { fakePanel.activations=0; fakePanel.launches=0; fakePanel.picking=false; fakePanel.keyboardNavigation=false; fakePanel.draggedEntry=null; fakePanel.opened=true }
    function test_actions_are_right_aligned_and_do_not_launch_main_item() {
        var row=createTemporaryObject(rowFactory,test,{modelData:{id:"app",name:"App",actions:[{id:"a",name:"Action"},{id:"b",name:"Second"}]}})
        verify(row)
        wait(20)
        compare(row.height,32)
        mouseClick(row, 15, 16)
        compare(fakePanel.activations,1)
        mouseClick(row, 350, 16)
        compare(fakePanel.launches,1)
        compare(fakePanel.activations,1)
    }
    function test_no_remove_button_on_normal_pin() {
        var row=createTemporaryObject(rowFactory,test,{modelData:{id:"app",name:"App"}})
        mouseClick(row,350,16)
        compare(fakePanel.activations,1)
    }
    function test_hover_updates_selection_and_clears_keyboard_mode() {
        var row=createTemporaryObject(rowFactory,test,{modelData:{id:"app",name:"App"},index:3})
        mouseMove(test,390,190)
        fakePanel.keyboardNavigation=true
        mouseMove(row,30,16)
        tryCompare(fakeList,"currentIndex",3)
        compare(fakePanel.keyboardNavigation,false)
    }
    function test_tooltip_is_plain_and_wraps() {
        var tip=createTemporaryObject(tooltipFactory,test,{text:"<img src='https://invalid/'>"+"x".repeat(1000),maximumWidth:200})
        compare(tip.contentItem.textFormat,Text.PlainText)
        verify(tip.width<=200)
        compare(tip.contentItem.wrapMode,Text.WrapAnywhere)
        compare(tip.delay,500)
    }
    function test_terminal_indicator_data() {
        return [
            {tag: "terminal command", entry: {id:"cmd", name:"Command", kind:"command", runInTerminal:true}, shown:true},
            {tag: "legacy command", entry: {id:"cmd", name:"Command", kind:"command"}, shown:true},
            {tag: "background command", entry: {id:"cmd", name:"Command", kind:"command", runInTerminal:false}, shown:false},
            {tag: "terminal app", entry: {id:"app", name:"App", runInTerminal:true}, shown:false}
        ]
    }
    function test_terminal_indicator(data) {
        var row=createTemporaryObject(rowFactory,test,{modelData:data.entry})
        var indicator=findChild(row,"terminalIndicator")
        verify(indicator)
        compare(indicator.visible,data.shown)
        compare(indicator.width,data.shown ? 18 : 0)
        // The indicator must not intercept the row's launch action.
        mouseClick(row,350,16)
        compare(fakePanel.activations,1)
    }
    function test_terminal_icon_tooltip_on_hover() {
        var row=createTemporaryObject(rowFactory,test,{modelData:{id:"cmd",name:"Command",kind:"command",commandText:"echo hello",runInTerminal:true}})
        var icon=findChild(row,"terminalIndicator")
        var tooltip=findChild(row,"terminalToolTip")
        verify(icon)
        verify(tooltip)
        mouseMove(test,390,190)
        mouseMove(icon,icon.width/2,icon.height/2)
        tryCompare(tooltip,"visible",true)
        compare(tooltip.text,"Runs in terminal")
        compare(tooltip.delay,500)
        compare(tooltip.contentItem.textFormat,Text.PlainText)
        compare(findChild(row,"commandToolTip").visible,false)
        fakePanel.draggedEntry=row.modelData
        tryCompare(tooltip,"visible",false)
        fakePanel.draggedEntry=null
        tryCompare(tooltip,"visible",true)
        fakePanel.opened=false
        tryCompare(tooltip,"visible",false)
        fakePanel.opened=true
        tryCompare(tooltip,"visible",true)
        mouseMove(test,390,190)
        tryCompare(tooltip,"visible",false)
        mouseMove(row,100,16)
        tryCompare(findChild(row,"commandToolTip"),"visible",true)
        compare(tooltip.visible,false)
        row.modelData={id:"cmd",name:"Command",kind:"command",runInTerminal:false}
        compare(icon.visible,false)
        compare(icon.width,0)
    }
}
