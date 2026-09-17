"""Native folder selection and bounded metadata for explicit user launches."""
import os
from pathlib import Path
from .schema import text, MAX_PATH


def directory(value):
    text(value, MAX_PATH, 'folder path')
    path = Path(value).expanduser().resolve()
    if not path.is_dir(): raise ValueError('This folder is missing or unavailable.')
    return {'path': str(path), 'name': (path.name or '/')[:256], 'uri': path.as_uri()}


def check(value):
    result = directory(value)
    import gi
    from gi.repository import Gio
    app = Gio.AppInfo.get_default_for_type('inode/directory', False)
    result['desktopId'] = app.get_id() if app else ''
    return result


def choose():
    import gi
    gi.require_version('Gtk', '4.0')
    from gi.repository import Gtk, Gio, GLib
    Gtk.init()
    loop = GLib.MainLoop()
    result = {'cancelled': True}
    dialog = Gtk.FileChooserNative.new('Pin a folder', None, Gtk.FileChooserAction.SELECT_FOLDER, 'Pin folder', 'Cancel')
    dialog.set_current_folder(Gio.File.new_for_path(os.path.expanduser('~')))
    def response(chooser, code):
        nonlocal result
        try:
            if code == Gtk.ResponseType.ACCEPT:
                selected = chooser.get_file()
                path = selected.get_path() if selected else None
                if not path: raise ValueError('Choose a local folder.')
                result = directory(path)
        except Exception:
            result = {'error': 'Could not select this folder.'}
        finally:
            chooser.destroy(); loop.quit()
    dialog.connect('response', response)
    dialog.show(); loop.run()
    return result
