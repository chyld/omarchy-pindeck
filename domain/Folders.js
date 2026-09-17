function key(pin) { return pin.pinId || pin.id }
function inGroup(pin, folderId) { return (pin.folderId || "") === (folderId || "") }
function conflict(pins, pin, folderId) {
    return pins.some(function(p) { return key(p) !== key(pin) && p.id === pin.id && inGroup(p, folderId) })
}
// Keep desktop entry objects intact so launch commands and actions stay native.
function rows(pins, folders, applications, order) {
    function entry(pin) {
        if (pin.kind === "location" || pin.kind === "command") return pin
        var app = applications.find(function(app) { return app.id === pin.id })
        if (!app) return {id:pin.id, pinId:pin.pinId, name:pin.name, icon:pin.icon, missing:true}
        if (!pin.pinId) return app
        return {id:app.id, pinId:pin.pinId, name:app.name, icon:app.icon, command:app.command,
            actions:app.actions, startupClass:app.startupClass, runInTerminal:app.runInTerminal}
    }
    var result = []
    rootOrder(pins, folders, order).forEach(function(orderKey) {
        if (orderKey.slice(0, 4) === "app:") {
            result.push(entry(pins.find(function(p) { return "app:" + key(p) === orderKey })))
        } else {
            var folder = folders.find(function(f) { return "folder:" + f.id === orderKey })
            var children = pins.filter(function(pin) { return pin.folderId === folder.id })
            result.push({id:folder.id, name:folder.name, folder:true, expanded:folder.expanded, count:children.length})
            if (folder.expanded !== false) result = result.concat(children.map(entry))
        }
    })
    return result
}
function move(pins, id, folderId) {
    var pin = pins.find(function(p) { return key(p) === id })
    if (pin && conflict(pins, pin, folderId)) return null
    return pins.map(function(pin) {
        return key(pin) === id ? Object.assign({}, pin, {folderId:folderId || ""}) : pin
    })
}
function remove(pins, folders, id) {
    return {
        pins:pins.filter(function(pin) { return pin.folderId !== id }),
        folders:folders.filter(function(folder) { return folder.id !== id })
    }
}

function rootOrder(pins, folders, order) {
    var valid = pins.filter(function(p) { return !folders.some(function(f) { return f.id === p.folderId }) }).map(function(p) { return "app:" + key(p) })
        .concat(folders.map(function(f) { return "folder:" + f.id }))
    var result = []
    ;(order || []).concat(valid).forEach(function(key) {
        if (valid.indexOf(key) !== -1 && result.indexOf(key) === -1) result.push(key)
    })
    return result
}
// zone: before/after relative to a row, inside a folder, or top-level end.
function drop(pins, folders, order, source, target, zone) {
    var nextPins = pins.slice(), nextFolders = folders.slice()
    var nextOrder = rootOrder(pins, folders, order)
    var sourceKey = (source.folder ? "folder:" + source.id : "app:" + key(source))
    if (target && key(source) === key(target) && !!source.folder === !!target.folder) return {pins:nextPins, folders:nextFolders, order:nextOrder}
    if (source.folder) {
        if (!folders.some(function(f) { return f.id === source.id })) return null
        if (target && !target.folder) {
            var targetPin = pins.find(function(p) { return key(p) === key(target) })
            if (targetPin && targetPin.folderId) target = {id:targetPin.folderId, folder:true}
        }
        if (target && target.folder && target.id === source.id) return null
        if (zone === "inside") return null
    } else {
        if (!pins.some(function(p) { return key(p) === key(source) })) return null
        var folderId = ""
        if (target && target.folder && zone === "inside") folderId = target.id
        else if (target && !target.folder) {
            var sibling = pins.find(function(p) { return key(p) === key(target) })
            folderId = sibling ? sibling.folderId || "" : ""
        }
        if (!folders.some(function(f) { return f.id === folderId })) folderId = ""
        nextPins = move(pins, key(source), folderId)
        if (!nextPins) return null
        var moving = nextPins.find(function(p) { return key(p) === key(source) })
        nextPins = nextPins.filter(function(p) { return key(p) !== key(source) })
        var index = target && !target.folder ? nextPins.findIndex(function(p) { return key(p) === key(target) }) : -1
        if (index < 0) nextPins.push(moving)
        else nextPins.splice(index + (zone === "after" ? 1 : 0), 0, moving)
        if (folderId) {
            nextFolders = folders.map(function(f) { return f.id === folderId ? Object.assign({}, f, {expanded:true}) : f })
            return {pins:nextPins, folders:nextFolders, order:rootOrder(nextPins, nextFolders, nextOrder)}
        }
    }
    nextOrder = nextOrder.filter(function(k) { return k !== sourceKey })
    var targetKey = target ? (target.folder ? "folder:" + target.id : "app:" + key(target)) : ""
    var at = nextOrder.indexOf(targetKey)
    if (at < 0) nextOrder.push(sourceKey)
    else nextOrder.splice(at + (zone === "after" ? 1 : 0), 0, sourceKey)
    return {pins:nextPins, folders:nextFolders, order:rootOrder(nextPins, nextFolders, nextOrder)}
}
if (typeof module !== "undefined") module.exports = {rows:rows, move:move, remove:remove, rootOrder:rootOrder, drop:drop, key:key, conflict:conflict}
