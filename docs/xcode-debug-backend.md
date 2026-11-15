# Run the remote backend from Xcode

Open `ios/Runner.xcworkspace`, select the **Runner** scheme and your iPhone (or
simulator), then choose **Product > Scheme > Edit Scheme > Run > Info** and
confirm **Build Configuration: Debug**. Close the dialog and press **Run (▶)**.
No `flutter run` command or scheme environment variables are needed.

## Configure this Mac

From the repository root, load the trusted local `.env` and generate the override:

```sh
set -a
source .env
set +a
python3 scripts/configure_ios_debug.py \
  --url https://api.speechspace.health
```

The script reads `APP_DEV_TOKEN` and writes `ios/Flutter/Debug.local.xcconfig`
with owner-only permissions. That file is Git-ignored. It supplies the existing
`API_BASE_URL` and `DEV_API_TOKEN` compile-time contracts as comma-separated
Base64 `KEY=value` entries in Flutter's `DART_DEFINES` build setting. It never
prints the token. Base64 is encoding, not encryption; this token remains embedded
in the compiled development app. Use synthetic test data only.

`Debug.xcconfig` includes the local file **after** `Generated.xcconfig`, so it
overrides generated Debug defines and survives `flutter pub get`, `flutter clean`,
and normal Flutter configuration regeneration. Do not edit Generated.xcconfig or
flutter_export_environment.sh. Existing build/prepare/embed scripts and schemes
are unchanged. Release and Profile still use their existing Release.xcconfig.

The local override replaces the Debug DART_DEFINES list, including any generated
CLI defines. Remove the local file to return to standard Flutter CLI behavior.
Other platforms are unaffected. Avoid posting full Xcode build settings/logs,
which may include the encoded token.

On a fresh checkout, first run `flutter pub get` and, if iOS generated files are
missing, `flutter build ios --config-only --debug --no-codesign` once. This is
configuration preparation, not required before each Xcode Run.

## Switch URLs or tokens

After `https://api.speechspace.health` is routed to the backend and HTTPS works:

```sh
set -a
source .env
set +a
python3 scripts/configure_ios_debug.py --url https://api.speechspace.health
```

Stop and Run again in Xcode to recompile. A Quick Tunnel URL can change when
the tunnel restarts; use the same script with the replacement URL. Updating
`.env` alone does not refresh the generated override; rerun the script.

## Demo mode

```sh
python3 scripts/configure_ios_debug.py --demo
```

Stop and Run again. This explicitly sets both defines to empty, even if stale
remote defines remain in Generated.xcconfig. The existing demo selection in
`lib/main.dart` and all Flutter UI remain unchanged.

## Checks

`git check-ignore ios/Flutter/Debug.local.xcconfig` should report the file.
The backend's `/health` checks process availability; an authenticated
`/api/snapshot` request checks the token and database. A successful iOS build
does not establish backend availability or physical-device connectivity.
