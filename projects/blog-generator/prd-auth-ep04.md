# PRD: EP-04 — Authentication, Roles & User-Scoped Data

**Status**: Draft
**Author**: Mohamed Naser (Product Manager via ApexYard agent)
**Created**: 2026-05-04
**Last Updated**: 2026-05-04
**Supersedes**: EP-04 placeholder section in the master `PRD.md` for this project (US-01 and US-02 ACs are inherited and refined here).
**Related tech designs**: `technical-design-ep01.md` (placeholder `requireAuth` middleware) and `technical-design-user-context.md` (EP-04-ready schema; the latter lives on a parallel branch and is not yet on the fork's trunk — hence no relative link).

---

## Overview

### Problem Statement

The product has shipped EP-01 through EP-03 with a single hardcoded "dev user" UUID (`00000000-0000-0000-0000-000000000001`) baked into every `blogs.user_id`, `author_profiles.user_id`, and downstream row. Real users cannot sign up, cannot recover lost access, and cannot be separated from one another — every visitor today shares the same dataset. To open the product to real users, we need email/password accounts, email verification, password reset, two roles (`admin`, `user`), and a one-time cutover that adopts the existing dev data under the first admin so no work is lost.

### Target Users

**Primary — User**: A content marketer / SEO professional / founder who wants to register, verify their email, and start generating blogs scoped to their own account.
**Secondary — Admin**: An operator (initially Mohamed Naser) who can manage other users, manage the predefined author-profile templates, audit all blogs, and promote/demote other admins.

### Goals

1. Replace the placeholder dev-user UUID with a real `auth.users.id` (Supabase Auth) on every owned row, with zero data loss for existing dev content.
2. Ship a complete email-driven account lifecycle (register → verify → login → forgot → reset → logout) using Supabase Auth, with Mailtrap as the SMTP provider.
3. Enforce role-based access (`admin` vs `user`) at the API layer for every protected endpoint and every admin-only action.
4. Soft-gate blog creation on verified-email status so unverified users can browse but not produce content.
5. Make the first admin (designated via migration) inherit every pre-cutover blog and custom author profile.
6. Achieve > 80 % unit + integration coverage on auth domain code and the role-enforcement middleware.

### Non-Goals (Out of Scope)

- **OAuth / SSO providers** (Google, GitHub, magic-link). Email/password only in v1.
- **Multi-factor authentication.** Deferred — added once we have a critical-mass user base.
- **Per-organisation / multi-tenant** workspaces. Single-tier user model only — admin is *operator* of the platform, not "admin of a workspace".
- **Account deletion / data-export self-service (GDPR DSAR).** Admins can deactivate; full self-service deletion is a separate feature (compliance work).
- **Rate-limiting / brute-force protection beyond Supabase defaults.** Tracked separately if abuse appears.
- **User-facing audit log.** Admins see all blogs read-only; structured audit logging is out of scope for v1.
- **Email-change flow.** Users cannot change their registered email in v1; admin can re-issue an account with a new email if needed.

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Registration → first-login conversion | ≥ 70 % within 24h | Supabase auth events |
| Email verification rate | ≥ 60 % within 7 days of registration | Supabase auth events |
| Forgot-password completion rate | ≥ 50 % of initiated resets | Token-redemption tracking |
| Auth-related production errors per 1 000 sessions | ≤ 5 | Backend error logs |
| Coverage on auth domain + middleware | > 80 % | Vitest coverage report |
| Cutover migration outcome | 0 placeholder rows remain in production after the cutover migration | Post-migration query |

---

## User Stories & Acceptance Criteria

### US-AUTH-01 — Registration

> As a new visitor, I want to register an account using my email and password, so that I can start using the product under my own identity.

**Priority**: Must Have · **Refines master PRD US-01**

**Acceptance Criteria**:

- [ ] AC1: Given I am on `/register`, when I submit a valid email and password (≥ 8 characters), then a Supabase `auth.users` record is created and a verification email is sent via Mailtrap.
- [ ] AC2: Given I submit an email already registered, then an inline error is shown: *"An account with this email already exists. Try logging in or resetting your password."* — I am **not** told whether the email is verified (information-disclosure prevention).
- [ ] AC3: Given my password is shorter than 8 characters, then an inline validation error is shown before submission.
- [ ] AC4: Given registration succeeds, then I am redirected to a *"Check your email"* page that explains verification is required to create blogs (soft-gate language).
- [ ] AC5: Given any required field is empty, then the form is not submitted and missing fields are highlighted.
- [ ] AC6: Given I register, then a row exists in our application `users` profile table (FK to `auth.users.id`) with default role `user` and `email_verified_at = NULL`.
- [ ] AC7: Given I register, then a `Mailtrap inbox` (dev/test) or a real email (prod) is received containing the verification link with a token that expires in 24 hours.

---

### US-AUTH-02 — Email Verification

> As a registered user, I want to click the verification link in my email, so that my account becomes fully active and I can start creating blogs.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I click the verification link with a valid, unexpired token, then `auth.users.email_confirmed_at` is set, our application `users.email_verified_at` is mirrored, and I am redirected to the dashboard with a success toast.
- [ ] AC2: Given the token has expired (> 24 h), then I see an *"Verification link expired"* page with a *"Resend verification email"* button.
- [ ] AC3: Given I click *"Resend verification email"* while logged in (or after entering my email), then a new verification email is sent and any prior unredeemed token is invalidated.
- [ ] AC4: Given I click a verification link for an account that is already verified, then I am redirected to the dashboard with a *"Already verified"* toast (no error).
- [ ] AC5: Given the token is malformed or unknown, then a generic *"Invalid verification link"* page is shown — no information about whether the email exists.

---

### US-AUTH-03 — Login

> As a registered user, I want to log in with my email and password, so that I can access my dashboard and previously generated blogs.

**Priority**: Must Have · **Refines master PRD US-02**

**Acceptance Criteria**:

- [ ] AC1: Given I submit valid credentials, then I am authenticated via Supabase and redirected to my dashboard. The Supabase session JWT is stored client-side via `@supabase/supabase-js` (default storage). The "Remember me" toggle controls Supabase's session persistence option (default 30-day refresh).
- [ ] AC2: Given my credentials are wrong, then a generic error is shown: *"Invalid email or password"* — I am not told which field is wrong (information-disclosure prevention).
- [ ] AC3: Given my email is **not** verified, then I am still allowed to log in (soft gate). The dashboard banner explains *"Verify your email to start creating blogs"* with a *"Resend verification email"* link.
- [ ] AC4: Given my session JWT expires, then the next API call returns 401, the frontend redirects to `/login` with a *"Session expired — please log in again"* notice.
- [ ] AC5: Given the *"Forgot password?"* link is on the login page, then it routes to the password-reset request flow.
- [ ] AC6: Given my account has been deactivated by an admin (`users.deactivated_at IS NOT NULL`), then login fails with *"This account has been deactivated. Please contact support."*

---

### US-AUTH-04 — Forgot Password (Request Reset)

> As a user who has forgotten their password, I want to enter my email and receive a reset link, so that I can regain access to my account.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I submit my email on `/forgot-password`, then a reset email is sent via Mailtrap **regardless of whether the email is registered** (timing-safe, no enumeration).
- [ ] AC2: Given my email is registered, then the email contains a reset link with a token that expires in 1 hour.
- [ ] AC3: Given my email is **not** registered, then no reset email is sent but the user-facing response is identical to AC1 (*"If an account exists for that email, a reset link has been sent"*).
- [ ] AC4: Given I request a reset multiple times in quick succession (≥ 3 in 5 minutes), then the rate limit returns the same generic response (no enumeration via timing).

---

### US-AUTH-05 — Reset Password (Complete Reset)

> As a user with a valid reset link, I want to set a new password, so that I can log in again.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I click the reset link with a valid, unexpired token, then I see a *"Set new password"* form requiring the new password and a confirmation field.
- [ ] AC2: Given my new password is ≥ 8 characters and the confirmation matches, then the password is updated via Supabase, the reset token is consumed (single-use), and **all existing sessions for that user are revoked**.
- [ ] AC3: Given the token is expired or already used, then a *"This reset link is no longer valid"* page is shown with a link back to *"Forgot password"*.
- [ ] AC4: Given the new password equals the previous one (when detectable), then submission still succeeds — no password-history check in v1.
- [ ] AC5: Given the reset succeeds, then the user is redirected to `/login` with a *"Password updated — please log in"* toast.

---

### US-AUTH-06 — Logout

> As a logged-in user, I want to log out, so that my session is invalidated on this device.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I click *"Log out"*, then the Supabase session is signed out client-side and the next protected route returns 401.
- [ ] AC2: Given I log out, then I am redirected to `/login` with a *"Logged out"* toast.
- [ ] AC3: Logout does not affect other devices' sessions (per-device only, by design).

---

### US-AUTH-07 — Soft Gate: Verified Email Required to Create Blogs

> As an unverified user, I want to log in and explore the app, but not create blogs until I verify my email, so that the platform discourages drive-by registrations without locking me out entirely.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I am logged in but `users.email_verified_at IS NULL`, then a persistent banner on the dashboard reads *"Verify your email to start creating blogs"* with a *"Resend verification email"* action.
- [ ] AC2: Given I click *"New Blog"* while unverified, then the action is blocked client-side with the same prompt; the backend `POST /api/blogs` also returns `403 EMAIL_NOT_VERIFIED` as a defence-in-depth check.
- [ ] AC3: Given I am unverified, then I **can** still browse predefined author profiles and read documentation pages; only blog creation and brief submission are blocked.
- [ ] AC4: Given I verify my email after registration, then the banner disappears on next page load and `POST /api/blogs` succeeds.

---

### US-AUTH-08 — Admin: Manage Users

> As an admin, I want to list, deactivate, and force-reset other users, so that I can operate the platform.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I am an admin, when I navigate to `/admin/users`, then I see a paginated table of all users with: email, role, verified-status, created-at, last-login, deactivated-status.
- [ ] AC2: Given I am an admin, when I click *"Deactivate"* on a user, then `users.deactivated_at = NOW()`; the user can no longer log in (per US-AUTH-03 AC6).
- [ ] AC3: Given I am an admin, when I click *"Force password reset"* on a user, then a reset email is sent to that user's email and all of their sessions are revoked.
- [ ] AC4: Given I am a regular user, when I attempt to access any `/api/admin/*` endpoint, then the API returns `403 FORBIDDEN` and the UI hides admin entry points entirely.
- [ ] AC5: Given I am an admin, I **cannot** deactivate or demote myself if I am the *only* admin remaining (last-admin protection — see US-AUTH-11 AC4).

---

### US-AUTH-09 — Admin: Manage Predefined Author Profiles

> As an admin, I want to edit, add, or remove the predefined author profiles, so that I can curate the templates shown to all users.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I am an admin, when I navigate to `/admin/profiles`, then I see all `author_profiles WHERE is_predefined = true` (the four seeded profiles) with edit + delete actions.
- [ ] AC2: Given I edit a predefined profile and save, then the row is updated in place (no clone); no existing user-cloned profiles are retroactively affected.
- [ ] AC3: Given I add a new predefined profile, then it becomes immediately available in the ProfileWizard for new users.
- [ ] AC4: Given I delete a predefined profile that has been *cloned* by users, the user-owned clones are unaffected (they have their own row); the predefined template just disappears from the wizard.
- [ ] AC5: Given a regular user attempts `PUT /api/profiles/:id` on a predefined profile, the existing `403 PREDEFINED_READONLY` response (from the user-context tech design) is preserved unchanged.

---

### US-AUTH-10 — Admin: View All Blogs (Read-Only Audit)

> As an admin, I want to read every user's blogs, so that I can investigate quality issues, abuse reports, or support tickets.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I am an admin, when I navigate to `/admin/blogs`, then I see all blogs across all users with: blog title, owner email, status, current step, created-at, updated-at.
- [ ] AC2: Given I open a specific blog from the admin view, then I see the full read-only blog content (brief, alignment, outline, draft, etc.).
- [ ] AC3: Given I am an admin viewing another user's blog, then I **cannot** edit, regenerate, or delete it (read-only enforced server-side).
- [ ] AC4: Given a regular user attempts to access another user's blog by direct URL, then the existing user-scoping check (`blog.user_id !== req.user.id`) returns `403 FORBIDDEN` unchanged.

---

### US-AUTH-11 — Admin: Promote / Demote Other Users

> As an admin, I want to promote another user to admin or demote an admin to user, so that I can grow or shrink the operator team.

**Priority**: Must Have · **NEW**

**Acceptance Criteria**:

- [ ] AC1: Given I am an admin, when I click *"Promote to admin"* on a user row, then `users.role = 'admin'` and the change takes effect on that user's next API call.
- [ ] AC2: Given I am an admin, when I click *"Demote to user"* on another admin, then `users.role = 'user'`.
- [ ] AC3: Given I am an admin, I cannot demote myself directly via the UI (defence in depth) — I must ask another admin to demote me.
- [ ] AC4: Given I am the **only** admin remaining, then both *"Demote to user"* on me and *"Deactivate"* on me are disabled with the tooltip *"At least one admin must remain. Promote another user first."* — backend also enforces `409 LAST_ADMIN`.

---

### US-AUTH-12 — Cutover: Adopt Existing Dev Data Under First Admin

> As the first admin (Mohamed Naser), I want all pre-cutover blogs and custom author profiles to appear in my account on first login, so that no existing work is lost.

**Priority**: Must Have · **NEW** · **Migration ticket required**

**Acceptance Criteria**:

- [ ] AC1: Given the cutover migration runs, then a `users` table is created (FK to `auth.users.id`, `role`, `email_verified_at`, `deactivated_at`, timestamps).
- [ ] AC2: Given the migration runs, then all `blogs.user_id = '00000000-0000-0000-0000-000000000001'` rows are reassigned to the first-admin's real `auth.users.id` via an idempotent `UPDATE`. Same for `author_profiles.user_id` (non-predefined rows only).
- [ ] AC3: Given the migration runs, then a foreign-key constraint is added: `blogs.user_id REFERENCES users.id` (and equivalently for `author_profiles.user_id`).
- [ ] AC4: The cutover is split into (i) a SQL migration that creates the `users` table and adds FKs, and (ii) a TypeScript seeder `scripts/seed-first-admin.ts` that: creates the auth user (`mnaser.tech@gmail.com`) via Supabase Admin API, inserts the corresponding `users` row with `role='admin'` and `email_verified_at=NOW()`, then runs the placeholder-UUID `UPDATE`s. The seeder is idempotent — running it twice is a no-op on second pass. If an auth user with that email already exists, the seeder uses it instead of creating a new one.
- [ ] AC5: Given the migration completes, then a verification query `SELECT COUNT(*) FROM blogs WHERE user_id = '00000000-…-001'` returns 0.
- [ ] AC6: Rollback: the migration AgDR documents how to re-stamp the placeholder UUID and drop the FK if catastrophic data corruption is detected post-cutover.

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User registers with same email twice (race condition) | Second registration sees AC2 generic "already exists" error |
| Verification token used after the email was changed via admin | Treated as expired/invalid (AC2 / AC5 of US-AUTH-02) |
| Password reset link used while account is deactivated | Reset succeeds but login still fails per US-AUTH-03 AC6 |
| Mailtrap delivery fails (SMTP error) | API returns 202 to the user (no information disclosure); the failure is logged for ops; user can re-trigger via "Resend verification" |
| Admin deletes a predefined profile then a user tries to clone it | Clone request returns `404 NOT_FOUND` |
| Admin views their own blog through `/admin/blogs` | Treated as read-only (admin-mode); to edit, they navigate via the normal user dashboard |
| User has stale JWT after admin promoted them | Role promotion takes effect on next API call (JWT carries the user_id, role is read fresh from `users` table per request — no stale-token issue) |
| Cutover migration runs twice | Idempotent — `WHERE user_id = '00000000-…-001'` matches zero rows on second run |
| First-admin auth user does not exist when cutover migration runs | Migration aborts with a clear error; no partial state |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-AUTH-01 | Email/password registration with 8-char min and duplicate-email handling | Must |
| FR-AUTH-02 | Email verification via signed token, 24-hour expiry, resend, idempotent re-click | Must |
| FR-AUTH-03 | Login with Supabase JWT, ambiguous-error wording, deactivated-account check, "Remember me" 30-day | Must |
| FR-AUTH-04 | Forgot-password flow with timing-safe enumeration prevention and rate limiting | Must |
| FR-AUTH-05 | Reset-password flow with single-use 1-hour token and global session revocation | Must |
| FR-AUTH-06 | Per-device logout via Supabase signOut | Must |
| FR-AUTH-07 | Soft gate: `POST /api/blogs` returns 403 if `email_verified_at IS NULL` | Must |
| FR-AUTH-08 | Application `users` table: id (FK→auth.users), role, email_verified_at, deactivated_at, created_at, updated_at | Must |
| FR-AUTH-09 | Role middleware: `requireAuth` validates JWT, `requireAdmin` additionally checks role | Must |
| FR-AUTH-10 | Admin user-management endpoints: list, deactivate, reactivate, force-reset, promote, demote | Must |
| FR-AUTH-11 | Admin profile-management endpoints (CRUD on predefined profiles) | Must |
| FR-AUTH-12 | Admin blog-audit endpoints: list-all-blogs, view-any-blog (read-only) | Must |
| FR-AUTH-13 | Last-admin protection on demote and deactivate (UI + backend) | Must |
| FR-AUTH-14 | One-time cutover migration: create `users`, reassign placeholder rows to first admin, add FKs | Must |
| FR-AUTH-15 | Mailtrap SMTP integration: Sandbox in dev/test, Email API in prod, env-driven | Must |
| FR-AUTH-16 | Existing `requireAuth` placeholder middleware in routes is replaced with the real one (no behavioural drift on EP-01..EP-03 endpoints) | Must |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Security | Password hashing | Supabase default (bcrypt) — not stored by our application |
| Security | Token transport | HTTPS enforced in production |
| Security | Tokens (verify, reset) | Cryptographically random, signed by Supabase, single-use, time-bounded |
| Security | Information disclosure | Auth errors are generic (no enumeration via response shape or timing) |
| Security | Admin-only routes | `requireAdmin` middleware verified on every `/api/admin/*` route |
| Privacy | PII in logs | Email addresses scrubbed from non-error logs; passwords never logged |
| Performance | Login round-trip | ≤ 500 ms p95 (excluding Supabase external) |
| Performance | Verification email delivery | ≤ 30 s end-to-end via Mailtrap in dev (Sandbox) |
| Reliability | SMTP failure handling | Retry once, then surface generic 202 to user; alert ops |
| Reliability | Cutover migration | Idempotent, dry-run-able in staging, rollback documented |
| Coverage | Auth domain + middleware unit/integration tests | > 80 % |
| Accessibility | Auth forms (register, login, forgot, reset) | WCAG 2.1 AA — labels, focus order, error association |

---

## Constraints (Pre-Decided — Recorded for AgDRs)

The following decisions are **already made** by the operator and will be captured as AgDRs during the Tech Design phase rather than re-litigated:

| Decision | Choice | AgDR placeholder |
|----------|--------|------------------|
| Auth provider | **Supabase Auth** (already in stack via `@supabase/supabase-js`) | `AgDR-NNNN-auth-provider-supabase.md` |
| Email transport | **Mailtrap** — Sandbox SMTP in dev/test, Email API in production. Sender: `me@mnaser.me`. | `AgDR-NNNN-email-transport-mailtrap.md` |
| Session storage | **`@supabase/supabase-js` default** (token in localStorage); backend verifies JWT per request | `AgDR-NNNN-session-supabase-js-default.md` |
| Verification gate | **Soft gate** — login allowed; blog creation blocked until verified | `AgDR-NNNN-soft-verification-gate.md` |
| Role model | **Single `role` column** on application `users` table (`'user' \| 'admin'`); not a separate `roles` table | `AgDR-NNNN-role-column-vs-table.md` |
| Existing-data cutover | **Adopt by first admin** via a TypeScript seeder script (`scripts/seed-first-admin.ts`) that creates the auth user via Supabase Admin API, inserts the application `users` row, and UPDATEs all placeholder-UUID rows. SQL migration creates the `users` table + adds FKs; the seeder is the human-runnable side. First admin: `mnaser.tech@gmail.com` (Mohamed Naser). | `AgDR-NNNN-cutover-adopt-by-first-admin.md` |
| Rate limiting | **Supabase Auth defaults** — no application-level overrides in v1 | `AgDR-NNNN-rate-limits-defaults.md` (or rolled into the Supabase-Auth AgDR) |
| Deactivation propagation | **Clean logout on next API call** — backend reads `users.deactivated_at` per request; if set, returns 401 and frontend clears the session | `AgDR-NNNN-deactivation-propagation.md` (or rolled into role-middleware AgDR) |

---

## User Flows

### Registration → Verification → First Blog (Soft Gate)

```
[Visitor]
   |
   v
[/register] -- submit email + password
   |
   v
Supabase auth.users row + application users row (email_verified_at NULL, role='user')
   |
   v
Mailtrap sends verification email (24h token)
   |
   v
[/check-email]  ← user redirected with banner
   |
   |  (user clicks email link)
   v
[/verify?token=...]
   |
   +-- valid token  --> users.email_verified_at = NOW() --> [/dashboard] (success toast)
   +-- expired      --> [Resend verification] page
   +-- already used --> [/dashboard] (already-verified toast)
   +-- malformed    --> [Generic invalid-link page]

   While unverified:
   [/dashboard] -- banner "Verify your email to start creating blogs"
                -- "New Blog" button blocked client-side
                -- POST /api/blogs returns 403 EMAIL_NOT_VERIFIED
```

### Forgot → Reset

```
[/login] -- "Forgot password?" link
   |
   v
[/forgot-password] -- enter email
   |
   v
Always responds 200 + "If account exists, link sent"  (timing-safe)
   |
   v  (only if account exists)
Mailtrap sends reset email (1h token)
   |
   v
[/reset-password?token=...]
   |
   +-- valid token   --> set new password --> revoke all sessions --> [/login] (success toast)
   +-- expired/used  --> [Try again] page back to forgot-password
```

### Admin Promote / Demote (Last-Admin Protection)

```
[/admin/users]
   |
   v
"Demote" or "Deactivate" on a user:
   |
   +-- Target is the only remaining admin?
   |     +-- yes --> button disabled, tooltip "At least one admin must remain"
   |     +-- no  --> action allowed
   |
   +-- Backend re-checks the same invariant (defence in depth) -- 409 LAST_ADMIN if violated
```

### Cutover Migration (One-Time)

```
[Pre-cutover state]                       [Post-cutover state]
- blogs.user_id = '00000000-…-001'        - blogs.user_id = first_admin_auth_uuid
- author_profiles.user_id = '…-001'       - author_profiles.user_id = first_admin_auth_uuid
- No `users` table                        - users table with first admin (role='admin', verified)
- No FK on user_id columns                - blogs.user_id REFERENCES users(id)
                                          - author_profiles.user_id REFERENCES users(id)

Steps:
1. Create users table.
2. Insert first admin row (linked to FIRST_ADMIN_AUTH_USER_ID env var).
3. UPDATE blogs SET user_id = <first_admin_auth_uuid> WHERE user_id = '00000000-…-001'.
4. UPDATE author_profiles SET user_id = <first_admin_auth_uuid> WHERE user_id = '00000000-…-001'.
5. Add FKs.
6. Verify: SELECT COUNT(*) WHERE user_id = '00000000-…-001' = 0 on both tables.

Rollback (documented in migration AgDR):
1. DROP FKs.
2. UPDATE … SET user_id = '00000000-…-001' WHERE user_id = <first_admin_auth_uuid>.
3. DROP first admin row + users table.
```

---

## Dependencies

| Dependency | Type | Status | Owner |
|------------|------|--------|-------|
| Supabase project (already provisioned) — Auth module **not yet enabled** | External | ⚠️ Action required: enable Email provider, configure Custom SMTP (Mailtrap), set Site URL + redirect allowlist | Mohamed Naser |
| Mailtrap account — Sandbox + Email API | External | Needs provisioning. Sender domain: `mnaser.me` (verify SPF/DKIM for Email API in prod) | Mohamed Naser |
| `@supabase/supabase-js` (already installed) | Library | ✅ In `backend/package.json` | — |
| First admin auth user (`mnaser.tech@gmail.com`, Mohamed Naser) | Operational | Created by seeder script during cutover | Backend Engineer + Mohamed Naser |
| Production redirect URL for verification + reset emails | Operational | ⚠️ Not available yet — **launch blocker for prod release**. Dev uses `http://localhost:5173/*`. | Mohamed Naser |
| Frontend pages (register, verify, login, forgot, reset, admin/*) | Internal | TBD | Frontend Engineer |
| Cutover migration runbook | Internal | TBD | Tech Lead + SRE |
| Replacement of placeholder `requireAuth` middleware | Internal | TBD | Backend Engineer |

---

## Open Questions

| Question | Owner | Status | Resolution |
|----------|-------|--------|------------|
| Production email "from" address | Mohamed Naser | ✅ Resolved | `me@mnaser.me`. SPF/DKIM for `mnaser.me` to be configured during Mailtrap Email API setup. |
| Production redirect URLs for verification + reset links | Mohamed Naser | ⚠️ Deferred | No prod URL exists yet. Dev/staging uses `http://localhost:5173/*`. Treated as a **launch blocker** for general availability — must be resolved before cutover applied to production. |
| Initial admin seed mechanism | Mohamed Naser | ✅ Resolved | Seeder script: `scripts/seed-first-admin.ts` (creates auth user via Supabase Admin API, inserts `users` row, runs cutover UPDATEs). |
| Rate-limit numbers (forgot-password attempts/min, login attempts/min) | Mohamed Naser | ✅ Resolved | Use Supabase Auth defaults; no application-level overrides in v1. |
| What happens to in-progress wizards if a user is deactivated mid-session? | Mohamed Naser | ✅ Resolved | Backend reads `users.deactivated_at` per request; if set, returns 401, frontend clears the session ("clean logout on next call"). |
| Should we also revoke sessions on email verification (defence in depth)? | Tech Lead | Open | Recommend **no** — would force a re-login immediately after verifying, adds friction. To be confirmed by Tech Lead in tech design. |

---

## Timeline (Indicative — Tech Lead to Refine in Tech Design Phase)

| Milestone | Target | Status |
|-----------|--------|--------|
| PRD approved | 2026-05-05 | Draft |
| Tech design + 6 AgDRs approved | 2026-05-07 | Not started |
| Migration ticket + migration AgDR drafted | 2026-05-08 | Not started |
| Backend (register, verify, login, forgot, reset, role middleware) | 2026-05-12 | Not started |
| Backend (admin endpoints) | 2026-05-13 | Not started |
| Frontend (auth pages) | 2026-05-13 | Not started |
| Frontend (admin pages) | 2026-05-14 | Not started |
| Cutover migration applied to staging | 2026-05-15 | Not started |
| QA verification of all ACs in staging | 2026-05-16 | Not started |
| Cutover applied to production + general availability | 2026-05-17 | Not started |

---

## Glossary

| Term | Definition |
|------|------------|
| **Supabase Auth** | The hosted authentication service bundled with Supabase. Manages `auth.users`, password hashing (bcrypt), JWT issuance, refresh tokens, and email-based flows (verification, reset). |
| **Application `users` table** | Our own Postgres table that mirrors `auth.users.id` and adds product-level fields (`role`, `email_verified_at`, `deactivated_at`). Source of truth for role and deactivation. |
| **Mailtrap Sandbox** | Mailtrap's SMTP testing environment — emails land in a virtual inbox visible only to the team. Used in dev and staging. |
| **Mailtrap Email API** | Mailtrap's production sending product — real delivery to real inboxes. Used in production only. |
| **Soft gate** | A restriction that limits some actions but does not block login. Contrast with a *hard gate* which would block login until verified. |
| **Cutover migration** | The one-time migration that creates the `users` table, reassigns the placeholder dev UUID rows to the first admin, and adds foreign-key constraints. |
| **First admin** | The auth user (initially Mohamed Naser) designated via env var to inherit all pre-cutover blogs and custom author profiles. |
| **Last-admin protection** | The invariant that the system always has at least one active admin; demote / deactivate are blocked when only one admin remains. |
| **Information-disclosure prevention** | Designing error responses so that a caller cannot tell from the response which input field was wrong, or whether an email exists in the system. |
| **Idempotent migration** | A migration that can be re-run safely; running it twice yields the same end state as running it once. |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser (via ApexYard agent) | 2026-05-04 | Author |
| Head of Product | — | — | Pending |
| Tech Lead | — | — | Pending (activates next, in Tech Design phase) |
| Head of Engineering | — | — | Pending (architecture review on role middleware + cutover migration) |
| Security Auditor | — | — | Pending (full review — auth, password, session, role enforcement) |
