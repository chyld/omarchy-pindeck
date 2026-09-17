import base64
from pathlib import Path
import struct
import tempfile
import unittest
from backend.icons import load

class IconTest(unittest.TestCase):
    def test_network_svg_oversize_and_symlink_inputs_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'icon.png'
            for raw in [b'<svg><image href="https://example.com"/></svg>', b'\x89PNG\r\n\x1a\n'+struct.pack('>I',13)+b'IHDR'+struct.pack('>II',100000,100000)+b'\0'*20, b'x'*1048577]:
                path.write_bytes(raw)
                with self.assertRaises(ValueError): load(str(path))
            alias=Path(directory)/'alias';alias.symlink_to(path)
            with self.assertRaises(OSError): load(str(alias))
        with self.assertRaises(ValueError): load('https://example.com/icon.png')
    def test_valid_png_is_normalized(self):
        try:
            import gi
            gi.require_version('GdkPixbuf','2.0')
            from gi.repository import GdkPixbuf
        except (ImportError,ValueError):
            self.skipTest('GdkPixbuf not installed on this test host')
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'icon.png'
            pixbuf=GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB,True,8,128,128)
            pixbuf.fill(0x80b0c0ff)
            pixbuf.savev(str(path),'png',[],[])
            source=load(str(path))['source']
            self.assertTrue(source.startswith('data:image/png;base64,'))
            raw=base64.b64decode(source.split(',',1)[1])
            self.assertEqual(struct.unpack('>II',raw[16:24]),(64,64))
