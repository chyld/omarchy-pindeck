# PinDeck

**Your next task, one click away.**

Before you can work, you have to open everything: the editor, the browser, the project folder, the terminal running that command you always forget. Tomorrow, you do it again.

PinDeck puts that setup in your Omarchy bar. Collect apps, folders, and commands into a named group, arrange them once, and click its lightning bolt to open the whole set. Keep your everyday favorites at the top level and collapse the rest until you need them.

A deck for each project. A place for every shortcut. Less setup between you and the work.

## Build a deck for what you do

| Group | What goes inside |
| --- | --- |
| **Development** | Your editor, browser, project folder, and a command to start the dev server |
| **Photos** | Your photo editor, camera imports, and the folder where finished pictures go |
| **Daily** | Mail, notes, Downloads, and your morning terminal commands |
| **A specific project** | The apps, directories, and commands that belong to that project |

Open a single pin when that is all you need. Open the group when it is time to get started. The lightning bolt works even when the group is collapsed.

## Three kinds of pins, one place

**Apps.** Click **Add app**, fuzzy-search your installed applications, and pin one. GUI and terminal apps are both supported. An app's own actions—such as opening a private browser window—are available through its right-click menu and small numbered buttons. Hover a button to see what it does.

**Folders.** Click **Add folder** and choose a directory. Home, Downloads, a deep project directory: each becomes a shortcut that opens in your default file manager. Give it a useful name; hover to see the full path.

**Commands.** Click **Add command**, give it a name, and save the command you want to run. For example, **List downloads**:

```sh
eza -a -l ~/Downloads
```

Commands run in your configured terminal using Bash, starting from your home directory. `~`, variables, pipes, and redirects work. When the command finishes, the terminal shows its exit status and waits for Enter, so the output does not disappear before you can read it.

## Arrange it your way

- **Create groups** with **Add group**. Right-click a group to add apps, folders, or commands directly inside it.
- **Drag to reorder** pins and groups. Drop a pin onto a group's center to move it inside, or onto the bottom drop area to move it back to the top level.
- **Reuse your favorites.** The same app or folder can appear in several groups, plus once at the top level. Each copy has its own position; folder copies can have different names.
- **Change things in place.** Right-click to move or unpin an item, rename a folder shortcut, or edit a command. Removing one copy leaves the others alone.
- **Delete a group and its pins.** Copies at the top level or in other groups remain. The underlying apps and files are unaffected.

Groups use a four-square grid icon, folders use folder icons, and commands use terminal icons. The panel follows your Omarchy theme and keeps the layout compact.

## Install

```sh
omarchy plugin add https://github.com/chyld/omarchy-pindeck.git --enable
```

Click the four-tile icon in your bar, add your first few items, and make a group when you are ready.

PinDeck requires Omarchy Quattro, Python 3, PyGObject (`python-gobject`), GTK 4, GdkPixbuf, Bash, `uwsm-app`, `gtk-launch`, `xdg-terminal-exec`, `xdg-open`, and `notify-send`. Programs used in your saved commands must be installed separately.

## Keyboard controls

| Key | Action |
| --- | --- |
| ↑ / ↓ | Select an item |
| Enter | Open, pin, or expand the selected item |
| Escape | Go back, cancel a drag, or close the panel |
| Menu / Shift+F10 | Open the selected item's actions |
| Ctrl+N | Create a group |
| Ctrl+O | Add a folder shortcut |
| Ctrl+K | Add a command |

To open PinDeck from a keybinding or another tool:

```sh
omarchy-shell shell summon chyld.pindeck '{}'
```

## Your configuration is yours

Everything you arrange is stored in:

```text
~/.config/omarchy/pindeck.json
```

Manage your pins and groups through the panel. Valid external configuration changes reload automatically. If an edit is invalid, PinDeck displays an error and keeps the last valid data visible instead of replacing your setup.

Deleting `pindeck.json` while PinDeck is running resets the panel and recreates the file with empty pins and groups.

The file is plain JSON: `pinnedApps` holds your pins, `folders` holds your groups, and `rootOrder` records their top-level order. Stable `pinId` and `folderId` values connect the pieces; `version` is currently `1`. Directory shortcuts use `kind: "location"` with an absolute `path`; commands use `kind: "command"` with `commandText`.

Existing `pinned.json` data is imported when `pindeck.json` does not yet exist. The old file remains as a backup. You can copy your configuration between machines; matching apps and command dependencies need to be installed there too.

## What it does to your system

PinDeck runs inside the Omarchy shell. It reads installed desktop entries and saves its configuration through a supervised Python helper with bounded reads and atomic writes. It creates the config on first use, importing older settings when available. Opening the panel does not launch your pins; you choose when an item or group runs.

- **App launches** use `uwsm-app` and `gtk-launch`; terminal launches use `xdg-terminal-exec`.
- **Folder shortcuts** use a native chooser and open through `xdg-open`. An unavailable folder reports an error without stopping the remaining group launches.
- **Focus** follows a matching launched window, with the pointer moved to its center. Group launches track the final app or folder manager.
- **Network and credentials:** PinDeck fetches no remote data and has no credential store. Saved commands are plain text. The apps and commands you launch run with your user permissions and may access files, credentials, or the network as those programs normally do.
- **Configuration:** PinDeck writes `~/.config/omarchy/pindeck.json` and a private `.pindeck.lock` alongside it. New configuration writes use mode `0600`; compatible older `0644` files become private on the next save. It does not install dependencies or add startup commands.

## Remove

```sh
omarchy plugin remove chyld.pindeck
```

Your `pindeck.json`, any legacy `pinned.json`, and `.pindeck.lock` remain for a future reinstall. Temporary helpers and the configuration watcher stop with the plugin. Apps and commands already launched continue running.

## Development

The root `manifest.json`, `BarWidget.qml`, and `Service.qml` are the plugin entry points. The shared service coordinates configuration across monitors. `ui/` contains views, `controllers/` contains interaction and launch coordination, `domain/` contains pure JavaScript logic, and `backend/` contains bounded filesystem and helper operations.

```sh
python3 scripts/test.py
python3 scripts/test_mutations.py
python3 scripts/test_coverage.py
# On an Omarchy desktop, using an isolated configuration:
python3 scripts/test_runtime.py
```

Qt 6 QML Test, Quick, and Controls modules are needed for component tests. See [testing](docs/TESTING.md) and [security boundaries](docs/SECURITY.md).

Desktop checks should also cover loading, keyboard and pointer interactions, launches, config edits, shell reloads, and multiple monitors. Portable tests alone do not verify those behaviors.

## License

[MIT](LICENSE) · Chyld Medford
