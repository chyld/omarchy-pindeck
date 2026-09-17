#!/usr/bin/python3
"""Ensure representative security and organization regressions fail real tests."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
MUTATIONS=[
 ('backend/storage.py','if self.revision(current) != expected:', 'if False:', ['python3','-m','unittest','discover','-s','tests','-p','test_storage.py']),
 ('backend/storage.py','if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:', 'if False:', ['python3','-m','unittest','discover','-s','tests','-p','test_storage.py']),
 ('backend/processes.py','if len(target) + len(chunk) > limit:', 'if False:', ['python3','-m','unittest','discover','-s','tests','-p','test_processes.py']),
 ('domain/Folders.js','return pin.folderId !== id','return true', ['node','--test','tests/folders.test.cjs']),
 ('domain/Config.js','Object.create(null)', '{}', ['node','--test','tests/properties.test.cjs']),
]
for filename,before,after,command in MUTATIONS:
    with tempfile.TemporaryDirectory(prefix='pindeck-mutation-') as directory:
        target=Path(directory)
        for name in ('backend','domain','tests'):
            shutil.copytree(ROOT/name,target/name,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
        file=target/filename; source=file.read_text()
        if before not in source: raise SystemExit('Mutation target no longer exists: '+filename)
        file.write_text(source.replace(before,after,1))
        result=subprocess.run(command,cwd=target,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
        if result.returncode==0: raise SystemExit('SURVIVED: '+filename+' '+before)
        print('KILLED:',filename,before)
print('PASS: all 5 representative regressions detected')
