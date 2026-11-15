# SpeechSpace

SpeechSpace is a voice-powered childhood memory journal for Android and iOS. Kids record a favorite moment by voice or text, and parents get an at-a-glance view of how their child grows over time. It's built with Flutter, a FastAPI + MongoDB Atlas backend, and Gemini Flash for AI suggestions. The app is a hackathon prototype, not a production service for real children's data.

- **Kids mode:** record a favorite moment by voice (up to 90 seconds) or text. The audio is transcribed and never stored.
- **AI highlights:** Gemini suggests a short highlight, the child's stated favorite, and tags. It never infers traits or development, and a parent approves every suggestion.
- **Parent mode:** a calendar with milestones, a searchable timeline, and an editable mind map that links related memories.
- **Setup:** put secrets in a root `.env` (copy from `.env.example`), then run `flutter pub get`, `python3 scripts/configure_ios_debug.py --sync-android`, and `flutter run --dart-define-from-file=config/dev.local.json`. See [run.md](run.md) and [run_prod.md](run_prod.md) for details.
- **Not yet built:** parent accounts and consent, encryption, offline support. The dev token is embedded in the client build, so only use synthetic data.

See [docs/architecture.md](docs/architecture.md) for the data model, safety design, and extension points.
