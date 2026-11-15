# Deploy the prototype API with a GoDaddy domain

A domain registration supplies the address, not an application server. Keep DNS
at GoDaddy and deploy this repository's Dockerfile to a container application
host. The mobile app connects to the host over HTTPS; your Mac need not stay on.

## Container setup

Build from the repository root with `Dockerfile`. The process listens on `PORT`
(default `8000`) on all interfaces. Configure the platform health check as
`GET /health`. This checks process health; verify `/api/snapshot` separately to
exercise authentication and MongoDB.

For a local Docker smoke test:

```sh
docker build -t speechspace-api .
docker run --rm --env-file .env -p 8001:8000 speechspace-api
# In another terminal:
curl --fail http://127.0.0.1:8001/health
```

The image intentionally includes only the API source and requirements, not
the local `.env`, Flutter assets, Git history, or test data. Supply environment
variables in the hosting dashboard:

- `MONGODB_URI`, `MONGODB_DB`, `APP_DEV_TOKEN`
- `GEMINI_API_KEY`, `GEMINI_MODEL` for AI features
- `STT_PROVIDER`, `ELEVENLABS_API_KEY`, `ELEVENLABS_STT_MODEL` for ElevenLabs;
  or `STT_ENDPOINT_URL`, `STT_API_TOKEN` for the generic transcription adapter

Use the same values as the local `.env` where appropriate. Permit the hosting
service's outbound addresses in Atlas network access. Choose an always-on
instance if avoiding cold-start delays is important.

## Domain and HTTPS

1. Deploy and confirm `/health` on the provider's HTTPS URL.
2. Add `api.YOUR_DOMAIN` in the provider's custom-domain settings.
3. In GoDaddy DNS, add exactly the record and verification values the provider
   supplies (typically a CNAME named `api`). Leave unrelated website/mail records
   intact.
4. Wait for domain verification and the provider's TLS certificate to complete.
5. Test authenticated `GET /api/snapshot` on the custom HTTPS URL.

## Connect Flutter

From the project root, with `APP_DEV_TOKEN` already loaded from `.env`:

```sh
flutter run --profile -d YOUR_DEVICE_ID \
  --dart-define=API_BASE_URL=https://api.YOUR_DOMAIN \
  --dart-define=DEV_API_TOKEN="$APP_DEV_TOKEN"
```

Rebuild when changing these compile-time values. Omitting `API_BASE_URL` selects
demo mode.

This remains the existing shared-token prototype: every authenticated request
uses the same `prototype-parent` owner. Hosting does not add per-user accounts;
use synthetic data until real identity and ownership isolation are implemented.
