# PinDeck rewrite

The plugin remains `chyld.pindeck`, hosted in the Omarchy shell. A singleton
service owns one configuration snapshot and serializes requests. Visual instances
own only local interaction state. QML views emit actions; the controller applies
pure domain transitions and asks the service to persist them.

The Python backend owns bounded descriptor-based config I/O. It exchanges bounded
JSON over private pipes with a supervised worker. No network, privilege elevation,
public mutation IPC, agent invocation, or dependency installation is introduced.

Keep the existing version-1 config format, pin identities and accepted UI. Import
legacy settings only when no current config has been observed. Deletion after load
creates empty defaults. Invalid or unsafe files preserve the last valid snapshot.
Save conflicts are reported instead of silently overwriting detectable revisions.
Cooperating writers share a lock; arbitrary external editors can still race the
last revision check and atomic replacement. This is not a same-user sandbox.

User commands are intentionally executable and applications launched by users are
not owned temporary helpers. They continue after panel dismissal. Temporary helper
processes are supervised and cleaned up. Saved command text is private configuration,
not a credential vault. Do not promise isolation from other processes of the user.

Implementation stages: domain/storage → shared service → modular views/controllers
→ lifecycle/security tests → isolated live smoke test → installed upgrade.

Acceptance: preserve existing tests, add randomized domain operations, adversarial
storage and process tests, QML interactions, real Quickshell protocol tests, and a
recorded live checklist. Never exercise destructive tests on real configuration.
