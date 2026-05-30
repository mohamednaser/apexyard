# PRD: User Dashboard — Drafts List, Sort/Filter & Account Widget

**Status**: Draft
**Author**: Product Manager
**Created**: 2026-05-10
**Last Updated**: 2026-05-10
**Epic**: [mohamednaseramein/blog-generator#119](https://github.com/mohamednaseramein/blog-generator/issues/119)

---

## Overview

### Problem Statement

After signing up and creating a few blog drafts, users today have **no central place to see their work**. The app drops them straight into the Draft step (a single-blog editing surface). To revisit an older draft, they need to dig into the URL or browser history. To create a new one, there is no obvious CTA outside the existing in-flight editing screen.

Three concrete problems:

1. **No portfolio view.** A user with 8 drafts has no list of those 8 drafts. They cannot sort by last edited, filter by status, or scan AI-check scores at a glance. They cannot tell which drafts are ready to publish and which still need work.
2. **No activation surface to instrument.** Without a stable post-login landing page, we cannot measure activation (did the new user create their first draft?), retention (do users return week-over-week?), or feature engagement (which drafts are users running the AI check against?).
3. **AI-check and SEO signals have nowhere to live.** The AI detector ([#115](https://github.com/mohamednaseramein/blog-generator/issues/115)) and the SEO-ready-content work produce per-draft signals that are valuable across drafts, not just inside the one currently being edited. A user comparing two drafts cannot see at a glance which one scored more human-like.

This epic introduces an authenticated `/dashboard` route that lists the user's drafts in a sortable, filterable table with AI-check and SEO-readiness badges, a "New blog" primary CTA that enters the existing Draft step, and an account summary widget showing the user's identity, plan, and monthly usage. It also formalises the shared header (logo + settings/gear icon → account menu) that the landing page ([#118](https://github.com/mohamednaseramein/blog-generator/issues/118)) introduces and that the Draft and Publish steps will adopt.

### What Already Exists (do not re-build)

| Capability | Where |
|------------|-------|
| Auth — session, `/signup`, `/login`, logout, current user identity | EP-04 ([#95](https://github.com/mohamednaseramein/blog-generator/issues/95)), shipped |
| Draft step (single-blog editing) | EP-01, shipped |
| Publish step (preview + SEO panel + readability score) | EP-03 + SEO-ready-content PRD, shipped |
| `GET /api/blogs` endpoint listing the user's drafts (or equivalent) | Existing — verify shape in tech design |
| AI authenticity check (per-draft score) | [#115](https://github.com/mohamednaseramein/blog-generator/issues/115), in flight; dashboard surfaces the score, does not compute it |
| Author profiles | [#73](https://github.com/mohamednaseramein/blog-generator/issues/73) |

### Target User

**Primary** — Signed-in content creators, bloggers, media buyers, and account managers managing 2–50 blog drafts. They want to see all their drafts in one place, jump back into any of them, and start new ones from a single button.

**Secondary** — First-time signed-in users who have just completed signup and have zero drafts. They need a welcoming, instructive empty state that nudges them to create their first blog.

**Tertiary** — Internal team / admins evaluating the activation funnel. They will rely on dashboard analytics events to measure activation, retention, and feature engagement.

### Goals

1. A logged-in user lands on `/dashboard` and sees their drafts list within ≤ 1 second (P50) on a normal network.
2. From the dashboard, a returning user can find, sort, or filter any draft in ≤ 5 seconds without using browser search.
3. AI-check and SEO-readiness signals are visible at a glance for every draft, so users can prioritise edits across their portfolio.
4. ≥ 80 % of new users who land on the empty-state dashboard click "Create your first blog" within their first session.
5. ≥ 60 % of returning users who visit the dashboard click into at least one draft within 30 seconds of landing.
6. The dashboard never appears in search-engine results (always `noindex`) and is hard-gated behind auth.
7. The settings/gear icon in the dashboard header behaves identically to the one on the landing page (same component, same menu items in the logged-in state).

### Non-Goals (Out of Scope)

- **Bulk actions** (delete multiple, archive, export multiple at once). Phase 2.
- **Folders / tags / categories** on drafts. Phase 2.
- **Team / shared workspaces.** The Team pricing tier exists as a placeholder on the landing page but is not implemented anywhere in v1.
- **Full-text search inside draft bodies.** v1 supports title-based filtering only.
- **Per-draft analytics drill-down** (page views, click-throughs from published versions). Out of scope — would need a publishing-platform integration we don't have.
- **Drag-to-reorder, kanban view, calendar view.** v1 is a single sortable table.
- **Notifications / activity feed.** No "your draft was reviewed" type signals in v1.
- **Real billing / plan upgrade flow.** The account widget shows the current plan (likely "Free preview" for everyone) but tier upgrades are not wired.
- **Editable account settings on the dashboard itself.** A "Settings" menu item exists in the account menu (per the landing PRD) but the settings page itself is a separate, future scope. For v1, the menu item routes to `/dashboard` as a no-op or to a minimal placeholder.

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| First-session activation — share of new users who click "Create your first blog" from the empty state in their first session | ≥ 80 % | `recordDashboardEmptyStateCtaClick` / `recordSignupCompleted` |
| Returning-user engagement — share of returning users who open a draft within 30 s of dashboard view | ≥ 60 % | `recordDashboardDraftOpened` joined with `recordDashboardViewed` session |
| Dashboard time-to-interactive | ≤ 1 s P50, ≤ 2 s P95 | Real-user monitoring (RUM) or Lighthouse |
| Draft-open rate per dashboard view | ≥ 0.5 (i.e. one in two views results in opening a draft) | Events ratio |
| AI-check score badge engagement — share of users who hover or click an AI-check badge | ≥ 25 % of users who have ≥ 1 draft with a score | `recordDashboardBadgeInteracted` |
| Sort / filter usage — share of users who change the default sort or apply a filter | ≥ 20 % of users with ≥ 5 drafts | `recordDashboardSortChanged` / `recordDashboardFilterApplied` |

---

## User Stories

### US-1: Drafts list (table view)

> As a returning user, I want to see all my drafts in one table, so that I can scan them and jump back into the one I want without searching.

**Acceptance Criteria**:

- [ ] `/dashboard` renders a single sortable table with one row per draft the current user owns
- [ ] Each row shows: **Title** (clickable, opens the draft in the editor), **Status** chip (`draft`, `in_review`, `ready_to_publish`, `published`, `archived`), **Last edited** (relative time — "2h ago" — with absolute on hover), **AI-check score** badge (or "—" if not yet run), **SEO readiness** badge (or "—" if not computed), **Word count**
- [ ] Default sort: `last_edited` descending (most recently touched at the top)
- [ ] Rows render server-side or via SSR-hydrated React; first paint ≤ 1 s on a 3-draft account
- [ ] Clicking a row title opens the draft in the existing editor (`/draft/:id`); analytics: `recordDashboardDraftOpened` with `draft_id`, `position_in_list`, `current_sort`, `current_filter`
- [ ] Clicking outside the title link (anywhere else on the row) does NOT navigate; the row title is the only navigation control. This avoids accidental navigation when interacting with badges
- [ ] Table is keyboard-navigable: tab through rows, Enter on a focused title opens the draft

### US-2: Sort & filter

> As a user with 10+ drafts, I want to sort and filter the list, so that I can find what I need without reading every title.

**Acceptance Criteria**:

- [ ] Table column headers are clickable to sort: **Title** (alphabetical asc/desc), **Status**, **Last edited** (default), **AI-check score** (lowest first or highest first), **SEO readiness**, **Word count**
- [ ] One sort active at a time; the active column header shows an up/down indicator
- [ ] Sort preference is persisted in `localStorage` per user (or per device); a new session restores the last-used sort
- [ ] A filter control above the table allows: **Filter by status** (multi-select, e.g. only `draft` + `in_review`), **Filter by title** (free-text search, case-insensitive, matches anywhere in the title), **Filter by AI-check score range** (slider: 0–100; defaults to "all")
- [ ] Active filters render as removable chips below the filter control
- [ ] Filter state is also persisted in `localStorage`
- [ ] Sort and filter both update the URL query string (`?sort=...&filter=...`) so users can deep-link or share a filtered view
- [ ] Analytics: `recordDashboardSortChanged` with `column`, `direction`; `recordDashboardFilterApplied` with the filter type and value

### US-3: "Create new blog" primary CTA

> As any user (new or returning), I want a single, prominent button that starts a new blog, so that I don't have to hunt for it.

**Acceptance Criteria**:

- [ ] A primary CTA button labelled **"New blog"** sits at the top of the dashboard, immediately above the drafts table (or in the page header area, depending on the wireframe)
- [ ] The button is the most visually prominent action on the page
- [ ] Clicking the button navigates to the existing Draft step entry route (e.g. `/draft/new` or whatever the existing flow uses); the existing flow handles creation
- [ ] The button is keyboard-focusable; activating it via Enter or Space is equivalent to a click
- [ ] Analytics: `recordDashboardNewBlogClick` with `current_draft_count`

### US-4: Account summary widget

> As a user wanting to know my current plan and usage, I want a small widget showing my identity and quota, so that I have at-a-glance visibility without going to a settings page.

**Acceptance Criteria**:

- [ ] An account widget sits in the dashboard sidebar (desktop) or at the top of the page below the header (mobile)
- [ ] Widget displays: user's display name (or email if no display name), avatar / initials, current plan (`Free preview` is acceptable for v1 since real billing isn't wired), **drafts this month / quota** (e.g. "3 / 50" if on Pro; "3 / 3" if on Free)
- [ ] If the user is approaching or has exceeded their monthly quota, the quota line is amber (≥ 80 % used) or red (= 100 % used)
- [ ] If real plan / quota data is not yet available from the backend, the widget shows the user's name + avatar only; the plan/quota lines are hidden (not "Loading..." forever)
- [ ] The widget includes a small "Manage account" link that opens the settings/gear menu (parity with US-6) or routes to `/settings` if it exists
- [ ] Widget is responsive — collapses to a single line on mobile (name + plan, no quota detail unless tapped)
- [ ] Analytics: `recordAccountWidgetViewed` once per dashboard view

### US-5: Empty state for first-time users

> As a brand-new user who just signed up and has zero drafts, I want a welcoming dashboard that explains what to do next, so that I know how to start.

**Acceptance Criteria**:

- [ ] When the user has zero drafts, the table is replaced with an empty-state block
- [ ] Empty state shows: a friendly heading ("Let's write your first blog"), a 2-sentence explainer, a primary **"Create your first blog"** CTA, and 2–3 secondary links (e.g. "See how it works" → links to `/help` or to the landing page how-it-works anchor, "Read the AI Detector rules" → `/help/ai-detector-rules`)
- [ ] Empty state is shown only when there are genuinely zero drafts; an active filter that hides all results does NOT trigger the empty state (filter mismatches show a "No drafts match your filters" message with a "Clear filters" button instead)
- [ ] Analytics: `recordDashboardEmptyStateViewed` (once per session); `recordDashboardEmptyStateCtaClick` with `cta_id` on any CTA click
- [ ] Empty state passes Lighthouse a11y ≥ 95

### US-6: Shared navigation shell (header + settings icon)

> As a user moving between dashboard, draft, and publish screens, I want the header and account menu to behave identically everywhere, so that there is no learning curve between screens.

**Acceptance Criteria**:

- [ ] The dashboard, draft, and publish screens share the same header component (a single React component used in all three layouts)
- [ ] Header contains: logo (links to `/dashboard` for logged-in users, `/` for logged-out — but on dashboard the user is always logged-in, so always `/dashboard`), and a settings/gear icon on the top-right
- [ ] The settings/gear icon's menu, in the logged-in state, shows: **Dashboard** (→ `/dashboard`), **Settings** (→ `/settings` if it exists; otherwise no-op or hidden in v1), **Log out** (calls existing logout endpoint, then redirects to `/`)
- [ ] Header is responsive — on mobile, the logo collapses to an icon and the menu remains a gear icon
- [ ] Header is the SAME component that the landing page ([#118](https://github.com/mohamednaseramein/blog-generator/issues/118)) introduces; this PRD does not re-spec the component, only mandates that the dashboard adopts it and that the menu items behave per US-8 of the landing PRD
- [ ] Analytics: account-menu events fire identically to the landing page (`recordAccountMenuOpened`, `recordAccountMenuItemClicked`)

### US-7: AI-check & SEO readiness badges on each row

> As a user comparing drafts, I want to see each draft's AI-check score and SEO readiness at a glance, so that I can prioritise which drafts to refine first.

**Acceptance Criteria**:

- [ ] Each row in the table displays:
  - **AI-check score** — a coloured numeric badge (`0–100`) using the same colour bands as the AI detector PRD: green (≤ 30), amber (31–69), red (≥ 70). Shows "—" if no AI check has been run on the draft. Tooltip on hover: "AI authenticity check — last run: <timestamp>"
  - **SEO readiness** — a small chip showing one of: `✓ Ready`, `Needs work`, `Missing fields`. Colour bands match the readability score from the SEO-ready-content work (or the PRD-defined SEO readiness bands)
- [ ] Badge values are populated from the existing per-draft fields returned by the drafts API (the dashboard does NOT recompute either score)
- [ ] If the AI detector endpoint is not yet shipped at dashboard launch, the AI-check badge column simply shows "—" for all rows until the detector is live; the column header is still present so layout doesn't shift on detector launch
- [ ] Hovering or clicking an AI-check badge opens a minimal popover showing: score, mode (`pure_ai`, `ai_assisted`, etc.), last-run timestamp, and a "Open draft to see details" link
- [ ] Hovering an SEO readiness chip opens a popover listing the missing fields (e.g. "Meta description, Suggested slug") if status is `Needs work` or `Missing fields`
- [ ] Analytics: `recordDashboardBadgeInteracted` with `badge_type: "ai_check" | "seo_readiness"`, `draft_id`

### US-8: Pagination / load-more

> As a power user with 50+ drafts, I want the dashboard to remain fast and scannable, so that loading the page doesn't slow down or scroll endlessly.

**Acceptance Criteria**:

- [ ] The drafts API returns the user's drafts in pages of 25 (configurable)
- [ ] The dashboard renders the first page, then either auto-loads more on scroll (infinite scroll) or shows a **"Load more"** button (decision deferred to UX). v1 ships exactly one of the two; PRD does not pre-commit
- [ ] If the user has ≤ 25 drafts, no pagination control is needed
- [ ] Sort and filter are applied server-side via the API; the page does not require all drafts in memory to be sortable or filterable
- [ ] Analytics: `recordDashboardPageLoaded` with `page_number`, `total_drafts`

### US-9: Analytics instrumentation

> As a product analyst, I want every interaction on the dashboard instrumented, so that I can measure activation, engagement, and feature adoption.

**Acceptance Criteria**:

- [ ] On dashboard load, fire `recordDashboardViewed` with `draft_count`, `auth_provider`, `is_first_session` (true if this is the user's first-ever dashboard view)
- [ ] On row open, fire `recordDashboardDraftOpened` (US-1)
- [ ] On sort change, fire `recordDashboardSortChanged` (US-2)
- [ ] On filter apply, fire `recordDashboardFilterApplied` (US-2)
- [ ] On "New blog" click, fire `recordDashboardNewBlogClick` (US-3)
- [ ] On account widget view, fire `recordAccountWidgetViewed` (US-4)
- [ ] On empty state view / CTA click, fire `recordDashboardEmptyStateViewed` / `recordDashboardEmptyStateCtaClick` (US-5)
- [ ] On badge interaction, fire `recordDashboardBadgeInteracted` (US-7)
- [ ] On pagination load, fire `recordDashboardPageLoaded` (US-8)
- [ ] All events route through the existing analytics SDK (same as `recordExportEvent`)

### US-10: Auth gate & noindex

> As a security-conscious product, I want the dashboard to be inaccessible to logged-out visitors and invisible to search engines, so that user data and the authenticated surface are never exposed publicly.

**Acceptance Criteria**:

- [ ] `/dashboard` is gated by the existing `requireAuth` middleware; logged-out visitors are redirected to `/login?redirect=/dashboard`
- [ ] After successful login from that redirect, the user lands on `/dashboard`
- [ ] HTML `<head>` includes `<meta name="robots" content="noindex, nofollow">`
- [ ] The route is in the disallow list of `/robots.txt` (per the landing PRD)
- [ ] The route is NOT in `/sitemap.xml`
- [ ] Server responds with `Cache-Control: private, no-store` so the page is never served from a shared cache
- [ ] Session expiry while on the dashboard surfaces a "Session expired — please log in again" inline message and redirects to `/login?redirect=/dashboard` after 3 seconds

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User has 0 drafts | Empty state shown (US-5); table and filters hidden |
| User has 1 draft | Table shown with that one row; sort/filter controls visible but trivially scoped |
| User has 500 drafts | Pagination kicks in; first 25 rendered; sort/filter applied server-side |
| User applies a filter with no matches | Empty filter state shown ("No drafts match your filters — Clear filters") — distinct from the new-user empty state |
| User's session expires while on the page | Inline "Session expired" banner appears; redirect to `/login?redirect=/dashboard` after 3 s |
| Drafts API call fails (network / 5xx) | Inline error block: "Couldn't load your drafts. Retry?" with a retry button. The header, account widget, and "New blog" CTA still render |
| Account widget data not available (plan/quota endpoint fails) | Widget renders with name + avatar only; plan/quota lines hidden, no "Loading..." state |
| User has draft with no AI-check yet | AI-check badge column shows "—" for that row; tooltip says "AI check not yet run" |
| User has draft with missing SEO fields | SEO badge shows `Missing fields`; tooltip lists the missing fields |
| User changes sort order while filter is active | Both apply together; both reflected in URL query string; both persist to `localStorage` |
| User opens a deep-linked URL with sort+filter params | Page restores that sort and filter state; if params are invalid, falls back to defaults silently |
| Logged-out user navigates directly to `/dashboard` | Redirected to `/login?redirect=/dashboard` |
| Logged-in user with another user's draft ID in the URL | The drafts API enforces ownership; an attempt to open a non-owned draft via `/draft/:id` returns 403 and the user sees an error (handled by the draft route, not this PRD) |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | `/dashboard` route renders the drafts list for the authenticated user | Must |
| FR-2 | The list is sortable by Title, Status, Last edited, AI-check score, SEO readiness, Word count (US-2) | Must |
| FR-3 | The list is filterable by status (multi-select), title (free text), AI-check score (range) (US-2) | Must |
| FR-4 | Sort and filter state are reflected in the URL query string and persisted in `localStorage` | Must |
| FR-5 | "New blog" CTA routes to the existing Draft-step entry (US-3) | Must |
| FR-6 | Account summary widget displays name, avatar, plan, quota (with graceful degradation if backend data is missing) (US-4) | Must |
| FR-7 | Empty state shown when the user has zero drafts (US-5) | Must |
| FR-8 | Empty filter state shown when filters exclude all rows (distinct from US-5) | Must |
| FR-9 | Shared header component (logo + settings/gear icon → account menu) is used on dashboard, draft, and publish screens (US-6) | Must |
| FR-10 | AI-check and SEO readiness badges rendered per row, populated from existing draft fields (US-7) | Must |
| FR-11 | Drafts API returns paginated results (25 per page); dashboard loads more on scroll or via "Load more" (US-8) | Must |
| FR-12 | All analytics events per US-9 are wired to the existing analytics SDK | Must |
| FR-13 | Route is auth-gated; logged-out users are redirected to `/login?redirect=/dashboard` (US-10) | Must |
| FR-14 | `<head>` includes `noindex, nofollow`; route is in `robots.txt` disallow list; route is not in `sitemap.xml` (US-10) | Must |
| FR-15 | Response is uncacheable (`Cache-Control: private, no-store`) | Must |
| FR-16 | First-session detection (`is_first_session`) is reliable — uses a per-user flag (server-side or signed cookie), not client-only heuristics | Should |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | Time to interactive (P50) on a 3-draft account | ≤ 1 s |
| Performance | Time to interactive (P95) on a 500-draft account | ≤ 2 s |
| Performance | API response time for `GET /api/blogs?page=1&page_size=25` (P95) | ≤ 200 ms |
| Accessibility | Lighthouse Accessibility score | ≥ 95 |
| Accessibility | All controls keyboard-navigable, with visible focus | Verified |
| Accessibility | All status/score badges convey meaning via text or icon, not colour alone | Verified |
| Security | Page only accessible to authenticated users; drafts API enforces ownership | Existing auth middleware |
| Security | No drafts API call leaks other users' data (negative tests included) | Required |
| SEO | Page is `noindex, nofollow`; never in sitemap | Verified |
| Privacy | Analytics events do not include draft body content; only IDs, counts, and aggregate metrics | Verified |
| Compatibility | Modern browsers (Chrome / Edge / Firefox / Safari, last 2 major versions) | Full support |

---

## Design

### Page Layout (desktop, 1280 px)

```
┌─ Header (shared component) ──────────────────────────────────────┐
│  [Logo]                                                  [⚙]     │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────┬───────────────────┐
│   Your drafts              [ + New blog ]    │  Account          │
│                                              │                   │
│   [ Filter: status | title | score range ]   │  [avatar]         │
│   [ Active filter chips:  status: draft × ]  │  Mohamed Naser    │
│                                              │  Free preview     │
│   ┌──────────────────────────────────────┐   │  Drafts this      │
│   │ Title  Status  Last  AI  SEO  Words  │   │  month            │
│   ├──────────────────────────────────────┤   │  3 / 3 (full)     │
│   │ Why X… draft   2h ago  72  ✓ Ready 1.2k │  │                   │
│   │ The Y… draft   1d ago  45  Needs… 980  │  │  [Manage account] │
│   │ How Z… ready   3d ago  18  ✓ Ready 1.5k │  │                   │
│   │ …                                      │  │                   │
│   └──────────────────────────────────────┘   │                   │
│                                              │                   │
│   [ Load more ]                              │                   │
└──────────────────────────────────────────────┴───────────────────┘
```

### Empty State (zero drafts)

```
┌─ Header ─────────────────────────────────────────────────────────┐
│  [Logo]                                                  [⚙]     │
└──────────────────────────────────────────────────────────────────┘

                  ┌────────────────────────────┐
                  │                            │
                  │     [empty-state illo]     │
                  │                            │
                  │  Let's write your first    │
                  │  blog                      │
                  │                            │
                  │  Tell us your topic and    │
                  │  audience — we'll generate │
                  │  an SEO-ready first draft  │
                  │  in under a minute.        │
                  │                            │
                  │  [ Create your first blog ]│
                  │                            │
                  │  See how it works · Read   │
                  │  the AI Detector rules     │
                  │                            │
                  └────────────────────────────┘
```

### Mobile Layout (375 px)

- Header collapses to logo + gear icon only
- Account widget moves to a collapsed strip at the top of the page (name + plan in one line; tap to expand for full quota detail)
- Drafts table becomes a list of cards (one card per draft, title + key fields, badges below)
- Filter / sort controls collapse behind a "Filter" button that opens a bottom sheet

### User Flow — first-time signed-in visitor

```
[New user finishes signup]
    |
    v
[/dashboard renders with empty state]
    |
    +--> [Click "Create your first blog"]
            |
            v
        [/draft/new — existing Draft step]
```

### User Flow — returning user

```
[Returning user lands on /dashboard]
    |
    v
[Drafts list renders with default sort: last_edited desc]
    |
    +--> [Click a draft title] -> [/draft/:id]
    |
    +--> [Click "New blog"]     -> [/draft/new]
    |
    +--> [Apply filter / change sort]
            |
            v
        [Table re-renders; URL + localStorage updated]
```

### Wireframes / Mockups

To be produced by the UX Designer before implementation begins. Key screens:

- Dashboard desktop, populated (3 drafts, 25 drafts)
- Dashboard mobile (cards layout)
- Empty state (desktop and mobile)
- Account widget collapsed (mobile) vs expanded (desktop sidebar)
- Filter / sort controls active state
- Error states (drafts API failure, session expired)

---

## Technical Notes

### Dependencies

| Dependency | Type | Status | Notes |
|------------|------|--------|-------|
| Auth (EP-04 / #95) | Internal | Shipped | Provides session, `requireAuth` middleware, current user |
| `GET /api/blogs` listing endpoint | Internal | Verify | Needs pagination + sort + filter support; tech design to confirm or extend |
| AI detector ([#115](https://github.com/mohamednaseramein/blog-generator/issues/115)) | Internal | In flight | Provides per-draft AI-check score; dashboard reads, doesn't compute |
| SEO readiness signal | Internal | Verify | Likely already on each draft record (from the SEO-ready-content work); tech design to confirm field shape |
| Existing analytics SDK | Internal | Ready | Same as `recordExportEvent` |
| Existing frontend stack (React + TypeScript + Vite) | Internal | Ready | Dashboard is a new module / route in the existing app |
| Shared header component | Internal | New (built in landing PRD #118) | Dashboard reuses |
| `Cache-Control` and `noindex` headers | Internal | Trivial | Standard middleware addition |

### Technical Constraints

- **New route inside the existing blog-generator app**: dashboard lives at `/dashboard` in the existing React frontend. No new repo, no new deploy.
- **Auth-gated route**: existing `requireAuth` middleware applies. Logged-out users redirect to `/login?redirect=/dashboard`.
- **Server-side sort / filter / pagination**: the dashboard does NOT load all drafts and sort client-side. The drafts API must support `?sort=<col>&direction=<asc|desc>&filter_status=...&filter_title=...&filter_score_min=...&filter_score_max=...&page=N&page_size=25` (final shape to be agreed in tech design). This keeps the dashboard fast for power users with 100+ drafts.
- **`noindex` + `robots.txt` disallow + not-in-sitemap**: triple-layered to prevent any accidental indexing. The page is also `Cache-Control: private, no-store` so it's never served from a CDN cache.
- **Read-only of AI detector and SEO signals**: the dashboard does NOT compute or refresh either score. It surfaces whatever the drafts API returns. Refreshing a score is the responsibility of the editor / publish step, not the dashboard.
- **Account widget gracefully degrades**: if the plan / quota endpoint isn't yet wired, the widget still renders with name + avatar. No "Loading..." flicker. No empty "0 / 0" quota.
- **Shared header is the single source of truth**: the same React component is used on dashboard, draft, and publish. Any change to the header's behaviour or analytics events is a portfolio change, not a per-route one.
- **Pagination strategy (infinite scroll vs "Load more")**: explicit choice deferred to UX Designer + Tech Lead in tech design. Default recommendation: **"Load more"** button — more predictable for screen readers and keyboard users, less performance risk than infinite scroll.

---

## Launch Plan

### Rollout Strategy

- **Phase 1 — Internal dogfood**: deploy behind a feature flag (`dashboard_enabled = true` for internal users) for 3–5 days. Validate empty state for fresh accounts, drafts list for power users (10+ drafts), error states for offline / API-down cases.
- **Phase 2 — Gradual rollout**: enable for 10 % of users for 24 hours; monitor `recordDashboardViewed` event rates and any error spikes; ramp to 50 %, then 100 % over 3–5 days.
- **Phase 3 — Remove the flag**: once at 100 % with no regressions, remove the feature flag.

### Migration / Cutover

- Existing users who bookmark `/draft/:id` or `/publish/:id` URLs continue to work — those routes are untouched.
- The "logo in header" link previously pointed to wherever the app's logged-in home was (likely the most recent draft, or just `/`). After this epic, the logo points to `/dashboard`. Communicate this in release notes.
- No data migrations are required. The dashboard reads from the existing drafts table via the existing drafts API.

### Rollout Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Drafts API doesn't yet support server-side sort/filter at the shape this PRD assumes | Tech design verifies API shape; if extensions are needed, ship API changes in the same release |
| Empty state misfires for existing users with archived drafts | The empty-state check is strictly "draft count = 0 across all statuses (including archived)" — verified by integration test |
| Sort / filter state in `localStorage` leaks between users sharing a device | Key the state by user ID, not just "dashboardState"; clear on logout |
| AI-check badge column is empty for everyone at launch (because [#115](https://github.com/mohamednaseramein/blog-generator/issues/115) ships later) | Column header is present; cells show "—"; tooltip explains "AI check not yet available"; no broken layout |
| Account widget shows "Free preview / 3/3" for all users and confuses them about whether they're actually rate-limited | Tooltip on the quota line clarifies "Preview period — no enforced limits yet"; final copy in tech design |

---

## Resolved Decisions

| Decision | Resolution |
|----------|------------|
| Dashboard location | New route at `/dashboard` in the existing blog-generator app (same repo, same deploy) |
| Auth dependency | EP-04 (#95) shipped; dashboard uses existing `requireAuth` middleware |
| Companion epic | Ships in parallel with the landing page epic ([#118](https://github.com/mohamednaseramein/blog-generator/issues/118)); both target the same launch window |
| AI-check + SEO badges | Surfaced as-is from the drafts API; dashboard does not recompute or refresh scores |
| Shared header | Same component as the landing page header; defined in the landing PRD, reused here |
| Pagination default | Server-side pagination + sort + filter; rendering strategy (infinite scroll vs Load more) deferred to UX |
| Indexing | `noindex, nofollow` + `robots.txt` disallow + not in `sitemap.xml` + `Cache-Control: private, no-store` |
| Account widget on failure | Degrades gracefully — shows name + avatar only; no "Loading..." state |

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Existing drafts API — does it already support server-side sort/filter/pagination at the shape this PRD assumes, or do we need to extend it? | Tech Lead | Open |
| Plan & quota endpoint — does one exist? If not, do we ship the account widget with name + avatar only in v1, and add plan/quota when billing arrives? | Tech Lead / Head of Product | Open |
| Pagination — infinite scroll vs "Load more" button — which does the UX team prefer for v1? | UX Designer | Open |
| First-session detection — what's the most reliable signal? Per-user server-side flag on first dashboard view, or a signed cookie? | Tech Lead | Open |
| Status enum — is there an existing canonical status enum for drafts (`draft`, `in_review`, etc.) or do we define it here? | Tech Lead | Open |
| Settings menu item — does `/settings` exist yet, or should the menu item be hidden in v1? | Head of Product | Open |
| "Manage account" link in the account widget — does this go to the same place as the menu item, or somewhere different? | UX Designer | Open |
| Mobile card layout for the drafts list — final visual treatment | UX Designer | Open |

---

## Timeline

| Milestone | Target | Status |
|-----------|--------|--------|
| PRD Approved | 2026-05-13 | Pending |
| Tech Design Complete | 2026-05-17 | Pending |
| Wireframes Complete | 2026-05-17 | Pending |
| Dev Complete (MVP — list + sort + filter + empty state + widget + header + badges) | 2026-06-01 | Pending |
| QA Complete | 2026-06-04 | Pending |
| Internal dogfood begins (behind flag) | 2026-06-05 | Pending |
| Gradual rollout begins | 2026-06-08 | Pending |
| Full launch | 2026-06-12 | Pending |

---

## Phase 2 — Backlog (Not In Scope for This Release)

| Feature | Rationale for Deferral |
|---------|----------------------|
| Bulk actions (select, delete, archive, export) | Phase 2 — needs a multi-select UX and confirmation flows; revisit after we have engagement data |
| Folders / tags / categories | Phase 2 — needs taxonomy decisions and migration of existing drafts |
| Team / shared workspaces | Belongs with the Team-tier billing epic; deferred until real billing |
| Full-text search across draft bodies | Needs a search index; defer until v1 usage proves the need |
| Per-draft analytics (page views, click-throughs) | Needs publishing-platform integration we don't have |
| Drag-to-reorder, kanban view, calendar view | Adds significant UX complexity; revisit if usage patterns suggest demand |
| Notifications / activity feed | Needs a notifications system we don't have |
| Editable account settings on the dashboard | Belongs in a dedicated `/settings` route; v1 menu item is a placeholder |
| Real plan upgrade flow | Belongs with the billing integration epic |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser | 2026-05-10 | Author |
| Head of Product | | | Pending |
| Tech Lead | | | Pending |
| Head of Design | | | Pending |
