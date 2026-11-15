# Deploy a production copy of SpeechSpace

## Update the existing Debian LXC backend

Use this section for the Python/systemd installation at `192.168.0.246`, with
service `speechspace` and files in `/opt/speechspace`. It does not require Docker.
The Docker instructions later in this document describe a separate deployment.

**On your Mac, from the repository root:** stage the new code without replacing
the running backend or its `.env`:

```bash
ssh root@192.168.0.246 'mkdir -p /opt/speechspace/incoming'
scp backend/app.py backend/requirements.txt \
  root@192.168.0.246:/opt/speechspace/incoming/
```

After both transfers succeed, run this **from your Mac**. The block executes
inside the LXC, saves a dated code backup, installs dependencies, and restarts
the API. It stops on errors; the existing server `.env` is retained.

```bash
ssh root@192.168.0.246 bash -s <<'REMOTE'
set -eu
cd /opt/speechspace
test -s incoming/app.py
test -s incoming/requirements.txt
test -f .env
backup="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp backend/app.py backend/requirements.txt "$backup/"
.venv/bin/python -c "import ast; from pathlib import Path; ast.parse(Path('incoming/app.py').read_text())"
.venv/bin/pip install -r incoming/requirements.txt
install -o speechspace -g speechspace -m 644 incoming/app.py backend/app.py
install -o speechspace -g speechspace -m 644 incoming/requirements.txt backend/requirements.txt
systemctl restart speechspace
sleep 2
systemctl is-active speechspace
curl --fail --retry 5 --retry-connrefused --retry-delay 2 http://127.0.0.1:8000/health
printf '\nCode backup: /opt/speechspace/%s\n' "$backup"
REMOTE
```

Dependency installation updates the existing virtual environment. The code backup
does not snapshot that environment or the database. If an update fails, inspect
the logs before retrying. A normal code update does not require restarting
`cloudflared` or rebuilding Flutter unless the client code, token, or URL changed.

**LXC console or SSH session — inspect services/logs:**

```bash
systemctl status speechspace cloudflared --no-pager
journalctl -u speechspace -n 60 --no-pager
```

**Mac — verify the public route:**

```bash
curl --fail https://api.speechspace.health/health
python3 - <<'PY'
import json, urllib.request
from pathlib import Path
settings = json.loads(Path('config/dev.local.json').read_text())
request = urllib.request.Request(
    'https://api.speechspace.health/api/snapshot',
    headers={
        'Authorization': 'Bearer ' + settings['DEV_API_TOKEN'],
        'User-Agent': 'SpeechSpace-check/1.0',
    },
)
with urllib.request.urlopen(request, timeout=30) as response:
    print('Authenticated snapshot HTTP', response.status)
PY
```

Expect HTTP 200. Local `/health` alone does not prove public access or MongoDB
connectivity. A public 403 still needs access-rule/backend investigation.

Do not copy your Mac's `.env` over the server during routine code updates. For an
intentional credential change, edit the server `.env`, restart `speechspace`, and
update the matching local `.env`. Then synchronize and rebuild the apps:

```bash
python3 scripts/configure_ios_debug.py --url https://api.speechspace.health --sync-android
```

## Frontend: build, install, and run on iPhone

Run these commands **on your Mac, from the repository root**, after the backend
update. The local `.env` token must match the server. Connect and unlock the
iPhone; Developer Mode, computer trust, and Xcode signing must be configured.

```bash
python3 scripts/configure_ios_debug.py --url https://api.speechspace.health --sync-android
flutter pub get
flutter devices

flutter build ios --release \
  --dart-define-from-file=config/dev.local.json \
  --dart-define=API_BASE_URL=https://api.speechspace.health
```

Once the build succeeds, install and launch on Tyler's physical iPhone:

```bash
xcrun devicectl device install app \
  --device 00008140-001054EC3A79801C \
  build/ios/iphoneos/Runner.app

xcrun devicectl device process launch \
  --device 00008140-001054EC3A79801C \
  com.example.speechspace
```

Replace the device ID for a different iPhone. These direct Apple install/launch
commands worked when `flutter run --release` failed during installation. If iOS
asks you to trust the developer, approve it in Settings and rerun the launch
command. See [run_iphone_release.md](run_iphone_release.md) for details.

## Frontend: build, install, and run on Android

Run **on your Mac, from the repository root**. Connect an Android phone with USB
debugging enabled and accept its computer authorization prompt. Use a physical
phone for Release testing. The Android SDK comes with Android Studio.

