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
    def test_nonterminal_command_returns_status_without_close_prompt(self):
        with tempfile.TemporaryDirectory() as home:
            data=schema.defaults(); data['pinnedApps']=[{'id':'cmd','name':'Example','kind':'command','commandText':'printf launched; exit 7','runInTerminal':False}]
            with Store(home+'/.config/omarchy') as store:
                state=store.load(); state=store.save(data,state['revision'])
            result=subprocess.run([sys.executable,'-I',str(RUNNER),'cmd',state['revision']],
                env=dict(os.environ,HOME=home),input='',text=True,capture_output=True,timeout=5)
            self.assertEqual(result.returncode,7)
            self.assertEqual(result.stdout,'launched')

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
            self.assertEqual(result.returncode,7)
    def test_changed_config_never_runs_stale_command(self):
        with tempfile.TemporaryDirectory() as home:
            marker=Path(home)/'must-not-exist'
            data=schema.defaults(); data['pinnedApps']=[{'id':'cmd','name':'Example','kind':'command','commandText':'touch '+str(marker)}]
            with Store(home+'/.config/omarchy') as store:
                initial=store.load(); store.save(data,initial['revision'])
            # Keep stdin open: a rejected background launch must not wait for Enter.
            with subprocess.Popen([sys.executable,'-I',str(RUNNER),'cmd',initial['revision']],
                    env=dict(os.environ,HOME=home),stdin=subprocess.PIPE,stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,text=True) as process:
                try:
                    status=process.wait(timeout=5)
                    output,errors=process.communicate()
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.communicate()
            self.assertFalse(marker.exists())
            self.assertEqual(status,1)
            self.assertIn('Could not run',errors)
            self.assertNotIn('Press Enter',output)
