import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from backend.catalog import hidden, read_regular

class CatalogTest(unittest.TestCase):
    def test_precedence_and_desktop_visibility(self):
        with tempfile.TemporaryDirectory() as root:
            user=Path(root)/'user/applications';system=Path(root)/'system/applications'
            user.mkdir(parents=True);system.mkdir(parents=True)
            (user/'app.desktop').write_text('[Desktop Entry]\nHidden=true\n')
            (system/'app.desktop').write_text('[Desktop Entry]\nName=Visible elsewhere\n')
            (system/'only.desktop').write_text('[Desktop Entry]\nOnlyShowIn=GNOME;\n')
            (system/'not.desktop').write_text('[Desktop Entry]\nNotShowIn=Hyprland;\n')
            (system/'shown.desktop').write_text('[Desktop Entry]\nOnlyShowIn=Hyprland;\n')
            with patch.dict(os.environ,{'HOME':root,'XDG_DATA_HOME':str(user.parent),'XDG_DATA_DIRS':str(system.parent),'XDG_CURRENT_DESKTOP':'Hyprland','OMARCHY_PATH':root}):
                result=hidden()
            self.assertEqual(set(result['hidden']),{'app','only','not'})
    def test_metadata_special_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            fifo=Path(root)/'fifo';os.mkfifo(fifo)
            with self.assertRaises(ValueError): read_regular(fifo)
