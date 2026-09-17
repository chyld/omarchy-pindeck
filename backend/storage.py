"""Private, bounded, descriptor-relative storage with cooperating-writer locking."""
import contextlib
import fcntl
import hashlib
import os
import secrets
import stat
import time
from . import schema


class ConflictError(ValueError):
    pass


class Store:
    def __init__(self, directory):
        self.observed = False
        # Resolve components with held descriptors, never follow a directory symlink.
        if not os.path.isabs(directory): raise ValueError('Absolute configuration directory required.')
        self.fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        try:
            parts = directory.split('/')[1:]
            for part in parts:
                if part in ('', '.', '..'): raise ValueError('Invalid configuration directory.')
                try:
                    child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=self.fd)
                except FileNotFoundError:
                    try: os.mkdir(part, 0o700, dir_fd=self.fd)
                    except FileExistsError: pass
                    child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=self.fd)
                info = os.fstat(child)
                if info.st_uid not in (0, os.getuid()) or (info.st_mode & 0o022 and not info.st_mode & stat.S_ISVTX):
                    os.close(child)
                    raise PermissionError('Unsafe configuration directory.')
                os.close(self.fd); self.fd = child
            if os.fstat(self.fd).st_uid != os.getuid(): raise PermissionError('Configuration directory is not owned by you.')
        except BaseException:
            self.close(); raise

    def close(self):
        if self.fd is not None:
            os.close(self.fd); self.fd = None

    def __enter__(self): return self
    def __exit__(self, *args): self.close()

    @contextlib.contextmanager
    def locked(self):
        fd = os.open('.pindeck.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC, 0o600, dir_fd=self.fd)
        try:
            self._check(fd, 1024, private=True)
            deadline = time.monotonic() + 1
            while True:
                try:
                    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB); break
                except BlockingIOError:
                    if time.monotonic() >= deadline: raise TimeoutError('Configuration is busy.')
                    time.sleep(.01)
            yield
        finally:
            os.close(fd)

    @staticmethod
    def _check(fd, limit, private=False):
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
            raise PermissionError('Unsafe configuration file type or ownership.')
        # Existing 0644 configs from v0.1 are readable; all new writes are 0600.
        if info.st_mode & (0o077 if private else 0o022): raise PermissionError('Unsafe configuration permissions.')
        if info.st_size > limit: raise ValueError('Configuration exceeds 512 KiB.')
        return info

    def read(self, name='pindeck.json'):
        if name not in ('pindeck.json', 'pinned.json'): raise ValueError('Invalid configuration name.')
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC, dir_fd=self.fd)
        except FileNotFoundError: return None
        if name == 'pindeck.json': self.observed = True
        try:
            before = self._check(fd, schema.MAX_BYTES)
            raw = bytearray()
            while len(raw) <= schema.MAX_BYTES:
                chunk = os.read(fd, min(65536, schema.MAX_BYTES + 1 - len(raw)))
                if not chunk: break
                raw.extend(chunk)
            if len(raw) > schema.MAX_BYTES: raise ValueError('Configuration grew past its limit.')
            after = os.fstat(fd)
            if (before.st_mtime_ns, before.st_size) != (after.st_mtime_ns, after.st_size):
                raise ConflictError('Configuration changed during reading.')
            return bytes(raw)
        finally: os.close(fd)

    @staticmethod
    def revision(raw):
        return hashlib.sha256(raw).hexdigest() if raw is not None else ''

    def _publish(self, raw):
        name = '.pindeck-' + secrets.token_hex(16) + '.tmp'
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600, dir_fd=self.fd)
        try:
            os.fchmod(fd, 0o600)
            view = memoryview(raw)
            while view:
                n = os.write(fd, view)
                if n <= 0: raise OSError('Short configuration write.')
                view = view[n:]
            os.fsync(fd)
            os.replace(name, 'pindeck.json', src_dir_fd=self.fd, dst_dir_fd=self.fd)
            os.fsync(self.fd)
        finally:
            os.close(fd)
            try: os.unlink(name, dir_fd=self.fd)
            except FileNotFoundError: pass

    def load(self, seen=False, legacy=None):
        with self.locked():
            raw = self.read()
            if raw is None:
                old = None if seen else self.read('pinned.json')
                data = schema.decode(old) if old is not None else schema.validate(legacy) if legacy and not seen else schema.defaults()
                raw = schema.encode(data)
                self._publish(raw)
            return {'data': schema.decode(raw), 'revision': self.revision(raw)}

    def save(self, data, expected):
        raw = schema.encode(data)
        with self.locked():
            current = self.read()
            if self.revision(current) != expected: raise ConflictError('Configuration changed elsewhere. Reload and try again.')
            # Never replace an invalid external edit just because its hash matched.
            if current is not None: schema.decode(current)
            self._publish(raw)
        return {'data': data, 'revision': self.revision(raw)}
