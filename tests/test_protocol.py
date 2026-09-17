import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

MAIN=Path(__file__).resolve().parents[1]/'backend/main.py'
class ProtocolTest(unittest.TestCase):
    def request(self, home, data):
        raw=json.dumps(data).encode() if isinstance(data,dict) else data
        result=subprocess.run([sys.executable,'-I',str(MAIN)],input=raw,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
            env=dict(os.environ,HOME=home,PATH='/nonexistent',PYTHONPATH='/nonexistent'),timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertLessEqual(len(result.stdout),2*1024*1024)
        return json.loads(result.stdout)
    def test_real_pipes_initialize_save_reload_and_delete(self):
        with tempfile.TemporaryDirectory() as home:
            loaded=self.request(home,{'id':1,'op':'load'})
            self.assertTrue(loaded['ok'],loaded)
            data=loaded['result']['data'];data['folders']=[{'id':'g','name':'Group'}]
            saved=self.request(home,{'id':2,'op':'save','data':data,'revision':loaded['result']['revision']})
            self.assertTrue(saved['ok'],saved)
            self.assertEqual(self.request(home,{'id':3,'op':'load'})['result']['data'],data)
            Path(home+'/.config/omarchy/pindeck.json').unlink()
            self.assertEqual(self.request(home,{'id':4,'op':'load','seen':True})['result']['data']['folders'],[])
    def test_invalid_request_unknown_op_and_oversize_fail_closed(self):
        with tempfile.TemporaryDirectory() as home:
            for request in [b'{bad',{'id':2,'op':'run','command':'echo unwanted'},b'x'*1048577,{'id':True,'op':'load'}]:
                self.assertFalse(self.request(home,request)['ok'])
            self.assertFalse(Path(home+'/.config/omarchy/pindeck.json').exists())
