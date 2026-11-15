# Local run config

## Shared repository versus local machine

Commit the `.run` launch configurations, the placeholder example JSON, and the
optional include in `ios/Flutter/Debug.xcconfig`. Do not commit `.env`,
`config/*.local.json`, or `ios/Flutter/Debug.local.xcconfig`.

On another computer, the missing optional Xcode file does not prevent builds.
Flutter uses its normally generated Dart defines (demo if no API URL is supplied).
For Xcode remote development, follow `docs/xcode-debug-backend.md` and generate
that computer's local file. Android Studio's Android/web runs keep using the
launch configurations below. Release/Profile do not include the Xcode override.

On a Mac with the Xcode override installed, it also overrides Debug iOS runs
launched from Flutter or Android Studio. To use their iOS launch arguments,
remove `ios/Flutter/Debug.local.xcconfig`; regenerate it with the documented script
when returning to Xcode. No app source or shared project setting needs changing.

## Android Studio

1. `cp config/dev.local.example.json config/dev.local.json`
2. Put the backend's `APP_DEV_TOKEN` value in `DEV_API_TOKEN`. `dev.local.json` is gitignored.
   Flutter never reads `.env` (only the Python backend does), so copy the value over, e.g.
   `python3 -c "import re,json;t=[re.split('=',l,1)[1].strip().strip('\"\'') for l in open('.env') if l.strip().startswith('APP_DEV_TOKEN=')][0];json.dump({'DEV_API_TOKEN':t},open('config/dev.local.json','w'))"`
3. In Android Studio pick **SpeechSpace (Remote API)** and press Run.

Changing the backend URL: edit `API_BASE_URL` in `.run/SpeechSpace_Remote_API.run.xml`
(Run > Edit Configurations > Additional run args), e.g. `https://api.speechspace.health`.

Limitation: Android Studio run configs cannot read OS env vars into Flutter args, so the token
lives in a local gitignored file passed via `--dart-define-from-file`. As the README warns,
the token is embedded in the built app; use only for private synthetic-data dev.
