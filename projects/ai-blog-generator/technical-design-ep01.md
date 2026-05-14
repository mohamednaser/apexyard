# Technical Design: EP-01 — Blog Input & Alignment

**Status**: Draft
**Author**: Mohamed Naser (Tech Lead)
**Date**: 2026-04-20
**PRD**: [projects/ai-blog-generator/PRD.md](./PRD.md)
**Issues**: [EP-01 #1](https://github.com/mohamednaseramein/blog-generator/issues/1) · [US-06/st #2](https://github.com/mohamednaseramein/blog-generator/issues/2) · [US-07 #3](https://github.com/mohamednaseramein/blog-generator/issues/3)

---

## Overview

### Summary

EP-01 covers the entry point of the blog generation wizard: a structured brief form (US-06) where the user provides topic, keyword, persona, tone, and word count targets, followed by an AI-generated Alignment Summary (US-07) that reflects the inputs back and must be confirmed before the wizard proceeds. An optional reference URL is scraped asynchronously in the background to enrich subsequent AI steps.

### Goals

- Accept and persist a validated blog brief with full input sanitisation.
- Scrape optional reference URL in the background without blocking the form submission response.
- Generate an Alignment Summary via the Claude API that can be iterated on before the user confirms.
- Ensure all data is persisted immediately — zero loss on browser refresh.

### Non-Goals

- No AI generation beyond the Alignment Summary (Research and beyond are EP-02+).
- No rich-text editor for the Blog Brief field — plain textarea only in v1.
- No scraping of JavaScript-heavy SPAs — static HTML scraping only.

---

## Domain Model

### Entities

```
Blog
├── id: UUID
├── userId: UUID
├── status: BlogStatus  (draft | in_progress | completed)
├── currentStep: number (0–7, 0 = brief not yet submitted)
├── createdAt: Date
└── updatedAt: Date

BlogBrief
├── id: UUID
├── blogId: UUID  (FK → Blog, 1:1)
├── title: string
├── primaryKeyword: string
├── audiencePersona: string
├── toneOfVoice: string
├── wordCountMin: number
├── wordCountMax: number
├── blogBrief: string
├── referenceUrl: string | null
├── scrapedContent: string | null
├── scrapeStatus: ScrapeStatus  (pending | success | failed | skipped)
├── alignmentSummary: string | null
├── alignmentConfirmed: boolean
├── alignmentIterations: number
├── createdAt: Date
└── updatedAt: Date
```

### Value Objects


| Value Object        | Fields                     | Purpose                                        |
| ------------------- | -------------------------- | ---------------------------------------------- |
| `WordCountRange`    | `min: number, max: number` | Enforces min > 0 and max ≥ min                 |
| `ReferenceUrl`      | `value: string`            | Validates well-formed URL on construction      |
| `AlignmentFeedback` | `text: string`             | Non-empty string passed to Claude regeneration |


### Domain Events


| Event                       | Trigger                       | Data                                |
| --------------------------- | ----------------------------- | ----------------------------------- |
| `BlogBriefSubmitted`        | Brief form saved              | `blogId`, `referenceUrl?`           |
| `UrlScrapeCompleted`        | Scraper finishes              | `blogId`, `status`, `contentLength` |
| `AlignmentSummaryGenerated` | Claude returns summary        | `blogId`, `iteration`               |
| `AlignmentConfirmed`        | User clicks Confirm & Proceed | `blogId`, `finalSummary`            |


---

## Architecture

### Component Diagram

```
React Frontend
│
│  POST /api/blogs/:id/brief
│  GET  /api/blogs/:id/brief/scrape-status   (polling)
│  POST /api/blogs/:id/alignment             (generate)
│  PUT  /api/blogs/:id/alignment             (regenerate w/ feedback)
│  POST /api/blogs/:id/alignment/confirm
│
▼
Express API (TypeScript)
├── BlogBriefHandler          ← validates input, persists brief, fires scrape
├── ScrapeStatusHandler       ← returns scrape_status for polling
├── AlignmentHandler          ← calls Claude API, persists summary
└── AlignmentConfirmHandler   ← marks confirmed, advances currentStep to 1

       │                          │
       ▼                          ▼
PostgreSQL                  UrlScraperService
(blogs, blog_briefs)        (cheerio + axios, fire-and-forget)
                                   │
                                   ▼ updates scrape_status + scraped_content

                            Claude API (Anthropic SDK)
                            (alignment summary generation)
```

### Data Flow — Brief Submission

```
User submits form
      │
      ▼
POST /api/blogs/:id/brief
      │
      ├─► Validate inputs (WordCountRange, ReferenceUrl, required fields)
      │         └─► 400 on failure
      │
      ├─► Upsert blog_briefs row (scrape_status = pending | skipped)
      │
      ├─► If referenceUrl present:
      │       fire-and-forget UrlScraperService.scrape(blogId, url)
      │       (does NOT await — returns immediately)
      │
      └─► 201 { blogId, scrapeStatus }

Frontend polls GET /api/blogs/:id/brief/scrape-status every 2s
until scrapeStatus ∈ { success, failed, skipped }
```

### Data Flow — Alignment Summary

```
User clicks "Generate Alignment Summary" (or auto-triggered after brief save)
      │
      ▼
POST /api/blogs/:id/alignment
      │
      ├─► Load blog_brief row
      ├─► Build Claude prompt (see Prompt Design section)
      ├─► Call Anthropic SDK claude-sonnet-4-6
      ├─► Persist summary to blog_briefs.alignment_summary
      ├─► Increment alignment_iterations
      └─► Return { alignmentSummary, iteration }

User iterates (PUT /api/blogs/:id/alignment with { feedback })
      │
      └─► Same flow, feedback injected into prompt

User confirms (POST /api/blogs/:id/alignment/confirm)
      │
      ├─► Set alignment_confirmed = true
      ├─► Set blog.current_step = 1
      └─► Return { nextStep: 'research' }
```

---

## API Design

### Endpoints


| Method | Path                                 | Purpose                         | Auth     |
| ------ | ------------------------------------ | ------------------------------- | -------- |
| POST   | `/api/blogs`                         | Create blank blog record        | Required |
| POST   | `/api/blogs/:id/brief`               | Submit/update blog brief        | Required |
| GET    | `/api/blogs/:id/brief`               | Get saved brief + scrape status | Required |
| GET    | `/api/blogs/:id/brief/scrape-status` | Poll scrape status              | Required |
| POST   | `/api/blogs/:id/alignment`           | Generate alignment summary      | Required |
| PUT    | `/api/blogs/:id/alignment`           | Regenerate with feedback        | Required |
| POST   | `/api/blogs/:id/alignment/confirm`   | Confirm and advance to Step 2   | Required |


### Request / Response Examples

**POST `/api/blogs/:id/brief`**

Request:

```json
{
  "title": "10 Benefits of Morning Routines",
  "primaryKeyword": "morning routine benefits",
  "audiencePersona": "Busy professionals aged 25-40 seeking productivity",
  "toneOfVoice": "conversational",
  "wordCountMin": 1200,
  "wordCountMax": 1800,
  "blogBrief": "Focus on science-backed benefits, include actionable tips",
  "referenceUrl": "https://example.com/morning-routines"
}
```

Response `201`:

```json
{
  "blogId": "550e8400-e29b-41d4-a716-446655440000",
  "scrapeStatus": "pending"
}
```

**GET `/api/blogs/:id/brief/scrape-status`**

Response `200`:

```json
{
  "scrapeStatus": "success",
  "scrapedContentLength": 4320
}
```

**POST `/api/blogs/:id/alignment`**

Response `200`:

```json
{
  "alignmentSummary": "You want to write a 1,200–1,800 word blog post targeting busy professionals ...",
  "iteration": 1
}
```

**PUT `/api/blogs/:id/alignment`**

Request:

```json
{
  "feedback": "Make the SEO intent clearer — this is informational, not transactional"
}
```

Response `200`:

```json
{
  "alignmentSummary": "Updated summary reflecting informational intent ...",
  "iteration": 2
}
```

### Error Responses


| Status | Code                  | When                                                      |
| ------ | --------------------- | --------------------------------------------------------- |
| 400    | `VALIDATION_ERROR`    | Invalid input (missing fields, bad URL, word count range) |
| 401    | `UNAUTHORIZED`        | No valid session                                          |
| 403    | `FORBIDDEN`           | Blog belongs to a different user                          |
| 404    | `NOT_FOUND`           | Blog ID doesn't exist                                     |
| 409    | `ALIGNMENT_NOT_READY` | Confirm called before summary generated                   |
| 500    | `INTERNAL_ERROR`      | Unhandled server error                                    |
| 502    | `AI_UNAVAILABLE`      | Claude API unreachable or rate-limited                    |


---

## Data Model

### Database Schema

`**blogs` table**


| Field          | Type        | Key        | Purpose                               |
| -------------- | ----------- | ---------- | ------------------------------------- |
| `id`           | UUID        | PK         | Unique blog identifier                |
| `user_id`      | UUID        | FK → users | Ownership scoping                     |
| `status`       | VARCHAR(20) | —          | Enumerated: `draft`, `in_progress`, `completed` |
| `current_step` | SMALLINT    | —          | 0–7; 0 = brief not submitted          |
| `created_at`   | TIMESTAMPTZ | —          | Record creation                       |
| `updated_at`   | TIMESTAMPTZ | —          | Last modification                     |


`**blog_briefs` table**


| Field                  | Type         | Key                | Purpose                                      |
| ---------------------- | ------------ | ------------------ | -------------------------------------------- |
| `id`                   | UUID         | PK                 | —                                            |
| `blog_id`              | UUID         | FK → blogs, UNIQUE | 1:1 with blog                                |
| `title`                | VARCHAR(500) | —                  | Blog title                                   |
| `primary_keyword`      | VARCHAR(255) | —                  | SEO target keyword                           |
| `audience_persona`     | TEXT         | —                  | Target audience description                  |
| `tone_of_voice`        | VARCHAR(100) | —                  | Writing tone                                 |
| `word_count_min`       | INTEGER      | —                  | Minimum word count                           |
| `word_count_max`       | INTEGER      | —                  | Maximum word count                           |
| `blog_brief`           | TEXT         | —                  | Directional notes                            |
| `reference_url`        | TEXT         | —                  | Optional URL for scraping                    |
| `scraped_content`      | TEXT         | —                  | Raw extracted page text                      |
| `scrape_status`        | VARCHAR(20)  | —                  | Enumerated: `pending`, `success`, `failed`, `skipped` |
| `alignment_summary`    | TEXT         | —                  | Last generated summary                       |
| `alignment_confirmed`  | BOOLEAN      | —                  | User confirmed the summary                   |
| `alignment_iterations` | SMALLINT     | —                  | How many times summary was generated         |
| `created_at`           | TIMESTAMPTZ  | —                  | —                                            |
| `updated_at`           | TIMESTAMPTZ  | —                  | —                                            |


### Indexes

```sql
CREATE INDEX idx_blogs_user_id ON blogs(user_id);
CREATE INDEX idx_blogs_status ON blogs(status);
CREATE UNIQUE INDEX idx_blog_briefs_blog_id ON blog_briefs(blog_id);
```

### Access Patterns


| Pattern               | Query                                                      |
| --------------------- | ---------------------------------------------------------- |
| Load brief by blog ID | `SELECT * FROM blog_briefs WHERE blog_id = $1`             |
| Check scrape status   | `SELECT scrape_status FROM blog_briefs WHERE blog_id = $1` |
| Scope blog to user    | `SELECT * FROM blogs WHERE id = $1 AND user_id = $2`       |


---

## Prompt Design — Claude API

### Alignment Summary Generation

**Model**: `claude-sonnet-4-6`

**System prompt**:

```
You are an expert content strategist helping a writer align their blog brief before generation begins.
Given the writer's inputs, produce a clear, structured alignment summary that restates:
1. The blog's primary goal and angle
2. The target audience and their pain point
3. The SEO intent (informational / navigational / transactional) and primary keyword focus
4. The tone and voice
5. The scope: approximate word count and depth of coverage

Be concise (150–250 words). Write in second person ("You want to…", "Your audience is…").
Do not invent information not present in the inputs.
```

**User message template**:

```
Blog Inputs:
- Title: {{title}}
- Primary Keyword: {{primaryKeyword}}
- Audience Persona: {{audiencePersona}}
- Tone of Voice: {{toneOfVoice}}
- Word Count: {{wordCountMin}}–{{wordCountMax}} words
- Blog Brief: {{blogBrief}}
{{#if scrapedContent}}
- Reference Content (scraped): {{scrapedContent | truncate 2000}}
{{/if}}
{{#if feedback}}
Previous summary was rejected. User feedback: {{feedback}}
Please regenerate incorporating this feedback.
{{/if}}
```

**AgDR reference**: `docs/agdr/AgDR-0001-claude-api-alignment-summary.md`

---

## URL Scraping Design

**Library**: `axios` (HTTP) + `cheerio` (HTML parsing)
**Execution**: fire-and-forget (no queue in v1 — see AgDR)
**Timeout**: 10 seconds
**Content extraction**: `<article>`, `<main>`, `<body>` text — strip scripts, styles, navs
**Max stored length**: 10,000 characters (truncated if longer)

**AgDR reference**: `docs/agdr/AgDR-0002-url-scraping-approach.md`

### Scraper pseudocode

```typescript
async function scrapeUrl(blogId: string, url: string): Promise<void> {
  try {
    const { data } = await axios.get(url, { timeout: 10_000 });
    const $ = cheerio.load(data);
    $('script, style, nav, footer, header').remove();
    const text = ($('article, main').first().text() || $('body').text())
      .replace(/\s+/g, ' ').trim().slice(0, 10_000);
    await db.blogBriefs.update(blogId, { scrapedContent: text, scrapeStatus: 'success' });
  } catch {
    await db.blogBriefs.update(blogId, { scrapeStatus: 'failed' });
  }
}
```

---

## Implementation Plan


| #   | Task                                                          | Owner  | Estimate | Dependencies |
| --- | ------------------------------------------------------------- | ------ | -------- | ------------ |
| 1   | DB migrations: `blogs` + `blog_briefs` tables                 | Nour   | 2h       | —            |
| 2   | Domain entities + value objects (TypeScript)                  | Nour   | 3h       | 1            |
| 3   | Repository layer (PostgreSQL queries)                         | Nour   | 3h       | 1, 2         |
| 4   | `POST /api/blogs` — create blank blog                         | Nour   | 1h       | 3            |
| 5   | `POST /api/blogs/:id/brief` — submit brief + fire scraper     | Nour   | 3h       | 3            |
| 6   | `UrlScraperService` (axios + cheerio)                         | Nour   | 2h       | —            |
| 7   | `GET /api/blogs/:id/brief/scrape-status` polling endpoint     | Nour   | 1h       | 3, 6         |
| 8   | `AlignmentService` — Claude API integration                   | Nour   | 4h       | 3            |
| 9   | `POST /api/blogs/:id/alignment` + `PUT` (regenerate)          | Nour   | 2h       | 8            |
| 10  | `POST /api/blogs/:id/alignment/confirm`                       | Nour   | 1h       | 9            |
| 11  | Blog Brief Form — React component (all fields + validation)   | Hossam | 4h       | —            |
| 12  | Alignment Summary screen — display + feedback input + confirm | Hossam | 3h       | 11           |
| 13  | Scrape status polling UI (progress indicator)                 | Hossam | 2h       | 7, 12        |
| 14  | Unit tests — domain entities + services                       | Nour   | 3h       | 2, 6, 8      |
| 15  | Integration tests — API endpoints                             | Nour   | 3h       | 4–10         |
| 16  | E2E test — brief submission → alignment confirm flow          | Tarek  | 3h       | 11–13        |


**Total Estimate**: ~40h

---

## Risks & Mitigations


| Risk                                                    | Likelihood | Impact | Mitigation                                                             |
| ------------------------------------------------------- | ---------- | ------ | ---------------------------------------------------------------------- |
| Reference URL behind Cloudflare / bot protection (403)  | High       | Low    | Graceful failure — notify user, continue without scraped content (AC8) |
| Claude API latency spikes (alignment takes > 10s)       | Med        | Med    | Show streaming indicator; set 30s client timeout with retry            |
| Claude API rate limit during high concurrency           | Low        | High   | Catch 429, return `AI_UNAVAILABLE`, prompt retry                       |
| Scraped content too large for context window            | Low        | Med    | Truncate to 2,000 chars before injecting into prompt                   |
| Brief form data lost on browser crash before submission | Low        | Med    | Auto-save draft to localStorage on every field change                  |


---

## Security Considerations

- All `/api/blogs/:id/`* endpoints verify `blog.user_id === req.user.id` before any read/write.
- `referenceUrl` validated as well-formed URL; internal/private IPs blocked (SSRF prevention).
- Scraped content stored as plain text — no HTML rendered in the UI (XSS prevention).
- Claude API key stored in environment variable, never exposed to frontend.
- `alignment_summary` and `scraped_content` not included in any log output (may contain PII from reference URLs).
- `wordCountMin` / `wordCountMax` validated as positive integers with a reasonable upper bound (e.g. max 20,000).

---

## Testing Strategy


| Type             | Coverage                                                                  | Notes                                                           |
| ---------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------- |
| Unit             | Domain entities, value objects, UrlScraperService, AlignmentService       | All validation rules, scrape failure paths, prompt construction |
| Integration      | All 7 API endpoints                                                       | Happy path + error cases (403, invalid URL, Claude 502)         |
| E2E (Playwright) | Full EP-01 flow: brief form → scrape wait → alignment → iterate → confirm | One critical path test                                          |


---

## AgDRs Required

Two decisions require AgDRs before implementation begins (per `.claude/rules/agdr-decisions.md`):


| #   | Decision                                                            | AgDR File                                             |
| --- | ------------------------------------------------------------------- | ----------------------------------------------------- |
| 1   | Claude API model + prompt strategy for Alignment Summary            | `docs/agdr/AgDR-0001-claude-api-alignment-summary.md` |
| 2   | URL scraping library and execution model (fire-and-forget vs queue) | `docs/agdr/AgDR-0002-url-scraping-approach.md`        |


---

## Open Questions


| Question                                                                                               | Owner | Status |
| ------------------------------------------------------------------------------------------------------ | ----- | ------ |
| Should the Alignment Summary auto-generate immediately after form submit, or require a manual trigger? | Amar  | Open   |
| Should scraped content be shown to the user for review, or silently used as context only?              | Amar  | Open   |


---

## Approvals


| Role                | Name          | Date       | Status                                |
| ------------------- | ------------- | ---------- | ------------------------------------- |
| Tech Lead           | Mohamed Naser | 2026-04-20 | Author                                |
| Head of Engineering | —             | —          | Pending                               |
| Security            | —             | —          | N/A (no auth/crypto changes in EP-01) |


