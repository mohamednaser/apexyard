# Technical Design: Subscription Plans

**Author**: Tech Lead (via ApexYard agent)
**Date**: 2026-05-14
**Status**: Approved (2026-05-14) — AgDRs formalised before Build per Gate 2
**PRD**: `prd-subscriptions.md`
**Epic**: _to be created — see PRD OQ-1_

---

## Overview

Introduce admin-managed subscription plans with four numeric limits, self-serve upgrade/downgrade, server-side quota enforcement on four metered actions, a live-data landing page pricing section, and a cutover migration that seeds three plans and backfills every existing user onto Free. Billing is **display-only** — the schema carries a Stripe seam but no payment provider is integrated.

This design covers the backend (two migrations, domain types, two repositories, two services, two handler modules, route wiring, enforcement integration into four existing handlers) and the frontend (two API clients, one user page, one admin page, shared components, the landing-page rebind, routing).

---

## Key Technical Decisions

> These are AgDR-worthy. They will be formalised as standalone AgDRs in `workspace/blog-generator/docs/agdr/` and linked from their tickets **before Build** (Gate 2 requires AgDRs for key decisions). Captured here so the design is reviewable as a whole.

### KD-1 — Plan limits: explicit typed columns, not JSONB

| Option | Pros | Cons |
|--------|------|------|
| **Four explicit columns** (chosen) | Type-safe end-to-end, `CHECK` constraints, queryable, matches the codebase's typed/DDD lean | Adding a 5th limit later = a migration |
| JSONB `limits` column | Flexible, no migration to add a limit | Loses type safety + constraints, every read needs runtime validation |

**Chosen**: four nullable integer columns (`blog_quota`, `ai_check_quota`, `author_profile_limit`, `reference_extraction_quota`). v1 has exactly four known limits; flexibility we don't need isn't worth the type-safety loss. JSONB is the documented upgrade path if limits proliferate.

### KD-2 — Usage period: explicit `current_period_start/end` columns, lazily rolled

The `subscriptions` row carries `current_period_start` and `current_period_end`. In v1 they are calendar-month boundaries (UTC) — `date_trunc('month', now())` to `+ interval '1 month'` (PRD OQ-2 assumption). Enforcement and the usage API **read the window from the row**, never compute it ad hoc. When a read observes `now() >= current_period_end`, the period is rolled forward lazily (no cron). This is the Stripe seam: when Stripe arrives, anniversary-based periods simply change *how these columns are populated* — every consumer is unaffected.

### KD-3 — Usage counting: count live rows by `created_at`, no counter table

Monthly metrics (blogs, AI checks, reference extractions) are counted as live rows with `created_at` inside the current period window. Author-profile count is a standing `COUNT(*)` of live non-predefined rows. No dedicated `usage_counters` table in v1 — the data already exists, all four metrics already have `created_at`, and "deleting an item frees a slot this period" is acceptable per the PRD (Edge Cases). A counter table is the documented upgrade path if a strict "creation events are permanent" model is later required.

### KD-4 — New-user subscription: DB trigger, extending the existing auth-sync pattern

`migrate-013-auth-sync-triggers.sql` already has `handle_new_user()` firing on `auth.users` INSERT to create the `public.users` row. We extend that same function to also insert a subscription on the current default plan. Rationale: guarantees no orphaned user regardless of which code path creates the account, and matches the established pattern. (App-layer creation in the registration handler was rejected — it would miss admin-created or trigger-created users.)

### KD-5 — Enforcement: a shared service helper, not Express middleware

A single tested function `assertWithinQuota(userId, metric)` is called at the top of the four gated handlers. Middleware was rejected: the four endpoints live on different routers, the AI-check handler has its own pre-checks (language detection, cache lookup, rate-limit) that must run in a specific order, and middleware param-plumbing for "which metric does this route consume" is awkward. One unit, called explicitly, fully testable.

### KD-6 — Quota-exceeded response: `402 Payment Required` + typed code (resolves PRD OQ-5)

`AppError(402, 'QUOTA_EXCEEDED', message)`. 402 semantically signals "an upgrade unlocks this," which is exactly the intent and lets the frontend branch cleanly on status. The error payload carries `{ code: 'QUOTA_EXCEEDED', message, metric, limit, usage }` via an extended `AppError` (or a structured message) so the UI can render a precise upgrade prompt.

---

## Domain Model

New file: `backend/src/domain/subscription-types.ts`

