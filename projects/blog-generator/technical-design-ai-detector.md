# Technical Design: AI Content Detector

**Status**: Draft
**Author**: Mohamed Naser (Tech Lead)
**Date**: 2026-05-07
**PRD**: [`prd-ai-detector.md`](./prd-ai-detector.md)
**Epic**: [mohamednaseramein/blog-generator#115](https://github.com/mohamednaseramein/blog-generator/issues/115)

---

## Overview

### Summary

A heuristic AI-content detector embedded in the blog wizard. Users click **Run AI check** on the Draft or Publish step; the backend sends the draft body + SEO title + meta description to the configured LLM with a fixed-rubric prompt, parses a strict JSON response, and returns a score (0–100), a mode (`pure_ai | ai_assisted | human_polish | pure_human`), per-rule breakdown with evidence and fixes, per-section scores, and creator tips. Results are hard-cached in Postgres keyed by `hash(body + seo_title + meta_description) + rubric_version` so identical inputs never re-bill the LLM. A separate public `/help/ai-detector-rules` page renders the same rubric source the LLM uses, giving writers a study guide.

### Goals

- Production-ready endpoint reachable from both Draft and Publish steps in v1, sharing the cached result.
- Rubric content lives in a single source file; LLM prompt and help page are both rendered from it (no drift).
- LLM provider/model read from `.env`; `temperature=0` pinned in code; `rubric_version` flows through cache key, response, and help page footer.
- 30-post labelled fixture suite + CI gate; bumping `rubric_version` requires the suite to pass.
- P50 latency ≤ 5 s for drafts up to 2,000 words; cost per check ≤ $0.02.
- New surface area is purely additive — no changes to existing endpoints, schemas, or wizard flow.

### Non-Goals

- Auto-humanizer, live scoring, multi-language support, comparison-with-external-detectors, per-author baselines, PDF export — all Phase 2.
- Approving or blocking exports based on score (warn-only by PRD).
- Author-notes UI on the Publish step (does not exist; not added in v1).

---

## Domain Model

### Entities

```
BlogAiCheck                          (one row per cached run)
├── id: UUID
├── blogId: UUID                     (FK → blogs.id, scoped to user via blogs.user_id)
├── inputHash: STRING                (sha256(body + '' + seoTitle + '' + meta))
├── rubricVersion: STRING            (e.g. "1.0.0")
├── aiLikelihoodPercent: SMALLINT
├── humanLikelihoodPercent: SMALLINT
├── uncertaintyPercent: SMALLINT
├── mode: ENUM                       (pure_ai | ai_assisted | human_polish | pure_human | language_unsupported)
├── result: JSONB                    (full strict-schema object — top_signals, rule_breakdown, section_scores, excluded_segments, creator_tips)
├── llmProvider: STRING              (e.g. "anthropic")
├── llmModel: STRING                 (echo of resolved model at run time)
├── tokensInput: INTEGER
├── tokensOutput: INTEGER
├── createdAt: TIMESTAMPTZ
└── Methods:
    ├── isFresh(currentRubricVersion): boolean
    └── toApiResponse(): AiCheckApiResponse
```

### Value Objects

| Value Object | Fields | Purpose |
|--------------|--------|---------|
| `AiDetectorMode` | enum: `pure_ai`, `ai_assisted`, `human_polish`, `pure_human`, `language_unsupported` | Bounded set; rejected if LLM returns anything else |
| `RubricVersion` | `value: string` | Validates semver (`X.Y.Z`); enforces non-empty |
| `ScoredFieldName` | enum: `body`, `seo_title`, `meta_description` | Used in `rule_breakdown[].field` so each rule attributes to its source field |
| `EvidenceSnippet` | `text: string` (1–200 chars) | Trimmed; rejected if not present in scored input (anti-hallucination) |
| `InputHash` | `value: string` (64-char hex) | Constructed from normalised inputs; the cache key |

### Domain Events (lightweight — analytics only)

| Event | Trigger | Data |
|-------|---------|------|
| `AiCheckRequested` | Handler entered | `blogId`, `userId`, `rubricVersion` |
| `AiCheckCacheHit` | Cached row returned without LLM call | `blogId`, `cacheRowId` |
| `AiCheckCacheMiss` | LLM call completed and persisted | `blogId`, `cacheRowId`, `tokensInput`, `tokensOutput` |
| `AiCheckRuleExpanded` | Frontend records user expanded a rule (separate event endpoint) | `blogId`, `ruleId` |

---

## Architecture

### Component Diagram

```
React Frontend
│
│  POST /api/blogs/:id/ai-check    (Draft + Publish steps both call this)
│  GET  /help/ai-detector-rules    (public, server-rendered or static SSG)
│
▼
Express API (TypeScript, ES modules)
├── routes/blog-routes.ts
│   └── POST /api/blogs/:id/ai-check  → handleRunAiCheck
│
├── handlers/blog-ai-check-handler.ts
│   ├── verifies blog.user_id === req.user.id (existing pattern)
│   ├── loads body + seoTitle + metaDescription from blog_drafts
│   ├── computes input hash + reads rubric_version from rubric source
│   ├── repo lookup → cache hit → return
│   ├── cache miss → ai-detector-service → persist → return
│   └── records analytics event
│
├── services/ai-detector-service.ts   (mirrors alignment-service.ts)
│   ├── strips excluded segments (code, quote, log, url) → counts surfaced
│   ├── detects language; non-English short-circuit
│   ├── builds prompt from rubric YAML
│   ├── calls Anthropic SDK with temperature=0, model from env
│   ├── parses strict JSON + validates schema
│   └── verifies every evidence snippet appears in source text (anti-hallucination)
│
├── repositories/blog-ai-checks-repository.ts
│   ├── findFresh(blogId, inputHash, rubricVersion)
│   └── insert(row)
│
└── lib/ai-detector-rubric.ts
    ├── loads ai-detector-rubric.yaml (singleton, cached at process start)
    ├── exports RUBRIC_VERSION + getSystemPrompt() + getRulesForHelpPage()
    └── single source of truth for prompt and help page

PostgreSQL (Supabase)
├── blog_ai_checks                  (new table — see migration 015)
└── blog_drafts                     (existing — reads markdown, seo_title, meta_description)

Anthropic SDK (existing dep — @anthropic-ai/sdk)
└── messages.create({ model: env.ANTHROPIC_MODEL ?? "claude-haiku-4-5-20251001",
                      temperature: 0,
                      max_tokens: 2048 })
```

### Data Flow — Run AI Check

```
User clicks "Run AI check" on Draft or Publish step
      │
      ▼
POST /api/blogs/:id/ai-check
      │
      ├─► Auth + ownership check (existing middleware + verify blog.user_id)
      │
      ├─► Load draft.markdown, draft.seo_title, draft.meta_description
      │     └─► If markdown empty → 409 DRAFT_NOT_READY
      │
      ├─► Strip excluded segments (code, blockquote, log block, link URLs)
      │     └─► Compute counts and example snippets (returned to client)
      │
      ├─► Detect language on stripped body
      │     └─► If non-English → persist + return mode=language_unsupported (no LLM call)
      │
      ├─► Compute inputHash = sha256(body + '' + seoTitle + '' + meta)
      ├─► Read RUBRIC_VERSION from rubric source
      │
      ├─► repo.findFresh(blogId, inputHash, rubricVersion)
      │     └─► HIT → record analytics, return cached row.toApiResponse()
      │
      ├─► CACHE MISS:
      │     ├─► Build LLM prompt (system + user) from rubric YAML
      │     ├─► Anthropic.messages.create({ model: resolveModel(), temperature: 0, max_tokens: 2048 })
      │     ├─► Strip ```json fences if present (existing alignment-service trick)
      │     ├─► JSON.parse → validate against AiCheckResult schema
      │     │     └─► On parse fail: retry once with stricter prompt; second fail → 502 AI_BAD_RESPONSE
      │     ├─► For each evidence_snippet: verify substring exists in scored input
      │     │     └─► If not found, drop the entry (anti-hallucination)
      │     └─► repo.insert(row)
      │
      └─► 200 { ...AiCheckApiResponse, cached: false }
```

### Data Flow — Help Page Render

```
Build / runtime
      │
      ▼
Frontend imports ai-detector-rubric.json (built from same YAML source via a small build step)
      │
      ▼
GET /help/ai-detector-rules  (public SPA route, no auth)
      │
      ▼
AiDetectorRulesPage renders:
  - Hero + score-computation explanation
  - "AI-like signals" section, one card per rule (rule_id matches API)
  - "Human-like signals" section, one card per rule
  - "Excluded from scoring" section
  - "Modes" reference table
  - Footer: rubric_version + last updated
```

The build step ensures the YAML source produces:

1. The system prompt embedded in the LLM call (`backend/src/lib/ai-detector-rubric.ts` reads YAML at process start)
2. A JSON file the frontend imports (`frontend/src/lib/ai-detector-rubric.generated.json` — gitignored, regenerated on `npm run build`)

Identical content, two consumers — they cannot drift.

---

## API Design

### Endpoints

| Method | Path | Purpose | Auth |
|--------|------|---------|------|
| POST | `/api/blogs/:id/ai-check` | Run AI check on the current draft (cache-first) | Required |
| POST | `/api/blogs/:id/events` | Existing — used to record `recordAiCheckRuleExpanded` etc. | Required |

> **Note on PRD discrepancy**: the PRD said `/api/drafts/:id/ai-check`. The repo's existing convention is to scope all draft operations under `/api/blogs/:id/...` (see `routes/blog-routes.ts`). I'm using `/api/blogs/:id/ai-check` to match. The PRD will be updated to reflect this in approval.

### Request / Response Examples

**POST `/api/blogs/:id/ai-check`**

Request: empty body (server reads the latest persisted draft for this blog).

Response `200`:

```json
{
  "rubric_version": "1.0.0",
  "ai_likelihood_percent": 72,
  "human_likelihood_percent": 28,
  "uncertainty_percent": 18,
  "mode": "ai_assisted",
  "cached": false,
  "scored_at": "2026-05-07T10:23:00Z",
  "llm": { "provider": "anthropic", "model": "claude-haiku-4-5-20251001" },
  "tokens": { "input": 2410, "output": 612 },
  "top_signals": {
    "ai_like": [
      { "signal": "Repetitive phrasing", "weight": 12, "evidence_snippets": ["As noted earlier..."] }
    ],
    "human_like": [
      { "signal": "Personal mistake", "weight": -15, "evidence_snippets": ["I once shipped a config..."] }
    ]
  },
  "rule_breakdown": [
    {
      "rule_id": "ai-repetitive-phrasing",
      "direction": "ai_like",
      "points_applied": 12,
      "evidence_snippet": "As noted earlier, planning is essential...",
      "section": "H2: Best Practices",
      "field": "body",
      "suggested_fix": "Vary sentence openers — 'As noted earlier' appears 4 times."
    }
  ],
  "section_scores": [
    { "section": "Intro", "ai_likelihood_percent": 45, "notes": "Generic opener but no repetition" },
    { "section": "H2: Best Practices", "ai_likelihood_percent": 78, "notes": "Repetitive phrasing + mechanical transitions" }
  ],
  "excluded_segments": [
    { "type": "code", "count": 3, "example_snippet": "npm install lodash" }
  ],
  "creator_tips": [
    "Add a specific failure story (reduces AI score by ~15 points).",
    "Replace 'in conclusion' with a sharp, opinionated closing line."
  ]
}
```

Response `200` — cached:

Identical schema with `"cached": true` and `"scored_at"` reflecting the original run.

Response `200` — non-English:

```json
{
  "rubric_version": "1.0.0",
  "mode": "language_unsupported",
  "cached": false,
  "creator_tips": ["Detector currently supports English only."],
  "ai_likelihood_percent": null,
  "human_likelihood_percent": null,
  "uncertainty_percent": null
}
```

### Error Responses

| Status | Code | When |
|--------|------|------|
| 401 | `UNAUTHORIZED` | No valid session |
| 403 | `FORBIDDEN` | Blog belongs to a different user |
| 404 | `NOT_FOUND` | Blog ID doesn't exist |
| 409 | `DRAFT_NOT_READY` | No draft body persisted yet |
| 429 | `RATE_LIMITED` | Per-user limit exceeded (30 checks per draft per hour) |
| 502 | `AI_BAD_RESPONSE` | LLM returned malformed JSON twice |
| 502 | `AI_UNAVAILABLE` | Anthropic API unreachable / 5xx |
| 500 | `INTERNAL_ERROR` | Unhandled |

---

## Data Model

### Migration: `migrate-015-blog-ai-checks-table.sql`

```sql
CREATE TABLE blog_ai_checks (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blog_id                  UUID NOT NULL REFERENCES blogs(id) ON DELETE CASCADE,
  input_hash               CHAR(64) NOT NULL,
  rubric_version           VARCHAR(32) NOT NULL,
  ai_likelihood_percent    SMALLINT,
  human_likelihood_percent SMALLINT,
  uncertainty_percent      SMALLINT,
  mode                     VARCHAR(32) NOT NULL,
  result                   JSONB NOT NULL,
  llm_provider             VARCHAR(32) NOT NULL,
  llm_model                VARCHAR(100) NOT NULL,
  tokens_input             INTEGER NOT NULL DEFAULT 0,
  tokens_output            INTEGER NOT NULL DEFAULT 0,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cache lookup index (the hot path)
CREATE UNIQUE INDEX uniq_blog_ai_checks_cache_key
  ON blog_ai_checks (blog_id, input_hash, rubric_version);

-- Cleanup / observability indexes
CREATE INDEX idx_blog_ai_checks_blog_id ON blog_ai_checks (blog_id);
CREATE INDEX idx_blog_ai_checks_created_at ON blog_ai_checks (created_at);

-- Mode validation (cheap CHECK; rubric versions handled in app)
ALTER TABLE blog_ai_checks
  ADD CONSTRAINT chk_blog_ai_checks_mode CHECK (
    mode IN ('pure_ai', 'ai_assisted', 'human_polish', 'pure_human', 'language_unsupported')
  );
```

This migration requires the `/migration` skill to produce the labelled ticket + AgDR before any of these SQL files are touched, per the `migration` gate in `.claude/rules/workflow-gates.md`. See **Implementation Plan** Task #1.

### Access Patterns

| Pattern | Query |
|---------|-------|
| Cache lookup | `SELECT * FROM blog_ai_checks WHERE blog_id=$1 AND input_hash=$2 AND rubric_version=$3 LIMIT 1` |
| Insert new run | `INSERT INTO blog_ai_checks (...) VALUES (...) ON CONFLICT (blog_id,input_hash,rubric_version) DO NOTHING RETURNING *` |
| Cleanup (cron, deferred to Phase 2) | `DELETE FROM blog_ai_checks WHERE created_at < NOW() - INTERVAL '90 days'` |

The `ON CONFLICT DO NOTHING` handles the race where two parallel calls miss the cache, both call the LLM, and both try to insert — the second insert is a no-op and the handler re-reads.

---

## Rubric Source File

Path: `backend/src/lib/ai-detector-rubric.yaml`

```yaml
version: 1.0.0
last_updated: 2026-05-07
language: en
initial_score: 50
mode_thresholds:
  pure_human:   { max: 24 }
  human_polish: { min: 25, max: 49 }
  ai_assisted:  { min: 50, max: 79 }
  pure_ai:      { min: 80 }

excluded_segments:
  - type: code
    description: Fenced code blocks and inline code
  - type: log
    description: Log-output blocks (rendered like code, prefixed with timestamps)
  - type: blockquote
    description: Lines starting with > (attributed external text)
  - type: url
    description: URLs inside link markdown — link text is still scored

short_post_words: 300        # below this, +20 uncertainty (capped at 100)
long_post_words: 5000        # truncate to this many words

rules:
  ai_like:
    - id: ai-repetitive-phrasing
      name: Repetitive phrasing / same sentence shapes
      weight_min: 8
      weight_max: 15
      definition: |
        Multiple paragraphs use the same sentence opener or structure
        (e.g. "As noted earlier...", "Similarly...", "It is important to...").
      ai_example: "As noted earlier, planning is essential. Similarly, execution matters."
      human_example: "Planning matters. Execution matters more — and most teams forget this."
      fix_tip: Vary your sentence openers; cut transitional crutches.

    - id: ai-mechanical-transitions
      name: Mechanical transitions
      weight_min: 4
      weight_max: 9
      definition: |
        "Firstly / Secondly / Lastly" or "In conclusion" used without genuine sequencing.
      ai_example: "Firstly, plan. Secondly, execute. Lastly, review."
      human_example: "Plan first. Then ship something rough. Review after it lands."
      fix_tip: Replace mechanical connectors with prose flow or remove them.

    # ... full set of rules from the PRD rubric ...

  human_like:
    - id: human-personal-stakes
      name: First-person experience with stakes
      weight_min: -10
      weight_max: -20
      definition: |
        First-person ("I", "we") narrative attached to a concrete consequence —
        a failure, a trade-off, an uncomfortable choice.
      ai_example: "Teams should consider trade-offs before deploying."
      human_example: "We deployed on a Friday and our pager went off at 2 a.m. Never again."
      fix_tip: Add a moment from your real experience — what went wrong, what you learned.

    # ... full set ...
```

`backend/src/lib/ai-detector-rubric.ts` loads this file once at process start, exposes `RUBRIC_VERSION`, `getSystemPrompt()`, and `getRulesForHelpPage()`. A small build step (`scripts/build-rubric-json.ts`) converts the same YAML into `frontend/src/lib/ai-detector-rubric.generated.json` for the help page.

---

## Implementation Plan

### Tasks

| # | Task | Layer | Estimate | Dependencies |
|---|------|-------|----------|--------------|
| 1 | `/migration` flow → labelled ticket + AgDR + `migrate-015-blog-ai-checks-table.sql` | DB | 2h | — |
| 2 | Domain types + value objects (`AiDetectorMode`, `RubricVersion`, `InputHash`, `AiCheckResult`) in `domain/types.ts` | Domain | 2h | 1 |
| 3 | Author rubric YAML at `backend/src/lib/ai-detector-rubric.yaml` (full rule set, 8 AI-like + 6 human-like + thresholds) | Rubric | 4h | — |
| 4 | `lib/ai-detector-rubric.ts` — singleton loader + `getSystemPrompt()` + `getRulesForHelpPage()` | Backend lib | 3h | 3 |
| 5 | `lib/exclusion-stripper.ts` — strip code, log, quote, link URL; return cleaned text + counts + example snippets | Backend lib | 3h | — |
| 6 | `lib/language-detector.ts` — heuristic English detection (ASCII ratio + common-word check) | Backend lib | 2h | — |
| 7 | `lib/input-hash.ts` — sha256 of normalised body+seoTitle+meta with separator | Backend lib | 1h | — |
| 8 | `repositories/blog-ai-checks-repository.ts` — `findFresh` + `insert` | Repo | 2h | 1, 2 |
| 9 | `services/ai-detector-service.ts` — Anthropic SDK call, JSON parse + validate + anti-hallucination check, retry-once on bad JSON | Service | 6h | 2, 4 |
| 10 | `handlers/blog-ai-check-handler.ts` — orchestrator (auth + load draft + strip + lang detect + cache lookup + service call + persist + analytics) | Handler | 4h | 5–9 |
| 11 | Wire `POST /api/blogs/:id/ai-check` in `routes/blog-routes.ts`; rate-limit middleware (30/draft/hour) | Routes | 2h | 10 |
| 12 | `scripts/build-rubric-json.ts` — YAML → JSON build step; wire into `npm run build` for both frontend and backend | Build | 2h | 3 |
| 13 | `frontend/src/api/blog-api.ts` — `runAiCheck(blogId): Promise<AiCheckResult>` | Frontend API | 1h | 11 |
| 14 | `frontend/src/components/AuthenticityPanel.tsx` — score badge, mode chip, section scores, expandable rule_breakdown, creator tips, "How does this score work?" link | Frontend UI | 8h | 12, 13 |
| 15 | Wire `AuthenticityPanel` into `DraftStep.tsx` and `PublishStep.tsx` (button enabled only when draft body exists) | Frontend integration | 2h | 14 |
| 16 | `frontend/src/pages/AiDetectorRulesPage.tsx` — public page rendering the generated JSON; add `/help/ai-detector-rules` route in `App.tsx` outside `<ProtectedRoute>` | Frontend page | 5h | 12 |
| 17 | Fixture suite: 30 labelled posts under `backend/fixtures/ai-detector/` (10 known-AI, 10 known-human, 10 hybrid); each is a `.md` plus a `.expected.json` with score range + required fired rules | Fixtures | 6h | 9 |
| 18 | Vitest suite `__tests__/ai-detector-rubric-fixtures.test.ts` — runs detector against each fixture; asserts known-AI ≥ 60, known-human ≤ 40, hybrid 30–70 | Tests | 3h | 17 |
| 19 | Unit tests — domain types, exclusion stripper, language detector, input hash, JSON validation | Tests | 4h | 5–9 |
| 20 | Integration tests — handler full path: cache miss, cache hit, draft-not-ready, non-English, ownership-denied | Tests | 3h | 10 |
| 21 | Add `recordAiCheckRun`, `recordAiCheckRuleExpanded`, `recordAiCheckCacheHit` events via existing `/api/blogs/:id/events` endpoint | Analytics | 2h | 11, 14 |
| 22 | CI: hook the fixture suite into the existing GitHub Actions run; rubric YAML changes trigger the suite | CI | 2h | 18 |
| 23 | E2E (Playwright) — generate a draft, click Run AI check on Publish step, expand a rule, verify scroll-to behaviour | Tests | 3h | 14, 15 |

**Total estimate**: ~72 h ≈ 2 engineer-weeks plus QA / E2E. Aligned with the PRD timeline (Dev complete 2026-05-25).

### Sub-issue mapping for the epic

| User story | Maps to tasks |
|------------|---------------|
| US-1 (run on demand, both steps) | 10, 11, 13, 14, 15 |
| US-2 (mode classification) | 4, 9, 14 |
| US-3 (rule breakdown expand) | 9, 14 |
| US-4 (section scores) | 9, 14 |
| US-5 (creator tips) | 9, 14 |
| US-6 (re-run + hard cache) | 7, 8, 10, 14 |
| US-7 (excluded-segment transparency) | 5, 10, 14 |
| US-8 (rules reference page) | 12, 16 |

The Tech Lead will create one sub-issue per user story under #115 once this design is approved.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| LLM returns malformed JSON despite `temperature=0` | Med | Med | Retry once with stricter "Return ONLY valid JSON" reinforcement (existing trick in `alignment-service.ts`); if second fail, return 502 `AI_BAD_RESPONSE` and log full response |
| Rubric YAML and prompt drift (someone edits `rubric.yaml` but forgets to bump `rubric_version`) | Med | High | The `lib/ai-detector-rubric.ts` loader hashes the YAML content at load and exposes `RUBRIC_VERSION` from the YAML's `version:` field. CI step asserts `version` was bumped if the YAML hash changed |
| LLM hallucinates evidence snippet that isn't in the source text | Med | Med | Server-side anti-hallucination check: every `evidence_snippet` must be a substring of the scored input. Failed entries are dropped from `rule_breakdown` and `top_signals` before the response is returned (PRD requirement) |
| Cache key collision on draft re-edits with whitespace-only changes | Low | Low | Normalise input before hashing: trim trailing whitespace, collapse repeated spaces, normalise line endings to `\n`. Document the normalisation rules in `lib/input-hash.ts` |
| Postgres `blog_ai_checks` table grows unbounded | Low | Low | Acceptable in v1 (one row per unique (blog, input, rubric_version)). Phase-2 cleanup cron deletes rows older than 90 days |
| LLM call > 5 s for 2,000-word drafts | Med | Med | Default to Haiku 4.5 (matches `.env.example` default); set Anthropic SDK timeout to 30 s with one retry on 5xx; report P95 in monitoring |
| Help page not indexed by Google because SPA | High | Med | Either pre-render the page at build time (Vite SSG), or accept that Google now indexes JS-rendered SPAs. AgDR-required decision before building Task 16 |
| Two parallel cache misses double-bill the LLM | Low | Low | `INSERT ... ON CONFLICT DO NOTHING` then re-read. Both clients get the same cached row; only one LLM bill |
| Rate limiter (30/draft/hour) is per-process; multiple backend pods would multiply | Low | Low | v1 has a single backend pod (current deploy). When we scale out, move limiter to a shared store. Document as a known limitation |

---

## Security Considerations

- All `/api/blogs/:id/ai-check` calls go through the existing `requireAuth` middleware AND the handler verifies `blog.user_id === req.user.id` before reading the draft (matches every other blog-scoped handler).
- The Anthropic API key stays in `.env`; never reach the frontend.
- Draft text sent to the LLM is logged ONLY when `LOG_AI_CHECK_PAYLOADS=true` (off by default; intended for staging debug only). Audited before launch.
- The `result` JSONB column may contain user-authored text in `evidence_snippet` fields; no PII is added by the detector itself, but the user's draft body itself is the thing being scored — same data sensitivity as any other draft persistence.
- Help page (`/help/ai-detector-rules`) is fully static content — no user input, no XSS surface. Renders from a build-time JSON, not a runtime user-supplied source.
- Rate limit (30/draft/hour) protects against a malicious or buggy client looping the endpoint.
- This PR does NOT touch auth, crypto, secrets, or `.env` paths beyond reading `ANTHROPIC_API_KEY` and `ANTHROPIC_MODEL` (already used elsewhere). Security review (`security-auditor` role) does not auto-fire per `.claude/rules/role-triggers.md`. If the Tech Lead disagrees, escalate.

---

## Testing Strategy

| Type | Coverage | Notes |
|------|----------|-------|
| Unit (Vitest) | Domain types, value objects, exclusion stripper, language detector, input hash, JSON schema validation, anti-hallucination check | All branches; ≥ 90 % for domain logic |
| Fixture suite (Vitest) | 30 labelled posts, asserts score ranges + required fired rules per post | The CI gate for any rubric change |
| Integration (Vitest + supertest) | Handler full path: cache miss, cache hit, draft-not-ready (409), language unsupported (200 with `language_unsupported` mode), ownership denied (403), rate limit (429), bad-JSON-from-LLM (502 after retry) | One test per branch |
| E2E (Playwright) | Generate a draft → Run AI check on Publish step → expand a rule → click snippet → assert preview scrolls and highlights | One critical-path test |
| Frontend component | `AuthenticityPanel` rendering states (idle, loading, success, error, language-unsupported, cached-result indicator); accessibility (colour + icon for severity) | Mock the API |

The fixture suite is the contract: bumping `rubric_version` requires the suite to pass. The CI workflow runs it on PRs that touch `backend/src/lib/ai-detector-rubric.yaml`, `backend/src/services/ai-detector-service.ts`, or `backend/fixtures/ai-detector/**`.

---

## AgDRs

Per `.claude/rules/agdr-decisions.md`, the following decisions are recorded as Agent Decision Records in the project repo:

| # | Decision | AgDR | Decision summary |
|---|----------|------|------------------|
| 1 | Rubric source format | [`AgDR-0027`](../../workspace/blog-generator/docs/agdr/AgDR-0027-ai-detector-rubric-source-format.md) | YAML at `backend/src/lib/ai-detector-rubric.yaml`; build script emits frontend JSON |
| 2 | Cache layer | [`AgDR-0028`](../../workspace/blog-generator/docs/agdr/AgDR-0028-ai-detector-cache-layer.md) | New Postgres table `blog_ai_checks`, unique index on `(blog_id, input_hash, rubric_version)` |
| 3 | Language detection | [`AgDR-0029`](../../workspace/blog-generator/docs/agdr/AgDR-0029-ai-detector-language-detection.md) | Heuristic — ASCII ratio ≥ 0.85 + 5-of-10 common English stopwords; no dependency |
| 4 | Help page rendering | [`AgDR-0030`](../../workspace/blog-generator/docs/agdr/AgDR-0030-ai-detector-help-page-rendering.md) | SPA route in existing Vite app + build-time JSON import; phase-2 escalation to SSG if indexing is poor |
| 5 | Default LLM model | [`AgDR-0031`](../../workspace/blog-generator/docs/agdr/AgDR-0031-ai-detector-default-model.md) | `claude-haiku-4-5-20251001`; fixture suite (FR-16) is the gate that proves it's good enough |

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| What signal indicates "draft is ready" on the Draft step? Existing `draft.markdown` non-empty check, or a new `draft.status === 'generated'` flag? | Tech Lead | Open |
| Help page lives under the existing app router (`/help/ai-detector-rules`) or on a separate marketing/docs site for SEO indexing? Drives AgDR #4 | Head of Product | Open |
| Naming — "Authenticity check" vs "AI check" vs "Originality score". Affects `AuthenticityPanel.tsx` filename, panel heading, help page heading | UX Designer | Open |
| Cache: Postgres now (per AgDR #2); revisit Redis when we scale beyond one backend pod — when's that? | Tech Lead | Open |
| The `recordAiCheckRuleExpanded` event needs a `rule_id` field — is that already supported by the events endpoint, or does the schema need extending? | Tech Lead | Open |
| Per-user rate limit (30/draft/hour) is documented as v1 single-pod — when we scale, do we use Postgres-backed limiter or move to Redis? | Platform | Open |

---

## Estimates Summary

| Phase | Effort |
|-------|--------|
| Backend (Tasks 1–11, 17–22) | ≈ 39 h |
| Frontend (Tasks 12–16) | ≈ 18 h |
| Tests (Tasks 18–20, 23) | ≈ 13 h |
| **Total** | **≈ 70 h** |

Maps to PRD timeline: Tech Design Complete 2026-05-13 → Dev Complete 2026-05-25 (≈ 9 working days for 70 h with two engineers part-time).

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Tech Lead | Mohamed Naser | 2026-05-07 | Author |
| Head of Engineering | — | — | Pending |
| Security Auditor | — | — | N/A — no auth/crypto/secrets changes; existing patterns reused |
