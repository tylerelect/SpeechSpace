# Startup follow-up after the UI checkpoint

The pre-UI-import checkpoint remains the original snapshot. Preserve these later
changes too when integrating another developer's UI:

- `lib/services/app_controller.dart`: read optional saved-profile preferences
  concurrently with the initial repository load. Limit the preferences read to
  two seconds, fall back to the chooser if unavailable, and do not wait for stale
  selection cleanup. Late preferences cannot unexpectedly switch profiles.
- `lib/screens/app_shell.dart`: describe the loading state instead of displaying
  an unexplained spinner.
- `test/startup_test.dart`: cover a stuck preferences read, late completion,
  concurrent startup work, HTTP timeout, and retry recovery.

The remote snapshot still has its existing 15-second HTTP timeout and requires
the backend to respond before profiles are usable. This change does not add an
offline cache or make a slow backend respond faster. `main.dart` already calls
runApp without awaiting initialization, so this addresses in-app loading rather
than native engine/debugger attachment before the first Flutter frame.

Validation: 109 Flutter tests passed, one opt-in live-backend test skipped;
analysis reported 25 existing deprecation infos and no errors/warnings. The
updated Xcode Debug simulator build launched and displayed the remote Test Adult
and Test Kid profiles. Physical Android/iPhone startup and the earlier LLDB symbol
resolution delay remain unverified. Flutter attach could not discover the
simulator VM service (mDNS failure); hot restart was not verified.