```ts
export type QuotaMetric =
  | 'blogs'                  // monthly creation quota
  | 'ai_checks'              // monthly creation quota
  | 'reference_extractions'  // monthly creation quota
  | 'author_profiles';       // standing total cap

export type BillingPeriod = 'monthly';                 // only value in v1
export type SubscriptionStatus = 'active';             // 'past_due' | 'canceled' reserved for Stripe

/** A limit value of null = unlimited for that metric. */
export interface PlanLimits {
  blogQuota: number | null;
  aiCheckQuota: number | null;
  authorProfileLimit: number | null;
  referenceExtractionQuota: number | null;
}

export interface Plan {
  id: string;
  slug: string;                 // stable, immutable once subscribers exist
  name: string;
  description: string;
  priceCents: number;           // display-only in v1
  currency: string;             // ISO 4217, default 'USD'
  billingPeriod: BillingPeriod;
  limits: PlanLimits;
  isPublic: boolean;            // shown on landing + self-serve picker
  isDefault: boolean;           // exactly one true across all non-archived plans
  archivedAt: Date | null;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface Subscription {
  id: string;
  userId: string;
  planId: string;
  status: SubscriptionStatus;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  stripeSubscriptionId: string | null;   // Stripe seam — unused in v1
  changedBy: string | null;              // admin user_id, or null for self-serve
  createdAt: Date;
  updatedAt: Date;
}

/** Per-metric usage vs limit, computed for the current period. */
export interface UsageSnapshot {
  metric: QuotaMetric;
  used: number;
  limit: number | null;          // null = unlimited
  exceeded: boolean;             // used >= limit (false when unlimited)
}

export interface SubscriptionView {
  subscription: Subscription;
  plan: Plan;
  usage: UsageSnapshot[];
  periodResetsAt: Date;          // = currentPeriodEnd
}
```

---

## Data Model

Two migration files (next free numbers after `migrate-015`). Both belong to story **US-SUB-10** and both trip the migration gate — produced via `/migration`, each with a header block linking the migration ticket + migration AgDR (per the `migrate-015` precedent).

### `migrate-016-subscriptions-schema.sql` — tables

```sql
-- Migration 016: Subscription plans + per-user subscriptions
-- Ticket:   <migration ticket URL>
-- Epic:     <epic URL>
-- AgDR:     docs/agdr/AgDR-NNNN-migration-subscriptions-schema.md
-- Rollback: DROP TABLE IF EXISTS subscriptions; DROP TABLE IF EXISTS plans;

CREATE TABLE plans (
  id                           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                         VARCHAR(50)  NOT NULL UNIQUE,
  name                         VARCHAR(120) NOT NULL,
  description                  TEXT         NOT NULL DEFAULT '',
  price_cents                  INTEGER      NOT NULL DEFAULT 0 CHECK (price_cents >= 0),
  currency                     CHAR(3)      NOT NULL DEFAULT 'USD',
  billing_period               VARCHAR(20)  NOT NULL DEFAULT 'monthly'
                               CHECK (billing_period IN ('monthly')),
  blog_quota                   INTEGER      CHECK (blog_quota IS NULL OR blog_quota >= 0),
  ai_check_quota               INTEGER      CHECK (ai_check_quota IS NULL OR ai_check_quota >= 0),
  author_profile_limit         INTEGER      CHECK (author_profile_limit IS NULL OR author_profile_limit >= 0),
  reference_extraction_quota   INTEGER      CHECK (reference_extraction_quota IS NULL OR reference_extraction_quota >= 0),
  is_public                    BOOLEAN      NOT NULL DEFAULT false,
  is_default                   BOOLEAN      NOT NULL DEFAULT false,
  archived_at                  TIMESTAMPTZ,
  sort_order                   SMALLINT     NOT NULL DEFAULT 0,
  created_at                   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at                   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- At most one default plan among non-archived plans.
CREATE UNIQUE INDEX uniq_plans_single_default
  ON plans (is_default) WHERE is_default = true AND archived_at IS NULL;

CREATE TABLE subscriptions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id                 UUID NOT NULL REFERENCES plans(id),
  status                  VARCHAR(20) NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active')),  -- 'past_due','canceled' added with Stripe
  current_period_start    TIMESTAMPTZ NOT NULL,
  current_period_end      TIMESTAMPTZ NOT NULL,
  stripe_subscription_id  VARCHAR(255) UNIQUE,           -- Stripe seam, null in v1
  changed_by              UUID REFERENCES users(id),     -- admin id, or null = self-serve
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One active subscription per user (the invariant the whole feature rests on).
CREATE UNIQUE INDEX uniq_subscriptions_one_active_per_user
  ON subscriptions (user_id) WHERE status = 'active';

CREATE INDEX idx_subscriptions_plan_id ON subscriptions (plan_id);
```

