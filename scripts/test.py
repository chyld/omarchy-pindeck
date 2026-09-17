#!/usr/bin/python3
"""One entry point for portable tests; --runtime adds the installed-shell harness."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--runtime',action='store_true')
    args=parser.parse_args()
    os.chdir(ROOT)
    subprocess.run(['node','--test',*map(str,sorted(Path('tests').glob('*.test.cjs')))],check=True)
    subprocess.run([sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py'],check=True)
    subprocess.run([sys.executable,'scripts/check_source.py'],check=True)
    runner=shutil.which('qmltestrunner') or next((str(p) for p in (Path('/usr/lib/qt6/bin/qmltestrunner'),Path('/usr/lib/qt6/bin/qmltestrunner6')) if p.exists()),None)
    if not runner: raise SystemExit('Qt 6 qmltestrunner is required for component tests.')
    subprocess.run([runner,'-input','tests/qml','-import','tests/qml/imports','-o','-,txt'],check=True,
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'))
    if shutil.which('omarchy'): subprocess.run(['omarchy','plugin','validate','.'],check=True)
    if args.runtime: subprocess.run([sys.executable,'scripts/test_runtime.py'],check=True)

if __name__=='__main__': main()
