# Security boundaries

PinDeck is unsandboxed user code hosted in Omarchy. Its purpose includes executing
commands explicitly saved and launched by the user. It provides no isolation from
other programs with the same user privileges, and saved commands are not secrets
managed by a credential vault. No network client, privilege elevation, dependency
installer, or public mutation IPC is included.

## Configuration

The version-one JSON format and `~/.config/omarchy/pindeck.json` path remain stable.
The helper traverses directories with held descriptors and refuses symlinked
components. Files must be regular, owned by the user, single-link, and not writable
by group/other. Symlinked XDG directories are deliberately unsupported. Existing
0644 files are accepted for compatibility; writes create private 0600 files.

Reads are capped at 512 KiB before parsing; limits are 1,000 pins, 100 groups,
256-character names, 4,096-character paths, 16,384-character commands, and nesting
depth 16. Unsupported schema, invalid data, and unsafe files retain the last valid
view and block saves. Only absence permits default recreation. Legacy `pinned.json`
and inline settings import only before the current file has been observed.

A private advisory lock serializes cooperating writers; a content revision detects
stale saves. Forms also reject a changed revision. External editors do not share
our lock and can still race the final comparison and atomic replacement. Atomic
writes prevent torn files, not all possible concurrent-editor conflicts. The helper
checks writes and syncs the file and directory. An error after replacement can mean
the new file exists but durability was not confirmed; reload reconciles the view.

## Processes and rendering

Requests are limited to 1 MiB. Helpers run in separate process groups, with 2 MiB
stdout and 4 KiB stderr ceilings enforced before collection in QML. Ordinary work
has a 10-second deadline; a native folder chooser allows five minutes. Cancellation
and parent death terminate supervised groups. The inotify watcher emits only fixed
change notifications, debounced to avoid a refresh storm; a periodic fallback and
bounded restart budget handle watcher failures.

Saved commands are resolved by pin identity and configuration revision in a terminal
runner. Command bytes reach Bash through an anonymous descriptor, leaving terminal
stdin available and avoiding full command text in launcher argv. The command may
itself expose secrets or perform arbitrary actions. Bash login profiles and normal
user application environments are intentional features, not trusted sandboxes.

All plugin Text elements use PlainText. Application icons use theme names; absolute
PNG paths are read with byte/type checks, decoded outside the shell, limited to
1,024 × 1,024 source pixels, normalized to at most 64 × 64, and delivered as bounded
PNG data. Unsafe, unsupported, or unavailable images use a generic icon. No remote
image URL or raw SVG from configuration is loaded into the shell. The icon cache
holds at most 128 entries. Desktop visibility scanning visits at most 10,000 entries
and reads at most 64 KiB per desktop file; symlinked entries are excluded.

A group launch is limited to 100 items, started sequentially. App/action IDs cannot
be interpreted as options or shell source. Temporary helpers are owned by PinDeck;
user-launched applications intentionally survive panel closure and plugin removal.

## Evidence

The tests cover concrete boundary failures, not a claim of complete security.
See TESTING.md for portable, runtime, mutation, and live-host evidence. Marketplace
rules and installed Omarchy API contracts take precedence over third-party examples.
