# PRD: SEO-Ready Content Generation

**Status**: Draft
**Author**: Product Manager
**Created**: 2026-04-23
**Last Updated**: 2026-04-23

---

## Overview

### Problem Statement

Content creators, bloggers, media buyers, and account managers use the blog-generator to produce content they publish on their own CMS (WordPress, Ghost, Webflow, etc.). The generated output is copied and pasted directly — there is no hosted public URL. If the output lacks proper SEO structure, users must manually clean it up before publishing. That cleanup is error-prone, time-consuming, and undermines the core value proposition of the tool.

The tool already captures a `primaryKeyword`, generates a `metaDescription`, and suggests a `slug` — but stops short of enforcing heading hierarchy, providing an SEO-optimised title separate from the blog title, guiding word count strategically, or showing any quality signals (readability score, character counts) that help a professional judge whether the content is publish-ready.

### What Already Exists (do not re-build)

| Feature | Where |
|---------|-------|
| `primaryKeyword` input | `BlogBriefForm` — Step 1 |
| `wordCountMin` / `wordCountMax` numeric inputs | `BlogBriefForm` — Step 1 |
| `metaDescription` generated and displayed | `PublishStep` — SEO & social panel |
| `suggestedSlug` generated and displayed | `PublishStep` — SEO & social panel |
| Copy-to-clipboard for slug and meta | `PublishStep` — SEO & social panel |

### Target User

**Primary**: Content creators, bloggers, media buyers, account managers — professionals who generate high volumes of content and publish it on external CMS platforms. They know what SEO is and will judge the tool by whether the output is publish-ready without extra work.

**Secondary**: Freelancers and agency writers producing content for clients. They need to hand off output that looks professional and doesn't require client-side SEO review.

### Goals

1. Generated blog posts include a separate SEO title (≤ 60 chars, keyword-first) ready to paste into the CMS `<title>` field
2. Generated heading structure (H1 → H2 → H3) uses the focus keyword in H1 and LSI / secondary terms in H2s — verified by the generation prompt
3. Users can select a word count preset (Short / Standard / Long-form) instead of entering raw min/max numbers — reducing friction and anchoring expectations to SEO best practice
4. Readability score (Flesch-Kincaid grade) is displayed on the Publish step so professionals can verify copy quality before export
5. Character count indicators on SEO title (≤ 60) and meta description (150–160) give instant visual feedback

### Non-Goals (Out of Scope)

- Hosting generated posts on a public URL (users publish on their own sites — no change to this model)
- Automated keyword research or competitor analysis (out of scope for this release)
- Google Search Console integration or organic traffic tracking
- Editing the generated content inside the app (export-only model is unchanged)
- Phase 2 items: JSON-LD Article snippet, internal link placeholders, alt text suggestions (tracked separately)

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Export rate (users who reach Publish step and copy content) | +15% vs baseline | `recordExportEvent` analytics |
| Time-to-first-export (from brief submit to first copy) | No regression | Session duration analytics |
| User satisfaction with SEO output quality | ≥ 4.0 / 5 in post-session feedback | In-app feedback prompt |
| Support requests about "how to add meta title to WordPress" | -50% vs baseline | Support ticket tagging |

---

## User Stories

### US-1: SEO Title Field

> As a media buyer, I want the tool to generate a separate SEO title (≤ 60 chars) distinct from the blog title, so that I can paste it directly into my CMS's `<title>` field without editing it myself.

**Acceptance Criteria**:

- [ ] The Publish step displays an "SEO Title" field separate from the blog post title
- [ ] The SEO title is ≤ 60 characters and contains the `primaryKeyword` near the front
- [ ] A character count indicator shows the current length with a green/amber/red signal (≤ 60 / 51–60 / > 60)
- [ ] The SEO title is copyable via a "Copy SEO title" button
- [ ] If the SEO title is not yet generated, a placeholder message guides the user to confirm the draft

### US-2: Word Count Presets

> As a blogger, I want to pick a content length preset (Short, Standard, Long-form) instead of typing min/max word counts, so that I don't need to know the SEO-optimal word count for each content type.

**Acceptance Criteria**:

