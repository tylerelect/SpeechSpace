# Deploy a production copy of SpeechSpace

This runs a **separate production stack** next to the dev backend. It has its own
container, database, token and Cloudflare named tunnel at
`https://api.speechspace.health`. It also covers building the Flutter app that
points at it. The dev setup in `run.md` (quick tunnel, `SpeechSpace (Remote API)`)
keeps working unchanged.

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
| `GEMINI_MODEL` | e.g. `gemini-2.5-flash-lite` |
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
| URL | `*.trycloudflare.com` (changes) | `https://api.speechspace.health` |
| Backend env file | `.env` | `.env.prod` |
| Database | `speechspace_dev` | `speechspace_prod` |
| Container / port | dev setup | `speechspace-prod` on `127.0.0.1:8100` |
| Flutter token file | `config/dev.local.json` | `config/prod.local.json` |
| Android Studio config | SpeechSpace (Remote API) | SpeechSpace (Production API, local) |
