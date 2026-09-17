// Pass desktop IDs/actions as arguments, never as shell command strings.
function command(entry, actionId) {
    if (!entry || !entry.id || entry.missing) return null;
    if (entry.kind === "location") {
        if (actionId || !entry.path || entry.path.charAt(0) !== "/") return null;
        return ["xdg-open", "file://" + entry.path.split("/").map(encodeURIComponent).join("/")];
    }
    if (entry.kind === "command") {
        if (actionId || !String(entry.commandText || "").trim()) return null;
        // The saved command is a separate argv value, interpreted only by the
        // requested shell. An outer shell holds the terminal even after exit.
        return ["uwsm-app", "--", "xdg-terminal-exec", "--", "bash", "-lc",
            'cd "$HOME" || exit; bash -lc "$1"; result=$?; printf "\\nExit status: %s\\nPress Enter to close…" "$result"; read -r reply',
            "pinned-command", entry.commandText];
    }
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
    var seen = {};
    return pins.filter(function(pin) { return pin.folderId === groupId; })
        .map(function(pin) { return (pin.kind === "command" || pin.kind === "location") ? pin : applications.find(function(app) { return app.id === pin.id; }); })
        .filter(function(app) {
            if (!app || seen[app.id] || !command(app, "")) return false;
            seen[app.id] = true;
            return true;
        });
}
if (typeof module !== "undefined") module.exports = {command: command, groupEntries: groupEntries};
