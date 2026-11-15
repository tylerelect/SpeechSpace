# Build and install Release on Tyler's iPhone

Run from the repository root on the Mac. Connect and unlock the iPhone. Developer
Mode, computer trust, and Xcode signing must already be configured.

## 1. Synchronize local credentials

The local `.env` must contain `APP_DEV_TOKEN` matching the deployed backend.

```bash
python3 scripts/configure_ios_debug.py \
  --url https://api.speechspace.health --sync-android
flutter pub get
flutter devices
```

This creates the Git-ignored `config/dev.local.json` used below. It synchronizes
the existing token; it does not rotate the backend token.

## 2. Build the signed Release app

```bash
flutter build ios --release \
  --dart-define-from-file=config/dev.local.json \
  --dart-define=API_BASE_URL=https://api.speechspace.health
```

Output: `build/ios/iphoneos/Runner.app`. Xcode uses the project's configured
development team to sign it. This is a device Release build for the prototype,
not an App Store production deployment. Use synthetic test data.

## 3. Install and launch

```bash
xcrun devicectl device install app \
  --device 00008140-001054EC3A79801C \
  build/ios/iphoneos/Runner.app

xcrun devicectl device process launch \
  --device 00008140-001054EC3A79801C \
  com.example.speechspace
```

These Apple device commands successfully installed and launched the signed
Release app on November 15, 2026. After installation, open SpeechSpace directly
from the iPhone; Xcode does not need to remain open. Installation replaces the
existing app with the same bundle identifier.

## Optional combined Flutter command

```bash
flutter run --release -d 00008140-001054EC3A79801C \
  --dart-define-from-file=config/dev.local.json \
  --dart-define=API_BASE_URL=https://api.speechspace.health \
  --no-resident
```

In the verified session, this compiled and signed successfully but failed during
installation/launch. The direct `devicectl` commands above then succeeded. If the
combined command fails after building, use step 3 without rebuilding.

## Notes

- For another iPhone, replace the device ID with the one from `flutter devices`.
- After pulling major changes or diagnosing a stale build, run `flutter clean`
  followed by `flutter pub get`, then repeat the build. Cleaning is not required
  for every installation.
- Changing the token or URL requires a rebuild and reinstall.
- `ios/Flutter/Debug.local.xcconfig` affects Debug only; Release receives the
  explicit Dart defines above.
- The backend returned HTTP 403 to health and authenticated snapshot checks from
  this Mac during the verified session. Successful installation and launch do not
  prove backend data access. Check the permanent route and access rules separately.
- Never commit `.env`, local token JSON, or the signed app bundle.
