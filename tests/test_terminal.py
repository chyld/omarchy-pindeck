import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from backend import schema
from backend.storage import Store

RUNNER = Path(__file__).resolve().parents[1]/'backend/terminal.py'
class TerminalTest(unittest.TestCase):
    def test_command_has_terminal_stdin_and_exit_status_without_argv_disclosure(self):
        with tempfile.TemporaryDirectory() as home:
            value='read -r word; printf "result: %s\\n" "$word"; exit 7'
            data=schema.defaults(); data['pinnedApps']=[{'id':'cmd','name':'Example','kind':'command','commandText':value}]
            with Store(home+'/.config/omarchy') as store:
                state=store.load(); state=store.save(data,state['revision'])
            result=subprocess.run([sys.executable,'-I',str(RUNNER),'cmd',state['revision']],
                env=dict(os.environ,HOME=home),input='hello\n\n',text=True,capture_output=True,timeout=5)
            self.assertIn('result: hello',result.stdout)
            self.assertIn('Exit status: 7',result.stdout)
            self.assertIn('Press Enter',result.stdout)
    def test_changed_config_never_runs_stale_command(self):
        with tempfile.TemporaryDirectory() as home:
            marker=Path(home)/'must-not-exist'
            data=schema.defaults(); data['pinnedApps']=[{'id':'cmd','name':'Example','kind':'command','commandText':'touch '+str(marker)}]
            with Store(home+'/.config/omarchy') as store:
                initial=store.load(); store.save(data,initial['revision'])
            result=subprocess.run([sys.executable,'-I',str(RUNNER),'cmd',initial['revision']],env=dict(os.environ,HOME=home),input='\n',text=True,capture_output=True,timeout=5)
            self.assertFalse(marker.exists())
            self.assertIn('Could not run',result.stdout)
