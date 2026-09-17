import QtQuick
import Quickshell.Hyprland
import "../domain/Focus.js" as Focus

Item {
    id: root
    property var pendingApp: null
    property var previous: []
    property double started: 0
    property string candidate: ""
    property double candidateSince: 0

    function begin(entry, newWindow) {
        pendingApp = {
            id: entry.id,
            name: entry.name,
            startupClass: entry.startupClass,
            executable: entry.command && entry.command.length ? String(entry.command[0]).split("/").pop() : "",
            terminal: entry.kind === "command" || entry.runInTerminal,
            newWindow: newWindow === true
        };
        previous = Hyprland.toplevels.values.map(function (t) {
            return t.lastIpcObject.address;
        });
        started = Date.now();
        candidate = "";
        poll.restart();
    }
    function cancel() {
        poll.stop();
        pendingApp = null;
    }

    Timer {
        id: poll
        interval: 100
        repeat: true
        onTriggered: {
            if (!root.pendingApp || Date.now() - root.started > 15000) {
                root.cancel();
                return;
            }
            Hyprland.refreshToplevels();
            var active = Hyprland.activeToplevel;
            var windows = Hyprland.toplevels.values.map(function (t) {
                return t.lastIpcObject;
            });
            var target = Focus.choose(windows, root.pendingApp, root.previous, active ? active.lastIpcObject.address : "");
            if (!target) {
                root.candidate = "";
                return;
            }
            if (target.address !== root.candidate) {
                root.candidate = target.address;
                root.candidateSince = Date.now();
                return;
            }
            // Let the popup close and the opening window finish its animation.
            if (Date.now() - root.candidateSince < 350)
                return;
            var point = Focus.center(target);
            if (!point || !/^0x[0-9a-f]+$/i.test(target.address))
                return;
            root.cancel();
            Hyprland.dispatch('hl.dsp.focus({window="address:' + target.address + '"})');
            Hyprland.dispatch('hl.dsp.cursor.move({x=' + point.x + ',y=' + point.y + '})');
        }
    }
}
