"""Bounded process supervision. Only temporary helpers belong to this supervisor."""
import ctypes
import os
import selectors
import signal
import subprocess
import time

MAX_OUTPUT = 2 * 1024 * 1024
MAX_ERROR = 4096


class ProcessFailure(ValueError):
    pass


def parent_death_signal():
    parent = os.getppid()
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(1, signal.SIGTERM, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'Could not bind helper lifetime.')
    if os.getppid() != parent: raise ProcessFailure('Parent exited.')


def run(argv, payload=b'', timeout=10, output_limit=MAX_OUTPUT, error_limit=MAX_ERROR, environment=None):
    process = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=True, env=environment)
    streams = selectors.DefaultSelector()
    output, errors = bytearray(), bytearray()
    pending = memoryview(payload)
    previous = {}
    def cancelled(signum, frame): raise ProcessFailure('Operation cancelled.')
    try:
        for sig in (signal.SIGTERM, signal.SIGINT):
            previous[sig] = signal.signal(sig, cancelled)
        for pipe, name in ((process.stdout, 'out'), (process.stderr, 'err'), (process.stdin, 'in')):
            os.set_blocking(pipe.fileno(), False)
            if name != 'in' or payload: streams.register(pipe, selectors.EVENT_WRITE if name == 'in' else selectors.EVENT_READ, name)
            else: pipe.close()
        deadline = time.monotonic() + timeout
        while streams.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0: raise ProcessFailure('Operation timed out.')
            for key, mask in streams.select(min(remaining, .1)):
                if key.data == 'in':
                    try: pending = pending[os.write(key.fd, pending[:65536]):]
                    except BrokenPipeError: pending = pending[:0]
                    if not pending: streams.unregister(key.fileobj); key.fileobj.close()
                else:
                    chunk = os.read(key.fd, 65536)
                    if not chunk:
                        streams.unregister(key.fileobj); key.fileobj.close(); continue
                    target, limit = (output, output_limit) if key.data == 'out' else (errors, error_limit)
                    if len(target) + len(chunk) > limit: raise ProcessFailure('Helper output limit exceeded.')
                    target.extend(chunk)
        # Don't reap the leader before group cleanup: its pid pins the process group.
        if time.monotonic() >= deadline: raise ProcessFailure('Operation timed out.')
        # A worker may close its pipes early and continue. waitid observes without reaping.
        while os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is None:
            if time.monotonic() >= deadline: raise ProcessFailure('Operation timed out.')
            time.sleep(.01)
        observed = os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOWAIT)
        code = observed.si_status if observed.si_code == os.CLD_EXITED else -observed.si_status
        if code: raise ProcessFailure('Helper failed (exit %s).' % code)
        return bytes(output)
    finally:
        for sig in previous: signal.signal(sig, signal.SIG_IGN)
        # Leader is still unreaped; no delayed kill of a potentially reused PID.
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try: os.killpg(process.pid, sig)
            except ProcessLookupError: pass
            if sig == signal.SIGTERM: time.sleep(.03)
        process.wait()
        streams.close()
        for pipe in (process.stdin, process.stdout, process.stderr):
            if not pipe.closed: pipe.close()
        for sig, handler in previous.items(): signal.signal(sig, handler)
