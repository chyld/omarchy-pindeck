# PinDeck

A workflow is often a few apps, a couple of folders, and a command you keep typing. PinDeck puts them together in your Omarchy bar. Make a group for each task, arrange its shortcuts, and open the whole group with one click.

Apps, folder shortcuts, and terminal commands share one compact panel. Groups collapse when you do not need them, and the same app or folder can belong to several groups with independent ordering and removal.

## How it works

- **Left click the bar icon** to open PinDeck.
- **Add app** searches the installed apps using Omarchy's visibility rules, including terminal applications.
- **Add folder** opens the system folder chooser. Folder shortcuts open in your default file manager.
- **Add command** saves a name and Bash command, such as `eza -a -l ~/Downloads`. Commands run from your home directory in the configured terminal, show their exit status, and wait for Enter before closing.
- **New group** collects related pins. Its launch button opens its apps, folders, and commands, even while collapsed.
- **Drag** to reorder pins and groups. Drop onto a group's center to move inside; use the bottom drop area to return to the top level. Escape cancels.
- **Right click** for desktop actions, moving, editing commands, renaming shortcuts or groups, and unpinning. Numbered buttons below apps expose their desktop actions; hover for names.
- **Edit config** opens `~/.config/omarchy/pinned.json` in Omarchy's default editor. Valid saved edits reload automatically.

Arrow keys select and Enter activates. Escape goes back or closes. Menu or Shift+F10 opens the selected pin's actions. Ctrl+N creates a group, Ctrl+O adds a folder, and Ctrl+K adds a command.

A group allows one copy of each app or canonical folder path, plus one at the top level. Moving into a group that already contains that item is rejected. Deleting a group returns its pins to the top level, retaining an existing copy there when one is already present.

## A group for each task

A **Development** group might hold your editor, a browser, the project folder, and a command that starts the development server. A **Photos** group might hold your photo editor and several picture folders. Open individual pins as needed, or use the group's rocket button to open the whole set.

For a command pin, enter a label such as **List downloads** and a command such as:

```sh
eza -a -l ~/Downloads
```

The command runs when you launch the pin or its group. Bash expands `~`, variables, pipes, and redirects; the terminal stays open for you to read the output.

## Configuration

Pins, groups, their order, and expanded states live in `~/.config/omarchy/pinned.json`. The **Edit config** button uses Omarchy's selected default editor. The file reloads when saved; an invalid edit displays an error while keeping the last valid data visible.

- `pinnedApps`: app, folder, and command pins. A `pinId` distinguishes independent copies; `folderId` identifies a group.
- `folders`: organizational groups with IDs, names, and expanded states.
- `rootOrder`: the order of top-level pins and groups.
- `version`: the configuration schema version, currently `1`.

Group IDs and pin IDs are stable references. A directory shortcut has `kind: "location"` and an absolute `path`; a command has `kind: "command"` and `commandText`.

## The icon

A pin marks PinDeck in the bar. Groups have a theme-colored four-square grid, folder shortcuts use folder icons, and commands use terminal icons. Each group's rocket button opens everything inside it.

## Install

Install and enable PinDeck from this repository:

```sh
omarchy plugin add https://github.com/chyld/omarchy-pindeck.git --enable
```

For a local checkout, copy the root QML and JavaScript files, `manifest.json`, and `bin/` into `~/.config/omarchy/plugins/chyld.pindeck/`, then validate, rescan, and enable:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/chyld.pindeck
omarchy-shell shell rescanPlugins
omarchy plugin enable chyld.pindeck
```

Requires Omarchy Quattro, Python 3, PyGObject (`python-gobject`), GTK 4, Bash, `uwsm-app`, `gtk-launch`, `xdg-terminal-exec`, `xdg-open`, and `notify-send`. Commands you add need their own programs installed.

## What it does to your system

- **Files written:** `~/.config/omarchy/pinned.json`, containing `version`, `pinnedApps`, `folders`, and `rootOrder`. Writes are atomic. Invalid edits preserve the last valid in-memory data and block UI saves until corrected.
- **Network access:** PinDeck does not fetch remote data. Apps and commands you launch can access the network and operate with your user permissions.
- **Credentials:** PinDeck has no credential store. Saved commands are plain text in the config file.
- **Commands run:** app launches through `uwsm-app` and `gtk-launch`; terminals through `xdg-terminal-exec`; folder selection and validation through `bin/locations.py`; folder opening through `xdg-open`; editor opening through `omarchy launch editor`; folder failure notifications through `notify-send`.
- **On load:** reads its config and installed desktop entries. On first use, it creates the config, preserving legacy inline settings when present. It does not install dependencies or launch your pins automatically.
- **Window focus:** after launching, waits for a matching window, focuses it, and moves the pointer to its center. Group launching tracks the final app or folder manager.
- **IPC:** the shell can summon the bar widget with `omarchy-shell shell summon chyld.pindeck '{}'`.

## Removing this plugin

```sh
omarchy plugin remove chyld.pindeck
```

Your `~/.config/omarchy/pinned.json` remains so your saved pins can be restored after reinstalling. Applications and commands already launched continue running.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin identity, metadata, and bar entry point |
| `BarWidget.qml` | Bar icon and panel lifecycle |
| `AppsPanel.qml` | Pins, groups, editors, drag/drop, and config persistence |
| `Launch.js`, `LaunchFocus.qml`, `Focus.js` | Launch commands and window focus |
| `Folders.js`, `Search.js`, `Config.js` | Organization, fuzzy search, and config validation |
| `ActionMenuItem.qml`, `TinyActionButton.qml` | App action controls |
| `bin/locations.py` | Native folder chooser and directory validation |
| `tests/` | Tests against shipped implementation files |

## Tests

```sh
node --test tests/*.test.cjs
python3 -m unittest discover -s tests -p 'test_*.py'
omarchy plugin validate .
```

Live checks should cover panel loading, keyboard and pointer actions, terminal launches, config edits, shell reloads, and multiple monitors. Portable tests alone do not establish those behaviors.

## License

MIT
