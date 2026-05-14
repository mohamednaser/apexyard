# PRD: AI Blog Generator

**Status**: Draft
**Author**: Amar (Product Manager)
**Created**: 2026-04-20
**Last Updated**: 2026-04-20
**Idea**: IDEA-001 · [GH#1](https://github.com/mohamednaseramein/apexyard/issues/1)

---

## Overview

### Problem Statement

Content creators, marketers, and SEO professionals face significant friction when producing high-quality blog posts: blank-page paralysis, inconsistent structure, missing SEO strategy, and AI-generated output that sounds robotic. Existing tools either generate a full draft in one shot (no control) or provide a blank editor with no guidance. There is no product that walks a user through every phase — research, SEO, headlines, outline, draft, humanization — step by step, saving progress at each stage and keeping the human in control throughout.

### Target Users

**Primary**: Content Marketers — produce consistent, SEO-optimized blog content at scale.
**Secondary**: SEO Specialists — keyword-driven content with validated strategy steps.
**Secondary**: Founders & Small Business Owners — lack dedicated writing resources.
**Secondary**: Freelance Writers — accelerate drafting and research workflows.

### Goals

1. Reduce time-to-first-draft for a 1,500-word blog post to under 30 minutes.
2. Ensure 100% of generated blogs include a validated SEO keyword cluster and meta description.
3. Achieve a wizard completion rate of ≥ 60% for sessions that reach Step 2 (Research).
4. Ensure zero data loss — all approved step outputs persist across sessions and browser refreshes.
5. Deliver a UI that meets WCAG 2.1 AA accessibility standards at launch.

### Non-Goals (Out of Scope)

- Direct CMS publishing (WordPress, Webflow, Ghost) — export only in v1.
- Social media post generation from the blog — deferred to v2.
- Team collaboration / multi-user editing on a single blog — single-user only in v1.
- Built-in plagiarism or AI-detection scoring — out of scope for v1.
- Custom AI model fine-tuning per user — not in v1.
- Paid subscription / billing flows — authentication only; monetisation deferred.

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Wizard completion rate (Step 1 → Step 7) | ≥ 60% | Analytics funnel |
| Time-to-completed-draft | ≤ 30 min median | Session duration tracking |
| AI step generation time | ≤ 30 s p95 | Backend latency logs |
| Dashboard load time | ≤ 2 s p95 | Frontend performance monitoring |
| User-reported satisfaction (post-completion survey) | ≥ 4/5 | In-app survey |
| Step regeneration rate per session | ≤ 1.5 avg per step | Analytics events |

---

## Epics Overview

| Epic ID | Epic Name | Description |
|---------|-----------|-------------|
| EP-01 | Blog Input & Alignment | Blog brief form, URL scraping, AI understanding summary, alignment confirmation. |
| EP-02 | Blog Generation Wizard | Six AI-powered steps: Research, SEO Strategy, Headlines, Outline, Draft, Humanization. |
| EP-03 | Step Control & Progress | Approve, regenerate with feedback, and track progress across all wizard steps. |
| EP-04 | Authentication | User registration, login, and session management. |
| EP-05 | Blog Dashboard | Viewing, managing, and resuming existing blog projects. |

---

## User Stories & Acceptance Criteria

### EP-01 · Authentication

#### US-01 User Registration

> As a new visitor to the platform, I want to register a new account using my email and password, so that I can access the blog generation features and have my work saved to my account.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am on the registration page, when I submit a valid email and password, then my account is created and I am redirected to the dashboard.
- [ ] AC2: Given I enter an email that is already registered, when I submit the form, then an inline error message is displayed stating the email is already in use.
- [ ] AC3: Given I enter a password shorter than 8 characters, when I submit the form, then an inline validation error is displayed.
- [ ] AC4: Given registration is successful, then a confirmation email is sent to the provided address.
- [ ] AC5: Given I submit the form with any required field empty, then the form is not submitted and the missing field is highlighted.

---

#### US-02 User Login

> As a registered user, I want to log in to my account with email and password, so that I can access my dashboard and previously generated blogs.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I enter valid credentials, when I click Login, then I am authenticated and redirected to my dashboard.
- [ ] AC2: Given I enter an incorrect password, when I click Login, then an error message is shown without specifying which field is wrong.
- [ ] AC3: Given I am logged in, when my session token expires, then I am redirected to the login page with a session-expired message.
- [ ] AC4: Given I check 'Remember me', then my session persists for 30 days across browser restarts.
- [ ] AC5: Given I click 'Forgot password', then I am presented with a password reset flow via email.

---

### EP-02 · Blog Dashboard

#### US-03 View Blog History

> As a logged-in user, I want to see a list of all my previously created and in-progress blogs, so that I can track my work and return to any blog at any time.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I navigate to the dashboard, then I see a list of all my blogs ordered by last-modified date descending.
- [ ] AC2: Given a blog is incomplete, then a progress bar is displayed showing which step (1–7) was last completed.
- [ ] AC3: Given a blog is fully completed, then it is marked with a 'Completed' status badge.
- [ ] AC4: Given I have no blogs yet, then a friendly empty state is shown with a call-to-action to create a new blog.
- [ ] AC5: Given there are more than 20 blogs, then the list is paginated or supports infinite scroll.

---

#### US-04 Resume a Blog in Progress

> As a logged-in user with an incomplete blog, I want to click on an in-progress blog and be taken to the exact step I left off, so that I don't lose my work and can continue generating the blog without starting over.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given a blog's last completed step is Step 3 (Headlines), when I open it, then the wizard opens at Step 4 (Outline) with all previous steps locked and visible.
- [ ] AC2: Given I open an in-progress blog, then all previously approved step outputs are displayed in read-only mode.
- [ ] AC3: Given I open a blog, then the progress bar accurately reflects the number of completed steps.
- [ ] AC4: Given I navigate back to the dashboard from an in-progress blog, then no data is lost.

---

#### US-05 Create a New Blog

> As a logged-in user, I want to start a new blog generation session from the dashboard, so that I can begin the wizard workflow for a fresh blog post.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I click 'New Blog', then a new blog record is created in the database and I am directed to Step 1 of the wizard.
- [ ] AC2: Given a new blog session starts, then the progress bar shows 0% with Step 1 highlighted as active.
- [ ] AC3: Given I accidentally close the browser during Step 1 before submitting, then the blank blog record is cleaned up after a 24-hour timeout.

---

### EP-03 · Blog Input & Alignment

#### US-06 Fill In Blog Brief Form

> As a logged-in user starting a new blog, I want to fill in a structured input form with my blog's key parameters, so that the AI has enough context to generate relevant, targeted content.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am on Step 1, then the form displays all required fields: Title, Primary Keyword, Audience Persona, Tone of Voice, Word Count Min, Word Count Max, Blog Brief.
- [ ] AC2: Given I submit the form with any required field empty, then the form is not submitted and the empty fields are highlighted with descriptive error messages.
- [ ] AC3: Given I enter a Word Count Min of 0 or a negative number, then an error is shown: 'Minimum word count must be greater than 0'.
- [ ] AC4: Given I enter a Word Count Max less than Word Count Min, then an error is shown: 'Maximum word count must be greater than or equal to minimum'.
- [ ] AC5: Given I submit valid data, then the inputs are trimmed of leading/trailing whitespace before being saved.
- [ ] AC6: Given I add an optional reference URL, then the system validates it is a well-formed URL and shows an error if not.
- [ ] AC7: Given a reference URL is valid, then the system scrapes its content in the background and stores it for use in subsequent AI steps.
- [ ] AC8: Given the URL scraping fails (e.g. 403 or timeout), then the user is notified that the URL could not be scraped and the blog can still proceed without it.

---

#### US-07 AI Understanding Summary & Alignment

> As a logged-in user who has submitted the blog input form, I want to see a summary of what the AI has understood from my inputs before proceeding, so that I can catch misinterpretations early and ensure the AI is fully aligned with my intent before generation begins.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I submit the input form, then an AI-generated understanding summary is displayed before moving to Step 2.
- [ ] AC2: Given the summary is displayed, then it covers: the blog's goal, target audience, SEO intent, tone, and scope.
- [ ] AC3: Given I find an inaccuracy in the summary, then I can click 'Edit Inputs' to return to the form and amend specific fields without losing other data.
- [ ] AC4: Given I submit feedback on the summary (free-text), then the AI regenerates the summary incorporating my feedback.
- [ ] AC5: Given the summary reflects my intent accurately, then I can click 'Confirm & Proceed' to advance to the Research step.
- [ ] AC6: Given I iterate on the summary more than 5 times, then the system still accepts further feedback without restriction.
- [ ] AC7: Given I confirm the summary, then the inputs and the final alignment summary are saved to the blog record.

---

### EP-04 · Blog Generation Wizard Steps

#### US-08 Research Step (Step 2)

> As a logged-in user who has confirmed the blog brief, I want to have the AI find and present relevant sources, key findings, and competitor insights, so that my blog is grounded in real, current information.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given Step 2 is active, then the AI generates: a list of cited sources (title + URL), a bullet list of key findings, and a summary of competitor content angles.
- [ ] AC2: Given I review the research, then I can click 'Approve' to lock it and proceed, or 'Regenerate' to request a new version.
- [ ] AC3: Given I click 'Regenerate', then I can optionally provide a feedback note before the AI re-runs the step.
- [ ] AC4: Given the step is approved, then the research data is persisted to the blog record and displayed as read-only in subsequent steps.

---

#### US-09 SEO Strategy Step (Step 3)

> As a logged-in user who has approved the Research step, I want to receive an AI-generated SEO strategy including keyword clusters, meta description, content angles, and search intent analysis, so that my blog is optimized for search engines from the start.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given Step 3 is active, then the AI generates: a keyword cluster (primary + secondary), a meta description (≤ 160 characters), recommended content angles, and identified search intent (informational / navigational / transactional).
- [ ] AC2: Given the meta description exceeds 160 characters, then it is flagged and the user is prompted to regenerate or edit.
- [ ] AC3: Given I approve the SEO strategy, then it is persisted to the blog record.
- [ ] AC4: Given I regenerate with feedback, then the new output incorporates my stated preferences.
- [ ] AC5: Given the step is approved, then the keyword cluster is made available to subsequent steps.

---

#### US-10 Headlines Step (Step 4)

> As a logged-in user who has approved the SEO Strategy step, I want to see multiple AI-generated headline candidates each with a score and recommended pick, so that I can choose the strongest, most click-worthy title for my post.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given Step 4 is active, then the AI generates at least 5 headline candidates.
- [ ] AC2: Given the headlines are displayed, then each shows: headline text, a score (1–10), and a brief rationale for the score.
- [ ] AC3: Given the AI has a recommended headline, then it is visually highlighted as 'AI Recommended'.
- [ ] AC4: Given I approve the step, then the selected headline is saved as the blog's working title.
- [ ] AC5: Given I want a different approach, then I can regenerate with feedback to get a new set of candidates.

---

#### US-11 Outline Step (Step 5)

> As a logged-in user who has approved the Headlines step, I want to see a detailed blog outline with H2 and H3 headings and key points per section, so that I can validate the structure and flow before a full draft is written.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given Step 5 is active, then the AI generates an outline with a minimum of 4 H2 sections.
- [ ] AC2: Given the outline is displayed, then each H2 section includes at least 1 H3 sub-section and a list of key talking points.
- [ ] AC3: Given I approve the outline, then it is persisted and used as the blueprint for the Draft step.
- [ ] AC4: Given I regenerate with feedback, then I can specify structural changes (e.g. 'add a FAQ section', 'remove the comparison section').

---

#### US-12 Draft Step (Step 6)

> As a logged-in user who has approved the Outline step, I want to receive a fully written long-form blog draft in Markdown format, so that I have a complete, publish-ready draft that follows my approved outline and brief.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given Step 6 is active, then the AI generates a Markdown draft that follows the approved outline structure.
- [ ] AC2: Given the brief specifies a word count range, then the draft falls within the approved min–max range (±10% tolerance).
- [ ] AC3: Given the draft is displayed, then the word count is shown prominently.
- [ ] AC4: Given I approve the draft, then it is saved to the blog record.
- [ ] AC5: Given I regenerate with feedback, then I can direct specific sections to be rewritten (e.g. 'make the intro more engaging').
- [ ] AC6: Given the draft uses optional reference URL content, then the sourced information is correctly cited within the Markdown.

---

#### US-13 Humanization Step (Step 7)

> As a logged-in user who has approved the Draft step, I want to receive a rewritten version of my draft that softens AI tone and reads more naturally, so that the final blog post resonates with my target audience.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given Step 7 is active, then the AI produces a humanized rewrite of the approved draft.
- [ ] AC2: Given the humanized draft is displayed, then a 'Changes Summary' panel is shown listing the key modifications made.
- [ ] AC3: Given I approve the humanized draft, then it is saved as the final version and the blog status is set to 'Completed'.
- [ ] AC4: Given I regenerate with feedback, then I can specify the type of humanization needed (e.g. 'more conversational', 'add personal anecdotes style').
- [ ] AC5: Given the blog is marked Completed, then the dashboard shows the blog with a Completed badge and the final word count.

---

### EP-05 · Step Control & Progress

#### US-14 Approve or Regenerate Any Step

> As a logged-in user at any generation step, I want to explicitly approve or regenerate each step with optional feedback before proceeding, so that I remain in control of content quality at every stage.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given a generation step has produced output, then two actions are available: 'Approve' and 'Regenerate'.
- [ ] AC2: Given I click 'Approve', then the step is marked complete, the output is locked, and the next step becomes active.
- [ ] AC3: Given I click 'Regenerate' without feedback, then the step re-runs with the original parameters.
- [ ] AC4: Given I click 'Regenerate' with feedback text entered, then the feedback is injected into the AI prompt and the step re-runs.
- [ ] AC5: Given a step is locked (approved), then its output is displayed in read-only mode and no regeneration is possible.
- [ ] AC6: Given I am on a later step, then I cannot go back and modify an already-approved earlier step without re-starting from that step.
- [ ] AC7: Given any step is regenerated, then the regeneration count for that step is tracked and visible (e.g. 'Generation 2 of X').

---

#### US-16 Export Completed Blog

> As a logged-in user whose blog is marked Completed, I want to copy the final blog to clipboard or download it as a Markdown file, so that I can publish or share it outside the platform.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given a blog is in Completed status, then an 'Export' section is visible on the final step view and the dashboard blog detail.
- [ ] AC2: Given I click 'Copy to Clipboard', then the full humanized Markdown content is copied and a success toast is shown.
- [ ] AC3: Given I click 'Download .md', then a file named `{blog-title-slug}.md` is downloaded to my device.
- [ ] AC4: Given the blog is not yet Completed, then the export options are disabled with a tooltip explaining that export is available after Step 7 approval.

---

#### US-15 Blog Progress Bar

> As a logged-in user working on or reviewing a blog, I want to see a visual progress bar and step indicator at all times during the wizard, so that I always know how far along the blog is and what step comes next.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am in the wizard, then a persistent progress bar is visible at the top showing 7 steps.
- [ ] AC2: Given a step is approved, then it is marked with a checkmark and shaded as complete.
- [ ] AC3: Given a step is currently active, then it is highlighted as in-progress.
- [ ] AC4: Given a step has not been reached yet, then it is shown as locked/greyed out.
- [ ] AC5: Given I resume a blog from the dashboard, then the progress bar correctly reflects the saved state.
- [ ] AC6: Given all 7 steps are approved, then the progress bar shows 100% and the blog is marked as Completed.

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| AI generation step times out (> 30 s) | Show error, allow retry without losing prior approved steps |
| URL scraping returns empty content | Notify user, continue without scraped context |
| Browser closed mid-generation (step in-flight) | On resume, step state is "incomplete" — user must re-trigger generation |
| User reaches Step 7 and the browser crashes | Approved steps 1–6 are already persisted; Step 7 re-runs on resume |
| Blank blog record (Step 1 never submitted) | Auto-deleted after 24-hour timeout |
| Meta description generated > 160 chars | Flag inline, prompt to regenerate or manually edit |
| Word count draft outside ±10% tolerance | Display warning but still allow approval |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01 | Email/password registration with confirmation email | Must |
| FR-02 | Email/password login with 'Remember me' (30-day session) and 'Forgot password' flow | Must |
| FR-03 | Dashboard listing all blogs ordered by last-modified, with status badges and progress indicators | Must |
| FR-04 | Resume wizard at the exact step last completed | Must |
| FR-05 | Blog brief form with all required fields and validation | Must |
| FR-06 | Optional reference URL field with background scraping and graceful failure handling | Must |
| FR-07 | AI Alignment Summary with iterative feedback loop before entering the wizard | Must |
| FR-08 | Six-step generation wizard: Research → SEO Strategy → Headlines → Outline → Draft → Humanization | Must |
| FR-09 | Approve / Regenerate (with optional feedback) control on every wizard step | Must |
| FR-10 | Persistent 7-step progress bar with correct state reflection on resume | Must |
| FR-11 | Markdown output for Draft and Humanization steps with prominent word count display | Must |
| FR-12 | 'Changes Summary' panel on Humanization step | Must |
| FR-13 | Regeneration counter per step visible to the user | Must |
| FR-14 | Dashboard pagination or infinite scroll at > 20 blogs | Must |
| FR-15 | Auto-cleanup of blank blog records after 24 hours | Should |
| FR-16 | Export completed blog: copy to clipboard and download as `.md` file | Must |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | AI generation step completion time | ≤ 30 s under normal load |
| Performance | Dashboard and form page load time | ≤ 2 s |
| Reliability | AI step failure handling — retry without data loss | 100% of prior approved steps preserved |
| Security | User data scoped to authenticated user only | Enforced at API layer |
| Security | Password hashing | bcrypt or equivalent |
| Security | Transport security | HTTPS enforced in production |
| Scalability | Concurrent multi-user generation sessions | No degradation in output quality |
| Data Persistence | Approved step outputs persisted immediately on approval | Zero data loss on browser refresh or navigation |
| Accessibility | UI compliance | WCAG 2.1 AA |
| Accessibility | Form inputs | Proper labels on all inputs |
| Accessibility | Progress indicators | Screen-reader friendly |

---

## Design

### User Flow

```
[Visitor] → Register / Login
    |
    v
[Dashboard]
    |
    +──► New Blog ──────────────────────────────────────────┐
    |                                                        |
    +──► Resume Blog ──► (opens at next incomplete step) ──►│
                                                             │
                                                             v
                                               [Step 0: Blog Brief Form]
                                                   │
                                                   v
                                           [Alignment Summary]
                                           ← iterate / edit inputs
                                                   │ Confirm & Proceed
                                                   v
                                           [Step 2: Research]
                                           ← Approve | Regenerate ±feedback
                                                   │ Approve
                                                   v
                                           [Step 3: SEO Strategy]
                                                   │ Approve
                                                   v
                                           [Step 4: Headlines]
                                                   │ Approve
                                                   v
                                           [Step 5: Outline]
                                                   │ Approve
                                                   v
                                           [Step 6: Draft (Markdown)]
                                                   │ Approve
                                                   v
                                           [Step 7: Humanization]
                                                   │ Approve
                                                   v
                                           [Blog → Completed]
                                                   │
                                                   v
                                            [Dashboard — Completed badge]
```

### Wireframes / Mockups

To be supplied by the UX/UI Designer. Key screens:

- Registration / Login pages
- Dashboard (blog list, empty state, progress indicators)
- Blog Brief Form (Step 1)
- Alignment Summary screen
- Wizard step template (output panel + Approve/Regenerate controls + feedback input)
- Progress bar component (7-step, locked/active/complete states)
- Completed blog view

---

## Technical Notes

### Stack

| Layer | Technology |
|-------|------------|
| Frontend | React (TypeScript, strict mode) |
| Backend | Node.js + Express (TypeScript) |
| Database | PostgreSQL |
| Hosting | AWS |
| CI/CD | GitHub Actions |
| Testing | Vitest (unit/integration) + Playwright (E2E) |
| AI Provider | Anthropic Claude API |

### Dependencies

| Dependency | Type | Status | Owner |
|------------|------|--------|-------|
| Anthropic Claude API (generation) | External | Confirmed | Mohamed Naser |
| Email service — Resend (free tier) | External | Confirmed | Nour |
| URL scraping library | Internal/Library | TBD | Nour |
| Auth (JWT / session management) | Internal | TBD | Nour |

### Technical Constraints

- All AI generation steps must be non-blocking (async); the UI must show a loading state.
- Step outputs must be persisted immediately on approval — no deferred writes.
- URL scraping runs in the background; it must not block the form submission response.
- The wizard enforces strict linear progression — no skipping steps or editing locked steps without re-running from that step.

---

## Launch Plan

### Rollout Strategy

- [ ] Beta program first (invited content creators and SEO professionals)
- [ ] Collect completion-rate and generation-time metrics during beta
- [ ] Full launch after beta issues resolved

---

## Open Questions

| Question | Owner | Status | Resolution |
|----------|-------|--------|------------|
| Which AI provider for generation steps? | Mohamed Naser | **Resolved** | Anthropic Claude API |
| What email service for transactional emails? | Nour | **Resolved** | Resend (free tier) |
| Will there be a usage/rate limit per user in v1? | Amar | **Resolved** | No limits in v1 |
| How is Humanization technically differentiated from Draft? | Mohamed Naser | **Resolved** | Draft = construction from structured blueprints (outline-driven). Humanization = stylistic post-processing of an already complete draft (same Claude API, different system prompt focused on tone, rhythm, and naturalness). |
| Should users be able to export the completed blog? | Amar | **Resolved** | Yes — copy to clipboard and download as .md (added as FR-16) |
| What is the target launch date? | Mohamed Naser | **Resolved** | 2026-04-30 |

---

## Timeline

| Milestone | Target Date | Status |
|-----------|-------------|--------|
| PRD Approved | 2026-04-21 | Draft |
| Technical Design Complete | 2026-04-22 | Not started |
| Design (Wireframes) Complete | 2026-04-22 | Not started |
| EP-01 Auth Dev Complete | 2026-04-24 | Not started |
| EP-02 Dashboard Dev Complete | 2026-04-25 | Not started |
| EP-03 Input & Alignment Dev Complete | 2026-04-26 | Not started |
| EP-04 Wizard Steps Dev Complete | 2026-04-28 | Not started |
| EP-05 Step Control Dev Complete | 2026-04-28 | Not started |
| QA Complete | 2026-04-29 | Not started |
| Beta Launch | 2026-04-30 | Not started |
| General Launch | 2026-04-30 | Not started |

---

## Glossary

| Term | Definition |
|------|------------|
| **Blog Brief** | The user-provided directional notes describing the content angle, key message, and context for the blog post. |
| **Alignment Summary** | An AI-generated restatement of the user's inputs, presented before generation begins, to confirm mutual understanding. |
| **Primary Keyword** | The single most important SEO keyword or phrase that the blog is targeting. |
| **Keyword Cluster** | A group of semantically related keywords (primary + secondary) that the blog should rank for. |
| **Humanization** | The process of rewriting an AI-generated draft to reduce AI-typical phrasing and improve natural readability. |
| **Wizard Step** | One of the 7 sequential phases of the blog generation workflow, each requiring explicit user approval before proceeding. |
| **URL Scraping** | The automated extraction of web page content from a user-provided reference URL, used to enrich the AI generation context. |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Amar | 2026-04-20 | Author |
| Head of Product | — | — | Pending |
| Tech Lead | Mohamed Naser | — | Pending |
| Head of Design | — | — | Pending (no designer assigned) |
