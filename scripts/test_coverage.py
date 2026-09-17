#!/usr/bin/python3
"""Dependency-free line coverage for in-process Python tests, plus Node coverage.
Subprocess integration paths are tested separately and are not counted by trace.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import trace
import unittest

ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
sys.path.insert(0,str(ROOT))
tracer=trace.Trace(count=True,trace=False,ignoredirs=[sys.prefix])
def exercise():
    suite=unittest.defaultTestLoader.discover('tests',pattern='test_*.py')
    return unittest.TextTestRunner().run(suite)
result=tracer.runfunc(exercise)
with tempfile.TemporaryDirectory(prefix='pindeck-coverage-') as directory:
    report=tracer.results()
    report.write_results(show_missing=True,summary=True,coverdir=directory)
subprocess.run(['node','--experimental-test-coverage','--test',*map(str,sorted(Path('tests').glob('*.test.cjs')))],check=True)
if not result.wasSuccessful(): raise SystemExit(1)
