# Local run config

## Shared repository versus local machine

Commit the `.run` launch configurations, the placeholder example JSON, and the
optional include in `ios/Flutter/Debug.xcconfig`. Do not commit `.env`,
`config/*.local.json`, or `ios/Flutter/Debug.local.xcconfig`.

On another computer, the missing optional Xcode file does not prevent builds.
Flutter uses its normally generated Dart defines. The default API is
`https://api.speechspace.health`; missing credentials show a configuration error.
For Xcode remote development, follow `docs/xcode-debug-backend.md` and generate
that computer's local file. Android Studio's Android runs keep using the
launch configurations below. Release/Profile do not include the Xcode override.

On a Mac with the Xcode override installed, it also overrides Debug iOS runs
launched from Flutter or Android Studio. To use their iOS launch arguments,
remove `ios/Flutter/Debug.local.xcconfig`; regenerate it with the documented script
when returning to Xcode. No app source or shared project setting needs changing.

## Android Studio

Run from the repository root to synchronize both IDEs from `.env` automatically:

```sh
python3 scripts/configure_ios_debug.py --url https://api.speechspace.health --sync-android
```

Then select **SpeechSpace (Remote API)** and press Run. No token copy/paste is
needed. The local JSON includes the URL, so it stays aligned with Xcode. Rerun
with the desired URL to change it. This does not rotate the deployed token.

The shared `.run/SpeechSpace_Remote_API.run.xml` also supplies the permanent URL.
Keep it aligned if changing the default for the whole team.

Limitation: Android Studio run configs cannot read OS env vars into Flutter args, so the token
lives in a local gitignored file passed via `--dart-define-from-file`. As the README warns,
the token is embedded in the built app; use only for private synthetic-data dev.