```bash
python3 scripts/configure_ios_debug.py --url https://api.speechspace.health --sync-android
flutter pub get
flutter devices

flutter build apk --release \
  --dart-define-from-file=config/dev.local.json \
  --dart-define=API_BASE_URL=https://api.speechspace.health
```

After the build succeeds, list devices and replace `REPLACE_WITH_ANDROID_SERIAL`
with the Android phone's serial from `adb devices -l`:

```bash
ANDROID_ADB="$HOME/Library/Android/sdk/platform-tools/adb"
"$ANDROID_ADB" devices -l
ANDROID_DEVICE_SERIAL='REPLACE_WITH_ANDROID_SERIAL'

"$ANDROID_ADB" -s "$ANDROID_DEVICE_SERIAL" install -r \
  build/app/outputs/flutter-apk/app-release.apk

"$ANDROID_ADB" -s "$ANDROID_DEVICE_SERIAL" shell am start \
  -n com.example.speechspace/.MainActivity
```

If your SDK lives elsewhere, adjust `ANDROID_ADB`. Wait for installation to report
`Success` before launching. If Android reports a signing-key mismatch, use the
original signing key; uninstalling the old app would remove its local data.

These are presentation builds of the existing prototype, using the current
backend token. Android Release currently uses the debug signing key; it is not
configured for Play Store publication. The installed apps can open without the
Mac running, provided the backend and tunnel remain online.

After major pulls or stale-build problems, run `flutter clean` before
`flutter pub get`. It is not required for each build. Rebuild and reinstall after
client code, token, or URL changes. Verify that profiles load and a test entry
can be saved/retrieved; successful installation alone does not prove API access.

## Optional separate Docker deployment

This runs a **separate production stack** next to the dev backend. It has its own
container, database, token and Cloudflare named tunnel at
`https://api.speechspace.health`. It also covers building the Flutter app that
points at it. The shared Remote API launcher in `run.md` already uses this
permanent hostname. Moving that route to a separate stack changes which backend
it reaches; update the local client token to match. Keep any separate dev stack
on a different hostname. A permanent address alone does not require a new database.

> **Read first.** "Production" here means a stable, always-on deployment of the
> **existing prototype**. Every client still shares one bearer token (`APP_DEV_TOKEN`),
> that token is compiled into the app, and all data belongs to one
> `prototype-parent` owner. Until real parent accounts and consent exist, use only
> synthetic or consented test data. Do not publish the app to stores and do not
> enter real children's data (see README "Prototype authentication warning").

## 0. What you need

| Item | Where it comes from |
|---|---|
| Proxmox VM/LXC with Docker + Docker Compose | Same host as dev is fine |
| Cloudflare account with `speechspace.health` as an active zone | Cloudflare dashboard |
| `cloudflared` on the Proxmox VM | `apt install cloudflared` (Cloudflare repo) |
| MongoDB Atlas cluster | Use a **separate prod database user** |
| Gemini API key | Google AI Studio (can be a separate prod key) |
| ElevenLabs API key + STT model id, *or* your own STT endpoint | ElevenLabs dashboard / GPU box |
| Flutter SDK + Android Studio (for the client build) | Your Mac |

## 1. Credentials: create `.env.prod` (never commit)

`.env.*` is already gitignored (only `.env.example` is tracked). Create the file
**on the Proxmox VM**, in the repository checkout:

```bash
cp .env.example .env.prod
chmod 600 .env.prod
```

Fill in every variable. Generate **new** values rather than copying dev ones:

| Variable | Production value |
|---|---|
| `MONGODB_URI` | Atlas URI for a prod-only DB user (readWrite on the prod DB only) |
| `MONGODB_DB` | `speechspace_prod` (never the dev `speechspace_dev`) |
| `APP_DEV_TOKEN` | **New**: `openssl rand -hex 32`. Do not reuse the dev token. |
| `GEMINI_API_KEY` | Gemini key (prod key recommended) |
| `GEMINI_MODEL` | e.g. `gemini-3.5-flash-lite` |
| `STT_PROVIDER` | `elevenlabs`, or leave empty and use `STT_ENDPOINT_URL` |
| `ELEVENLABS_API_KEY`, `ELEVENLABS_STT_MODEL` | Required if `STT_PROVIDER=elevenlabs` |
| `STT_ENDPOINT_URL`, `STT_API_TOKEN` | Generic STT adapter instead of ElevenLabs |
| `CORS_ORIGINS` | Only needed for a hosted Flutter **web** build; native apps ignore it |

Atlas → **Network Access**: allow the Proxmox host's public egress IP, not `0.0.0.0/0`.

## 2. Run the backend container

The `Dockerfile` contains only `backend/app.py` and its requirements. Secrets are
injected at runtime, not baked into the image.