- [ ] The Brief form replaces the two numeric `wordCountMin` / `wordCountMax` inputs with a segmented control or radio group offering three presets:
  - **Short** — 600–900 words (quick takes, news commentary)
  - **Standard** — 1,200–1,600 words (evergreen how-to posts)
  - **Long-form** — 2,400–3,000 words (pillar content, ultimate guides)
- [ ] The selected preset maps to the existing `wordCountMin` / `wordCountMax` fields sent to the backend (API contract unchanged)
- [ ] The Brief form still loads and saves correctly when an existing brief has custom word count values that don't match a preset — default to the nearest preset or show "Custom" state
- [ ] The preset selection is persisted when the brief is saved

### US-3: Heading Structure Enforcement

> As an account manager, I want the generated blog to use a proper H1 → H2 → H3 heading hierarchy with the focus keyword in the H1 and related terms in the H2s, so that the content is structurally correct for search engines without my having to edit headings.

**Acceptance Criteria**:

- [ ] The AI generation prompt is updated to explicitly instruct: one H1 (must contain the `primaryKeyword`), H2s for major sections (must use LSI or secondary keyword variants), H3s for subsections
- [ ] The Markdown preview in the Publish step correctly renders heading levels (already supported by the existing renderer)
- [ ] QA verification: a sample of 5 generated posts reviewed to confirm heading hierarchy is correct in output

### US-4: Readability Score

> As a content creator, I want to see a Flesch-Kincaid readability score on my generated post, so that I can confirm the copy is written at the right level for my audience before I export it.

**Acceptance Criteria**:

- [ ] The Publish step displays a readability score badge next to the post preview header
- [ ] The score is calculated client-side from the generated Markdown body (no backend call required)
- [ ] The badge shows the Flesch-Kincaid Reading Ease score (0–100) with a plain-English label:
  - 70–100: "Easy to read"
  - 50–69: "Fairly readable"
  - 30–49: "Difficult"
  - 0–29: "Very difficult"
- [ ] The score updates whenever the Markdown body changes (if re-generation is allowed)

### US-5: Character Count on Meta Description

> As a blogger, I want to see a live character count on the meta description field, so that I know immediately if it's within the 150–160 char sweet spot for Google.

**Acceptance Criteria**:

- [ ] The meta description in the SEO & social panel of the Publish step shows a character count
- [ ] The count is colour-coded: green (150–160), amber (120–149 or 161–170), red (< 120 or > 170)
- [ ] The character count is visible without expanding the SEO panel (show inline with the meta text)

### US-6: App-Level Meta and Open Graph Tags (Quick Win)

> As a team, we want the blog-generator app itself to have proper `<meta>` and Open Graph tags so that shared links on Slack and LinkedIn show a meaningful preview.

**Acceptance Criteria**:

- [ ] `frontend/index.html` includes `<meta name="description">`, `<meta property="og:title">`, `<meta property="og:description">`, `<meta property="og:type">`, and `<title>` with values that describe the product
- [ ] The title accurately reflects the product: "Blog Generator — AI-powered SEO content for creators"

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Draft confirmed but AI did not generate an SEO title | Publish step shows "SEO title not generated — try regenerating the draft" message |
| Generated SEO title exceeds 60 chars | Character count badge shows red; user is not blocked from exporting but is warned |
| Existing brief saved with `wordCountMin: 500` (outside all presets) | Brief form loads, selects nearest preset (Short), or shows a "Custom" display state — does not crash or reset |
| Markdown body is empty when readability score is computed | Score badge is hidden; no divide-by-zero error |
| Meta description not generated | Character count is not shown; existing placeholder message is displayed |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Generate and display a separate SEO title (≤ 60 chars, keyword-first) on the Publish step | Must |
| FR-2 | Add copy-to-clipboard for SEO title | Must |
| FR-3 | Replace word count min/max inputs with Short / Standard / Long-form presets | Must |
| FR-4 | Update AI generation prompt to enforce H1 / H2 / H3 heading hierarchy | Must |
| FR-5 | Display Flesch-Kincaid readability score on Publish step (client-side) | Must |
| FR-6 | Show character count indicator on meta description (colour-coded) | Must |
| FR-7 | Add character count indicator on SEO title (colour-coded) | Must |
| FR-8 | Add `<meta>`, Open Graph, and `<title>` tags to `frontend/index.html` | Must |
| FR-9 | Include SEO title in "Copy all (Markdown)" and "Copy all (HTML)" exports | Should |
| FR-10 | Persist SEO title in the draft data model alongside `metaDescription` and `suggestedSlug` | Must |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | Readability score computed client-side with no perceptible lag | < 100ms for posts up to 5,000 words |
| Accessibility | All new UI elements meet WCAG 2.1 AA | Colour-coded badges must also convey meaning via text/icon, not colour alone |
| API compatibility | Word count preset maps to existing `wordCountMin` / `wordCountMax` API fields | No backend API change required for presets |

