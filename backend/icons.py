"""Decode small local PNG icons outside the shell and return normalized pixels."""
import base64
import os
import stat
import struct

MAX_ICON = 1048576


def load(path):
    if not isinstance(path, str) or not path.startswith('/') or len(path) > 4096:
        raise ValueError('Invalid icon path.')
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid not in (0, os.getuid()) or info.st_size > MAX_ICON:
            raise ValueError('Unsafe icon file.')
        raw = bytearray()
        while len(raw) <= MAX_ICON:
            chunk = os.read(fd, min(65536, MAX_ICON + 1 - len(raw)))
            if not chunk: break
            raw.extend(chunk)
        if len(raw) > MAX_ICON or raw[:8] != b'\x89PNG\r\n\x1a\n' or len(raw) < 33 or raw[12:16] != b'IHDR':
            raise ValueError('Only bounded PNG icons are supported.')
        width, height = struct.unpack('>II', raw[16:24])
        if not (0 < width <= 1024 and 0 < height <= 1024): raise ValueError('Icon dimensions exceed limit.')
    finally: os.close(fd)
    import gi
    gi.require_version('GdkPixbuf', '2.0')
    from gi.repository import GdkPixbuf
    loader = GdkPixbuf.PixbufLoader.new_with_type('png')
    loader.write(bytes(raw)); loader.close()
    image = loader.get_pixbuf()
    scale = min(1, 64 / max(width, height))
    image = image.scale_simple(max(1, round(width * scale)), max(1, round(height * scale)), GdkPixbuf.InterpType.BILINEAR)
    ok, result = image.save_to_bufferv('png', [], [])
    if not ok or len(result) > 65536: raise ValueError('Could not normalize icon.')
    return {'source': 'data:image/png;base64,' + base64.b64encode(result).decode('ascii')}
