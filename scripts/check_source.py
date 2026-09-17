#!/usr/bin/python3
"""Small auditable invariants; this is not a security certification or QML parser."""
import json
from pathlib import Path
import re

root=Path(__file__).resolve().parents[1]
errors=[]
manifest=json.loads((root/'manifest.json').read_text())
assert manifest['id']=='chyld.pindeck'
assert manifest['schemaVersion']==1
for entry in manifest['entryPoints'].values():
    path=root/entry
    if not path.is_file() or not path.resolve().is_relative_to(root): errors.append('Invalid entry point: '+entry)
for path in [root/'BarWidget.qml',root/'Service.qml',*root.glob('ui/**/*.qml'),*root.glob('controllers/*.qml')]:
    source=path.read_text()
    for token in ('StdioCollector','FileView','ShellRoot'):
        if re.search(r'\b'+token+r'\s*\{',source): errors.append(f'{path.name}: forbidden production {token}')
    for match in re.finditer(r'\bText\s*\{',source):
        cursor=match.end();depth=1
        while cursor<len(source) and depth:
            depth+=(source[cursor]=='{')-(source[cursor]=='}');cursor+=1
        if 'textFormat: Text.PlainText' not in source[match.end():cursor]: errors.append(f'{path.name}: Text without explicit PlainText')
if errors: raise SystemExit('\n'.join(errors))
print('PASS: manifest paths, plain-text views, bounded-I/O component invariants')
