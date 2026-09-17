// Pass desktop IDs/actions as arguments, never as shell command strings.
function command(entry, actionId, context) {
    if (!entry || !entry.id || entry.missing) return null;
    if (entry.kind === "location") {
        if (actionId || !entry.path || entry.path.charAt(0) !== "/") return null;
        return ["xdg-open", "file://" + entry.path.split("/").map(encodeURIComponent).join("/")];
    }
    if (entry.kind === "command") {
        if (actionId || !String(entry.commandText || "").trim()) return null;
        if (!context || !context.runner || !context.revision) return null;
        return ["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-terminal-exec", "--", "/usr/bin/python3", "-I",
            context.runner, entry.pinId || entry.id, context.revision];
    }
    if (/^[\-]|[\x00-\x1f\x7f/]/.test(entry.id) || entry.id.length > 512) return null;
    if (actionId && (/^[\-]|[\x00-\x1f\x7f/:]/.test(actionId) || actionId.length > 256)) return null;
    var desktop = entry.id + ".desktop";
    if (actionId) {
        var actions = entry.actions || [];
        var found = false;
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].id === actionId) found = true;
        }
        if (!found) return null;
        var args = ["uwsm-app", "-t", "service"];
        if (entry.runInTerminal) args.push("-T");
        return args.concat(["--", desktop + ":" + actionId]);
    }
    if (entry.runInTerminal) return ["uwsm-app", "-t", "service", "-T", "--", desktop];
    return ["uwsm-app", "--", "gtk-launch", desktop];
}
// Group launch runs installed apps and saved commands in pinned order.
function groupEntries(pins, applications, groupId) {
    if (!groupId) return [];
    var seen = Object.create(null);
    return pins.filter(function(pin) { return pin.folderId === groupId; })
        .map(function(pin) { return (pin.kind === "command" || pin.kind === "location") ? pin : applications.find(function(app) { return app.id === pin.id; }); })
        .filter(function(app) {
            if (!app || seen[app.id] || !(app.kind === "command" ? String(app.commandText || "").trim() : command(app, ""))) return false;
            seen[app.id] = true;
            return true;
        });
}
if (typeof module !== "undefined") module.exports = {command: command, groupEntries: groupEntries};
