"""Bounded desktop visibility scanning; precedence follows XDG application dirs."""
import os
import stat

MAX_ENTRIES = 10000
MAX_FILE = 65536


def read_regular(path):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_FILE: raise ValueError('Oversized desktop metadata.')
        raw = os.read(fd, MAX_FILE + 1)
        if len(raw) > MAX_FILE: raise ValueError('Oversized desktop metadata.')
        return raw.decode('utf-8', 'replace')
    finally: os.close(fd)


def hidden():
    names = set(filter(None, ':'.join(os.environ.get(k, '') for k in ('XDG_CURRENT_DESKTOP', 'XDG_SESSION_DESKTOP', 'DESKTOP_SESSION')).split(':')))
    home = os.path.expanduser('~')
    dirs = [os.environ.get('XDG_DATA_HOME', home + '/.local/share')]
    dirs += os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
    dirs += [home + '/.nix-profile/share']
    seen, result, count = set(), [], 0
    for base in dirs[:32]:
        directory = os.path.join(base, 'applications')
        stack = [(directory, '')]
        while stack:
            current, prefix = stack.pop()
            try:
                with os.scandir(current) as entries:
                    for entry in entries:
                        count += 1
                        if count > MAX_ENTRIES: raise ValueError('Too many desktop entries.')
                        if entry.is_dir(follow_symlinks=False):
                            if prefix.count('/') < 8: stack.append((entry.path, prefix + entry.name + '/'))
                            continue
                        if not entry.name.endswith('.desktop'): continue
                        ident = (prefix + entry.name[:-8]).replace('/', '-')
                        if ident in seen: continue
                        seen.add(ident)
                        if entry.is_symlink():
                            result.append(ident); continue
                        try: raw = read_regular(entry.path)
                        except (OSError, ValueError):
                            result.append(ident); continue
                        active, values = False, {}
                        for line in raw.splitlines():
                            line = line.strip()
                            if line.startswith('['): active = line == '[Desktop Entry]'
                            elif active and '=' in line:
                                key, value = line.split('=', 1); values[key] = value
                        only = set(filter(None, values.get('OnlyShowIn', '').split(';')))
                        excluded = set(filter(None, values.get('NotShowIn', '').split(';')))
                        if values.get('Hidden') == 'true' or values.get('NoDisplay') == 'true' or (only and not only & names) or excluded & names:
                            result.append(ident)
            except FileNotFoundError: pass
    configured = []
    # The packaged Omarchy exclusion list is read with the same size/type bounds.
    path = os.environ.get('OMARCHY_PATH', '/usr/share/omarchy') + '/default/omarchy/launcher.hides'
    try: configured = [line.strip().removesuffix('.desktop') for line in read_regular(path).splitlines() if line.strip()]
    except FileNotFoundError: pass
    return {'hidden': result, 'configured': configured}
