"""Version-one configuration boundary. Limits apply before publishing to QML."""
import json

MAX_BYTES = 524288
MAX_PINS = 1000
MAX_GROUPS = 100
MAX_TEXT = 256
MAX_COMMAND = 16384
MAX_PATH = 4096


def defaults():
    return {"version": 1, "pinnedApps": [], "folders": [], "rootOrder": []}


def text(value, limit, label, empty=False):
    if not isinstance(value, str) or len(value) > limit or (not empty and not value):
        raise ValueError(f"Invalid {label}.")
    if any(ord(c) < 32 and c not in '\n\t' for c in value) or '\x7f' in value:
        raise ValueError(f"Control character in {label}.")
    return value


def validate(data):
    if not isinstance(data, dict) or type(data.get('version', 1)) is not int or data.get('version', 1) != 1:
        raise ValueError('Unsupported configuration version.')
    for field, maximum in [('pinnedApps', MAX_PINS), ('folders', MAX_GROUPS), ('rootOrder', MAX_PINS + MAX_GROUPS)]:
        if not isinstance(data.get(field), list) or len(data[field]) > maximum:
            raise ValueError(f'Invalid or oversized {field}.')
    groups, keys, memberships = set(), set(), set()
    for group in data['folders']:
        if not isinstance(group, dict): raise ValueError('Invalid group.')
        ident = text(group.get('id'), MAX_PATH + 32, 'group id')
        text(group.get('name'), MAX_TEXT, 'group name', True)
        if ident in groups: raise ValueError('Duplicate group id.')
        if 'expanded' in group and type(group['expanded']) is not bool: raise ValueError('Invalid expansion state.')
        groups.add(ident)
    for pin in data['pinnedApps']:
        if not isinstance(pin, dict): raise ValueError('Invalid pin.')
        ident = text(pin.get('id'), MAX_PATH + 32, 'pin id')
        text(pin.get('name'), MAX_TEXT, 'pin name', True)
        key = text(pin.get('pinId', ident), MAX_PATH + 32, 'pin identity')
        group = text(pin.get('folderId', ''), MAX_PATH + 32, 'membership', True)
        member = (ident, group if group in groups else '')
        if key in keys or member in memberships: raise ValueError('Duplicate pin.')
        keys.add(key); memberships.add(member)
        kind = pin.get('kind', 'app')
        if kind not in ('app', 'location', 'command'): raise ValueError('Unknown pin kind.')
        if 'icon' in pin: text(pin['icon'], MAX_PATH, 'icon', True)
        if 'runInTerminal' in pin and type(pin['runInTerminal']) is not bool: raise ValueError('Invalid terminal flag.')
        if kind == 'location':
            path = text(pin.get('path'), MAX_PATH, 'folder path')
            if not path.startswith('/'): raise ValueError('Folder path must be absolute.')
        if kind == 'command':
            if not text(pin.get('commandText'), MAX_COMMAND, 'command').strip(): raise ValueError('Empty command.')
    for key in data['rootOrder']: text(key, MAX_PATH + 40, 'ordering key')
    # Unknown fields remain compatible, but are covered by depth/byte bounds.
    def depth(value, level=0):
        if level > 16: raise ValueError('Configuration nesting limit exceeded.')
        if isinstance(value, dict):
            for key, item in value.items():
                text(key, MAX_PATH, 'field name', True)
                depth(item, level + 1)
        elif isinstance(value, list):
            for item in value: depth(item, level + 1)
        elif isinstance(value, float):
            import math
            if not math.isfinite(value): raise ValueError('Non-finite number.')
    depth(data)
    return data


def decode(raw):
    if len(raw) > MAX_BYTES: raise ValueError('Configuration exceeds 512 KiB.')
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result: raise ValueError('Duplicate JSON field.')
            result[key] = value
        return result
    try:
        return validate(json.loads(raw, object_pairs_hook=pairs))
    except (RecursionError, UnicodeError) as error:
        raise ValueError('Invalid configuration encoding or depth.') from error


def encode(data):
    raw = (json.dumps(validate(data), ensure_ascii=True, indent=2, allow_nan=False) + '\n').encode()
    if len(raw) > MAX_BYTES: raise ValueError('Configuration exceeds 512 KiB.')
    return raw
