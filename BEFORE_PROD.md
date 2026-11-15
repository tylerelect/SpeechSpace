# Before production

What has to happen before SpeechSpace runs as a real service with real families.
Compiled 2026-11-15 from a code and docs audit. Legal items are flagged for a
lawyer to confirm; they are not engineering conclusions.

**Priority:** 🔴 blocker (don't launch without it) · 🟡 should · ⚪ nice to have

---

## 0. Do today

- [ ] 🔴 **Rotate `APP_DEV_TOKEN`.** A real dev token was committed in `bbbc875`
  (`config/dev.local.example.json`) and is public on GitHub. The token in the
  current local `.env` is the same one. Fixing it:
  1. Run `openssl rand -hex 32` to make a new token.
  2. Set it in the backend env on the VM and on the Mac, then restart the
     container.
  3. Put it in the gitignored `config/dev.local.json` and `config/prod.local.json`,
     then rebuild the app.

  Rewriting git history is optional. Rotating is the fix that matters. Check the
  Atlas data for anything unexpected.
- [ ] 🔴 **Put the placeholder back in `config/dev.local.example.json`**
  (`REPLACE_WITH_YOUR_APP_DEV_TOKEN`). A real-looking token has come back
  uncommitted, so keep it out of every commit.

## 1. Gemini

- [x] **Switch to `gemini-3.5-flash-lite`.** Done in `a53153b` (the code
  default, `.env.example`, `run_prod.md` and `README.md`). Why it was needed:
  `gemini-2.5-flash` shuts down 2026-12-01, and new accounts may not be able to
  call `2.5-flash-lite`.
- [ ] 🔴 **Set `GEMINI_MODEL=gemini-3.5-flash-lite` in the VM's `.env.prod`**, or
  remove the line so the new default applies. An old value there overrides the
  code.
- [ ] 🔴 **Redeploy the backend.** The live `/health` shows it is older than
  `main`. On the VM: `git pull`, `docker build`, then replace the container
  (`run_prod.md` step 2).
- [ ] 🔴 **Use a paid (billing-enabled) Gemini key for prod.** On the free tier
  Google may use prompts to improve its products, and human reviewers may read
  them. The paid tier does not use them for training. Use a separate prod key
  and project, restricted to the Generative Language API.
- [ ] 🟡 **Remove `temperature=` from the Gemini call** (`generate_structured`
  in `backend/app.py`). Google says temperature/top_p/top_k are *deprecated and
  ignored* on 3.5 Flash-Lite, and will return HTTP 400 on future models. Today
  the `0.2` is silently ignored and the model runs at 1.0.
- [ ] ⚪ **Optionally pin thinking to minimal:**
  `thinking_config=types.ThinkingConfig(thinking_level='minimal')`. This is
  already the default for 3.5 Flash-Lite, so it only protects against future
  default changes. If you add it, raise `google-genai` in
  `backend/requirements.txt` to `>=1.75,<2`. Never combine it with
  `thinking_budget`, which returns a 400.
- [ ] 🟡 **Add a timeout and retries** for Gemini calls. Create the client once
  with `HttpOptions(timeout=…, retry_options=HttpRetryOptions(…))`, retrying on
  429/5xx. Return "busy, try again" rather than a vague 502.
- [ ] 🟡 **Give AI endpoints a longer client timeout.** The app gives up after
  20 s (`lib/services/repository.dart`). Use about 45–60 s for analyze, expand,
  prompts and calendar summary only.
- [ ] 🟡 **Live smoke test.** Using the paid key and made-up text, call each AI
  endpoint once (analyze, calendar summary, expand, prompts) and check the JSON
  validates. The unit tests mock Gemini, so nothing has exercised the real call
  on 3.5.
- [ ] 🟡 **Re-plan the budget.** 3.5 Flash-Lite is $0.30 / $2.50 per 1M
  input/output tokens, against $0.10 / $0.40 for 2.5 Flash-Lite. At 500 calls/day
  that's roughly $20/month, which is still small. Set a budget alert. Optionally
  set `max_output_tokens`.
- [ ] 🟡 **Set content-safety settings for Kids.** Kids see AI-generated text.
  Set strict `safety_settings` when `kind=kids`, plus a simple output check.

## 2. Kids' privacy and legal (lawyer to confirm)

- [ ] 🔴 **Gemini API terms bar services "likely to be accessed by" under-18s.**
  This applies on every tier, and Kids mode is exactly that. Before launch,
  choose one:
  - turn off AI features for Kids profiles,
  - move Kids traffic to a platform whose terms allow it (e.g. Vertex AI under
    Google Cloud terms, after checking them), or
  - get a legal opinion on the guardian-operated design.
- [ ] 🔴 **ElevenLabs:** its terms also restrict minors, and it keeps audio by
  default. Zero retention is Enterprise-only. Options:
  - Kids speech-to-text goes to a self-hosted or on-device engine through
    `STT_ENDPOINT_URL`.
  - For any ElevenLabs use, send `enable_logging=false`, opt out of training,
    and sign a DPA.

  Also fix `README.md`: the backend stores no audio, but ElevenLabs may.
- [ ] 🔴 **COPPA: verifiable parental consent before collecting from children
  under 13.** The 2025 amendments also require separate consent for disclosure
  to third parties (Gemini, ElevenLabs).
- [ ] 🔴 **Real guardian accounts.** Today every client shares one compiled-in
  token, and all data belongs to one `prototype-parent` owner. That rules out
  consent, access control and per-family deletion.
- [ ] 🔴 **Publish a privacy policy and a written data-retention policy.**
  Neither exists.
- [ ] 🔴 **Write an information-security program** (a COPPA 2025 requirement).
- [ ] 🔴 **Parents' rights.** Parents must be able to review, export and delete
  their child's data, and refuse further collection. Check that `delete_profile`
  removes everything, including vendor-side copies.
- [ ] 🟡 **Send less "About me" data to the AI.** For Kids, don't send the school
  name (use "attends school" or drop it). Only send profile details for children
  whose parent agreed to AI use. Add a disclosure on the About form.
- [ ] 🟡 **Replace the prototype notices in Settings** with real just-in-time
  notices: when recording, when using AI, and on the About form.
- [ ] 🟡 Review US state laws for teens (13–17), and GDPR-K / the UK Children's
  Code if the app is offered there.
- [ ] 🟡 **Fix the iOS microphone text** (`ios/Runner/Info.plist`). It says
  "document their child's development". Use neutral journaling wording that
  matches the privacy policy.
- [ ] 🟡 App-store kids-category rules, if you publish to a store.

## 3. Security

- [ ] 🔴 **Rate limits and spend caps** on `/api/analyze`, `/api/expand`,
  `/api/prompts`, `/api/calendar/summary` and `/api/transcribe`:
  - per-user and per-IP limits in the app,
  - a Cloudflare rate-limit rule on `/api/*`,
  - provider budget alerts and quotas.

  Without these, anyone with the token can run up the bill.
- [ ] 🟡 **Limit request body size** before parsing.
- [ ] 🟡 **Turn off public `/docs` and `/openapi.json` in prod**, and trim
  `/health`.
- [ ] 🟡 **Keep slow AI and STT calls from tying up all the workers.** Use
  timeouts and enough workers or async handling.
- [ ] 🟡 **Separate MongoDB users** for prod, dev and seeding. The prod user
  should not be able to reach `speechspace_dev`.
- [ ] 🟡 **Fail at startup if `MONGODB_DB` is unset** in prod. It currently
  defaults to `speechspace_dev`.
- [ ] 🟡 **Pin backend dependencies and the Docker base image.**
- [ ] 🟡 **Lock down the Cloudflare tunnel**, and make the env-file setup in
  `run_prod.md` fail safe (permissions, no defaults).
- [ ] ⚪ Harden the container at runtime: read-only filesystem, dropped
  capabilities.
- [ ] ⚪ Set CORS explicitly for prod.

## 4. Operations

- [ ] 🔴 **Atlas backups and a restore you've actually tested.**
- [ ] 🟡 **Add CI.** There's none today. Add GitHub Actions running
  `pytest backend`, `flutter analyze`, `flutter test` and `docker build`.
- [ ] 🟡 **Monitoring.** Add a deeper readiness check (one that pings Mongo),
  external uptime monitoring and alerts.
- [ ] 🟡 **Logging without journal text.** Use structured logs with the error
  type and endpoint, and rotate Docker logs.
- [ ] 🟡 **Keep seed scripts away from prod** (`scripts/seed_*.py`). They should
  refuse any database that isn't a demo database. Confirm `scripts/seed_data/`
  is fictional.
- [ ] 🟡 **Stop release builds from silently shipping demo mode.** A release
  build without `API_BASE_URL` currently falls back to demo mode. It should fail
  or show an error, or the build should go through a script that always passes
  the prod `--dart-define`s.
- [ ] 🟡 **Android/iOS app identity and signing**, needed before any store
  release.
- [ ] 🟡 **Fix stale or contradictory docs**: `run.md`, `run_prod.md`,
  `docs/deployment.md`.
- [ ] ⚪ Settings and error messages say "Gemini Flash". Make them
  provider-neutral if that ever changes.

---

### Not in scope
The uncommitted OpenAI-compatible / vLLM / Brev provider code is not planned
for prod. If it stays in the code, leave `LLM_BASE_URL` and `LLM_MODEL` empty in
prod so the backend uses Gemini.

### Sources
- Gemini models, deprecations, pricing and terms:
  [models](https://aistudio.google.com/docs/models),
  [deprecations](https://aistudio.google.com/docs/deprecations),
  [pricing](https://aistudio.google.com/docs/pricing),
  [terms](https://aistudio.google.com/docs/terms)
- Gemini 3.x parameters:
  [what's new / migration](https://aistudio.google.com/docs/whats-new-gemini-3.6),
  [thinking](https://aistudio.google.com/docs/thinking),
  [structured output](https://aistudio.google.com/docs/structured-output)
