# Rewrite validation

Candidate: `789b3048f2ded5920ba54c2e9be125ad2195d828` (0.2.0).
Local host: Omarchy 4.0.4, Qt 6.11.2, Wayland; 2026-09-17.

## Passed locally

- `python3 scripts/test.py --runtime`: 40 Node tests; 35 Python tests;
  four QtTest component tests plus initialization/cleanup; source invariants;
  installed Omarchy manifest validation; isolated production runtime integration.
- The domain suite includes 5,000 seeded randomized operations.
- Runtime integration uses two actual production panels sharing one service,
  actual helper processes, and an isolated HOME. Creation, save, collapse,
  keyboard state, catalog load, cross-panel updates, external valid edits,
  invalid-edit retention, and deleted-file recreation passed.
- `python3 scripts/test_mutations.py`: all five deliberate regressions detected.
- `python3 scripts/test_coverage.py`: domain JavaScript line coverage 100%,
  branch coverage 91.67%, function coverage 100%. Python in-process line coverage:
  schema 100%, icons 100%, storage 96.6%, catalog 91.5%, processes 89.2%,
  locations 28.9%. Main protocol, watcher, and terminal subprocess paths have
  integration tests but are not measured by the in-process Python tracer.
- Existing user configuration (12 pins, two groups) passed validation and remained
  byte-for-byte unchanged after installing the rewrite. A private local backup
  was taken before installation; no configuration contents are committed.
- `git diff --check` passed.
- GitHub Actions passed on Ubuntu 24.04 for the implementation candidate:
  [portable tests, mutation checks, and coverage](https://github.com/chyld/omarchy-pindeck/actions/runs/35198595660).

The isolated shell logged a desktop portal registration warning because a live
shell already owned the connection. It loaded its QML and completed the tests.

## Installed desktop checks still outstanding

The installed checkout was upgraded. `omarchy restart shell` refused to restart
while the session was locked. No attempt was made to bypass that protection.
Consequently, visible popup inspection and confirmation that the running installed
shell uses this candidate remain unverified. After unlocking, run
`omarchy restart shell` and complete the live checklist in TESTING.md.

Also unverified: native chooser interaction/cancellation, real GUI and desktop-action
launches, theme/vertical-bar changes, disabled/re-enabled service, and full clean
installation/removal. The QtTest components use narrow host stubs; isolated runtime
tests import the actual Omarchy modules but do not replace these manual checks.

These results are regression evidence, not a complete security certification.
