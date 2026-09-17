function normalized(value) {
    return String(value || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}
function matches(window, app) {
    var classes = [window.class, window.initialClass].map(normalized).filter(Boolean);
    var names = [app.id, app.name, app.startupClass, app.executable].map(normalized).filter(Boolean);
    if (classes.some(function(c) { return names.indexOf(c) >= 0; })) return true;
    if (!app.terminal) return false;
    var terminals = ["foot", "footclient", "alacritty", "kitty", "comghostty", "orgwezfurlongwezterm", "orggnometerminal", "orgkdekonsole", "xterm"];
    return classes.some(function(c) { return terminals.indexOf(c) >= 0; });
}
function choose(windows, app, previous, activeAddress) {
    var eligible = windows.filter(function(w) {
        return w.mapped !== false && !w.hidden && matches(w, app);
    });
    // A terminal launch must produce a new terminal; never pick an existing
    // terminal just because it happens to have focus behind the menu.
    var created = eligible.filter(function(w) { return previous.indexOf(w.address) < 0; });
    if (created.length) return created.find(function(w) { return w.address === activeAddress; }) || created[0];
    if (app.terminal || app.newWindow) return null;
    return eligible.find(function(w) { return w.address === activeAddress; }) || null;
}
function center(window) {
    if (!window.at || !window.size || window.size[0] <= 0 || window.size[1] <= 0) return null;
    if (window.at.concat(window.size).some(function(value) { return typeof value !== "number" || !isFinite(value) || Math.abs(value) > 1000000; })) return null;
    return {x: Math.round(window.at[0] + window.size[0] / 2), y: Math.round(window.at[1] + window.size[1] / 2)};
}
if (typeof module !== "undefined") module.exports = {matches: matches, choose: choose, center: center};