---

## Design

### User Flow

```
[Step 1 — Brief]
  User selects word count preset (Short / Standard / Long-form)
  User enters primaryKeyword (already exists)
    |
    v
[Step 2–4 — Outline, Alignment, Draft]
  AI prompt enforces H1/H2/H3 heading hierarchy
  AI generates SEO title alongside metaDescription + suggestedSlug
    |
    v
[Step 5 — Publish]
  Readability score badge visible above preview
  SEO title shown in SEO & social panel with char count (green/amber/red)
  Meta description shown with char count (green/amber/red)
  "Copy SEO title" button available
  "Copy all" exports include SEO title block
```

### New Fields on Publish Step — SEO & Social Panel

```
┌─ SEO and social ──────────────────────────────────┐
│                                                    │
│  SEO TITLE                              52 chars ✓ │
│  10 Tips for Better Sleep Hygiene in 2026          │
│                                    [Copy SEO title]│
│                                                    │
│  SUGGESTED SLUG                                    │
│  tips-for-better-sleep-hygiene-2026                │
│                                    [Copy slug]     │
│                                                    │
│  META DESCRIPTION                      157 chars ✓ │
│  Struggling to sleep? These 10 evidence-based...   │
│                                    [Copy meta]     │
└────────────────────────────────────────────────────┘
```

### Wireframes / Mockups

To be produced by UX Designer before implementation begins. Key screens: updated Brief step (word count presets), updated Publish step (SEO title field, readability badge, character counts).

---

## Technical Notes

### Dependencies

| Dependency | Type | Status | Notes |
|------------|------|--------|-------|
| Flesch-Kincaid library (e.g. `flesch-kincaid` npm) | External | To be evaluated | Client-side only; lightweight |
| AI prompt update | Internal | Ready | Update system prompt for H1/H2/H3 and SEO title generation |
| Backend draft schema | Internal | Ready | Add `seoTitle` field alongside `metaDescription` and `suggestedSlug` |

### Technical Constraints

- No backend API contract changes for word count (presets map to existing min/max fields)
- Readability score must be computed client-side — no extra backend call
- SEO title must be stored in the draft and included in export output (backend schema addition required)
- The app uses React + TypeScript + Vite (frontend) and Express + TypeScript (backend)

---

## Launch Plan

### Rollout Strategy

- All users at once (no feature flags — this is a quality improvement, not a risky behaviour change)

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Should users be able to edit the SEO title inline on the Publish step, or is it read-only (copy only)? | Product | Open |
| Which Flesch-Kincaid library should be used — or should we implement the formula directly to avoid a dependency? | Tech Lead | Open |
| Should the word count preset selection be shown as a segmented control (horizontal) or radio buttons (vertical)? | UX Designer | Open |
| Should "Custom" word count still be supported as a fourth option for power users? | Product | Open |

---

## Timeline

| Milestone | Target | Status |
|-----------|--------|--------|
| PRD Approved | 2026-04-24 | Pending |
| Tech Design Complete | 2026-04-25 | Pending |
| Dev Complete (MVP) | 2026-04-30 | Pending |
| QA Complete | 2026-05-02 | Pending |
| Launch | 2026-05-02 | Pending |

---

## Phase 2 — Backlog (Not In Scope for This Release)

| Feature | Rationale for Deferral |
|---------|----------------------|
| JSON-LD Article structured data snippet | High value but requires UX design for the copy/paste experience |
| Internal link placeholders (`[LINK: related post about X]`) | Requires understanding of user's existing content — needs research |
| Alt text suggestions per image slot | No image support in current output model |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser | 2026-04-23 | Author |
| Head of Product | | | Pending |
| Tech Lead | | | Pending |
| Head of Design | | | Pending |
