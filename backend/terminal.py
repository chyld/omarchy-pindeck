#!/usr/bin/python3
"""User-requested terminal command runner; command bytes never enter argv."""
import os
from pathlib import Path
import subprocess
import sys
# Omarchy watches the plugin tree: bytecode writes would reload the shell.
# Set this here because isolated Python ignores PYTHONDONTWRITEBYTECODE.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from backend import schema
from backend.storage import Store


def run_command(command):
    # An inherited anonymous descriptor preserves terminal stdin for interactive tools.
    fd = os.memfd_create('pindeck-command', os.MFD_CLOEXEC)
    try:
        payload = command.encode('utf-8')
        while payload:
            count = os.write(fd, payload)
            if count <= 0: raise OSError('Short command write.')
            payload = payload[count:]
        os.lseek(fd, 0, os.SEEK_SET)
        return subprocess.call(['/usr/bin/bash', '-l', '/proc/self/fd/' + str(fd)], pass_fds=(fd,), cwd=os.path.expanduser('~'))
    finally: os.close(fd)


def main():
    try:
        if len(sys.argv) != 3: raise ValueError('Invalid command request.')
        with Store(os.path.expanduser('~/.config/omarchy')) as store:
            raw = store.read()
            if raw is None or store.revision(raw) != sys.argv[2]: raise ValueError('Configuration changed. Launch the command again.')
            data = schema.decode(raw)
            pin = next((p for p in data['pinnedApps'] if p.get('pinId', p['id']) == sys.argv[1]), None)
            if not pin or pin.get('kind') != 'command': raise ValueError('Command no longer exists.')
        status = run_command(pin['commandText'])
        print('\nExit status: %s' % status)
    except Exception:
        print('Could not run the saved command. It may have changed; try launching it again.')
    try: input('Press Enter to close…')
    except EOFError: pass


if __name__ == '__main__': main()
