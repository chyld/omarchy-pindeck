import os
import sys
import time
import unittest
from backend.processes import run, ProcessFailure

class ProcessTest(unittest.TestCase):
    def test_roundtrip(self):
        self.assertEqual(run([sys.executable,'-c','import sys; sys.stdout.buffer.write(sys.stdin.buffer.read())'],b'hello'),b'hello')
    def test_both_streams_are_bounded(self):
        for stream in ('stdout','stderr'):
            with self.assertRaises(ProcessFailure):
                run([sys.executable,'-c',f'import sys; sys.{stream}.write("x"*100000)'],output_limit=64,error_limit=64)
    def test_timeout_even_when_pipes_are_closed(self):
        started=time.monotonic()
        with self.assertRaises(ProcessFailure):
            run([sys.executable,'-c','import os,time; os.close(1); os.close(2); time.sleep(10)'], timeout=.1)
        self.assertLess(time.monotonic()-started,2)
    def test_nonzero_and_missing_executable(self):
        with self.assertRaises(ProcessFailure): run([sys.executable,'-c','raise SystemExit(3)'])
        with self.assertRaises(FileNotFoundError): run(['/does-not-exist'])
    def test_stubborn_descendant_does_not_hold_operation_open(self):
        started=time.monotonic()
        code='import os,signal,time; os.fork(); signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(30)'
        with self.assertRaises(ProcessFailure): run([sys.executable,'-c',code], timeout=.15)
        self.assertLess(time.monotonic()-started,2)