```bash
git pull
docker build -t speechspace-api:prod .
docker rm -f speechspace-prod 2>/dev/null
docker run -d --name speechspace-prod --restart unless-stopped \
  --env-file .env.prod \
  -p 127.0.0.1:8100:8000 \
  speechspace-api:prod
curl --fail http://127.0.0.1:8100/health
```

- The container binds to `127.0.0.1:8100` only, so Cloudflare is the only public
  way in. The dev backend keeps its own port.
- To update: `git pull`, then rerun the build and `run` commands above.
- To check logs: `docker logs -f speechspace-prod`.

## 3. Expose it at `https://api.speechspace.health` (Cloudflare named tunnel)

Quick tunnels (`*.trycloudflare.com`) change URL on every restart. Production
uses a **named** tunnel instead:

```bash
cloudflared tunnel login                       # opens browser, pick speechspace.health
cloudflared tunnel create speechspace-prod     # writes ~/.cloudflared/<TUNNEL_ID>.json
cloudflared tunnel route dns speechspace-prod api.speechspace.health
```

Create `/etc/cloudflared/config.yml`:

```yaml
tunnel: speechspace-prod
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: api.speechspace.health
    service: http://127.0.0.1:8100
  - service: http_status:404
```

Install it as a service so it survives reboots:

```bash
cloudflared service install
systemctl enable --now cloudflared
```

The tunnel credentials JSON is a secret. Keep it on the VM only.

## 4. Verify the backend (before touching Flutter)

```bash
TOKEN=$(grep '^APP_DEV_TOKEN=' .env.prod | cut -d= -f2-)
curl --fail https://api.speechspace.health/health
curl -s -o /dev/null -w '%{http_code}\n' https://api.speechspace.health/api/snapshot                       # expect 401
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN" https://api.speechspace.health/api/snapshot   # expect 200
```

Don't continue until the last command returns `200`.

## 5. Build the Flutter app against production

On your Mac, put the **prod** token in a gitignored file. `config/*.local.json` is
already ignored. Copy the token over securely (password manager, `scp`); never
paste it into chat, issues or commits.

```bash
python3 - <<'PY'
import json, getpass
from pathlib import Path
p = Path('config/prod.local.json')
p.write_text(json.dumps({'DEV_API_TOKEN': getpass.getpass('Prod APP_DEV_TOKEN: ')}) + '\n')
p.chmod(0o600)
PY
```

**Android Studio:** create `.run/SpeechSpace_Production.local.run.xml`. It is
gitignored via `.run/*.local.run.xml`; see `run.md`. Set its additional args to:

```
--dart-define=API_BASE_URL=https://api.speechspace.health --dart-define-from-file=config/prod.local.json
```

(The existing local Production config on the dev Mac points at
`config/dev.local.json`. Switch it to `prod.local.json` once prod has its own token.)

**Release build from the CLI:**

```bash
flutter clean && flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.speechspace.health \
  --dart-define-from-file=config/prod.local.json
# Output: build/app/outputs/flutter-apk/app-release.apk
flutter install --release        # or: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

iOS: `flutter build ipa --release` with the same two flags, then sign and
distribute through Xcode/TestFlight internal testing. If a local
`ios/Flutter/Debug.local.xcconfig` exists it only affects Debug, not Release.

## 6. Known gaps before a real public launch

- **Android signing:** `android/app/build.gradle*` signs release with the
  **debug** key, and `applicationId` is `com.example.speechspace`. Fine for
  sideloading testers; Play Store needs a real upload keystore
  (`android/key.properties` and `*.jks` are already gitignored) and a real
  application id.
- **Auth:** the shared token can be extracted from the APK, and anyone holding it
  has full API access. Replace it with per-parent accounts and short-lived tokens.
- **Backups:** enable Atlas backups or scheduled `mongodump` for `speechspace_prod`.
- **Token rotation:** to rotate, change `APP_DEV_TOKEN` in `.env.prod`, restart the
  container with the step 2 commands, update `config/prod.local.json`, rebuild the
  app. Old builds stop working (401).

## Quick reference

| What | Dev | Prod |
|---|---|---|
| URL | Separate dev hostname, if needed | `https://api.speechspace.health` |
| Backend env file | `.env` | `.env.prod` |
| Database | `speechspace_dev` | `speechspace_prod` |
| Container / port | dev setup | `speechspace-prod` on `127.0.0.1:8100` |
| Flutter token file | `config/dev.local.json` | `config/prod.local.json` |
| Android Studio config | SpeechSpace (Remote API) | SpeechSpace (Production API, local) |