### `migrate-017-seed-plans-and-backfill.sql` — seed, backfill, trigger

```sql
-- Migration 017: Seed 3 plans, backfill existing users to Free, extend new-user trigger
-- Ticket / Epic / AgDR: <as above>
-- Rollback: DELETE FROM subscriptions; DELETE FROM plans WHERE slug IN ('free','pro','team');
--           plus restore handle_new_user() to its migrate-013 body.

INSERT INTO plans (slug, name, description, price_cents, currency,
                   blog_quota, ai_check_quota, author_profile_limit, reference_extraction_quota,
                   is_public, is_default, sort_order) VALUES
  ('free', 'Free', 'Get started at no cost.',                0,    'USD', 3,    5,    1,    10,   true, true,  1),
  ('pro',  'Pro',  'For regular content creators.',          1900, 'USD', 50,   200,  10,   300,  true, false, 2),
  ('team', 'Team', 'For teams shipping at volume.',          9900, 'USD', NULL, NULL, 50,   NULL, true, false, 3);

-- Backfill: every existing user gets an active Free subscription.
INSERT INTO subscriptions (user_id, plan_id, status, current_period_start, current_period_end)
SELECT u.id,
       (SELECT id FROM plans WHERE slug = 'free'),
       'active',
       date_trunc('month', NOW()),
       date_trunc('month', NOW()) + INTERVAL '1 month'
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM subscriptions s WHERE s.user_id = u.id AND s.status = 'active');

-- Extend the existing auth-sync function to also create the default subscription (KD-4).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  default_plan_id UUID;
BEGIN
  INSERT INTO public.users (id, role, email_verified_at)
  VALUES (new.id, 'user', new.email_confirmed_at);

  SELECT id INTO default_plan_id FROM public.plans
  WHERE is_default = true AND archived_at IS NULL LIMIT 1;

  IF default_plan_id IS NOT NULL THEN
    INSERT INTO public.subscriptions (user_id, plan_id, status,
                                      current_period_start, current_period_end)
    VALUES (new.id, default_plan_id, 'active',
            date_trunc('month', NOW()), date_trunc('month', NOW()) + INTERVAL '1 month');
  END IF;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Verification query** (run post-migration, US-SUB-10 AC4):
`SELECT COUNT(*) FROM users u WHERE NOT EXISTS (SELECT 1 FROM subscriptions s WHERE s.user_id = u.id AND s.status = 'active');` → must be `0`.

---

## API Design

### Public

**`GET /api/plans`** — new `plan-routes.ts`, no auth.
Returns public, non-archived plans ordered by `sort_order`.
`200 → { plans: PublicPlan[] }` where `PublicPlan` omits internal flags (`isDefault`, `archivedAt`).

### User (auth) — new `subscription-routes.ts`, `requireAuth`

**`GET /api/subscription`** → `200 → SubscriptionView` (current plan + four `UsageSnapshot`s + `periodResetsAt`).

**`PUT /api/subscription`** — body `{ planId: string }`. Self-serve plan change.
- Target must be a public, non-archived plan → else `404`.
- If target limits < current usage on any metric → `409 { code: 'DOWNGRADE_BLOCKED', conflicts: [{ metric, used, limit }] }`.
- Else updates the subscription (period **not** reset, usage carries over), `changed_by = null`.
- `200 → SubscriptionView`.

### Admin — added to `admin-routes.ts` (already `requireAuth, requireAdmin`)

| Method + path | Purpose |
|---------------|---------|
| `GET /api/admin/plans` | All plans incl. private + archived |
| `POST /api/admin/plans` | Create plan (defaults to private, non-default) |
| `PATCH /api/admin/plans/:id` | Edit name/description/price/limits/`isPublic`/`sortOrder`; `slug` immutable once subscribers exist |
| `POST /api/admin/plans/:id/archive` | Soft-delete; `409` if it has active subscribers or is the default |
| `POST /api/admin/plans/:id/set-default` | Make this the default; clears the previous default; existing subscribers unmoved |
| `GET /api/admin/users/:id/subscription` | A user's `SubscriptionView` |
| `PUT /api/admin/users/:id/subscription` | Change a user's plan — body `{ planId, override?: boolean }`; without `override` behaves like self-serve (`409` on conflict); with `override:true` proceeds and records `changed_by = <admin id>` |

Validation errors → `400` with field messages. All admin routes → `403` for `user` role (inherited from the router-level guard).

---

## Backend Architecture

```
migrate-016 / migrate-017 .......... schema, seed, backfill, trigger          [US-SUB-10]
domain/subscription-types.ts ....... Plan, Subscription, PlanLimits, etc.     [US-SUB-10]
repositories/plan-repository.ts .... CRUD + listPublic + findDefault + slug   [US-SUB-01..03, 09]
repositories/subscription-repository.ts  find-by-user, update plan, roll period, count active per plan  [US-SUB-04..07, 10]
services/quota-service.ts .......... computeUsage(userId), assertWithinQuota(userId, metric)            [US-SUB-05, 08]
services/subscription-service.ts ... changePlan(userId, planId, { actor, override }) — downgrade-block, period roll  [US-SUB-04, 06, 07]
handlers/plan-handler.ts ........... listPublicPlans | listAllPlans | createPlan | updatePlan | archivePlan | setDefaultPlan  [US-SUB-01..03, 09]
handlers/subscription-handler.ts ... getMySubscription | changeMyPlan | getUserSubscription | changeUserPlan  [US-SUB-04..07]
routes/plan-routes.ts .............. GET /api/plans (public)                  [US-SUB-09]
routes/subscription-routes.ts ...... GET/PUT /api/subscription (auth)         [US-SUB-05..07]
routes/admin-routes.ts ............. + plan CRUD + per-user subscription      [US-SUB-01..04]
index.ts ........................... mount /api/plans and /api/subscription   [US-SUB-09, 05]
```

`AppError` (in `error-handler.ts`) gains an optional structured `details` field so `QUOTA_EXCEEDED` / `DOWNGRADE_BLOCKED` can carry `{ metric, limit, usage }` / `conflicts[]` — or those handlers respond directly without throwing. Decided at implementation time; either keeps the existing error envelope shape.

### Enforcement integration (US-SUB-08) — surgical, one line per handler

`assertWithinQuota` throws `AppError(402, 'QUOTA_EXCEEDED', …)` when at/over limit; no-ops when under limit or unlimited.

| Handler | File | Inserted before |
|---------|------|-----------------|
| `handleCreateBlog` | `blog-handler.ts` | `createBlog(userId)` |
| `handleRunAiCheck` | `blog-ai-check-handler.ts` | the LLM call (after the existing cache hit / language / rate-limit pre-checks — a cache hit should arguably not consume quota; decided in the ticket) |
| `createProfile` path | `profile-handler.ts` | the `createProfile(...)` insert (custom profiles only — predefined/clone rules confirmed in the ticket) |
| `handleAddReference` | `blog-references-handler.ts` | the reference insert / scrape trigger |

This is why enforcement ships **last and isolated** (see Sequencing) — it is the only behaviour change existing users feel, and these four call-sites can be reverted independently.

---

## Frontend Architecture

```
api/plan-api.ts ............ getPublicPlans | (admin) list/create/update/archive/setDefault   [US-SUB-01..03, 09]
api/subscription-api.ts .... getMySubscription | changeMyPlan | (admin) getUserSubscription | changeUserPlan  [US-SUB-04..07]
landing/Pricing.tsx ........ rebind to getPublicPlans(); remove static pricing.tiers from content.ts (keep heading/subtitle/disclaimer copy)  [US-SUB-09]
pages/PlanUsagePage.tsx .... route /plan (ProtectedRoute) — current plan, usage meters, plan picker   [US-SUB-05..07]
components/PlanCard.tsx .... presentational plan card (shared by landing + picker)            [US-SUB-09, 06]
components/UsageMeter.tsx .. one metric's used/limit bar with a text equivalent (WCAG)        [US-SUB-05]
components/PlanPicker.tsx .. switch UI; confirm dialog; renders DOWNGRADE_BLOCKED conflicts   [US-SUB-06, 07]
components/QuotaBlockPrompt.tsx  upgrade prompt shown on a 402 QUOTA_EXCEEDED                 [US-SUB-08]
pages/admin/AdminPlansPage.tsx + AdminPlanForm.tsx  list / create / edit / archive / set-default  [US-SUB-01..03]
pages/admin/AdminUserDetailPage.tsx  + subscription section + plan-change control             [US-SUB-04]
pages/admin/AdminLayout.tsx  + "Plans" nav link                                               [US-SUB-01]
App.tsx .................... + /plan route, + /admin/plans route                              [US-SUB-05, 01]
```

**Quota-block UX**: `authed-fetch.ts` (or the per-API `parseJson`) detects a `402 QUOTA_EXCEEDED` and surfaces `QuotaBlockPrompt` (toast or inline) linking to `/plan`, firing `quota_blocked`. **Landing live-data (US-SUB-09 AC6)**: the landing page is statically pre-rendered (#118 / AgDR-0033); `Pricing.tsx` fetches `GET /api/plans` at runtime on the client so the published page is never frozen with stale plan data — confirm against the #118 prerender script during that ticket.

---

## Implementation Plan

One ticket per PRD story (matches how this project runs epics — cf. #82 → #84–#91). Each is one branch → PR → Rex review → CEO approval → QA.

### US-SUB-10 — Migration: schema, seed, backfill, trigger  *(migration story — `/migration` gate)*
| # | Task | Layer |
|---|------|-------|
| 1 | `migrate-016-subscriptions-schema.sql` | DB |
| 2 | `migrate-017-seed-plans-and-backfill.sql` (seed 3 + backfill + extend `handle_new_user()`) | DB |
| 3 | `domain/subscription-types.ts` | Domain |
| 4 | `plan-repository.ts`, `subscription-repository.ts` (read + period-roll) | Repo |
| 5 | Run migrations on staging; run the verification query (AC4) | DB |
| 6 | Tests: repository round-trips, period-roll logic | Tests |

### US-SUB-01/02/03 — Admin plan catalogue (create / edit / archive + set-default)
| # | Task | Layer |
|---|------|-------|
| 1 | `plan-handler.ts` — listAllPlans, createPlan, updatePlan, archivePlan, setDefaultPlan + validation | Handler |
| 2 | Wire admin routes in `admin-routes.ts` | Routes |
| 3 | `plan-api.ts` admin calls | Frontend |
| 4 | `AdminPlansPage.tsx` + `AdminPlanForm.tsx`; nav link; `/admin/plans` route | Frontend |
| 5 | Tests: archive-guard (subscribers / default), single-default invariant, validation | Tests |

### US-SUB-09 — Landing page live plans
| # | Task | Layer |
|---|------|-------|
| 1 | `plan-handler.ts` listPublicPlans; `plan-routes.ts`; mount `/api/plans` | Backend |
| 2 | `plan-api.ts` `getPublicPlans`; `PlanCard.tsx` | Frontend |
| 3 | Rebind `Pricing.tsx`; trim `content.ts` `pricing` block | Frontend |
| 4 | Verify against #118 prerender script | Frontend |
| 5 | Tests: public endpoint hides private/archived; no auth required | Tests |

### US-SUB-05/06/07 — User self-serve (view / upgrade / downgrade)
| # | Task | Layer |
|---|------|-------|
| 1 | `quota-service.ts` `computeUsage` | Service |
| 2 | `subscription-service.ts` `changePlan` (downgrade-block, period preserved) | Service |
| 3 | `subscription-handler.ts` getMySubscription, changeMyPlan; `subscription-routes.ts`; mount `/api/subscription` | Backend |
| 4 | `subscription-api.ts` user calls | Frontend |
| 5 | `PlanUsagePage.tsx`, `UsageMeter.tsx`, `PlanPicker.tsx`; `/plan` route; account-menu link | Frontend |
| 6 | Tests: downgrade-block per metric, upgrade carries usage, unlimited handling | Tests |

### US-SUB-04 — Admin per-user subscription management
| # | Task | Layer |
|---|------|-------|
| 1 | `subscription-handler.ts` getUserSubscription, changeUserPlan (`override` flag, `changed_by`) | Handler |
| 2 | Wire admin per-user routes | Routes |
| 3 | `subscription-api.ts` admin calls | Frontend |
| 4 | `AdminUserDetailPage.tsx` subscription section + plan-change control + override confirm | Frontend |
| 5 | Tests: override bypasses block + records actor; non-override respects block | Tests |

### US-SUB-08 — Quota enforcement  *(ships last, isolated — see Sequencing)*
| # | Task | Layer |
|---|------|-------|
| 1 | `quota-service.ts` `assertWithinQuota(userId, metric)` | Service |
| 2 | Insert the check into the 4 handlers (blog create, AI check, profile create, add reference) | Handler |
| 3 | `QuotaBlockPrompt.tsx`; 402 detection in `authed-fetch.ts`/API clients; `quota_blocked` event | Frontend |
| 4 | Tests: each metric blocked at limit / allowed below / never blocked when unlimited; server-side bypass-proof | Tests |

### FR-16 — Dashboard account widget bound to real plan data  *(Should — PRD OQ-4)*
Thin: point the #119 account widget at `GET /api/subscription`. If #119 is still open at Build time, hand off the contract to that team rather than duplicating; otherwise a small follow-up ticket.

### Recommended sequencing

```
US-SUB-10  (foundation: tables, seed, backfill, types, repos)
   └─► US-SUB-01/02/03  (admin can manage the catalogue)
   └─► US-SUB-09        (landing shows live plans)
   └─► US-SUB-05/06/07  (users can view + switch)
          └─► US-SUB-04 (admin manages a user's subscription)
                 └─► US-SUB-08  (enforcement ON — last, isolated, independently revertible)
                        └─► FR-16 (dashboard widget — or hand to #119)
```

Enforcement is deliberately last: it is the sole behaviour change existing users feel, so it lands as its own PR that can be verified and rolled back on its own (PRD Launch Plan).

---

## Testing Strategy

- **Unit** — `quota-service` (usage math, period-roll, unlimited handling), `subscription-service` (downgrade-block per metric, override path, period preserved on switch), repository row↔model mapping. Target > 80 % on subscription domain + enforcement.
- **Integration** — each of the 7 endpoints incl. `403` for non-admins on admin routes, `404` on private/archived target, `409` shapes for `DOWNGRADE_BLOCKED`, `402` for `QUOTA_EXCEEDED`; the four gated handlers at/below limit. Keep to ≤ 1 `:integration_test`-style heavy case per file.
- **Migration** — apply `016`+`017` on staging, run the verification query, exercise the documented rollback (drop tables; restore `handle_new_user()`), confirm a fresh signup gets a Free subscription via the trigger.
- **Frontend** — `PlanPicker` renders conflicts; `UsageMeter` text equivalent present; `Pricing.tsx` renders from fetched data; `QuotaBlockPrompt` shows on 402.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Cutover migration leaves an orphaned user | `uniq_subscriptions_one_active_per_user` index + backfill `WHERE NOT EXISTS` is idempotent + the AC4 verification query is a release gate |
| Enforcement misfires and blocks legitimate users | Ships last as an isolated PR; the four call-sites revert independently; 24–48 h monitoring of `quota_blocked` volume + blog/AI-check error rates per PRD Launch Plan |
| Race: two requests claim the last quota slot | v1 accepts a small transient over-count; tighten with a transactional check in the ticket if observed. Documented in PRD Edge Cases |
| `#118` / `#119` in flight touch `Pricing.tsx`, `content.ts`, the account widget | Sequence subscription PRs after / in coordination with those; FR-16 explicitly offers a contract handoff to #119 |
| Period-roll on read introduces a write on a GET | Roll only when `now() >= current_period_end` (rare); a single conditional `UPDATE`. A scheduled roll is the alternative if read-path writes prove undesirable |
| Default-plan invariant violated by a bad admin action | Partial unique index enforces ≤ 1 default; `archive`/`set-default` handlers guard the transitions; covered by tests |
| Stripe seam wrong, forcing reshape later | `status` enum, `stripe_subscription_id`, and period columns exist now; enforcement reads the period from the row — anniversary periods later change only how columns are populated |

---

## Open Questions

| # | Question | Owner | Status |
|---|----------|-------|--------|
| TD-1 | Does a **cached** AI-check (cache hit, no LLM call) consume AI-check quota? Leaning **no** — quota meters the expensive LLM call. Confirm in the US-SUB-08 ticket. | Tech Lead / PM | Open |
| TD-2 | Author-profile quota — does **cloning a predefined profile** count against `author_profile_limit`? Leaning **yes** (it creates a user-owned row). Confirm in the US-SUB-08 ticket. | Tech Lead / PM | Open |
| TD-3 | Carry-over of PRD OQ-2 (calendar-month UTC vs anniversary). This design assumes **calendar-month UTC**; the `current_period_*` columns make anniversary a non-breaking later change. | PM / Tech Lead | Open |
| TD-4 | `AppError` extended with structured `details`, or gated handlers respond directly without throwing? Both preserve the response envelope — implementation-time call. | Tech Lead | Open |
```
