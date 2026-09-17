# Testing PinDeck

Run `python3 scripts/test.py` for the Node domain tests, Python backend tests, source
invariants, QtTest components, and installed Omarchy validation when available.
Qt 6 qmltestrunner is required; it is not silently skipped. No production packages
are installed by the test runner. GitHub CI installs only its own test dependencies.

`python3 scripts/test_runtime.py` requires Omarchy and a Wayland session. It creates
an isolated HOME and imports the real shell UI modules. Two production panels share
one production service and real Python helper pipes. It checks creation, saving,
collapse, keyboard state, catalog loading, cross-panel synchronization, external
edits, invalid-file retention, and deletion recovery. It never uses the real pins.

`python3 scripts/test_mutations.py` deliberately removes five independent guards in
temporary copies and requires the corresponding test suites to fail. These probes
cover stale revisions, file type/ownership, output limits, group deletion, and
prototype-like identifiers. This is targeted mutation testing, not exhaustive.

`python3 scripts/test_coverage.py` reports Node line/branch/function coverage and
Python standard-library trace line coverage. Python subprocess integration paths
are tested but are not included in the in-process trace figures. Coverage of a
line containing multiple conditions does not prove every condition is exercised.

## Fixtures and scope

- Unit tests exercise shipped modules rather than duplicated reference logic.
- 5,000 seeded random grouping/reordering operations check identity, uniqueness,
  visible membership, normalized order, and lack of input mutation.
- Storage tests cover missing/invalid files, migration, repeated deletion, stale
  writes, symlinks, hard links, FIFOs, permissions, byte/depth limits, held-descriptor
  races, short writes, failed sync/replacement, and lock contention.
- Process tests cover both output streams, deadlines after pipe closure, stubborn
  descendants, missing executables, nonzero exits, and real request/response pipes.
- Command tests execute only fictional commands inside temporary homes, checking
  terminal stdin, exit reporting, and rejection of changed configuration.
- QtTest uses narrow palette/host-button stubs to test actual PinRow and tooltip
  components. It checks event routing, alignment, hover selection, and PlainText.
  Those stubs do not establish real Omarchy theme or layer-shell compatibility.

## Live acceptance checklist

Record the candidate commit and host version with results in VALIDATION.md:

- Existing configuration loads without changing pin identities or order.
- One singleton service and watcher for all monitors.
- Open/close, outside click, Escape, keyboard and pointer navigation.
- Pin/reorder/group/edit/unpin with fictional data; no changes to real user pins.
- Folder chooser cancel, folder launch, GUI launch, desktop action, terminal command.
- Theme change and horizontal/vertical placement.
- QML reload, shell restart, disabled/re-enabled service, clean installation/removal.
- Temporary helpers stop; applications explicitly launched by the user remain.

Unavailable or unperformed checks must stay labeled unverified. A screenshot and a
passing manifest validator do not substitute for runtime behavior tests.
