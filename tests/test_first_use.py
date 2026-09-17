"""Fresh installs must not write into Omarchy's recursively watched plugin tree."""
import json
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FirstUseTest(unittest.TestCase):
    def test_helpers_leave_fresh_plugin_tree_unchanged(self):
        with tempfile.TemporaryDirectory(prefix='pindeck-first-use-') as directory:
            root = Path(directory)
            plugin = root / 'plugin'
            shutil.copytree(ROOT / 'backend', plugin / 'backend',
                            ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
            home = root / 'home'
            home.mkdir()
            env = dict(os.environ, HOME=str(home))
            before = {str(p.relative_to(plugin)): p.read_bytes()
                      for p in plugin.rglob('*') if p.is_file()}

            def unchanged():
                after = {str(p.relative_to(plugin)): p.read_bytes()
                         for p in plugin.rglob('*') if p.is_file()}
                self.assertEqual(set(after), set(before), 'Helper wrote into watched plugin tree')
                self.assertEqual(after, before)

            def request(op, **fields):
                result = subprocess.run(
                    [sys.executable, '-I', str(plugin / 'backend/main.py')],
                    input=json.dumps(dict(id=1, op=op, **fields)), text=True,
                    capture_output=True, env=env, timeout=15, check=True)
                response = json.loads(result.stdout)
                unchanged()
                return response

            self.assertTrue(request('load')['ok'])
            self.assertTrue((home / '.config/omarchy/pindeck.json').exists())
            # First Add app imports catalog; Add folder imports locations.
            # A missing location exercises that import without a native dialog.
            request('hidden')
            self.assertFalse(request('location', path=str(home / 'missing'))['ok'])
            self.assertFalse(request('icon', path=str(home / 'missing.png'))['ok'])

            watcher = subprocess.Popen(
                [sys.executable, '-I', str(plugin / 'backend/watch.py')],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(watcher.stdout, selectors.EVENT_READ)
                    self.assertTrue(selector.select(5), 'Watcher did not initialize')
                    self.assertEqual(watcher.stdout.readline(), b'changed\n')
                unchanged()
            finally:
                watcher.terminate()
                watcher.communicate(timeout=5)

            result = subprocess.run([sys.executable, '-I', str(plugin / 'backend/terminal.py'),
                            'missing', 'stale'], input='\n', text=True,
                           capture_output=True, env=env, timeout=5)
            self.assertEqual(result.returncode, 1)
            unchanged()
