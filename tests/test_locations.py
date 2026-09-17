import importlib.util
from pathlib import Path
import tempfile
import unittest

from backend import locations

class LocationsTest(unittest.TestCase):
    def test_special_characters_are_encoded_as_file_uri(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'photos #1 % $(echo nope)'
            path.mkdir()
            result = locations.directory(str(path))
            self.assertEqual(result['path'], str(path))
            self.assertEqual(result['name'], path.name)
            self.assertEqual(result['uri'], path.as_uri())

    def test_aliases_normalize_to_one_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)
            (path / 'alias').symlink_to(path, target_is_directory=True)
            self.assertEqual(locations.directory(str(path / 'alias'))['path'], str(path))
            self.assertEqual(locations.directory(tmp + '/./')['path'], str(path))

    def test_missing_paths_and_regular_files_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'file'
            path.touch()
            for value in [str(path), tmp + '/missing']:
                with self.assertRaises(ValueError):
                    locations.directory(value)

    def test_filesystem_root_has_a_name(self):
        self.assertEqual(locations.directory('/')['name'], '/')

if __name__ == '__main__':
    unittest.main()
