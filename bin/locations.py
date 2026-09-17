#!/usr/bin/env python3
"""Choose and validate local directories; communicate with QML using JSON."""
import json
import os
from pathlib import Path
import sys


def directory(value):
    path = Path(value).expanduser().resolve()
    if not path.is_dir():
        raise ValueError("This folder is missing or unavailable: " + str(path))
    return {"path": str(path), "name": path.name or "/", "uri": path.as_uri()}


def choose():
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk, Gio, GLib
    Gtk.init()
    loop = GLib.MainLoop()
    dialog = Gtk.FileChooserNative.new("Pin a folder", None, Gtk.FileChooserAction.SELECT_FOLDER, "Pin folder", "Cancel")
    dialog.set_current_folder(Gio.File.new_for_path(os.path.expanduser("~")))

    def response(chooser, result):
        try:
            if result == Gtk.ResponseType.ACCEPT:
                selected = chooser.get_file()
                path = selected.get_path() if selected else None
                if not path:
                    raise ValueError("Choose a local folder.")
                print(json.dumps(directory(path)), flush=True)
            else:
                print(json.dumps({"cancelled": True}), flush=True)
        except Exception as error:
            print(json.dumps({"error": str(error)}), flush=True)
        finally:
            chooser.destroy()
            loop.quit()
    dialog.connect("response", response)
    dialog.show()
    loop.run()


if __name__ == "__main__":
    try:
        if sys.argv[1] == "choose":
            choose()
        else:
            result = directory(sys.argv[2])
            import gi
            from gi.repository import Gio
            app = Gio.AppInfo.get_default_for_type("inode/directory", False)
            result["desktopId"] = app.get_id() if app else ""
            print(json.dumps(result))
    except Exception as error:
        print(json.dumps({"error": str(error)}))
        sys.exit(1)
