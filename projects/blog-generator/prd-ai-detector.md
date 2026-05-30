# PRD: AI Content Detector

**Status**: Draft
**Author**: Product Manager
**Created**: 2026-05-07
**Last Updated**: 2026-05-07
**Epic**: [mohamednaseramein/blog-generator#115](https://github.com/mohamednaseramein/blog-generator/issues/115)

---

## Overview

### Problem Statement

Content creators, bloggers, media buyers, and account managers use the blog-generator to produce drafts they publish on external CMS platforms. AI-generated copy that reads like AI hurts them in three ways:

1. **Search visibility** — Google's "helpful content" guidance penalises content that lacks original perspective, and many SEO tools now flag AI-pattern text.
2. **Brand trust** — when readers (or clients reviewing drafts) sense AI prose, the publication loses credibility.
3. **Re-work cost** — users today copy generated drafts into third-party detectors (GPTZero, Originality.ai, Copyleaks), get a score, and then guess at what to change. The loop is slow and the third-party scores don't tell them *which sentences* to fix.

The blog-generator can close that loop in-product: give the user a transparent, rule-based AI-likelihood score plus a per-rule breakdown that points at the specific sentences and offers a concrete fix. Crucially, the rules must be **legible to the user** — the value isn't the score, it's that the user learns what AI prose looks like and gets better drafts on the next iteration.

### What Already Exists (do not re-build)

| Feature | Where |
|---------|-------|
| Markdown draft body, generated and editable | `PublishStep` — preview panel |
| Flesch-Kincaid readability score (per `prd-seo-ready-content.md`) | `PublishStep` — score badge area |
| Section structure (H1/H2/H3) | AI generation prompt |
| `metaDescription`, `suggestedSlug`, `seoTitle` (per `prd-seo-ready-content.md`) | `PublishStep` — SEO & social panel |

### Target User

**Primary**: Content creators, bloggers, media buyers, account managers — the same audience as the SEO-ready-content PRD. They publish on external CMS, care about search visibility and brand trust, and currently use third-party AI detectors as a manual step before publishing.

**Secondary**: Agency writers and freelancers handing drafts to clients. Clients increasingly run AI checks themselves; pre-running the check in-product lets the writer ship a cleaner draft.

### Goals

1. Users can run an AI-likelihood check on the generated draft from the Publish step with a single click and see a score within 5 seconds (P50).
2. The output classifies the draft into one of four modes — `pure_ai`, `ai_assisted`, `human_polish`, `pure_human` — alongside the 0–100 score, so users see the *kind* of AI-ness, not just the magnitude.
3. Every rule that fires is shown to the user with the exact snippet that triggered it, the points it added or removed, and a specific suggested fix — no black-box scoring.
4. After the user edits the draft, they can re-run the check and see the score move; signals that no longer fire disappear from the breakdown.
5. The detector is fully heuristic and runs against the LLM configured via `.env` (provider + model are environment-driven; temperature is pinned to 0 in code) — no third-party detection API dependency, no external service costs beyond the LLM call.
6. A `/help/ai-detector-rules` page documents every rule in the rubric so writers can study the rules and self-correct before they ever run a check.

### Non-Goals (Out of Scope)

- **Comparable accuracy to commercial AI detectors** (GPTZero, Originality.ai). This is a heuristic teaching tool, not a forensic one. We commit to transparency, not to leaderboard-grade accuracy.
- **Auto-humanizer / auto-rewrite** of flagged sections — Phase 2 follow-on, tracked separately.
- **Blocking export** based on score — the user decides whether to act on the warning. No gate.
- **Plagiarism / duplicate-content detection** — different problem, different signal set.
- **Multi-language support beyond English** in v1. Non-English drafts return a "language not supported" notice and skip scoring.
- **Continuous live scoring as the user types** — the score is computed on demand, per click, against the current draft state.
- **Author-provided overrides that change the score**. There is no `author_notes` field on the Publish step today and we are not adding one for v1. The principle stands for any future input: author-supplied claims about authorship can only bump *uncertainty*, never the score.
- **Free for all users** — no paid gating in v1. The cost ceiling (≤ $0.02 per check) and the per-user rate limit (30 checks per draft per hour) are the only protection against runaway usage.

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Adoption — share of Publish-step sessions that click "Run AI check" | ≥ 35 % within 4 weeks of launch | `recordAiCheckRun` analytics event |
| Iteration — share of users who re-run the check after editing | ≥ 50 % of users who ran it once | `recordAiCheckRun` event count per session |
| Score reduction — among users who re-run, median change in `ai_likelihood_percent` | ≥ -10 points | Score deltas per session |
| Educational value — share of users who expand at least one rule breakdown | ≥ 60 % of users who ran the check | `recordAiCheckRuleExpanded` event |
| Cost per check | ≤ $0.02 per run | LLM provider billing / runs |

---

## User Stories

### US-1: Run AI check on demand

> As a content creator working on a draft, I want to click "Run AI check" and get an AI-likelihood score, so that I can decide whether to humanise it before moving on.

**Acceptance Criteria**:

- [ ] An "Authenticity check" panel with a "Run AI check" button is available on **both** the Draft step and the Publish step
- [ ] On the Draft step, the button is enabled only after a draft body has been generated; before that it is disabled with a tooltip "Generate a draft first"
- [ ] On the Publish step, the button behaves identically and shares the same cached result (re-running on the Publish step after a Draft-step run hits the cache, no second LLM call)
- [ ] Clicking the button runs the detector against the current Markdown body **plus** the SEO title and meta description, and shows a loading state
- [ ] On success, the panel shows: `ai_likelihood_percent` (large numeric badge), `human_likelihood_percent`, `uncertainty_percent`, and the `mode` label (`pure_ai`, `ai_assisted`, `human_polish`, `pure_human`)
- [ ] The score badge is colour-coded: green (≤ 30), amber (31–69), red (≥ 70)
- [ ] If the LLM call fails, the panel shows an inline error with a retry button — the rest of the step is unaffected
- [ ] P50 response time is ≤ 5 seconds for drafts up to 2,000 words

### US-2: See the mode classification

> As a media buyer who knows my drafts are AI-assisted, I want to see *which mode* my draft sits in (pure_ai vs ai_assisted vs human_polish vs pure_human) rather than just a score, so that I know whether the issue is the AI baseline or my editing.

**Acceptance Criteria**:

- [ ] The mode is one of four values, displayed as a labelled chip next to the score:
  - **Pure AI** — score ≥ 80 and no human-like signals fired
  - **AI-assisted** — score 50–79 with mixed signals
  - **Human-polish** — score 25–49 with strong human-like signals overlaid on a generic structure
  - **Pure human** — score ≤ 24 with multiple strong human-like signals
- [ ] The mode definition is shown in a tooltip when the user hovers the chip
- [ ] The mode is consistent with the score (no `pure_human` chip on a 75% AI score)

### US-3: Expand the rule breakdown

> As a blogger learning what AI prose looks like, I want to expand the score panel and see exactly which rules fired, the snippet that triggered each one, and how to fix it, so that I can edit my draft with intent rather than guessing.

**Acceptance Criteria**:

- [ ] Below the score, an expandable "Why this score?" section lists every rule that fired
- [ ] Each row shows: rule name, direction (+ AI-leaning or − human-leaning), points applied, the ≤ 20-word evidence snippet, the section heading where it fired, and a one-line suggested fix
- [ ] Rules that fired with positive (AI-increasing) weight are visually distinct from rules with negative (human-increasing) weight
- [ ] Clicking a snippet scrolls the preview to that section and highlights the snippet for 2 seconds
- [ ] At least one rule must have evidence; rules without a quotable snippet are never shown (no hallucinated evidence)

### US-4: See section-level scores

> As an account manager debugging a long post, I want a per-section score breakdown (Intro, each H2, Conclusion), so that I know which section to focus my edits on rather than re-reading the whole post.

**Acceptance Criteria**:

- [ ] The panel shows a `section_scores` list with one row per H2 heading (plus Intro and Conclusion if detected)
- [ ] Each row shows the section title and its `ai_likelihood_percent` with the same colour coding as the overall score
- [ ] Sections without H2 headings are bucketed by 200-word windows or thirds (if shorter), labelled "Section 1", "Section 2", etc.
- [ ] If the post is < 300 words total, only one overall row is shown — section breakdown is hidden

### US-5: See actionable creator tips

> As a content creator who's seen the score, I want a short list of concrete things I can do to bring it down, so that I don't have to figure out the fix from the rule list alone.

**Acceptance Criteria**:

- [ ] The panel shows a "What to change" list of 3–5 creator tips
- [ ] Each tip is one sentence, action-oriented (e.g. "Add a specific failure story from your own experience to reduce the AI score by ~15 points")
- [ ] Tips are tied to the rules that actually fired — generic tips that don't apply to this draft are not shown
- [ ] If `ai_likelihood_percent` ≤ 30, tips are replaced with a "Looks human-written" confirmation message (no need to fix what isn't broken)

### US-6: Re-run after editing

> As a user who's edited my draft based on the breakdown, I want to re-run the check and see the score change, so that I know my edits worked.

**Acceptance Criteria**:

- [ ] The "Run AI check" button is available again after the first run completes
- [ ] Re-running replaces the previous result; previous breakdown is not retained in UI
- [ ] **Hard caching**: cache key is `hash(body + seo_title + meta_description) + rubric_version`. If the cache key matches a prior run, the cached result is returned with no LLM call and the panel surfaces a "Cached result" indicator
- [ ] Cache invalidates only when (a) any of the scored fields change, or (b) the deployed `rubric_version` is bumped (e.g. `1.0.0 → 1.1.0`)
- [ ] Manual cache flush is not exposed to users — if a user wants a "fresh" run on an unchanged draft, they edit the draft (which changes the hash) or wait for a rubric update

### US-7: Excluded-segment transparency

> As a developer-blogger writing posts heavy in code, I want to know that my code blocks were not used in scoring, so that I trust the score reflects my prose, not my snippets.

**Acceptance Criteria**:

- [ ] Below the score, a small "Excluded from scoring" line names the segment types that were skipped (e.g. "3 code blocks, 1 blockquote")
- [ ] Hovering shows the example snippet for each excluded segment
- [ ] Excluded segments are: code blocks, log output blocks, blockquotes, link URLs (the link text is still scored)

### US-8: Detector rules reference page

> As a writer who wants to understand what AI prose looks like, I want a dedicated page that documents every rule in the detector's rubric — what it means, what triggers it, examples, and how to write so it doesn't fire — so that I can learn the rules and improve my drafts before I ever run a check.

**Acceptance Criteria**:

- [ ] A new page is available at `/help/ai-detector-rules` and is linked from the Authenticity panel via a "How does this score work?" link
- [ ] The page is accessible without authentication and is indexable by search engines (this is content-marketing-grade educational content)
- [ ] The page lists **every rule** in the rubric, grouped into two sections: "AI-like signals (increase the score)" and "Human-like signals (decrease the score)"
- [ ] Each rule entry shows:
  - The rule name and `rule_id` (matches the `rule_id` in the API's `rule_breakdown`)
  - The weight range (e.g. `+8 to +15`)
  - A plain-English definition of what the rule looks for
  - A short AI-like example snippet that *would* trigger the rule
  - A short human-like example snippet that would *not* trigger it
  - A one-line "How to write so this doesn't fire" tip
- [ ] The page also documents: how the score is computed (initial 50 + weighted indicators, clamped 0–100), how the four modes are decided, what's excluded from scoring, the short-post and long-post rules, the language rule, and the anti-gaming principle for any future author-notes input
- [ ] The page footer shows the current `rubric_version` and a "last updated" date
- [ ] Page content and the API rubric are generated from a single source so they cannot drift

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Draft body is empty | "Run AI check" button is disabled with tooltip "Generate a draft first" |
| Draft body < 300 words after exclusions | Score is shown, but `uncertainty_percent` is bumped by ≥ 20 and a creator tip notes the short-post limitation |
| Draft body > 5,000 words | Only the first 5,000 words are scored; the panel notes "Scored first 5,000 words of 6,200" |
| Draft is non-English | Panel shows "Language not supported in v1 — score skipped" with no LLM call made |
| LLM returns malformed JSON | Server retries once with a stricter system prompt; on second failure, returns an error to the client |
| User clicks the button twice rapidly | Second click is a no-op while the first request is in flight (button disabled during loading) |
| Mixed signals (many AI + many human) | `uncertainty_percent` ≥ 50, and the mode defaults to `ai_assisted` |
| Draft is mostly bullet lists (≥ 40 % of lines) | `uncertainty_percent` ≥ 50 and a creator tip notes that lists are weak signal |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Add an "Authenticity check" panel with a "Run AI check" button to **both** the Draft step and the Publish step (shared cached result) | Must |
| FR-2 | Backend endpoint `POST /api/drafts/:id/ai-check` returns the strict JSON schema defined below | Must |
| FR-3 | Display `ai_likelihood_percent`, `human_likelihood_percent`, `uncertainty_percent`, `mode`, `top_signals`, `section_scores`, `excluded_segments`, `creator_tips`, `rule_breakdown` | Must |
| FR-4 | Score is colour-coded green (≤ 30) / amber (31–69) / red (≥ 70) with text/icon also conveying severity (accessibility) | Must |
| FR-5 | Each `rule_breakdown` row links to the corresponding section via scroll-to + highlight | Must |
| FR-6 | Per-section scores rendered with the same colour coding | Must |
| FR-7 | **Hard cache** results by `hash(body + seo_title + meta_description) + rubric_version`; identical input returns the cached result with no LLM call. Cache invalidates only on input change or `rubric_version` bump | Must |
| FR-8 | LLM provider and model are read from `.env` at runtime; `temperature=0` is pinned in code; `rubric_version` is returned in the response so consumers can correlate scores to a rule set | Must |
| FR-9 | Code blocks, log blocks, blockquotes, and link URLs are stripped before scoring; their counts surface in the UI | Must |
| FR-10 | Non-English detection short-circuits the check with a "language not supported" response | Must |
| FR-11 | Analytics events: `recordAiCheckRun`, `recordAiCheckRuleExpanded`, `recordAiCheckCacheHit` | Must |
| FR-12 | The on-demand button is disabled while a request is in flight | Must |
| FR-13 | Scored input is the concatenation of: draft body, SEO title, meta description. The `rule_breakdown` attributes each fired rule to the field it triggered on (`body` / `seo_title` / `meta_description`) | Must |
| FR-14 | A new `/help/ai-detector-rules` page renders the full rubric (every rule, examples, fixes); the page and the rubric prompt share a single content source so they cannot drift | Must |
| FR-15 | The Authenticity panel includes a "How does this score work?" link that navigates to `/help/ai-detector-rules` in a new tab | Must |
| FR-16 | Ship a labelled fixture set under `backend/fixtures/ai-detector/` with at least 10 known-AI, 10 known-human, and 10 hybrid posts. CI runs the detector against the fixtures on every change to the rubric prompt and asserts: known-AI scores ≥ 60, known-human scores ≤ 40, hybrid scores fall in 30–70. Bumping `rubric_version` requires the fixture suite to pass | Must |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | P50 end-to-end response time | ≤ 5 seconds for drafts up to 2,000 words |
| Performance | P95 end-to-end response time | ≤ 12 seconds |
| Cost | LLM cost per check | ≤ $0.02 |
| Reproducibility | Identical scored input + same `rubric_version` → identical cached result. Cold-cache re-run with the same input on the same model + `temperature=0` returns the same numeric score | Verified by the fixture suite (FR-16) on every rubric change |
| Accessibility | All UI elements meet WCAG 2.1 AA | Colour signals must also use icons / text labels |
| Security | The endpoint is authenticated to the draft owner only | Existing auth middleware |
| Privacy | Draft text sent to the LLM is logged only if `LOG_AI_CHECK_PAYLOADS=true` (off by default) | Audit before launch |
| Rate limit | Per-user limit | 30 checks per draft per hour |

### Output JSON Schema (returned by the endpoint)

```json
{
  "rubric_version": "1.0.0",
  "ai_likelihood_percent": 0,
  "human_likelihood_percent": 0,
  "uncertainty_percent": 0,
  "mode": "pure_ai | ai_assisted | human_polish | pure_human",
  "top_signals": {
    "ai_like": [
      { "signal": "Repetitive phrasing", "weight": 12, "evidence_snippets": ["..."] }
    ],
    "human_like": [
      { "signal": "Personal mistake", "weight": -15, "evidence_snippets": ["..."] }
    ]
  },
  "rule_breakdown": [
    {
      "rule_id": "ai-repetitive-phrasing",
      "direction": "ai_like",
      "points_applied": 12,
      "evidence_snippet": "As noted earlier, ...",
      "section": "H2: Best Practices",
      "suggested_fix": "Vary the sentence opener — 'As noted earlier' appears 4 times."
    }
  ],
  "section_scores": [
    { "section": "Intro", "ai_likelihood_percent": 45, "notes": "Generic opener but no repetition" }
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

---

## Design

### User Flow

```
[Publish step]
  Draft is shown in preview panel
  SEO & social panel and readability badge already visible
    |
    v
[Authenticity check panel — collapsed initial state]
  "Run AI check" button + "Last run: never" / "Last run: 2 mins ago"
    |
    v  user clicks "Run AI check"
[Loading]
  Button shows spinner, disabled
    |
    v
[Result rendered]
  Score badge (green / amber / red) + mode chip
  "Excluded from scoring: 3 code blocks, 1 quote"
  Section scores (one row per H2)
  "Why this score?" expander → rule_breakdown rows
  "What to change" → creator_tips list
    |
    v  user edits the draft
[Run AI check enabled again]
  Click → cache miss → fresh LLM call → fresh result
  Or unchanged → "No changes since last check" + cached result
```

### Authenticity Check Panel — Mockup

```
┌─ Authenticity check ──────────────────────┐
│                                                  │
│   AI likelihood       Mode                       │
│   ┌───────┐                                  │
│   │  72 %  │  [ AI-assisted ]                  │
│   └───────┘   uncertainty 18 %                │
│   amber                                          │
│                                                  │
│   Excluded from scoring: 3 code, 1 quote         │
│                                                  │
│   Section scores                                 │
│   • Intro — 45 % (amber)                         │
│   • H2: Best Practices — 78 % (red)              │
│   • H2: Common Pitfalls — 62 % (amber)           │
│   • Conclusion — 81 % (red)                      │
│                                                  │
│   [ Why this score? ▾ ]                           │
│                                                  │
│   What to change                                 │
│   1. Add a specific failure story (≈15 pts)      │
│   2. Replace 'in conclusion' with a sharp closer  │
│   3. Vary sentence openers in Best Practices      │
│                                                  │
│   [ Run AI check again ]                          │
│   Last run: just now                              │
└──────────────────────────────────────────────────┘
```

### Why this score? — Expanded state

```
• + 12  AI: Repetitive phrasing                    │ H2: Best Practices
        "As noted earlier, planning is essential..."  │ Suggestion: Vary sentence openers
• +  9  AI: Mechanical transitions                  │ H2: Common Pitfalls
        "Firstly, ... Secondly, ... Lastly, ..."      │ Suggestion: Use prose connectors
• -  8  Human: Use of \"I\" with stakes               │ Intro
        "I once shipped a config that broke prod..."  │ Strong personal anecdote — keep
```

### Wireframes / Mockups

To be produced by the UX Designer before implementation begins. Key screens: Publish step with collapsed Authenticity panel, Publish step with expanded result, error state, loading state.

---

## Technical Notes

### Dependencies

| Dependency | Type | Status | Notes |
|------------|------|--------|-------|
| LLM provider + model (read from `.env`) | External | Ready | Whatever the existing app config selects; `temperature=0` is pinned in code regardless of provider |
| Rubric prompt template (versioned) | Internal | Ready | Lives in `backend/prompts/ai-detector-rubric.md`; `rubric_version` field bumped on every rubric change |
| Single rubric content source feeding both the prompt and `/help/ai-detector-rules` | Internal | New | A structured YAML or JSON file (e.g. `backend/prompts/ai-detector-rubric.yaml`) is the source of truth; both the prompt and the help page render from it |
| Markdown stripper (excludes code, quotes, log blocks, URLs) | Internal | Ready | Re-uses utility from readability-score work |
| Result cache (in-memory or Redis, keyed by `hash(body + seo_title + meta_description) + rubric_version`) | Internal | Ready | Re-uses existing draft cache layer if available |
| Fixture set + CI gate (`backend/fixtures/ai-detector/`) | Internal | New | 30 labelled posts; CI runs detector against fixtures on rubric changes |
| Analytics — `recordAiCheckRun`, `recordAiCheckRuleExpanded`, `recordAiCheckCacheHit` | Internal | Ready | Same pattern as `recordExportEvent` |

### Technical Constraints

- Detector must be **trustworthy by construction**: hard cache by input hash + `rubric_version` (FR-7) means identical drafts return identical results, period. Model drift is a release-management concern, not a per-call one.
- LLM provider and model are environment-driven (read from `.env`). The PRD does not pick a provider; whatever is configured at deploy time is what runs. `temperature=0` is pinned in code regardless of provider.
- The endpoint is on the existing backend (Express + TypeScript) — no new service.
- The frontend is React + TypeScript + Vite — Authenticity panel is a new component used on both the Draft step and the Publish step.
- LLM cost is the dominant marginal cost. The hard cache (FR-7) is required, not optional.
- Heuristic rubric is the *only* signal source. No third-party detector calls (GPTZero, Originality.ai). This is both a cost and a privacy decision.
- The rubric content lives in a single source file (e.g. `backend/prompts/ai-detector-rubric.yaml`) and is rendered into both the LLM system prompt and the `/help/ai-detector-rules` page, so the user-facing rules and the detector behaviour cannot diverge.
- The `rubric_version` is bumped whenever the rubric source file changes. Bumping the version invalidates the result cache and triggers the CI fixture suite (FR-16).

### Rubric (Appendix)

The full weighted rubric — initial score 50, AI-like indicators (+8 to +15 each), human-like indicators (−8 to −20 each), short-post handling, language detection, anti-gaming author-notes rule — is captured in `backend/prompts/ai-detector-rubric.md` and tagged `rubric_version: 1.0.0`. The rubric is the implementation contract for FR-2; any change to the rubric requires a `rubric_version` bump and a regression test against a labelled fixture set (see Open Questions).

---

## Launch Plan

### Rollout Strategy

- **Phase 1 — Internal dogfood**: launch behind a feature flag (`ai_detector_enabled = true` for internal users) for one week. Goal: validate latency, cost, and the "score doesn't flap on re-runs" reproducibility target.
- **Phase 2 — All users**: remove the flag. No staged rollout — this is an opt-in feature (the user has to click the button), so the blast radius is naturally limited.

---

## Resolved Decisions

| Decision | Resolution |
|----------|------------|
| LLM provider + model | Read from `.env` at runtime; `temperature=0` pinned in code |
| Pricing | Free for all users in v1 (rate-limited at 30 checks per draft per hour) |
| `author_notes` field | Not added in v1 (no existing UI); FR-13 dropped. Anti-gaming principle preserved for any future input |
| Where the button lives | Both Draft step and Publish step, sharing the same cached result |
| Determinism | Hard cache by `hash(body + seo_title + meta_description) + rubric_version`; identical input → identical cached result |
| Fixture set | Ship 30 labelled posts (10 AI, 10 human, 10 hybrid) under `backend/fixtures/ai-detector/`; CI gate on every rubric change |
| Scored input | Body + SEO title + meta description (concatenated; rule_breakdown attributes each fired rule to the field it triggered on) |

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| What does "draft is ready" mean on the Draft step? Is there an existing flag (e.g. `draft.status === "complete"`) the button can key off, or do we need a new signal? | Tech Lead | Open |
| Should the help page (`/help/ai-detector-rules`) live under the existing app router, or is there a separate marketing/docs site it should belong to (for SEO)? | Head of Product | Open |
| Naming — "Authenticity check" vs "AI check" vs "Originality score". The panel label and the page heading need to match | UX Designer | Open |
| Should the cache be in-memory (per server) or shared (Redis)? Affects whether two users editing the same shared draft see consistent results | Tech Lead | Open |

---

## Timeline

| Milestone | Target | Status |
|-----------|--------|--------|
| PRD Approved | 2026-05-09 | Pending |
| Tech Design Complete | 2026-05-13 | Pending |
| Dev Complete (MVP — endpoint + panel + rules page + fixture suite) | 2026-05-25 | Pending |
| QA Complete | 2026-05-29 | Pending |
| Internal dogfood begins | 2026-05-29 | Pending |
| Launch (all users) | 2026-06-05 | Pending |

---

## Phase 2 — Backlog (Not In Scope for This Release)

| Feature | Rationale for Deferral |
|---------|----------------------|
| Auto-humanizer ("Rewrite flagged sections") | Needs a separate prompt pipeline + UX for accept/reject; v1 teaches the user to fix manually first |
| Live scoring as the user edits | Cost-prohibitive at v1 LLM prices; revisit after on-demand adoption stabilises |
| Multi-language support (Spanish, French, Arabic) | Rubric calibration per language is a research task |
| Compare against external detector (GPTZero / Originality.ai) score | Useful for trust but adds vendor cost + privacy concerns |
| Per-author baseline ("you usually score 35; this draft is 65") | Needs longitudinal data; revisit after 3+ months of usage |
| Export the report (PDF / Markdown) for client handoff | Agency/freelancer use case, deferred until adoption proves demand |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser | 2026-05-07 | Author |
| Head of Product | | | Pending |
| Tech Lead | | | Pending |
| Head of Design | | | Pending |
