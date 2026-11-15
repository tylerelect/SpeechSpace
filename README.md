# SpeechSpace — Flutter / Dart starter app

An interactive speech service to help parents have an at-a-glance view of their child's development, personally and productively.

An editable, parent-managed **childhood memory journal** prototype. Children can describe a favorite moment, and a parent can organize it on a calendar, browse the history, and link related memories in a mind map.

## What's implemented

- Responsive Flutter UI for **web, Android, and iOS**: Today, Calendar, Memories, Mind Map, Settings.
- Persisted child/adult profiles and memories from the live backend; add/edit/delete and search.
- Calendar with marked recording days and entries per date. Guardian-marked milestones can be filtered in the history.
- Editable mind map with draggable memory cards, persistent (server-side) links, and unlinking. Node positions are intentionally **session-only** in this version.
- Microphone capture on supported devices, assembled into a WAV recording (max 90 seconds), forwarded to a separate transcription endpoint.
- Optional Gemini Flash structured analysis (brief factual highlight, explicit favorite, optional tags).
- Optional backend with MongoDB Atlas for persistent profiles, dated memories, and links.
- No audio is stored in MongoDB or retained by the supplied backend. The chosen external STT service has its own retention policy.

**Not implemented:** production parental accounts/consent, offline persistence, push notifications, sync conflict handling, diagnostic/developmental scoring, production-grade privacy/security, choice of an STT model. The voice button is real recording but transcription requires configuring an adapter. Without backend, Gemini and STT show an informative configuration error; they do **not** generate a fake result.

## 1. Run against the live backend

Debug and Release default to `https://api.speechspace.health`. All normal launches
load the same persisted profiles and entries. There is no demo fallback; a missing
DEV_API_TOKEN produces a configuration error. DemoRepository is retained for tests.

With APP_DEV_TOKEN set in the local Git-ignored .env:

```bash
flutter pub get
python3 scripts/configure_ios_debug.py --sync-android
flutter run --dart-define-from-file=config/dev.local.json
```

See [run.md](run.md) for Xcode and Android Studio, and
[run_iphone_release.md](run_iphone_release.md) for physical iPhone installation.

## 2. Connect MongoDB Atlas / FastAPI

Create an Atlas database/cluster and a least-privileged **development-only** database user. Set Atlas network access for your backend host, not every end-user device.

```bash
# From the project root:
cp .env.example .env
# Fill in MONGODB_URI and APP_DEV_TOKEN in the root .env.
cd backend
python3 -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --host 127.0.0.1 --port 8000
```

Run the web app (in another terminal, from the project root):

```bash
# Set DEV_API_TOKEN to the same value as APP_DEV_TOKEN in your .env,
# but ONLY for a local synthetic-data demo.
flutter run -d chrome --web-port 5173 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DEV_API_TOKEN=YOUR_APP_DEV_TOKEN
```

**Keys and Git:** All backend secrets (`MONGODB_URI`, `GEMINI_API_KEY`, `STT_API_TOKEN`, and the development-only `APP_DEV_TOKEN`) belong in the single project-root `.env`. The `.gitignore` excludes `.env` files everywhere, while `.env.example` remains trackable. The backend loads this file by explicit path; never put these values in Dart source, `pubspec.yaml`, or a committed configuration file. Do not bundle `.env` in a client release. If any key was ever committed, rotate it; adding `.gitignore` does not erase Git history.

**Prototype authentication warning:** To call the dev API, the Flutter launch command above passes the `APP_DEV_TOKEN` value as `DEV_API_TOKEN` via `--dart-define`. Even though the value originates in a gitignored `.env`, **it becomes embedded in the compiled client and is not secret**. Use this only for a private, synthetic-data development demo. **Never distribute that build or use real children's data.** Replace this arrangement with verified parent authentication, short-lived scoped access tokens, and appropriate consent handling before any public/real-data deployment. Use HTTPS outside localhost.

Native device note: Android emulator sees the host at `10.0.2.2`, not `127.0.0.1`; a physical phone needs a reachable HTTPS API hostname. Native platform networking permissions and TLS settings must be configured by the developer.

## 3. Enable Gemini Flash analysis

Add in the project root `.env`:

```ini
GEMINI_API_KEY=your_server_side_key
GEMINI_MODEL=gemini-3.5-flash-lite
```

The model name is configurable. Use an API-available Flash model for your account. The backend asks Gemini to extract a non-diagnostic **highlight, an explicitly mentioned favorite, and 1–3 tags**. It must not infer psychological traits, medical conditions, or developmental ability. A guardian reviews the suggestions before saving them.

**Important:** If entered data identifies a child, sending it to a third-party AI provider requires appropriate guardian consent, privacy notices, retention controls, and a review of the provider's applicable terms.

## 4. Connect your existing Ubuntu GPU transcription service

Set in the project root `.env`:

```ini
STT_ENDPOINT_URL=https://your-private-voice-service.example/transcribe
STT_API_TOKEN=your-service-token-if-required
```

The adapter only specifies a **contract**, not a speech recognition model. Your server should accept `multipart/form-data`, field `file`, a mono 16 kHz 16-bit PCM **WAV**, and return:

```json
{"transcript": "My favorite thing today was my yellow dress."}
```

It may return `{"text": "..."}` instead. The proxy discards the recording bytes after forwarding. Do not expose your home VM's admin interface to the Internet; protect and rate-limit the speech endpoint. If the service uses a different payload, edit only `backend/app.py`'s `/api/transcribe` adapter.

Browser microphone capture requires HTTPS or localhost and permission. On Android add `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` to `android/app/src/main/AndroidManifest.xml` above `<application>`. On iOS add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist` with a plain-language explanation. Consult the `record` package's platform-specific setup instructions.

## 5. App layout

```text
lib/
  main.dart                     App entry and theme
  models/models.dart            Child, memory, link and AI result types
  services/
    repository.dart             Demo storage / remote API implementations
    app_controller.dart         Shared app state and mutations
  screens/
    app_shell.dart              Responsive navigation / child switcher
    today_page.dart             Daily voice/text journal entry point
    calendar_page.dart          Calendar & daily memories
    timeline_page.dart          Searchable history
    mind_map_page.dart          Visual and editable links
    settings_page.dart          Profiles and integration status
  widgets/
    entry_editor.dart           Full editor and Gemini suggestions
    voice_capture.dart          PCM capture / WAV envelope
backend/
  app.py                        Atlas REST API, Gemini, replaceable STT proxy
  requirements.txt
  test_api.py                   Example API tests (mongomock)
.env.example                    Safe placeholder keys; copy to .env
.gitignore                      Excludes .env and nested variants
docs/
  architecture.md               Data model, safety, extension points
```

## 6. Hackathon and child privacy

The Hack The Nest packet says all submitted project code must be written during the 24-hour event. If entering the competition, ensure your team follows those rules and discloses earlier components; obtain organizer clarification if reusing an existing speech service.

**This is a software prototype, not a child-safe production deployment.** At minimum, before real child use implement legal guardian account verification and consent, encryption of sensitive data, access audit, restricted sharing, data export/deletion and retention policies, privacy notices, vendor agreements, abuse prevention, and age-appropriate design. A calendar of memories is **not a clinical developmental assessment**.

## 7. Validation status

Backend Python syntax was checked with `python3 -m py_compile backend/app.py`. The current execution environment does **not** have the Flutter SDK or the needed Python packages installed, so this archive has **not** been built on Android/iOS/web or integration-tested against a live Atlas/Gemini/STT service. Run `flutter analyze`, `flutter test`, and backend tests in a configured development environment before a demo.
