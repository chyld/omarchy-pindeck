import QtQuick
import Quickshell
import qs.Commons
import "../domain/Launch.js" as Launch

Item {
    id: root
    property var service: null
    property var queue: []
    property int requestId: -1
    property var waitingEntry: null
    readonly property bool busy: queue.length > 0 || requestId >= 0
    readonly property string runner: decodeURIComponent(String(Qt.resolvedUrl('../backend/terminal.py')).replace(/^file:\/\//, ''))
    signal failed(string message)
    function launch(entries, actionId) {
        if (busy || !service || service.helperBusy || service.busy)
            return false;
        if (!entries.length || entries.length > 100) {
            failed("Choose a group with 1–100 launchable pins.");
            return false;
        }
        queue = entries.map(function (entry) {
            return {
                entry: entry,
                action: actionId || "",
                revision: service.revision
            };
        });
        advance.restart();
        return true;
    }
    function next() {
        if (!queue.length || requestId >= 0)
            return;
        var item = queue[0];
        queue = queue.slice(1);
        if (item.entry.kind === "location") {
            waitingEntry = item.entry;
            requestId = service.requestHelper("location", {
                path: item.entry.path
            });
            if (requestId < 0) {
                failed("Folder helper is busy.");
                advance.restart();
            }
            return;
        }
        var argv = Launch.command(item.entry, item.action, {
            runner: runner,
            revision: item.revision
        });
        if (!argv) {
            failed("This item or action is unavailable.");
            advance.restart();
            return;
        }
        focus.begin(item.entry, !!item.action);
        Util.execArgv(argv);
        advance.restart();
    }
    Connections {
        target: root.service
        function onHelperCompleted(id, response) {
            if (id !== root.requestId)
                return;
            root.requestId = -1;
            if (response.ok && response.result.uri && response.result.uri.indexOf("file:///") === 0) {
                var managerId = String(response.result.desktopId || "").replace(/\.desktop$/, "");
                var manager = DesktopEntries.applications.values.find(function (app) {
                    return app.id === managerId;
                });
                if (manager)
                    focus.begin(manager, false);
                Util.execArgv(["/usr/bin/xdg-open", response.result.uri]);
            } else
                root.failed(response.error || "Folder unavailable.");
            root.waitingEntry = null;
            advance.restart();
        }
    }
    Timer {
        id: advance
        interval: 100
        onTriggered: root.next()
    }
    LaunchFocus {
        id: focus
    }
    Component.onDestruction: {
        if (service && requestId >= 0)
            service.cancelHelper(requestId);
        focus.cancel();
    }
}
