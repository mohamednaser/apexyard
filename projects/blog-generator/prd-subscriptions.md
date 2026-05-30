# PRD: Subscription Plans — Admin-Managed Tiers, Self-Serve Upgrades & Quota Enforcement

**Status**: Approved
**Author**: Mohamed Naser (Product Manager via ApexYard agent)
**Created**: 2026-05-14
**Last Updated**: 2026-05-14
**Approved**: 2026-05-14 by Mohamed Naser (CEO / Head of Product)
**Epic**: _to be created — see Open Question OQ-1 on epic numbering_
**Related**: `prd-auth-ep04.md` (EP-04 auth — provides `users`, roles, admin panel), `prd-landing-page.md` (#118 — owns `Pricing.tsx`), `prd-dashboard.md` (#119 — account widget references a user "plan")

---

## Overview

### Problem Statement

The product has no concept of a subscription plan. Every authenticated user has unlimited access to every capability — blog generation, AI authenticity checks, author profiles, reference extraction — with no tiering and no commercial structure. Three concrete problems follow:

1. **No commercial model.** There is no way to differentiate a free user from a paying one. The landing page already advertises three tiers (Free / Pro / Team) in `frontend/src/landing/content.ts`, but they are hardcoded marketing copy with a *"billing not yet enabled — all paid features are free during this preview"* disclaimer. Nothing behind them is real.
2. **No usage limits.** A single user can generate unlimited blogs and consume unlimited AI/Claude API calls. This is an unbounded cost exposure and removes any incentive to upgrade.
3. **No admin control over packaging.** When the team wants to change what a tier includes — its price, its blog allowance — there is no surface to do it. It would require a code change and a deploy.

This epic introduces **admin-managed subscription plans**: an admin can create plans and edit their price and limits; every user is placed on a plan (all existing users on **Free**); users can self-serve upgrade and downgrade between plans; the four metered capabilities are enforced against the active plan's limits; and the landing page renders the live plans instead of hardcoded copy.

**Billing is display-only in v1.** Plans carry a price, but no money changes hands — switching plans is instant and free. The data model is built with a clean seam (`stripe_subscription_id`, explicit billing-period columns, a `status` enum) so a real Stripe integration can be added later without reshaping the schema. See Non-Goals and the Stripe seam note in Technical Notes.

### Target Users

**Primary — User (content creator)**: A content marketer, SEO professional, or founder who wants to understand what their plan includes, see how much of their monthly allowance they have used, and upgrade or downgrade their plan themselves without contacting support.

**Primary — Admin (platform operator)**: The operator (initially Mohamed Naser) who needs to define the commercial packaging — create plans, set each plan's price and four limits, control which plans appear on the landing page — and to manage individual users' subscriptions (view a user's plan and usage, move a user to a different plan).

**Secondary — Public visitor**: An unauthenticated visitor on the landing page who wants to compare plans before signing up.

### What Already Exists (do not re-build)

| Capability | Where |
|------------|-------|
| Auth — Supabase JWT, `users` table with `role` (`admin` \| `user`), `requireAuth` / `requireAdmin` middleware | EP-04 (#95), shipped |
| Admin panel — list users, view per-user usage, deactivate/reactivate, promote/demote | `backend/src/handlers/admin-handler.ts`, `frontend/src/pages/admin/*`, shipped |
| Per-user usage counting — blogs, custom author profiles, AI checks, reference extractions | `getUserUsage` in `admin-handler.ts`, shipped (counts only — **no enforcement**) |
| Landing page pricing section — renders 3 tiers from static content | `frontend/src/landing/Pricing.tsx` + `content.ts` `pricing` block (hardcoded — this epic replaces the data source) |
| Dashboard account widget — displays a user "plan" field | `prd-dashboard.md` / #119 (in flight — this epic provides the real plan data it binds to) |
| `created_at` timestamps on `blogs`, `blog_ai_checks`, `blog_references`, `author_profiles` | Existing migrations — used to compute monthly usage windows |

### Goals

1. An admin can create, edit, and archive subscription plans — including each plan's price and its four limits — entirely through the admin UI, with zero code changes or deploys.
2. Every existing user is migrated onto the **Free** plan with zero data loss and zero orphaned users (no user without an active subscription).
3. A user can view their current plan and their current-period usage against every limit, and can upgrade or downgrade between plans themselves.
4. The four metered capabilities (blog creation, AI authenticity check, author profile creation, reference extraction) are enforced server-side against the active plan's limits — a user at their limit is clearly blocked and told which plan would unblock them.
5. The landing page renders the live, public plans from the database; changing a plan in the admin UI is reflected on the landing page without a deploy.
6. Achieve > 80 % unit + integration coverage on the subscription domain logic and the quota-enforcement middleware.

### Non-Goals (Out of Scope)

- **Real payment processing.** No Stripe checkout, no card capture, no invoices, no receipts, no proration, no dunning/past-due handling. Price is **display-only**. The schema carries a Stripe seam (`stripe_subscription_id`, `status` enum, billing-period columns) but no provider is integrated in v1. Stripe is a planned **fast-follow epic**.
- **Annual / multiple billing periods.** Monthly only. `billing_period` exists as a column but `monthly` is its only value in v1.
- **Coupons, discounts, trials, promo codes, grandfathered legacy pricing.**
- **Usage-based / metered billing.** Limits are fixed per-plan caps, not pay-as-you-go meters.
- **Multi-seat / team subscriptions.** The "Team" plan is a pricing *tier*, not a multi-user workspace. Seat management is not in scope despite the name.
- **Per-feature boolean entitlements** (e.g. "Pro unlocks feature X"). v1 plans differ **only** by the four numeric limits + price. Boolean feature flags can be added later.
- **Email / in-app notifications** on plan change, quota-approaching, or quota-exceeded. Quota state is visible on the plan page on demand; proactive notifications are a fast-follow.
- **User-initiated plan deletion or plan creation.** Only admins manage the catalogue of plans. Users only *choose* among existing plans.
- **A usage-history / billing-history view.** Users see current-period usage only.
- **Refunds, credits, or any money movement** — follows from "no payments".

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Existing users backfilled to Free | 100 % — 0 users without an active subscription after the cutover migration | Post-migration `SELECT` (users LEFT JOIN subscriptions) |
| Plan catalogue manageable without deploy | Admin creates a plan, edits its price + a limit, and archives a plan — all via UI | QA manual verification |
| Quota enforcement correctness | Gated action is blocked at limit and allowed below limit, for all 4 metrics | Integration tests + QA |
| Landing page reflects live plans | Editing a public plan in admin changes the landing page with no deploy | QA manual verification |
| Downgrade-block correctness | Downgrade is refused when current usage exceeds the target plan on any metric, and a clear message names the offending metric(s) | Integration tests + QA |
| Coverage on subscription domain + enforcement middleware | > 80 % | Vitest coverage report |
| Plan-page engagement | ≥ 30 % of returning users visit the plan page within 14 days of launch | `plan_viewed` analytics event |

---

## User Stories & Acceptance Criteria

Stories are grouped: **Admin** (plan catalogue + per-user management), **User** (self-serve), **System** (enforcement, landing page, migration).

### Group A — Admin: Plan Catalogue

#### US-SUB-01 — Admin creates a plan

> As an admin, I want to create a new subscription plan with a name, price, and the four limits, so that I can package the product commercially without a code change.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am an admin on the admin Plans page, when I click "New plan", then I see a form with: name, description/summary, price (amount + currency, defaulting to USD), and four limit fields — blogs per month, AI checks per month, author profiles (total), reference extractions per month.
- [ ] AC2: Given I submit the form with a unique name and valid values, then a plan is created and appears in the plan list.
- [ ] AC3: Given I leave a limit field blank, then that limit is saved as **unlimited** (no cap on that metric).
- [ ] AC4: Given I enter a negative number or non-integer in a limit field, or a negative price, then an inline validation error is shown and the plan is not created.
- [ ] AC5: Given I create a plan, then I can choose whether it is **public** (shown on the landing page) or **private** (assignable by admin only, hidden from landing and from the user's self-serve picker). New plans default to private until explicitly published.
- [ ] AC6: Given a plan is created, then it is **not** the default plan and has no subscribers until users move to it.
- [ ] AC7: Given I create a plan, then the action is restricted to `admin` role — a `user`-role request to the create endpoint returns 403.

#### US-SUB-02 — Admin edits a plan's price and limits

> As an admin, I want to change an existing plan's price and limits, so that I can adjust packaging as the product evolves.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given a plan exists, when I edit its name, description, price, any of the four limits, public/private flag, or display order, then the changes are saved and reflected everywhere the plan is shown.
- [ ] AC2: Given I **raise** a plan's limit, then existing subscribers immediately benefit from the higher limit in their current period.
- [ ] AC3: Given I **lower** a plan's limit below a current subscriber's current-period usage, then that subscriber is **grandfathered for the current period** (their existing usage is never deleted and they are not retroactively blocked mid-period); the lower limit applies from their next period reset onward. The edit form shows a warning when a lowered limit affects existing subscribers.
- [ ] AC4: Given a plan has subscribers, then I cannot change its `slug` / stable identifier (name and display fields are editable; the stable identifier is immutable once created).
- [ ] AC5: Given I edit a plan, then the change is restricted to `admin` role (403 for `user`).
- [ ] AC6: Given I edit a public plan, then the landing page reflects the change with no deploy (next page load / within the plan-cache TTL).

#### US-SUB-03 — Admin archives a plan

> As an admin, I want to archive a plan that is no longer offered, so that it stops being advertised and cannot be newly subscribed to, without breaking history.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given a plan has **zero active subscribers**, when I archive it, then it disappears from the landing page and from the user self-serve picker, and can no longer be subscribed to.
- [ ] AC2: Given a plan has **one or more active subscribers**, when I try to archive it, then the action is refused with a message telling me to move those subscribers to another plan first.
- [ ] AC3: Given a plan is the **default** plan, when I try to archive it, then the action is refused — I must first designate a different plan as default.
- [ ] AC4: Given a plan is archived, then it is soft-deleted (retained in the database for referential history), not hard-deleted.
- [ ] AC5: Given exactly one plan must be the default at all times, when I designate a different plan as default, then the previous default loses the flag and existing subscribers are **not** moved.

### Group B — Admin: Per-User Subscription Management

#### US-SUB-04 — Admin views and changes a user's subscription

> As an admin, I want to see any user's current plan and usage and move them to a different plan, so that I can support and manage individual accounts.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am viewing a user in the admin user-detail page, then I see their current plan, the plan's four limits, and their current-period usage against each limit.
- [ ] AC2: Given I select a different plan for the user and confirm, then the user's active subscription is updated to the new plan, and the change is attributed to me (recorded as an admin-initiated change, not self-serve).
- [ ] AC3: Given I move a user to a plan whose limits are **below** the user's current usage, then I see a warning naming the offending metric(s), but I **can** override and confirm — the admin override is permitted (the user is grandfathered for the current period exactly as in US-SUB-02 AC3).
- [ ] AC4: Given I change a user's plan, then it takes effect immediately — no payment step, no approval step.
- [ ] AC5: Given this is an admin-only capability, then a `user`-role request to the endpoint returns 403, and a user can never assign *themselves* an arbitrary plan through this endpoint.
- [ ] AC6: Given a user is deactivated, then their subscription is left intact (untouched) and admin plan-change controls for that user are disabled.

### Group C — User: Self-Serve

#### US-SUB-05 — User views their plan and usage

> As a user, I want to see my current plan and how much of my monthly allowance I have used, so that I know where I stand.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am a signed-in user, then I can reach a "Plan & Usage" page from the account menu / dashboard account widget.
- [ ] AC2: Given I am on the Plan & Usage page, then I see my current plan's name, price, and all four limits.
- [ ] AC3: Given I am on the Plan & Usage page, then I see my **current-period usage** for each metered limit (blogs created this period, AI checks this period, reference extractions this period) and my **standing count** for author profiles, each shown against its limit (e.g. "2 of 3 blogs this month", "1 of 1 author profile").
- [ ] AC4: Given a limit is unlimited on my plan, then it is shown as "Unlimited" rather than a number.
- [ ] AC5: Given the current usage period, then the page shows when the monthly counters reset.
- [ ] AC6: Given a `plan_viewed` analytics event, then it fires when the page loads.

#### US-SUB-06 — User upgrades their plan

> As a user, I want to upgrade to a higher plan myself, so that I can lift my limits immediately.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I am on the Plan & Usage page, then I see the other available **public** plans I can switch to, with their prices and limits.
- [ ] AC2: Given I select a plan whose limits are all **greater than or equal to** my current plan's limits and confirm, then my subscription is updated immediately and my new limits apply at once.
- [ ] AC3: Given price is display-only in v1, then upgrading does **not** present a payment step — it is instant and free, and the UI makes clear that billing is not yet enabled (preview state).
- [ ] AC4: Given I upgrade, then a `plan_changed` analytics event fires with the from-plan and to-plan.
- [ ] AC5: Given I upgrade, then my current-period usage counts carry over unchanged (an upgrade never resets usage).

#### US-SUB-07 — User downgrades their plan

> As a user, I want to downgrade to a lower plan myself, so that I can move to a cheaper tier when I do not need the higher limits.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given I select a lower plan and my current-period usage is **within** every limit of the target plan, when I confirm, then my subscription is updated immediately to the lower plan.
- [ ] AC2: Given I select a lower plan and my current usage **exceeds** the target plan on one or more metrics, when I confirm, then the downgrade is **refused** (HTTP 409) and I see a clear message naming each offending metric and showing my current usage vs the target limit (e.g. "You have 7 author profiles; the Free plan allows 1. Delete 6 to switch.").
- [ ] AC3: Given a downgrade is refused for an over-limit metered metric (blogs / AI checks / reference extractions), then the message explains I can either wait for my usage period to reset or reduce the underlying items, after which the downgrade will succeed.
- [ ] AC4: Given a downgrade succeeds, then a `plan_changed` analytics event fires with from-plan and to-plan.
- [ ] AC5: Given a downgrade succeeds, then my current-period usage counts carry over unchanged (a downgrade never resets usage; the new, lower limits simply apply).

### Group D — System: Enforcement, Landing Page, Migration

#### US-SUB-08 — Quota enforcement on gated actions

> As the platform, I want to enforce the active plan's limits on the four metered actions, so that usage stays within the commercial structure.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given a user at or above their **blog** limit for the current period, when they attempt to create a blog, then the request is refused (HTTP 402 Payment Required / 403 with a typed `QUOTA_EXCEEDED` error code) and the response names the metric, the limit, and the current usage.
- [ ] AC2: Given a user at or above their **AI check** limit for the current period, when they attempt to run an AI authenticity check, then the request is refused with the same typed error shape.
- [ ] AC3: Given a user at or above their **author profile** limit (standing total), when they attempt to create a custom author profile, then the request is refused with the same typed error shape.
- [ ] AC4: Given a user at or above their **reference extraction** limit for the current period, when they attempt a reference extraction, then the request is refused with the same typed error shape.
- [ ] AC5: Given a user **below** a limit, then the corresponding action proceeds normally with no added user-visible friction.
- [ ] AC6: Given a limit is **unlimited** on the user's plan, then that action is never blocked by quota.
- [ ] AC7: Given a quota block occurs, then the frontend surfaces an upgrade prompt that links to the Plan & Usage page, and a `quota_blocked` analytics event fires naming the metric.
- [ ] AC8: Given enforcement happens server-side, then it cannot be bypassed by a crafted client request — every gated handler checks the quota before performing the action.
- [ ] AC9: Given a limit value is the inclusive maximum, then a user with N blogs and a limit of N is blocked from creating blog N+1 (limit means "up to and including N").

#### US-SUB-09 — Landing page shows live plans

> As a public visitor, I want the landing page pricing section to show the real, current plans, so that what I see matches what I get.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given the landing page pricing section, then it renders the **public, non-archived** plans from the database (via a public, unauthenticated endpoint), ordered by the admin-set display order.
- [ ] AC2: Given a plan's price and limits, then they are shown on its landing card, derived from the live plan data — not from hardcoded copy.
- [ ] AC3: Given the existing static `pricing` block in `frontend/src/landing/content.ts`, then it is removed (or reduced to section heading/subtitle/disclaimer copy only) — plan cards no longer come from static content.
- [ ] AC4: Given billing is display-only, then the existing preview disclaimer copy is retained or adapted so visitors understand paid features are free during the preview.
- [ ] AC5: Given the public plans endpoint, then it never exposes private or archived plans and requires no authentication.
- [ ] AC6: Given the landing page is statically pre-rendered (per #118 / AgDR-0033), then the plan data is fetched at runtime on the client (or the prerender step is updated) so the published page is not frozen with stale plan data — exact approach deferred to technical design.

#### US-SUB-10 — Migration: schema, seed plans, backfill existing users

> As the platform, I want the subscription tables created, three plans seeded, and every existing user placed on Free, so that the feature has a correct starting state with no orphaned users.

**Priority**: Must Have

**Acceptance Criteria**:

- [ ] AC1: Given the migration runs, then the `plans` and `subscriptions` tables are created (exact schema in the technical design).
- [ ] AC2: Given the migration runs, then **three** plans are seeded — **Free** (default, public), **Pro** (public), **Team** (public) — with the proposed starting values in the table below (all admin-editable afterwards).
- [ ] AC3: Given the migration runs, then **every** existing `users` row gets an `active` subscription on the **Free** plan.
- [ ] AC4: Given the migration completes, then a verification query confirms zero users without an active subscription.
- [ ] AC5: Given a **new** user registers after this ships, then they are automatically given an `active` subscription on the current **default** plan (mechanism — DB trigger vs. registration-handler code — decided in the technical design).
- [ ] AC6: Given the migration touches migration-path files, then it follows the ApexYard migration gate — a labelled migration ticket plus a migration AgDR covering rollback, downtime, consumers, and observability — produced via the `/migration` skill before any migration file is edited.
- [ ] AC7: Given the cutover, then it is reversible — the AgDR documents the rollback (drop the two tables; no existing table is destructively altered — only additive FKs/columns, if any).

**Proposed seed plan values** (starting point — admin edits all of these post-launch):

| Plan | Price (display-only) | Blogs / month | AI checks / month | Author profiles (total) | Reference extractions / month | Public | Default |
|------|----------------------|---------------|-------------------|-------------------------|-------------------------------|--------|---------|
| Free | $0 / mo | 3 | 5 | 1 | 10 | Yes | **Yes** |
| Pro  | $19 / mo | 50 | 200 | 10 | 300 | Yes | No |
| Team | $99 / mo | Unlimited | Unlimited | 50 | Unlimited | Yes | No |

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User's current-period usage exactly equals their limit | Action is blocked (limit is the inclusive maximum — see US-SUB-08 AC9). |
| User downgrades, then the period rolls over | New, lower limits apply; the new period's counters start at zero (counted from the new period start). |
| User upgrades mid-period | Higher limits apply immediately; current-period usage carries over (not reset). |
| Admin lowers a plan's limit below an existing subscriber's current usage | Subscriber grandfathered for the current period; lower limit applies from their next period reset (US-SUB-02 AC3). |
| Admin moves a user to a plan below their usage | Allowed with a warning + explicit confirm (admin override); user grandfathered for the current period (US-SUB-04 AC3). |
| Admin tries to archive a plan with active subscribers | Refused — must move subscribers first (US-SUB-03 AC2). |
| Admin tries to archive the default plan | Refused — must designate a new default first (US-SUB-03 AC3). |
| New user registers after launch | Auto-subscribed to the current default plan (US-SUB-10 AC5). |
| Deactivated user | Subscription left intact; quota checks are moot (user can't act); admin plan controls disabled for that user. |
| A blog / profile / reference is deleted after being created this period | For the **monthly creation quotas** (blogs, AI checks, reference extractions), v1 counts live rows by `created_at` within the period, so deleting an item frees a slot in the current period — this is acceptable and gives users a clear path to fit a downgrade. For **author profiles** (standing total cap) deleting a profile likewise frees a slot. (If a strict "creation events are permanent" model is wanted later, a dedicated usage-counter table is the upgrade path — flagged in the technical design.) |
| Two requests race the same last quota slot | Server-side enforcement; a small transient over-count is acceptable in v1, or guarded with a transactional check — decided in technical design. |
| Plan has an unlimited limit | That metric is never enforced for subscribers of that plan; shown as "Unlimited" in all UIs. |
| User has no subscription row (data integrity failure) | Treated as a hard error, not as "unlimited" — the user is treated as having no entitlement and the gated action is blocked with a "contact support" message; monitoring alerts on any such row (should never happen given US-SUB-10). |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-1 | `plans` catalogue with name, stable slug, description, price (amount + currency), four limits, public flag, default flag, archived flag, display order | Must | Limit columns nullable; NULL = unlimited |
| FR-2 | `subscriptions` — one active subscription per user, FK to user + plan, `status` enum, current-period start/end, nullable `stripe_subscription_id`, attribution of last change (self vs admin) | Must | Stripe seam — see Technical Notes |
| FR-3 | Admin plan CRUD endpoints — create, edit, archive, set-default — all `admin`-gated | Must | US-SUB-01/02/03 |
| FR-4 | Admin per-user subscription endpoints — view a user's plan + usage, change a user's plan (with override) — `admin`-gated | Must | US-SUB-04 |
| FR-5 | User self-serve endpoints — get my plan + usage, change my plan (upgrade/downgrade with downgrade-block) | Must | US-SUB-05/06/07 |
| FR-6 | Public, unauthenticated endpoint returning public + non-archived plans | Must | US-SUB-09 |
| FR-7 | Quota-enforcement check on the four gated actions — blog create, AI check, author profile create, reference extraction | Must | US-SUB-08 — server-side, typed `QUOTA_EXCEEDED` error |
| FR-8 | Current-period usage computation — monthly window for blogs / AI checks / reference extractions; standing total for author profiles | Must | Period boundary — see OQ-2 |
| FR-9 | Migration — create tables, seed 3 plans, backfill all existing users to Free, verification query | Must | US-SUB-10 — migration gate applies |
| FR-10 | New-user auto-subscription to the default plan | Must | US-SUB-10 AC5 |
| FR-11 | Landing `Pricing.tsx` rebound to the live public-plans endpoint; static `pricing.tiers` removed from `content.ts` | Must | US-SUB-09 |
| FR-12 | Admin Plans UI — list, create/edit form, archive, set-default | Must | Under `frontend/src/pages/admin/` |
| FR-13 | User "Plan & Usage" page — current plan, usage bars, upgrade/downgrade picker | Must | Reachable from account menu / dashboard widget |
| FR-14 | Quota-block UX — when a gated action returns `QUOTA_EXCEEDED`, surface an upgrade prompt linking to the Plan & Usage page | Must | US-SUB-08 AC7 |
| FR-15 | Analytics events — `plan_viewed`, `plan_changed` (from/to), `quota_blocked` (metric), `admin_plan_created`, `admin_plan_edited`, `admin_user_plan_changed` | Should | Aligns with #118/#119 analytics conventions |
| FR-16 | Dashboard account widget bound to real plan data | Should | Coordinate with #119 — see Dependencies |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | Quota check added to a gated action | < 50 ms added latency (p95); single indexed query or cached subscription lookup |
| Performance | Public plans endpoint | Cacheable; landing page paint not regressed beyond #118's budget |
| Security | All admin plan + per-user endpoints | `requireAuth` + `requireAdmin`; a `user` role gets 403 |
| Security | Self-serve plan change | A user can only change **their own** subscription and only to a non-archived, public plan; cannot self-assign private plans or bypass the downgrade-block |
| Security | Enforcement | Quota checks are server-side only; never trust a client-supplied usage count |
| Accessibility | Plan cards, usage bars, plan-picker, admin forms | WCAG 2.1 AA — usage bars have text equivalents, forms are labelled, focus states visible |
| Reliability | No orphaned users | A DB constraint or migration guarantee that every user has exactly one active subscription; monitoring alerts otherwise |
| Testability | Subscription domain + enforcement middleware | > 80 % unit + integration coverage |

---

## Design

### User Flow — Self-Serve Plan Change

```
[User on dashboard]
    |
    v
[Opens account menu -> "Plan & Usage"]      ---> plan_viewed event
    |
    v
[Sees current plan + current-period usage vs each limit]
    |
    v
[Picks a different public plan -> "Switch"]
    |
    +--> [Target plan limits >= current usage on all metrics]
    |        |
    |        v
    |     [Subscription updated immediately]  ---> plan_changed event
    |        |
    |        v
    |     [New limits apply; usage carried over]
    |
    +--> [Target plan limit < current usage on >=1 metric]
             |
             v
          [409 - downgrade refused]
             |
             v
          [Message names offending metric(s): usage vs target limit]
             |
             v
          [User reduces items or waits for period reset, retries]
```

### User Flow — Quota Enforcement

```
[User triggers a gated action: create blog / run AI check / create profile / extract reference]
    |
    v
[Server resolves active subscription -> plan limits]
    |
    v
[Server computes current usage for that metric]
    |
    +--> [usage < limit  OR  limit is unlimited]
    |        |
    |        v
    |     [Action proceeds normally]
    |
    +--> [usage >= limit]
             |
             v
          [402/403 QUOTA_EXCEEDED { metric, limit, usage }]
             |
             v
          [Frontend shows upgrade prompt -> link to Plan & Usage]  ---> quota_blocked event
```

### Admin Flow — Plan Management

```
[Admin] -> [Admin > Plans] -> [list of plans: name, price, 4 limits, public/default/archived badges]
    |
    +--> [New plan]   -> form -> create (defaults to private)
    +--> [Edit plan]  -> form -> save (warns if a lowered limit affects subscribers)
    +--> [Archive]    -> refused if subscribers exist or plan is default
    +--> [Set default]-> previous default loses flag; existing subscribers not moved
```

### Wireframes / Mockups

Not yet produced. UI surfaces touched: a new **Admin > Plans** page + plan form; a new user **Plan & Usage** page; the landing **Pricing** section (data-source change, layout largely unchanged); the **dashboard account widget** (bind to real data); a **quota-block prompt** component. Design review is required on the user-facing surfaces (landing, Plan & Usage page, quota prompt) before those PRs merge — `require-design-review-for-ui.sh` gate applies. UX/UI designer to produce mockups in the Design phase.

---

## Technical Notes

> Implementation-level decisions (exact schema, JSONB-limits-vs-columns, period-tracking mechanism, new-user-subscription trigger vs. handler, prerender vs. runtime fetch for landing) are **deferred to the technical design** in the Design phase and to AgDRs. This section captures only the shape and the constraints the PRD commits to.

### Entities (shape, not final schema)

- **`plans`** — `id`, `slug` (immutable once subscribers exist), `name`, `description`, `price_cents`, `currency`, `billing_period` (`monthly` only in v1), four limit fields (nullable — NULL = unlimited), `is_public`, `is_default` (exactly one true), `archived_at` (soft delete), `sort_order`, timestamps.
- **`subscriptions`** — `id`, `user_id` (FK → `users.id`, unique active per user), `plan_id` (FK → `plans.id`), `status` (`active` only in v1; enum reserves `past_due` / `canceled` for Stripe), `current_period_start`, `current_period_end`, `stripe_subscription_id` (nullable — the Stripe seam), `changed_by` (nullable admin `user_id`; NULL = self-serve), timestamps.

### Usage computation

- Monthly metrics (blogs, AI checks, reference extractions): count live rows by `created_at` within `[current_period_start, current_period_end)`. No new counter table in v1 — flagged as the upgrade path if a strict "creation events are permanent" model is needed later.
- Author profiles: standing count of live non-predefined `author_profiles` rows for the user.
- Enforcement reads period bounds from the `subscriptions` row (not computed ad hoc) so the same code path works when Stripe later drives anniversary-based periods.

### Stripe seam (v1 builds the seam, not the integration)

- `price_cents` + `currency` exist now, display-only.
- `subscriptions.status` is an enum with `active` as the only v1 value; `past_due` / `canceled` reserved.
- `subscriptions.stripe_subscription_id` exists, nullable, unused in v1.
- `current_period_start` / `current_period_end` exist now (set to calendar-month bounds in v1 — see OQ-2); later driven by Stripe webhook data.
- Plan-switch logic is a single service function; v1 applies the change directly, the Stripe epic inserts a checkout step ahead of it.

### Dependencies

| Dependency | Type | Status | Owner / Notes |
|------------|------|--------|---------------|
| EP-04 auth — `users` table, roles, `requireAuth`/`requireAdmin`, admin panel | Internal | **Ready** (shipped, #95) | Foundation for all role-gated endpoints |
| Landing page epic (#118) — owns `Pricing.tsx`, `content.ts`, prerender step (AgDR-0033) | Internal | **In flight** | This epic changes `Pricing.tsx`'s data source — file-level coordination needed |
| Dashboard epic (#119) — account widget references a user "plan" | Internal | **In flight** | This epic provides the real plan data the widget binds to — coordinate the contract |
| `getUserUsage` admin endpoint | Internal | Ready | Extend to also return plan + limits + period usage |
| Migration tooling (`backend/src/db/migrations/`, numbered SQL, `migrate.ts`) | Internal | Ready | New migration follows the existing numbered convention |
| `/migration` skill + migration AgDR | Process | Required | Migration gate (3a) — must run before editing migration files |

### Technical Constraints

- New migration must follow the existing numbered SQL convention (`migrate-0NN-*.sql`) and be additive — no destructive change to existing tables.
- Quota enforcement should be a shared, testable unit (middleware or service helper), not duplicated inline in four handlers.
- The landing page is statically pre-rendered (#118 / AgDR-0033) — the live-plans data must reach the published page without a deploy; runtime client fetch vs. updated prerender step is a technical-design call (US-SUB-09 AC6).
- `#118` and `#119` are in flight and touch `Pricing.tsx`, `content.ts`, and the dashboard account widget — sequence this epic's PRs to land after or in coordination with those, to minimise merge conflicts.

---

## Launch Plan

### Rollout Strategy

- [x] **All users at once.** The cutover migration places every existing user on Free. Because billing is display-only and Free's limits are generous enough not to disrupt current behaviour for typical users, a phased rollout adds little. The risk surface is the migration itself (covered by the migration AgDR) and the enforcement turning on.
- Enforcement (US-SUB-08) is the one behaviour change existing users will feel. Recommend: ship schema + seed + backfill + admin + user + landing first; turn on **enforcement last** as its own PR, so it can be verified in isolation and rolled back independently if it misfires. Final sequencing is the Tech Lead's call in the technical design.
- Monitor for 24–48 h after enforcement goes live: `quota_blocked` event volume, any "no subscription row" errors, blog/AI-check error rates.

---

## Open Questions

| # | Question | Owner | Status | Resolution |
|---|----------|-------|--------|------------|
| OQ-1 | Epic numbering — `EP-05` is already used in the workspace for "Smart Reference Intelligence". Should this epic get a formal `EP-NN` number, or just use its GitHub issue number as the canonical reference (the dominant pattern for `prd-dashboard` / `prd-landing-page` / `prd-ai-detector`)? PRD currently assumes the latter. | Head of Product | Open | |
| OQ-2 | Monthly usage period boundary — calendar month (UTC) for all subscribers, or per-subscriber anniversary? PRD assumes **calendar month UTC** for v1 (simplest; `current_period_start/end` columns make the anniversary model a later change). Confirm. | Head of Product / Tech Lead | Open | Assumed: calendar month UTC |
| OQ-3 | Proposed seed values (Free 3 / Pro 50 / Team unlimited blogs, etc.) — acceptable as launch defaults, or different starting numbers? All are admin-editable post-launch regardless. | Head of Product | Open | |
| OQ-4 | Should the dashboard account widget binding (FR-16) be in this epic or handed to the #119 team? PRD lists it as **Should**; recommend a thin contract handoff to #119 if #119 is still open when this reaches Build. | Product Manager / Tech Lead | Open | |
| OQ-5 | Quota-block HTTP status — `402 Payment Required` (semantically apt, signals "upgrade") vs `403 Forbidden` (more conventional). PRD uses a typed `QUOTA_EXCEEDED` error code regardless; the status code is a technical-design call. | Tech Lead | Open | |

---

## Timeline

| Milestone | Target Date | Status |
|-----------|-------------|--------|
| PRD Approved | 2026-05-16 | Pending |
| Technical Design Approved | 2026-05-20 | Pending |
| Epic + story tickets created | 2026-05-20 | Pending |
| Dev Complete | 2026-05-30 | Pending |
| QA Complete | 2026-06-03 | Pending |
| Launch | 2026-06-05 | Pending |

_Dates are PM placeholders pending Engineering estimation (the PM role cannot commit delivery dates without Engineering input — see role definition)._

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser (via ApexYard agent) | 2026-05-14 | Author |
| Head of Product | Mohamed Naser | 2026-05-14 | Approved |
| Tech Lead | Mohamed Naser | 2026-05-14 | Approved |
| Head of Design | | | Pending (UI surfaces — design review at PR time) |
