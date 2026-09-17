import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string helperPath: decodeURIComponent(String(Qt.resolvedUrl('../backend/main.py')).replace(/^file:\/\//, ''))
    property var request: null
    property string output: ""
    property int errorBytes: 0
    property string failure: ""
    readonly property bool busy: process.running
    signal completed(var response)

    function start(value) {
        if (busy)
            return false;
        var payload = JSON.stringify(value);
        if (payload.length > 1048576)
            return false;
        request = value;
        output = "";
        errorBytes = 0;
        failure = "";
        process.running = true;
        return true;
    }
    function cancel() {
        if (process.running) {
            failure = "Operation cancelled.";
            process.signal(15);
        }
    }
    Component.onDestruction: cancel()
    Process {
        id: process
        command: ["/usr/bin/python3", "-I", root.helperPath]
        stdinEnabled: true
        onStarted: {
            write(JSON.stringify(root.request));
            stdinEnabled = false;
        }
        onRunningChanged: {
            if (!running)
                stdinEnabled = true;
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: function (chunk) {
                if (root.output.length + chunk.length > 2097152) {
                    root.failure = "Response too large.";
                    process.signal(15);
                } else
                    root.output += chunk;
            }
        }
        stderr: SplitParser {
            splitMarker: ""
            onRead: function (chunk) {
                root.errorBytes += chunk.length;
                if (root.errorBytes > 4096) {
                    root.failure = "Helper error output exceeded its limit.";
                    process.signal(15);
                }
            }
        }
        onExited: function (code) {
            var response;
            try {
                if (root.failure || code !== 0)
                    throw new Error(root.failure || "Helper exited unexpectedly.");
                response = JSON.parse(root.output);
                if (response.id !== root.request.id || typeof response.ok !== "boolean")
                    throw new Error("Invalid helper response.");
            } catch (error) {
                response = {
                    id: root.request.id,
                    ok: false,
                    error: String(error).slice(0, 256)
                };
            }
            root.output = "";
            root.request = null;
            root.completed(response);
        }
    }
}
