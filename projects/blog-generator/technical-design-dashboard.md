# Technical Design: User Dashboard

**Status**: Draft
**Author**: Mohamed Naser (Tech Lead)
**Date**: 2026-05-11
**PRD**: [`prd-dashboard.md`](./prd-dashboard.md)
**Epic**: [mohamednaseramein/blog-generator#119](https://github.com/mohamednaseramein/blog-generator/issues/119)

---

## Overview

### Summary

Splits the existing `Dashboard.tsx` (currently a god-component holding the entire blog wizard at `/`) into two surfaces:

1. **`/dashboard`** — a new "hub" view: drafts list (table on desktop, cards on mobile) with sort + filter + pagination, account widget, "New blog" CTA, and a first-run empty state.
2. **`/draft/:id`** and `/publish/:id` — dedicated wizard routes for an individual blog, extracted from the existing in-component step machine.

The hub leverages the existing `GET /api/blogs` endpoint, extending it to support server-side sort / filter / pagination (no client-side filtering on huge lists). AI-check and SEO-readiness badges read existing per-blog signals; no new compute. The route is hard-gated by `ProtectedRoute` (existing) and ships `noindex` + `Cache-Control: private, no-store` headers via a small middleware addition.

### Goals

- `/dashboard` renders the drafts list with a stable, sortable, filterable table — server-side pagination (default 25 / page)
- Existing `BlogHistory.tsx` is the starting point — extended into a full table, not rewritten from scratch
- Wizard steps (`brief` → `alignment` → `outline` → `draft` → `publish`) move to dedicated routes; the god-component's in-memory step machine is replaced with URL-driven state
- Shared `AppHeader` (from the landing tech design) is reused — same gear-icon menu, same component
- AI-check + SEO readiness badges render off existing per-blog fields; if the AI-check field is null on a row, the column shows "—" without breaking layout
- First-session empty state distinct from filter-mismatch empty state
- Lighthouse Accessibility ≥ 95 on the dashboard route
- No additional auth/security primitives — existing `requireAuth` + Supabase RLS continue to enforce ownership

### Non-Goals

- Bulk actions, folders/tags, team workspaces — Phase 2 per PRD
- Full-text search inside draft bodies — Phase 2
- Drag-to-reorder, kanban view — Phase 2
- Editable `/settings` page — referenced in menu but built separately (out of scope)
- Real plan / quota enforcement — widget shows informational values only, with graceful degradation when backend lacks the data
- Recompute AI / SEO scores from the dashboard — dashboard is read-only of those signals

---

## Domain Model

### Entities

```
BlogDraftSummary           (read-model returned by GET /api/blogs)
├── id: UUID
├── userId: UUID                  (ownership; enforced server-side)
├── title: string                 (or null/placeholder for not-yet-named drafts)
├── status: enum                  (draft | in_review | ready_to_publish | published | archived)
├── currentStep: int              (0–6 — maps to wizard step; existing field)
├── wordCount: int | null
├── lastEditedAt: TIMESTAMPTZ
├── createdAt: TIMESTAMPTZ
├── aiCheckLatestScore: int | null        (from BlogAiCheck — most recent per blog)
├── aiCheckLatestMode: AiDetectorMode | null
├── aiCheckLatestRunAt: TIMESTAMPTZ | null
├── seoReadiness: enum            (ready | needs_work | missing_fields | null)
└── seoMissingFields: string[]    (only if seoReadiness != 'ready')
```

`BlogDraftSummary` is a **read-model**, not a domain entity. It's built on the server by joining `blogs` ← `blog_ai_checks` (latest per blog) ← derived SEO readiness (computed from `seo_title`, `meta_description`, `suggested_slug` presence). The dashboard never writes to this view.

### Value Objects

| Value Object | Fields | Purpose |
|--------------|--------|---------|
| `DashboardSort` | `column: SortableColumn`, `direction: 'asc' \| 'desc'` | Whitelisted column set; rejected outside that set |
| `DashboardFilter` | `status?: BlogStatus[]`, `title?: string`, `scoreMin?: number`, `scoreMax?: number` | All optional; combinable; persisted to URL + localStorage |
| `Pagination` | `page: number`, `pageSize: number` (default 25, max 100) | Page-based pagination — simpler than cursor for v1 |
| `QuotaSummary` | `used: number`, `limit: number`, `plan: string` | Account widget; degrades to `null` if backend data missing |

### Sortable Columns

```ts
type SortableColumn =
  | 'last_edited_at'       // default, desc
  | 'created_at'
  | 'title'
  | 'status'
  | 'word_count'
  | 'ai_check_score'
  | 'seo_readiness';
```

Any other value → 400.

### Filterable Status

Status enum already exists in `BlogStatus` (currentStep-derived); the dashboard exposes a stable status enum independent of the numeric step:

| Status | Derivation |
|--------|------------|
| `draft` | `current_step ∈ {0, 1, 2, 3}` |
| `in_review` | `current_step = 4` |
| `ready_to_publish` | `current_step = 5` |
| `published` | `current_step = 6 AND publishedAt IS NOT NULL` |
| `archived` | `archived_at IS NOT NULL` (new column — see migration below) |

If the existing `blogs` table doesn't yet have a clean status enum, we materialise it via a `GENERATED ALWAYS AS (...)` column or compute it in the read-model query — chosen in the migration AgDR.

---

## Architecture

### Component Tree

```
DashboardPage  (frontend/src/pages/Dashboard.tsx — RENAMED/REWRITTEN)
├── AppHeader                          (extracted by landing epic — reused)
├── DashboardLayout
│   ├── DashboardMain
│   │   ├── DashboardToolbar
│   │   │   ├── NewBlogCta
│   │   │   ├── FilterControls
│   │   │   │   ├── StatusFilter         (multi-select chip)
│   │   │   │   ├── TitleFilter          (text input, debounced)
│   │   │   │   └── ScoreRangeFilter     (slider 0–100)
│   │   │   └── ActiveFilterChips        (removable chips below toolbar)
│   │   ├── DraftsTable                  (desktop)
│   │   │   ├── TableHeader              (sortable columns)
│   │   │   └── DraftRow × N
│   │   │       ├── TitleCell            (clickable link)
│   │   │       ├── StatusBadge
│   │   │       ├── RelativeTimeCell     (with absolute on hover)
│   │   │       ├── AiCheckBadge         (popover on hover/click)
│   │   │       ├── SeoReadinessBadge    (popover on hover)
│   │   │       └── WordCountCell
│   │   ├── DraftsList                   (mobile — card-per-draft)
│   │   ├── PaginationControl            ("Load more" button — see AgDR)
│   │   ├── EmptyState                   (rendered when `total = 0` AND no filters)
│   │   └── EmptyFilterState             (rendered when `total = 0` AND filters active)
│   └── DashboardSidebar
│       └── AccountWidget
│           ├── UserIdentity             (avatar + name + email)
│           ├── PlanLine
│           └── QuotaLine                (hidden if data unavailable)
└── (existing modals / toasts continue to mount at root)
```

The existing wizard (`BlogBriefForm`, `AlignmentSummary`, `OutlineStep`, `DraftStep`, `PublishStep`) moves out of `Dashboard.tsx` into its own page: `frontend/src/pages/BlogWizard.tsx` mounted at `/blog/:id/:step`. The `useReducer` state machine that lived inside the old Dashboard is replaced with URL-driven state (`useParams` + small navigation helpers).

### Module Layout

```
frontend/src/
├── App.tsx                                       (modify: routing — see below)
├── components/
│   ├── AppHeader.tsx                             (from landing epic)
│   ├── AppFooter.tsx                             (from landing epic — also used here)
│   └── (existing wizard components — unchanged)
├── pages/
│   ├── Dashboard.tsx                             (REWRITTEN — hub view)
│   └── BlogWizard.tsx                            (NEW — extracts wizard from old Dashboard.tsx)
├── features/
│   └── dashboard/
│       ├── DashboardLayout.tsx
│       ├── DashboardToolbar.tsx
│       ├── DraftsTable.tsx                       (desktop)
│       ├── DraftsList.tsx                        (mobile cards)
│       ├── DraftRow.tsx
│       ├── EmptyState.tsx
│       ├── EmptyFilterState.tsx
│       ├── PaginationControl.tsx
│       ├── AccountWidget.tsx
│       ├── badges/
│       │   ├── AiCheckBadge.tsx
│       │   ├── SeoReadinessBadge.tsx
│       │   └── StatusBadge.tsx
│       ├── filters/
│       │   ├── StatusFilter.tsx
│       │   ├── TitleFilter.tsx
│       │   ├── ScoreRangeFilter.tsx
│       │   └── ActiveFilterChips.tsx
│       ├── hooks/
│       │   ├── useDashboardState.ts              (URL ↔ state ↔ localStorage)
│       │   ├── useDrafts.ts                      (TanStack Query wrapper)
│       │   └── useAccountSummary.ts              (TanStack Query wrapper)
│       └── analytics.ts                          (typed event helpers)
└── api/
    ├── blog-api.ts                               (extend listBlogs signature)
    └── account-api.ts                            (NEW — getAccountSummary)

backend/src/
├── routes/
│   ├── blog-routes.ts                            (existing — confirm GET /api/blogs supports new params)
│   └── account-routes.ts                         (NEW — GET /api/me/account-summary)
├── handlers/
│   ├── blog-handler.ts                           (modify: handleListBlogs accepts sort/filter/pagination)
│   └── account-summary-handler.ts                (NEW)
├── repositories/
│   ├── blog-repository.ts                        (modify: listForUser accepts sort/filter/pagination params)
│   └── account-repository.ts                     (NEW)
├── domain/
│   ├── dashboard/
│   │   ├── DashboardSort.ts                      (value object — whitelist validation)
│   │   ├── DashboardFilter.ts
│   │   └── Pagination.ts
│   └── (existing domain — unchanged)
└── middleware/
    └── no-cache-private.ts                       (NEW — sets Cache-Control: private, no-store + noindex helpers)
```

### Routing Changes

After landing epic (#118):

```tsx
<Route path="/" element={<LandingPage />} />

<Route element={<ProtectedRoute />}>
  <Route path="/dashboard" element={<Dashboard />} />   {/* hub */}
  <Route path="/blog/:id/:step" element={<BlogWizard />} />
  <Route path="/blog/new" element={<BlogWizard />} />   {/* navigates to brief on mount after create */}
  <Route path="/profile" element={<ProfilePage />} />
</Route>
```

`Dashboard` no longer contains the wizard state machine. `BlogWizard` reads `:id` and `:step` from the URL, drives the existing step components, and updates the URL on confirm/back navigation.

### Data Flow — Dashboard Load

```
1. Browser navigates to /dashboard
   |
   v
2. ProtectedRoute checks session via useAuth()
   - no session → Navigate to /login?redirect=/dashboard
   - has session → render Dashboard

3. Dashboard mounts
   |
   v
4. useDashboardState() reads URL ?sort=, ?filter_status=, etc.
   - falls back to localStorage if URL is bare
   - falls back to defaults if localStorage is empty
   - normalizes back to URL query (single source of truth)

5. useDrafts({ sort, filter, page }) fires GET /api/blogs?...
   useAccountSummary() fires GET /api/me/account-summary

6. While loading: skeleton rows (3-row placeholder)

7. On success:
   - DraftsTable renders rows
   - Empty state if total === 0 && no filters
   - Empty-filter state if total === 0 && filters active
   - AccountWidget renders; if account-summary call failed, falls back to name/avatar only

8. analytics.recordDashboardViewed fires once
```

### Data Flow — Sort / Filter Change

```
User changes a filter (e.g. checks "draft" status)
   |
   v
useDashboardState updates state
   |
   v
Two side effects:
   (a) URL query string updates (React Router setSearchParams)
   (b) localStorage entry for this user updates
   |
   v
useDrafts query key changes → TanStack Query refetches
   |
   v
analytics.recordDashboardFilterApplied fires
```

### Data Flow — Open a Draft

```
User clicks a draft title
   |
   v
React Router navigates to /blog/:id/:step
   |
   v
BlogWizard reads :id + :step from useParams
   |
   v
Loads blog state, renders the right step component
   |
   v
analytics.recordDashboardDraftOpened fires with position + sort + filter context
```

---

## API Design

### Endpoints

| Method | Path | Purpose | Auth | Status |
|--------|------|---------|------|--------|
| GET | `/api/blogs` | List user's blogs with sort + filter + pagination | Required | Existing — extend |
| GET | `/api/me/account-summary` | Identity + plan + quota for the current user | Required | **NEW** |

### `GET /api/blogs` — extended

**Query params** (all optional):

```
sort           = last_edited_at | created_at | title | status | word_count | ai_check_score | seo_readiness
direction      = asc | desc                 (default: desc)
page           = 1+                         (default: 1)
page_size      = 1..100                     (default: 25)

filter_status  = draft,in_review,...        (comma-separated; subset of status enum)
filter_title   = <substring>                (case-insensitive ILIKE on title)
filter_score_min = 0..100
filter_score_max = 0..100
```

Invalid values → `400 Bad Request` with field-level error detail. Unknown params → ignored (forwards-compatible).

**Response**:

```jsonc
{
  "blogs": [
    {
      "id": "uuid",
      "title": "Why X matters",
      "status": "draft",
      "currentStep": 3,
      "wordCount": 1240,
      "lastEditedAt": "2026-05-10T14:22:00Z",
      "createdAt": "2026-05-08T09:00:00Z",
      "aiCheckLatestScore": 72,
      "aiCheckLatestMode": "ai_assisted",
      "aiCheckLatestRunAt": "2026-05-10T14:21:00Z",
      "seoReadiness": "needs_work",
      "seoMissingFields": ["meta_description"]
    }
    // … up to page_size entries
  ],
  "pagination": {
    "page": 1,
    "pageSize": 25,
    "total": 38,
    "totalPages": 2,
    "hasMore": true
  }
}
```

**Implementation notes**:

- Sort by `ai_check_score` joins to the latest `blog_ai_checks` row per blog (LATERAL JOIN or window function). NULL scores sort last regardless of direction.
- Sort by `seo_readiness` orders by a stable mapping: `ready < needs_work < missing_fields < null`.
- Filter by `title` is `ILIKE '%query%'` — fine for v1 scale; revisit (full-text index) when user blog counts cross ~1000.
- `total` is computed via a parallel `COUNT(*)` over the filtered set (no caching in v1 — recompute per request is acceptable for expected scale).

### `GET /api/me/account-summary` — NEW

**Response (200)**:

```jsonc
{
  "user": {
    "id": "uuid",
    "displayName": "Mohamed Naser",
    "email": "m@example.com",
    "avatarUrl": null
  },
  "plan": {
    "name": "Free preview",
    "slug": "free_preview"
  },
  "quota": {
    "blogsThisMonth": 3,
    "blogsLimit": null,           // null = unmetered in v1
    "periodStart": "2026-05-01T00:00:00Z",
    "periodEnd": "2026-06-01T00:00:00Z"
  }
}
```

**Failure modes**:

- If quota data isn't computable (e.g. the blog-count query fails) → return the response with `quota: null` rather than 500. The widget gracefully hides the quota line.
- If user-metadata `plan` is missing → defaults to `{ name: "Free preview", slug: "free_preview" }`.

### Error Responses

Standard JSON shape:

```jsonc
{ "error": { "code": "INVALID_SORT_COLUMN", "message": "...", "field": "sort" } }
```

| Code | HTTP | Cause |
|------|------|-------|
| `INVALID_SORT_COLUMN` | 400 | `sort` outside whitelist |
| `INVALID_PAGE` | 400 | `page < 1` or non-numeric |
| `INVALID_PAGE_SIZE` | 400 | `page_size` outside 1..100 |
| `INVALID_SCORE_RANGE` | 400 | `score_min > score_max` or outside 0..100 |
| `UNAUTHENTICATED` | 401 | missing/invalid session |

---

## Data Model

### Migration: `migrate-016-blogs-status-and-archive.sql`

Two small changes if not already present:

```sql
-- Add archived_at if not present (allows filtering archived drafts)
ALTER TABLE blogs ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ NULL;

-- Index for the dashboard listing query
CREATE INDEX IF NOT EXISTS blogs_user_last_edited_idx
  ON blogs (user_id, last_edited_at DESC)
  WHERE archived_at IS NULL;

-- Index for the title filter (ILIKE — pg_trgm makes it indexable)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS blogs_user_title_trgm_idx
  ON blogs USING gin (user_id, title gin_trgm_ops)
  WHERE archived_at IS NULL;
```

This migration follows the existing `/migration` workflow — a labelled `migration` issue + migration AgDR must precede the SQL changes (see Risks).

### Access Patterns

| Query | Index used |
|-------|-----------|
| List drafts, sort by last_edited desc, no filter | `blogs_user_last_edited_idx` |
| List drafts, filter by title ILIKE | `blogs_user_title_trgm_idx` (pg_trgm gin) |
| List drafts, sort by ai_check_score | Sequential scan with LATERAL JOIN — fine at expected scale; revisit if blog counts cross ~10k per user |
| Count drafts for empty-state detection | Index-only scan via `blogs_user_last_edited_idx` |
| Count blogs this month for quota | Sequential scan filtered by `created_at >= period_start` — acceptable at v1 scale |

---

## Analytics

All events use the existing client analytics SDK; helpers live in `frontend/src/features/dashboard/analytics.ts`.

| Event | Trigger | Payload |
|-------|---------|---------|
| `recordDashboardViewed` | On mount | `draft_count`, `is_first_session`, `auth_provider` |
| `recordDashboardDraftOpened` | Row title clicked | `draft_id`, `position_in_list`, `current_sort`, `current_filter` |
| `recordDashboardSortChanged` | Sort column or direction changed | `column`, `direction` |
| `recordDashboardFilterApplied` | Any filter changed | `filter_type`, `filter_value` |
| `recordDashboardNewBlogClick` | "New blog" CTA clicked | `current_draft_count` |
| `recordAccountWidgetViewed` | Widget visible on mount | none |
| `recordDashboardEmptyStateViewed` | Empty state rendered | none |
| `recordDashboardEmptyStateCtaClick` | Empty-state CTA clicked | `cta_id` |
| `recordDashboardBadgeInteracted` | Badge hovered/clicked | `badge_type`, `draft_id` |
| `recordDashboardPageLoaded` | Pagination "Load more" clicked | `page_number`, `total_drafts` |
| `recordAccountMenuOpened` / `recordAccountMenuItemClicked` | Header gear icon | Same as landing — shared helper |

**`is_first_session` detection**: server-side flag — a `first_dashboard_view_at` timestamp column on `auth.users.raw_user_meta_data` (Supabase pattern). On first `/api/me/account-summary` call where this is null, the backend stamps it and returns `isFirstSession: true` for that call. Subsequent calls return `false`. Single source of truth, no client heuristics.

---

## State Management

### URL is the source of truth

`useDashboardState` keeps the dashboard's sort/filter/pagination state in the URL query string. Reasons:

1. **Deep-linking** — users can bookmark/share a filtered view
2. **Back/forward navigation** — browser history Just Works
3. **Reload safety** — refreshing the page preserves state

### localStorage is the fallback

When the user navigates to a bare `/dashboard` (no query string), `useDashboardState`:

1. Reads `localStorage.getItem('dashboardState:${userId}')`
2. If present, hydrates state and `replace`s the URL to reflect that state (so deep-linking still works)
3. If absent, applies defaults (`sort=last_edited_at`, `direction=desc`, no filters)

On every state change, `localStorage` is updated. Keyed by user ID so two users on the same browser don't bleed state. Cleared on logout.

### TanStack Query for server state

Drafts list and account summary use TanStack Query:

- `useDrafts({ sort, filter, page })` — query key is the full param object; refetches automatically on state change
- `useAccountSummary()` — single-key query; refetched on mount; `staleTime: 60_000` so we don't hammer the endpoint on quick re-renders
- `keepPreviousData: true` on `useDrafts` — when filter changes, old rows stay visible during refetch (smoother UX than a flash of skeleton)
- On 401: invalidate all queries, redirect to `/login?redirect=/dashboard`

---

## Implementation Plan

### Tasks

| # | Task | File(s) | Estimate |
|---|------|---------|----------|
| 1 | **Migration** — `archived_at` column + indexes (gated by `/migration` flow) | `backend/migrations/016-*.sql`, migration AgDR | 0.5 d |
| 2 | Extend `listForUser` repository to accept sort/filter/pagination | `backend/src/repositories/blog-repository.ts` | 1 d |
| 3 | Extend `handleListBlogs` handler — validate params, build response with `pagination` block | `backend/src/handlers/blog-handler.ts` | 1 d |
| 4 | New `GET /api/me/account-summary` route + handler + repository | `backend/src/routes/account-routes.ts`, handler, repo | 1 d |
| 5 | `no-cache-private` middleware; apply to dashboard route response (when served via backend) and add `<meta robots noindex>` to dashboard `<head>` | `backend/src/middleware/no-cache-private.ts`, `frontend/src/pages/Dashboard.tsx` | 0.5 d |
| 6 | Extract wizard from old `Dashboard.tsx` into `BlogWizard.tsx` mounted at `/blog/:id/:step` (replace useReducer state with URL-driven state) | `frontend/src/pages/BlogWizard.tsx`, `App.tsx` | 2 d |
| 7 | New `Dashboard.tsx` shell using `AppHeader` (from landing epic) + `DashboardLayout` | `frontend/src/pages/Dashboard.tsx`, `features/dashboard/DashboardLayout.tsx` | 0.5 d |
| 8 | `useDashboardState` hook — URL + localStorage + defaults | `features/dashboard/hooks/useDashboardState.ts` | 1 d |
| 9 | `useDrafts` + `useAccountSummary` TanStack Query wrappers | `features/dashboard/hooks/` | 0.5 d |
| 10 | `DraftsTable` (desktop) with sortable headers | `features/dashboard/DraftsTable.tsx`, `DraftRow.tsx` | 1.5 d |
| 11 | `DraftsList` (mobile cards) | `features/dashboard/DraftsList.tsx` | 1 d |
| 12 | Filter controls — `StatusFilter`, `TitleFilter` (debounced), `ScoreRangeFilter`, `ActiveFilterChips` | `features/dashboard/filters/` | 1.5 d |
| 13 | Badges — `AiCheckBadge` (with popover), `SeoReadinessBadge` (with popover), `StatusBadge` | `features/dashboard/badges/` | 1 d |
| 14 | `EmptyState` (no drafts) + `EmptyFilterState` (filters exclude all) | `features/dashboard/EmptyState.tsx`, `EmptyFilterState.tsx` | 0.5 d |
| 15 | `AccountWidget` with graceful degradation | `features/dashboard/AccountWidget.tsx` | 1 d |
| 16 | `PaginationControl` ("Load more" button — see AgDR) | `features/dashboard/PaginationControl.tsx` | 0.5 d |
| 17 | Analytics helpers + wiring throughout | `features/dashboard/analytics.ts` | 0.5 d |
| 18 | First-session detection — backend stamps `first_dashboard_view_at` on first call | `backend/src/handlers/account-summary-handler.ts` | 0.5 d |
| 19 | Session-expiry inline UX — banner + redirect after 3 s | `features/dashboard/SessionExpiredBanner.tsx`, `useDrafts` 401 handler | 0.5 d |
| 20 | E2E test — Playwright covering: load dashboard, sort, filter, paginate, open draft, "New blog" CTA, empty state for fresh user, session expiry | `frontend/tests/e2e/dashboard.spec.ts` | 1.5 d |
| 21 | Backend integration tests — sort/filter/pagination correctness, ownership enforcement (negative tests for cross-user access) | `backend/src/handlers/__tests__/blog-handler.spec.ts` | 1 d |
| 22 | Accessibility — axe-core via Playwright, keyboard nav for sort/filter, focus management | CI workflow | 0.5 d |
| 23 | Feature flag (`dashboard_v2_enabled`) — gradual rollout 10 → 50 → 100 % | Backend flag check; frontend reads from session | 0.5 d |

**Total: ~18 dev days** (single engineer). Critical path: tasks 1 → 2 → 3 (DB + API) blocks task 9 (frontend query wrapper).

### Sub-issue mapping for the epic

Sub-issues under [#119](https://github.com/mohamednaseramein/issues/119), one PR per group:

| Group | Tasks | PR title |
|-------|-------|----------|
| A | 1 | `feat(#119): migration — archived_at column + dashboard indexes` |
| B | 2, 3 | `feat(#119): GET /api/blogs supports sort + filter + pagination` |
| C | 4, 18 | `feat(#119): GET /api/me/account-summary + first-session detection` |
| D | 5 | `feat(#119): no-cache + noindex on dashboard route` |
| E | 6 | `refactor(#119): extract BlogWizard from Dashboard god-component` |
| F | 7, 8, 9 | `feat(#119): Dashboard shell + state + query wrappers` |
| G | 10, 11 | `feat(#119): DraftsTable (desktop) + DraftsList (mobile)` |
| H | 12 | `feat(#119): filter controls + active filter chips` |
| I | 13 | `feat(#119): AI-check + SEO + status badges` |
| J | 14, 15, 16, 19 | `feat(#119): empty states + account widget + pagination + session expiry` |
| K | 17, 20, 21, 22 | `feat(#119): analytics + e2e + integration + a11y` |
| L | 23 | `chore(#119): feature flag for gradual rollout` |

The Group E refactor (extracting BlogWizard) is the largest single PR and the highest review priority — landing it early de-risks every downstream UI task.

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Extracting BlogWizard from the god-component breaks the existing wizard for active users | High | High | Group E PR ships behind the `dashboard_v2_enabled` flag — old path still works until cutover; e2e tests cover the full wizard flow before merge |
| Sort-by-`ai_check_score` query is slow on accounts with many blogs | Medium | Medium | LATERAL JOIN benchmarked at PR time; if it's > 200 ms on a 500-blog account, materialise `ai_check_latest_score` on the `blogs` table via trigger |
| Title filter (`ILIKE`) sluggish at scale | Low (v1) | Low | `pg_trgm` GIN index handles it; if still slow at 10k blogs per user, revisit with PostgreSQL full-text search |
| First-session detection misfires after metadata wipe | Low | Low | `first_dashboard_view_at` is treated as "if null, first session"; metadata wipe re-triggers — acceptable false positive |
| URL query string grows unwieldy with many filters | Low | Low | Active filter chips give users an easy "remove" affordance; URL caps naturally at a few hundred chars |
| Wizard URL `/blog/:id/:step` collides with existing routes | Low | High | New route is unambiguous; check for existing usage in the codebase before merge |
| Migration #1 conflicts with #115 AI detector migration also in flight | Medium | Medium | Sequence migrations: AI-detector migration ships first; this one runs against the post-migration schema. Both follow `/migration` flow with AgDRs |
| Feature flag accidentally disables existing users' wizards mid-flow | Medium | High | Flag gates the **routes**, not the wizard components. When off, `/dashboard` → 404; old `/` continues serving the god-component. Cutover swaps `/` to landing AND opens `/dashboard` simultaneously |

---

## Security Considerations

- **Ownership enforcement** — `GET /api/blogs` filters by `user_id = current_user_id` at the repository layer. Negative tests assert that a user cannot list/open another user's draft, even by tampering with `?filter_status=` or `?page=` to force broader scans.
- **Sort/filter parameter validation** — every value is whitelisted server-side; arbitrary `sort=` strings are rejected with 400 (no SQL injection surface)
- **Title filter ILIKE** — uses parameterised queries (no string concatenation)
- **`Cache-Control: private, no-store`** + `<meta robots noindex>` + `robots.txt Disallow: /dashboard` + not in `sitemap.xml` — quadruple-layered to prevent any accidental indexing of authenticated content
- **Account summary** — returns only the current user's data; never accepts a `userId` query param
- **Analytics payloads** — never include draft body content; only IDs, counts, and aggregate metrics. Reviewed against `LOG_AI_CHECK_PAYLOADS=false` precedent from the AI detector PRD
- **Session expiry mid-page** — surfaced cleanly via the 401 handler; no silent failure that could leave stale data on screen

---

## Testing Strategy

| Layer | Tool | Coverage |
|-------|------|----------|
| Unit (FE) | Vitest + RTL | `useDashboardState` URL/localStorage/defaults precedence; filter validators; badge popover content |
| Unit (BE) | Vitest | `DashboardSort`, `DashboardFilter`, `Pagination` value-object validation; status-enum derivation |
| Integration (BE) | Vitest against test DB | Sort/filter/pagination correctness across all sortable columns; ownership enforcement (cross-user negative tests); empty-state count accuracy |
| E2E | Playwright | Load dashboard → sort by column → URL updates → reload preserves sort; filter by status + title → empty-filter state visible; open draft → wizard URL → back returns to dashboard with state intact; first-time user empty state CTA; session expiry banner |
| Accessibility | axe-core via Playwright | Zero serious/critical violations; keyboard reaches every sort header, filter input, and row title; focus rings visible |
| Visual regression | Playwright snapshots at 375/768/1280 px | Empty state, populated table, mobile cards, account widget, error states |
| Performance | RUM (existing analytics) + Lighthouse mobile preset | Time-to-interactive ≤ 1 s P50 on 3-draft account; API latency ≤ 200 ms P95 on `GET /api/blogs?page=1` |

---

## AgDRs

| AgDR | Topic | Why it matters |
|------|-------|----------------|
| AgDR-N | Migration approach — single migration vs split (archived_at separate from indexes) | Rollback granularity; `/migration` flow requires an AgDR before any migration file is touched |
| AgDR-N+1 | Pagination — page-based vs cursor-based; "Load more" vs infinite scroll | Affects API contract and accessibility; PRD defers; recommend page-based + "Load more" for a11y |
| AgDR-N+2 | Sort-by-ai-score query — LATERAL JOIN vs materialised `ai_check_latest_score` on `blogs` | Performance / write-amplification tradeoff |
| AgDR-N+3 | Feature flag mechanism — backend env var vs per-user flag in Supabase metadata | Granularity of gradual rollout |
| AgDR-N+4 | God-component refactor sequencing — flag-gated dual-write vs hard cutover | Risk to existing users mid-flow |

Each created via `/decide` before the relevant task starts.

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Existing `GET /api/blogs` response shape — confirm the existing fields match `BlogDraftSummary` and identify any gaps | Backend Engineer | Open (verify in task 2) |
| `seo_readiness` derivation — is there a canonical computation already, or do we define it in the read-model query? | Tech Lead | Open |
| Plan/quota — what's the v1 truth? "Free preview / unmetered for all"? Confirm with Head of Product | Head of Product | Open (PRD-level) |
| Pagination strategy — page-based vs cursor-based for the API. Recommend page-based for v1 simplicity | Tech Lead | Open (AgDR pending) |
| Feature flag — does an existing flag system exist (env / Supabase metadata / launchdarkly-style)? | Platform | Open |
| Existing wizard route shape — does any route already use `/blog/:id/*` or do we have a clean slate? | Backend Engineer | Open (verify in task 6) |
| `/settings` page — referenced by the gear menu; does it exist yet? If not, menu item routes to `/profile` as fallback | Head of Product | Open (PRD-level) |
| Mobile interaction for the AI-check / SEO badge popovers — hover doesn't exist; tap-to-open + tap-outside-to-close pattern OK? | UX Designer | Open |

---

## Estimates Summary

- **Total effort**: ~18 dev days (single engineer)
- **Parallelisable**: Yes — backend (tasks 1–4, 18, 21) and frontend (tasks 6–17, 19, 20, 22) can split across two engineers after task 3 lands the API contract
- **Critical path**: Task 1 (migration) → 2 → 3 (API) → 9 (FE query wrapper) → all UI tasks; task 6 (BlogWizard extraction) blocks task 7 (new Dashboard shell)
- **Recommended team shape**: 1 senior full-stack + 1 mid frontend, paired through tasks 1–6, then splitting backend vs frontend tracks

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Tech Lead | Mohamed Naser | 2026-05-11 | Author |
| Head of Engineering | | | Pending |
| Product Manager | | | Pending |
