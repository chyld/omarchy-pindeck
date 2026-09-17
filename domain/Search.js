// Consecutive letters and word starts rank above scattered subsequences.
function score(text, query) {
    text = String(text || "").toLowerCase();
    query = String(query || "").toLowerCase().trim();
    if (!query) return 0;
    if (text === query) return 10000;
    if (text.indexOf(query) === 0) return 8000 - text.length;
    var direct = text.indexOf(query);
    if (direct >= 0) return 6000 - direct - text.length;
    var pos = -1, total = 0;
    for (var i = 0; i < query.length; i++) {
        if (query[i] === " ") continue;
        var next = text.indexOf(query[i], pos + 1);
        if (next < 0) return -1;
        total += (next === pos + 1 ? 30 : 0) + (next === 0 || /[\s._-]/.test(text[next - 1]) ? 20 : 0) - (next - pos);
        pos = next;
    }
    return 1000 + total - text.length;
}
function hiddenIds(text) {
    var ids = Object.create(null);
    String(text || "").split(/\n/).forEach(function(line) {
        var id = line.trim().replace(/\.desktop$/, "");
        if (id) ids[id] = true;
    });
    return ids;
}
function search(entries, query, configuredHiddenIds, desktopHiddenIds) {
    return entries.filter(function(e) {
        return e && !e.noDisplay
            && !(configuredHiddenIds && configuredHiddenIds[e.id] === true)
            && !(desktopHiddenIds && desktopHiddenIds[e.id] === true);
    })
        .map(function(e) { return { entry: e, score: Math.max(score(e.name, query), score(e.id, query) - 200) }; })
        .filter(function(row) { return row.score >= 0; })
        .sort(function(a, b) { return b.score - a.score || a.entry.name.localeCompare(b.entry.name); })
        .map(function(row) { return row.entry; });
}
if (typeof module !== "undefined") module.exports = { score: score, search: search, hiddenIds: hiddenIds };
