import QtQuick
import Quickshell
import Quickshell.Io
import "controllers"
import "domain/Config.js" as Config

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var configData: ({
            version: 1,
            pinnedApps: [],
            folders: [],
            rootOrder: []
        })
    property string revision: ""
    property bool seen: false
    property bool ready: false
    property bool initialized: false
    property var legacyDefaults: null
    property string error: ""
    property int sequence: 0
    property string operation: ""
    property var previousData: null
    property var hiddenIds: ({})
    property var configuredHiddenIds: ({})
    property bool visibilityReady: false
    property string visibilityError: ""
    readonly property bool busy: configChannel.busy
    readonly property bool helperBusy: helperChannel.busy
    property double nextLoad: 0
    property int failures: 0
    property var iconCache: Object.create(null)
    property var iconQueue: []
    property string loadingIcon: ""
    function requestIcon(path) {
        if (!path || path.charAt(0) !== "/" || Object.prototype.hasOwnProperty.call(iconCache, path) || iconQueue.indexOf(path) >= 0 || loadingIcon === path)
            return;
        if (iconQueue.length >= 100 || Object.keys(iconCache).length + iconQueue.length + (loadingIcon ? 1 : 0) >= 128)
            return;
        iconQueue = iconQueue.concat([path]);
        iconNext.restart();
    }
    Timer {
        id: iconNext
        interval: 20
        onTriggered: {
            if (iconChannel.busy || !root.iconQueue.length)
                return;
            root.loadingIcon = root.iconQueue[0];
            root.iconQueue = root.iconQueue.slice(1);
            iconChannel.start({
                id: ++root.sequence,
                op: "icon",
                path: root.loadingIcon
            });
        }
    }
    BackendChannel {
        id: iconChannel
        onCompleted: function (response) {
            var next = Object.assign(Object.create(null), root.iconCache);
            next[root.loadingIcon] = response.ok ? response.result.source : "";
            root.iconCache = next;
            root.loadingIcon = "";
            iconNext.restart();
        }
    }
    property var launchOwner: null
    signal launchFailed(var owner, string message)
    function launch(entries, actionId, owner) {
        if (!launches.launch(entries, actionId))
            return false;
        launchOwner = owner;
        return true;
    }
    LaunchController {
        id: launches
        service: root
        onFailed: function (message) {
            root.launchFailed(root.launchOwner, message);
        }
    }
    signal helperCompleted(int requestId, var response)

    function initialize(legacy) {
        if (initialized)
            return;
        legacyDefaults = legacy;
        initialized = true;
        load(legacy);
    }
    function load(legacy) {
        if (busy)
            return false;
        operation = "load";
        return configChannel.start({
            id: ++sequence,
            op: "load",
            seen: seen,
            legacy: seen ? null : legacyDefaults
        });
    }
    function save(data) {
        if (!ready || busy || error)
            return false;
        try {
            Config.parse(JSON.stringify(data));
        } catch (problem) {
            error = String(problem);
            return false;
        }
        previousData = configData;
        operation = "save";
        if (!configChannel.start({
            id: ++sequence,
            op: "save",
            revision: revision,
            data: data
        }))
            return false;
        configData = data;
        return true;
    }
    function refreshVisibility() {
        if (catalogChannel.busy)
            return;
        visibilityReady = false;
        visibilityError = "";
        catalogChannel.start({
            id: ++sequence,
            op: "hidden"
        });
    }
    function requestHelper(op, fields) {
        if (helperChannel.busy)
            return -1;
        var id = ++sequence;
        if (!helperChannel.start(Object.assign({}, fields || {}, {
            id: id,
            op: op
        })))
            return -1;
        return id;
    }
    function cancelHelper(id) {
        if (helperChannel.request && helperChannel.request.id === id)
            helperChannel.cancel();
    }
    BackendChannel {
        id: configChannel
        onCompleted: function (response) {
            if (response.ok) {
                try {
                    var data = Config.parse(JSON.stringify(response.result.data));
                    if (JSON.stringify(data) !== JSON.stringify(root.configData))
                        root.configData = data;
                    root.revision = response.result.revision;
                    root.ready = true;
                    root.seen = true;
                    root.error = "";
                    root.failures = 0;
                } catch (problem) {
                    if (root.operation === "save" && root.previousData)
                        root.configData = root.previousData;
                    root.error = "Invalid configuration response.";
                    root.failures++;
                }
            } else {
                if (response.observed)
                    root.seen = true;
                if (root.operation === "save" && root.previousData)
                    root.configData = root.previousData;
                root.error = response.error || "Could not access configuration.";
                root.failures++;
            }
            root.previousData = null;
            root.nextLoad = Date.now() + (root.failures ? Math.min(30000, 1000 * Math.pow(2, Math.min(root.failures, 5))) : (watcher.running ? 30000 : 2000));
        }
    }
    BackendChannel {
        id: catalogChannel
        onCompleted: function (response) {
            if (!response.ok) {
                root.visibilityError = response.error;
                return;
            }
            var hidden = Object.create(null), configured = Object.create(null);
            response.result.hidden.forEach(function (id) {
                hidden[id] = true;
            });
            response.result.configured.forEach(function (id) {
                configured[id] = true;
            });
            root.hiddenIds = hidden;
            root.configuredHiddenIds = configured;
            root.visibilityReady = true;
        }
    }
    BackendChannel {
        id: helperChannel
        onCompleted: function (response) {
            root.helperCompleted(response.id, response);
        }
    }
    property int watchFailures: 0
    onInitializedChanged: if (initialized)
        watcher.running = true
    Process {
        id: watcher
        command: ["/usr/bin/python3", "-I", decodeURIComponent(String(Qt.resolvedUrl("backend/watch.py")).replace(/^file:\/\//, ""))]
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: function (chunk) {
                reloadDebounce.restart();
            }
        }
        // The watcher emits no file contents and no diagnostics.
        onExited: {
            root.watchFailures++;
            root.nextLoad = Date.now();
            if (root.watchFailures < 5)
                watchRetry.restart();
        }
    }
    Timer {
        id: watchRetry
        interval: 1000
        onTriggered: watcher.running = true
    }
    Component.onDestruction: if (watcher.running)
        watcher.signal(15)
    Timer {
        id: reloadDebounce
        interval: 150
        onTriggered: if (!root.busy)
            root.load(null)
        else
            restart()
    }
    // Fallback catches file replacement/deletion on filesystems with missed events.
    Timer {
        interval: 1000
        running: root.initialized
        repeat: true
        onTriggered: if (!root.busy && Date.now() >= root.nextLoad)
            root.load(null)
    }
}
