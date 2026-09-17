function parse(text) {
    if (typeof text !== "string" || text.length > 524288) throw new Error("Configuration exceeds its limit.")
    var data = JSON.parse(text)
    if (!data || Array.isArray(data) || typeof data !== "object") throw new Error("Expected a JSON object.")
    if (data.version !== undefined && data.version !== 1) throw new Error("Unsupported config version.")
    ;["pinnedApps", "folders", "rootOrder"].forEach(function(field) {
        if (!Array.isArray(data[field])) throw new Error(field + " must be an array.")
    })
    if (data.pinnedApps.length > 1000 || data.folders.length > 100 || data.rootOrder.length > 1100) throw new Error("Too many pins or groups.")
    function bounded(value, limit) { return typeof value === "string" && value.length <= limit && !/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(value) }
    data.folders.concat(data.pinnedApps).forEach(function(value) {
        if (!value || !bounded(value.id, 4128) || !bounded(value.name, 256)) throw new Error("Invalid or oversized name/identity.")
        if (value.pinId !== undefined && !bounded(value.pinId, 4128)) throw new Error("Invalid pin identity.")
        if (value.folderId !== undefined && !bounded(value.folderId, 4128)) throw new Error("Invalid membership.")
        if (value.kind !== undefined && ["app", "location", "command"].indexOf(value.kind) < 0) throw new Error("Unknown pin kind.")
        if (value.path !== undefined && !bounded(value.path, 4096)) throw new Error("Invalid path.")
        if (value.commandText !== undefined && !bounded(value.commandText, 16384)) throw new Error("Invalid command.")
        if (value.icon !== undefined && !bounded(value.icon, 4096)) throw new Error("Invalid icon.")
    })
    var groups = Object.create(null), keys = Object.create(null), memberships = Object.create(null)
    data.folders.forEach(function(f) {
        if (!f || typeof f.id !== "string" || !f.id || typeof f.name !== "string") throw new Error("Each group needs an id and name.")
        if (groups[f.id]) throw new Error("Duplicate group id: " + f.id)
        groups[f.id] = true
    })
    data.pinnedApps.forEach(function(p) {
        if (!p || typeof p.id !== "string" || !p.id || typeof p.name !== "string") throw new Error("Each pin needs an id and name.")
        if (p.pinId !== undefined && (typeof p.pinId !== "string" || !p.pinId)) throw new Error("pinId must be a nonempty string.")
        if (p.folderId !== undefined && typeof p.folderId !== "string") throw new Error("folderId must be a string.")
        var key = p.pinId || p.id
        if (keys[key]) throw new Error("Duplicate pin identity: " + key)
        keys[key] = true
        var member = JSON.stringify([p.id, groups[p.folderId] ? p.folderId : ""])
        if (memberships[member]) throw new Error("Duplicate pin in a group: " + p.name)
        memberships[member] = true
        if (p.kind === "location" && (typeof p.path !== "string" || p.path.charAt(0) !== "/")) throw new Error("Folder shortcuts need an absolute path.")
        if (p.kind === "command" && (typeof p.commandText !== "string" || !p.commandText.trim())) throw new Error("Command pins need commandText.")
    })
    if (data.rootOrder.some(function(k) { return typeof k !== "string" })) throw new Error("rootOrder must contain strings.")
    return data
}
if (typeof module !== "undefined") module.exports = {parse:parse}
