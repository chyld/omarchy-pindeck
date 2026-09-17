#!/usr/bin/python3
"""Private JSON request/response executable, never a public socket or shell API."""
import json
import os
from pathlib import Path
import selectors
import sys
import time

# Isolated Python does not search the working directory; load only our own package.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from backend import schema
from backend.storage import Store
from backend.processes import run, parent_death_signal

MAX_REQUEST = 1048576


def read_request():
    raw = bytearray()
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin.buffer, selectors.EVENT_READ)
    deadline = time.monotonic() + 5
    try:
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not selector.select(remaining): raise ValueError('Request timed out.')
            chunk = os.read(sys.stdin.fileno(), min(65536, MAX_REQUEST + 1 - len(raw)))
            if not chunk: break
            raw.extend(chunk)
            if len(raw) > MAX_REQUEST: raise ValueError('Request too large.')
    finally: selector.close()
    data = json.loads(raw)
    if not isinstance(data, dict) or type(data.get('id')) is not int or data['id'] < 0: raise ValueError('Invalid request.')
    return data


def operation(request):
    op = request.get('op')
    if op in ('load', 'save'):
        directory = os.path.expanduser('~/.config/omarchy')
        with Store(directory) as store:
            try:
                if op == 'load': return store.load(request.get('seen') is True, request.get('legacy'))
                return store.save(request.get('data'), request.get('revision'))
            finally:
                request['observed'] = store.observed
    if op == 'icon':
        from backend.icons import load
        return load(request.get('path'))
    if op == 'hidden':
        from backend.catalog import hidden
        return hidden()
    if op == 'choose':
        from backend.locations import choose
        return choose()
    if op == 'location':
        from backend.locations import check
        return check(request.get('path'))
    raise ValueError('Unknown operation.')


def main():
    request = {}
    try:
        parent_death_signal()
        request = read_request()
        if '--worker' in sys.argv:
            result = operation(request)
            response = {'id': request['id'], 'ok': True, 'result': result}
        else:
            payload = json.dumps(request, ensure_ascii=True).encode()
            raw = run(['/usr/bin/python3', '-I', str(Path(__file__).resolve()), '--worker'], payload,
                      timeout=300 if request.get('op') == 'choose' else 10)
            response = json.loads(raw)
    except Exception as error:
        # Fixed exceptions have bounded, plain messages; never return arbitrary stderr.
        message = str(error) if isinstance(error, (ValueError, PermissionError, TimeoutError)) else 'Operation failed. Check the file and dependencies.'
        response = {'id': request.get('id', 0), 'ok': False, 'error': message[:256], 'observed': request.get('observed') is True}
    raw = json.dumps(response, ensure_ascii=True, allow_nan=False).encode() + b'\n'
    if len(raw) > 2 * 1024 * 1024: raise ValueError('Response too large.')
    sys.stdout.buffer.write(raw)
    sys.stdout.buffer.flush()


if __name__ == '__main__': main()
