# Local run config

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
