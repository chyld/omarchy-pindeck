#!/usr/bin/python3
"""Exercise production QML and real helper pipes in an isolated Quickshell host."""
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SHELL = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
QML = '''import QtQuick
import Quickshell
import "plugin" as Plugin
import "plugin/ui" as Ui
Scope {
    Plugin.Service { id: service }
    Ui.PinPanel { id: panel; service: service }
    Ui.PinPanel { id: secondPanel; service: service }
    property int stage: 0
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (stage === 6 && service.error) {
                if (panel.pins.length !== 1) { console.log("FAIL last good state"); Qt.quit(); return }
                console.log("REQUEST_DELETE"); stage = 7; return
            }
            if (stage === 7 && service.error) return
            if (service.error) { console.log("FAIL", service.error); Qt.quit(); return }
            if (!service.ready || service.busy) return
            if (stage === 0) {
                if (panel.rows.length !== 0) { console.log("FAIL initial rows"); Qt.quit(); return }
                panel.editFolder(""); panel.folderInput.text = "Test group"; panel.submitFolder()
                stage = 1
            } else if (stage === 1) {
                if (panel.folders.length !== 1) { console.log("FAIL group save"); Qt.quit(); return }
                panel.editCommand(null, panel.folders[0].id)
                panel.commandName.text = "Example"; panel.commandText.text = "printf example"; panel.saveCommand()
                stage = 2
            } else if (stage === 2) {
                if (panel.pins.length !== 1 || panel.rows.length !== 2) { console.log("FAIL command save"); Qt.quit(); return }
                panel.toggleFolder(panel.folders[0].id)
                stage = 3
            } else if (stage === 3) {
                if (panel.rows.length !== 1) { console.log("FAIL collapse"); Qt.quit(); return }
                panel.move(1)
                if (!panel.keyboardNavigation) { console.log("FAIL navigation"); Qt.quit(); return }
                service.refreshVisibility(); stage = 4
            } else if (stage === 4 && service.visibilityReady) {
                if (secondPanel.pins.length !== 1 || secondPanel.folders.length !== 1) { console.log("FAIL shared state"); Qt.quit(); return }
                console.log("REQUEST_EXTERNAL"); stage = 5
            } else if (stage === 5 && service.configData.external === true) {
                console.log("REQUEST_INVALID"); stage = 6
            } else if (stage === 7 && panel.pins.length === 0 && panel.folders.length === 0) {
                if (secondPanel.rows.length !== 0) { console.log("FAIL deletion synchronization"); Qt.quit(); return }
                console.log("PINDECK_RUNTIME_PASS"); Qt.quit()
            } else if (stage === 4 && service.visibilityError) {
                console.log("FAIL", service.visibilityError); Qt.quit()
            }
        }
    }
}
'''

def main():
    with tempfile.TemporaryDirectory(prefix='pindeck-runtime-') as directory:
        root = Path(directory)
        for entry in SHELL.iterdir():
            if entry.name != 'shell.qml': (root/entry.name).symlink_to(entry)
        (root/'plugin').symlink_to(ROOT, target_is_directory=True)
        (root/'shell.qml').write_text(QML)
        home = root/'home'; home.mkdir()
        # No real user state is exposed through HOME to helper operations.
        environment = dict(os.environ, HOME=str(home), QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software')
        log = root/'runtime.log'
        with log.open('w') as output_file:
            process = subprocess.Popen(['quickshell','-p',str(root/'shell.qml'),'--no-color'], env=environment,
                                       stdout=output_file, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 25
            handled = set()
            try:
                while process.poll() is None and time.monotonic() < deadline:
                    output = log.read_text()
                    config = home/'.config/omarchy/pindeck.json'
                    for marker in ('REQUEST_EXTERNAL', 'REQUEST_INVALID', 'REQUEST_DELETE'):
                        if marker in output and marker not in handled:
                            handled.add(marker)
                            if marker == 'REQUEST_EXTERNAL':
                                import json
                                data = json.loads(config.read_text()); data['external'] = True
                                config.write_text(json.dumps(data))
                            elif marker == 'REQUEST_INVALID': config.write_text('{broken')
                            else: config.unlink()
                    time.sleep(.025)
                if process.poll() is None: raise TimeoutError('Runtime test timed out: ' + log.read_text())
            finally:
                if process.poll() is None: process.terminate()
                process.wait(timeout=5)
        output = log.read_text()
        print(output)
        if 'PINDECK_RUNTIME_PASS' not in output or any(x in output for x in ('ReferenceError', 'TypeError', 'Unable to load', 'Cannot assign')):
            raise SystemExit('Runtime integration failed.')
        print('PASS: production panel, service, and helper integration')

if __name__ == '__main__': main()
