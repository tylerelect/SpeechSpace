# Run SpeechSpace

Run commands from the repository root. Install Flutter and the IDE's Flutter/Dart
support first. Remote mode requires a local `.env` with `APP_DEV_TOKEN` matching
the deployed backend.

## Prepare (both IDEs)

Stop any running app. Use `flutter clean` after pulling major changes or when
builds are stale; it is not needed before every launch.

```bash
flutter clean
flutter pub get
flutter doctor
flutter devices
```

For remote mode, load your trusted local `.env` in the same terminal:

```bash
set -a
source .env
set +a
```

## Xcode (macOS)

```bash
python3 scripts/configure_ios_debug.py \
  --url https://course-rocks-purposes-transmitted.trycloudflare.com
flutter build ios --config-only --debug --no-codesign
open ios/Runner.xcworkspace
```

Select **Runner**, choose your iPhone or simulator, and confirm **Product > Scheme
> Edit Scheme > Run > Info > Debug**. For a physical iPhone, select your development
team under **Runner > Signing & Capabilities**. Press **Run (▶)**.

For demo mode, run `python3 scripts/configure_ios_debug.py --demo`, then Stop/Run.
The Git-ignored `ios/Flutter/Debug.local.xcconfig` survives normal regeneration.
`--no-codesign` above only prepares configuration; Xcode still signs device builds.

## Android Studio (Android device/emulator)

Create the Git-ignored token file from the environment loaded above:

```bash
python3 - <<'PY'
import json, os
from pathlib import Path
token = os.environ.get('APP_DEV_TOKEN', '')
assert token.strip(), 'Load APP_DEV_TOKEN from .env first'
p = Path('config/dev.local.json')
p.touch(mode=0o600, exist_ok=True)
p.chmod(0o600)
p.write_text(json.dumps({'DEV_API_TOKEN': token}, indent=2) + '\n')
PY
```

Open the **repository root** in Android Studio, not only `android/`.
On macOS: `open -a "Android Studio" .`

Start an emulator in **Device Manager**, or connect an Android phone with USB
debugging enabled. Select **SpeechSpace (Remote API)** and the device, then **Run**.
For offline demo, select **SpeechSpace (Demo)**; no token setup is required.

## Change the backend URL

- Xcode: rerun `configure_ios_debug.py --url https://api.speechspace.health`.
- Android Studio: edit `API_BASE_URL` in the Remote API run configuration
  (`.run/SpeechSpace_Remote_API.run.xml`).

Use the permanent hostname only after its HTTPS route works. Quick Tunnel URLs
can change. Stop/Run after changing defines. Never commit either local token file.

The local Xcode override also affects Debug **iOS** runs from Android Studio or
Flutter CLI. Remove `ios/Flutter/Debug.local.xcconfig` to use those launch arguments;
regenerate it when returning to Xcode. Android builds are unaffected.
