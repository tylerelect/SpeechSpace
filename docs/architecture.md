# Architecture and extension points

## Data flow

1. Parent selects the child's profile in Flutter.
2. Memory is added by typing or initiated microphone capture. Voice is encoded as 16kHz mono PCM WAV in memory.
3. Flutter sends audio to `/api/transcribe` with the prototype parent bearer token.
4. FastAPI forwards it to `STT_ENDPOINT_URL`, which may use any speech model or hardware; response contains just a transcript. The supplied API does not save raw audio.
5. Parent can edit transcript, request a Gemini Flash summary/tags, and approve or revise all generated fields.
6. Note, date, favorites, parent-entered tags, and graph links are saved in MongoDB Atlas. Each item has `ownerId` and `childId` for scoping.

## MongoDB collections

- `children`: `{ id, ownerId, name, color }`
- `entries`: `{ id, ownerId, childId, date, title, body, favorite, highlight, isMilestone, tags }`
- `links`: `{ id, ownerId, childId, fromId, toId, label }`

Stable note IDs preserve links when a note title changes. Each link connects notes in the same child profile. The layout of visual nodes currently lives in local Flutter widget state; add `nodePositions` to a parent-controlled profile or view settings collection to persist it across sessions.

Indexes suggested for further work:

```js
db.children.createIndex({ownerId: 1, id: 1}, {unique: true});
db.entries.createIndex({ownerId: 1, childId: 1, date: -1});
db.entries.createIndex({ownerId: 1, id: 1}, {unique: true});
db.links.createIndex({ownerId: 1, childId: 1});
```

## API boundary

- `GET /health` — integration configuration status, not a health monitor for children
- `GET /api/snapshot` — all child profiles, memories, and links for the authenticated demo actor
- `POST /api/children`; `DELETE /api/children/{id}`
- `POST /api/entries`; `DELETE /api/entries/{id}`
- `POST /api/links`; `DELETE /api/links/{id}`
- `POST /api/analyze` — Gemini Flash, text only
- `POST /api/transcribe` — optional speech service; not a model-specific implementation

For production replace `parent_actor` with an actual parent account system. A shared bearer secret in client code is **not** authorization for real child data. Use per-guardian scoped access, account and child membership checks, and authorized sharing relationships. Consider rate limiting, quotas, structured audit logs that exclude contents, encryption, secure secret management, export/deletion workflows, and safe handling of child identifiers. Review applicable child privacy laws and vendor contracts.

## Development priorities

1. Choose STT backend through measured child speech transcription accuracy and latency on your actual hardware.
2. Implement real parent auth and consent before using live child data.
3. Add encrypted local cache, offline writes, sync conflict handling, and media retention controls.
4. Persist mind-map positions and add graph filtering.
5. Add accessibility-friendly child input prompts and optional parent-curated milestones.

Avoid model-generated developmental scoring, diagnosis, personality profiling, and inference about sensitive attributes from children's speech.

## Environment and secrets

Copy the repository-root `.env.example` to `.env`; the backend uses `python-dotenv` to load that file regardless of the process working directory. Keep credentials only on the backend. `.gitignore` ignores `.env` and `.env.*` files in any subdirectory (but preserves `.env.example`). The single shared development token is insecure when passed to Flutter at build time; do not use it with real children's data. Replace it with parent authentication before deployment.
