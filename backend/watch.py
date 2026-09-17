#!/usr/bin/python3
"""Directory notifications without reading configuration into the shell."""
import ctypes
import os
from pathlib import Path
import selectors
import struct
import sys
import time
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from backend.processes import parent_death_signal
from backend.storage import Store


def main():
    parent_death_signal()
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
    if fd < 0: raise OSError('Could not initialize configuration watcher.')
    selector = selectors.DefaultSelector()
    try:
        with Store(os.path.expanduser('~/.config/omarchy')) as store:
            # Bind the watch to the directory descriptor, not a second path lookup.
            mask = 0x00000008 | 0x00000080 | 0x00000100 | 0x00000200 | 0x00000400 | 0x00000800
            if libc.inotify_add_watch(fd, ('/proc/self/fd/%s' % store.fd).encode(), mask) < 0:
                raise OSError('Could not watch configuration directory.')
            selector.register(fd, selectors.EVENT_READ)
            pending, last = True, 0
            while True:
                if selector.select(.15):
                    events = os.read(fd, 65536)
                    offset = 0
                    while offset + 16 <= len(events):
                        wd, event, cookie, length = struct.unpack_from('iIII', events, offset)
                        name = events[offset + 16:offset + 16 + length].rstrip(b'\0')
                        offset += 16 + length
                        if event & (0x400 | 0x800): return  # directory replaced; reopen it
                        if name == b'pindeck.json' or event & 0x4000: pending = True
                now = time.monotonic()
                if pending and now - last >= .15:
                    os.write(sys.stdout.fileno(), b'changed\n')
                    pending = False; last = now
    finally:
        selector.close(); os.close(fd)


if __name__ == '__main__':
    try: main()
    except Exception: sys.exit(1)
