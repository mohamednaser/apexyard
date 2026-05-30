# Technical Design: Landing Page

**Status**: Draft
**Author**: Mohamed Naser (Tech Lead)
**Date**: 2026-05-11
**PRD**: [`prd-landing-page.md`](./prd-landing-page.md)
**Epic**: [mohamednaseramein/blog-generator#118](https://github.com/mohamednaseramein/blog-generator/issues/118)

---

## Overview

### Summary

A public, SEO-indexable marketing page mounted at `/` of the blog-generator frontend. Built as a new module inside the existing React + Vite + TypeScript app (no new repo, no new deploy). The current `/` route (auth-protected `Dashboard`) is moved to `/dashboard` (see the companion dashboard tech design). The landing page is fully static — no backend changes, no new endpoints — and uses build-time prerendering so search engine crawlers receive fully-rendered HTML.

A shared `AppHeader` component (logo + `UserSettingsMenu` gear icon) is extracted from the existing `Dashboard.tsx` into its own module so the landing page, dashboard, and wizard steps all use the same header.

### Goals

- Landing page renders at `/` with fully prerendered HTML (Lighthouse Performance ≥ 90, SEO ≥ 95, Accessibility ≥ 95 — mobile)
- Same React + Vite + Tailwind stack — no new tooling beyond a prerender plugin
- Single content module — every string lives in one place (Phase-2-multilanguage-ready)
- `<head>` ships full SEO meta + OG + Twitter Card + JSON-LD `SoftwareApplication`
- `sitemap.xml` and `robots.txt` served at the site root
- Lighthouse CI gates every PR that touches `frontend/src/landing/**`
- Settings/gear icon menu adapts to logged-out / logged-in state without a hard redirect

### Non-Goals

- A separate marketing repo / domain — same Vite build, same Docker image, same deploy
- Server-side rendering (true SSR) — we use build-time prerender via `vite-plugin-prerender-spa` (decision: see AgDR below)
- Real billing — pricing tier CTAs route to `/register?plan=<tier>` and the `plan` URL param is captured client-side, written to user metadata on registration (Phase 2 wires Stripe)
- Cookie banner — global concern, not part of this epic
- Server-side analytics — events route through the existing client analytics layer

---

## Domain Model

The landing page has no domain entities of its own. It reads two pieces of state:

| State | Source | Use |
|-------|--------|-----|
| `authState: 'logged_in' \| 'logged_out'` | `useAuth()` from `context/AuthContext` (existing) | Determines which menu items render in `UserSettingsMenu` |
| `utmParams: Record<string, string>` | Parsed from `window.location.search` on mount | Forwarded to `/register?utm_*` via `localStorage` carry-through |

No new value objects or entities. No domain events — analytics are emitted directly via the existing analytics helper.

---

## Architecture

### Component Tree

```
LandingPage  (frontend/src/landing/LandingPage.tsx)
├── AppHeader                     (frontend/src/components/AppHeader.tsx — NEW, extracted)
│   ├── Logo
│   └── UserSettingsMenu          (existing — used as-is, menu items via prop)
├── HeroSection                   (frontend/src/landing/sections/Hero.tsx)
├── FeaturesSection               (frontend/src/landing/sections/Features.tsx)
├── HowItWorksSection             (frontend/src/landing/sections/HowItWorks.tsx)
├── SocialProofSection            (frontend/src/landing/sections/SocialProof.tsx) — renders only if data present
├── PricingSection                (frontend/src/landing/sections/Pricing.tsx)
└── AppFooter                     (frontend/src/components/AppFooter.tsx — NEW)
```

### Module Layout

```
frontend/src/
├── App.tsx                              (modify: route changes)
├── components/
│   ├── AppHeader.tsx                    (NEW — extracted shared header)
│   ├── AppFooter.tsx                    (NEW)
│   └── UserSettingsMenu.tsx             (existing — re-used; menu items controlled via props)
├── landing/
│   ├── LandingPage.tsx                  (NEW — top-level page component)
│   ├── content.ts                       (NEW — every visible string + tier data)
│   ├── seo.ts                           (NEW — JSON-LD object, OG/Twitter meta)
│   ├── analytics.ts                     (NEW — landing-specific event helpers)
│   ├── hooks/
│   │   ├── useScrollDepth.ts            (NEW — fires 25/50/75/100 events)
│   │   ├── useSectionInView.ts          (NEW — IntersectionObserver helper)
│   │   └── useUtmCarryThrough.ts        (NEW — reads UTMs + stores to localStorage)
│   └── sections/
│       ├── Hero.tsx
│       ├── Features.tsx
│       ├── HowItWorks.tsx
│       ├── SocialProof.tsx
│       └── Pricing.tsx
├── pages/
│   └── (existing pages — Dashboard moves to /dashboard, see dashboard tech design)
└── lib/
    └── analytics.ts                     (existing — landing events wrap this)

frontend/
├── vite.config.ts                       (modify: add prerender plugin, public-route allowlist)
├── public/
│   ├── robots.txt                       (NEW)
│   ├── sitemap.xml                      (NEW — static, regenerated only when public routes change)
│   └── og-image.png                     (NEW — 1200×630, < 200 KB)
└── lighthouse.config.json               (NEW — Lighthouse CI config)
```

### Routing Changes

Current `App.tsx`:

```tsx
<Route element={<ProtectedRoute />}>
  <Route path="/" element={<Dashboard />} />
  <Route path="/profile" element={<ProfilePage />} />
</Route>
```

After this epic:

```tsx
{/* Public marketing */}
<Route path="/" element={<LandingPage />} />

{/* Protected app */}
<Route element={<ProtectedRoute />}>
  <Route path="/dashboard" element={<Dashboard />} />   {/* moved */}
  <Route path="/profile" element={<ProfilePage />} />
</Route>

{/* Fallback unchanged — Navigate to "/" */}
```

Note: `LandingPage` is **outside** `ProtectedRoute`. It does not redirect logged-in visitors; the `UserSettingsMenu` reflects auth state via `useAuth()` and shows the "Dashboard" item when logged in.

### Data Flow — First Paint (Bot or Cold User)

```
1. CDN serves prerendered /index.html with full body content
   (HeroSection markup is in the HTML, no JS execution required)

2. <head> contains:
   - <title>, <meta description>
   - OG + Twitter Card meta
   - <script type="application/ld+json"> with SoftwareApplication schema
   - <meta name="viewport">
   - <link rel="canonical">

3. Browser hydrates React; useAuth() runs:
   - logged-out → UserSettingsMenu shows "Sign in" / "Sign up"
   - logged-in  → menu shows "Dashboard" / "Settings" / "Log out"

4. Analytics SDK loads asynchronously (deferred); recordLandingPageViewed fires once
```

### Data Flow — CTA Click

```
User clicks "Start Pro" (Pricing → Pro tier)
   |
   v
analytics.recordLandingPricingCtaClick({ plan: 'pro' })
   |
   v
Navigate to /register?plan=pro&source=landing_pricing&<utm_*>
   |
   v
RegisterPage reads ?plan=pro, stores it on form state,
includes it in the user-metadata field of the Supabase signUp call
```

### Build & Prerender

We use `vite-plugin-prerender-spa` (or `vite-plugin-ssr-pro`/`@prerenderer/vite-plugin` — final choice pinned in the AgDR). At `npm run build`:

1. `tsc && vite build` produces the standard CSR bundle
2. The prerender plugin spins up a headless browser, navigates to each public route in `prerenderRoutes: ['/']` (extensible — `/help/ai-detector-rules` may also benefit later), captures the fully-rendered HTML, and writes it to `dist/index.html` (and `dist/help/ai-detector-rules/index.html` if extended)
3. The CSR bundle still ships — the prerendered HTML is the "first paint", hydration takes over

Bot UX: bot reads the prerendered HTML, sees real content, never executes JS.
User UX: browser loads the prerendered HTML, then hydrates → identical interactivity to a normal SPA.

`/dashboard`, `/draft/*`, `/publish/*`, `/login`, `/register`, etc. are NOT prerendered — they stay as standard CSR routes behind `noindex`.

---

## API Design

### Endpoints

**No new backend endpoints.** The landing page is fully static after prerendering.

The page consumes one existing client signal:

| Source | Returns | Use |
|--------|---------|-----|
| `useAuth()` from `context/AuthContext` (Supabase-backed) | `{ user, role, isLoading }` | Drives `UserSettingsMenu` menu items |

### CTA Targets

| Source | Destination | Notes |
|--------|-------------|-------|
| Hero primary CTA | `/register?source=landing_hero&<utm_*>` | Existing RegisterPage handles |
| Hero secondary CTA | `#how-it-works` | In-page anchor |
| Feature card "Learn more" | `#features-<id>` (or scroll to corresponding section) | In-page anchor |
| Pricing — Free CTA | `/register?plan=free&source=landing_pricing&<utm_*>` | New `plan` query param |
| Pricing — Pro CTA | `/register?plan=pro&source=landing_pricing&<utm_*>` | New `plan` query param |
| Pricing — Team CTA | `/register?plan=team_waitlist&source=landing_pricing&<utm_*>` | Waitlist marker |
| Footer — AI Detector Rules | `/help/ai-detector-rules` | Existing route |
| Footer — Help | `/help` | Existing route (if present; else hide) |
| Footer — Privacy / Terms / Cookies | `/legal/privacy`, `/legal/terms`, `/legal/cookies` | Open question — page existence (see PRD) |
| Header gear icon (logged-out) | `/login`, `/register` | Existing routes |
| Header gear icon (logged-in) | `/dashboard`, `/profile`, `<logout>` | Existing routes; logout via Supabase |

### Register Page — small extension

`RegisterPage` is extended (NOT rewritten) to:

1. Read `?plan=<free|pro|team_waitlist>` from `useSearchParams()` and store in component state
2. Read `?source=` and any `?utm_*` params via the same hook
3. Pass `plan` + `source` + `utm_*` as `options.data` to `supabase.auth.signUp({ email, password, options: { data: { plan, source, ...utm } } })` — these land in `user_metadata` and are auditable

No new endpoint; existing Supabase signup flow accepts the metadata payload.

### Robots / Sitemap

**`public/robots.txt`** (static):

```
User-agent: *
Allow: /
Allow: /help/ai-detector-rules

Disallow: /dashboard
Disallow: /draft
Disallow: /publish
Disallow: /profile
Disallow: /register
Disallow: /login
Disallow: /verify
Disallow: /forgot-password
Disallow: /reset-password
Disallow: /admin/
Disallow: /api/

Sitemap: https://<domain>/sitemap.xml
```

**`public/sitemap.xml`** (static):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://<domain>/</loc><changefreq>weekly</changefreq><priority>1.0</priority></url>
  <url><loc>https://<domain>/help/ai-detector-rules</loc><changefreq>monthly</changefreq><priority>0.7</priority></url>
</urlset>
```

Domain placeholder is resolved at build time via `VITE_PUBLIC_URL` env var (new) — the build script does a sed replacement on `dist/sitemap.xml` and `dist/robots.txt` after `vite build`.

---

## Data Model

No database changes for this epic.

User-metadata addition (already-supported Supabase pattern, no migration):

```jsonc
// auth.users.raw_user_meta_data — appended at signup time only
{
  "plan": "pro",                         // "free" | "pro" | "team_waitlist"
  "signup_source": "landing_pricing",
  "utm_source": "linkedin",
  "utm_medium": "social",
  "utm_campaign": "may_launch"
}
```

These fields are write-once at signup. They're informational only in v1 (no plan enforcement); they unblock billing-time grandfathering when Stripe wires in.

---

## Analytics

All events route through the existing client analytics layer (`frontend/src/lib/analytics.ts`). New event helpers live in `frontend/src/landing/analytics.ts` and wrap the generic tracker so payloads are typed.

| Event | Trigger | Payload |
|-------|---------|---------|
| `recordLandingPageViewed` | On mount | `auth_state`, `referrer`, `utm_source`, `utm_medium`, `utm_campaign` |
| `recordScrollDepth` | 25 / 50 / 75 / 100 % scroll (each once) | `percent` |
| `recordSectionViewed` | Section ≥ 50 % visible for ≥ 1 s (each once per session) | `section_id` |
| `recordLandingCtaClick` | Any CTA click | `cta_id`, `destination_url`, `current_section_id` |
| `recordLandingFeatureClick` | Feature card click | `feature_id` |
| `recordLandingPricingCtaClick` | Pricing tier CTA click | `plan`, `tier_label` |
| `recordAccountMenuOpened` | Gear icon opened | `auth_state` |
| `recordAccountMenuItemClicked` | Menu item clicked | `item_id`, `auth_state` |
| `recordFooterLinkClick` | Footer link clicked | `link_id` |

The two scroll/section helpers (`useScrollDepth`, `useSectionInView`) deduplicate per-page-view via refs — no event fires twice.

---

## Performance Plan

The landing page is the highest-traffic external-facing route. Budget:

| Metric | Budget | Strategy |
|--------|--------|----------|
| LCP | ≤ 2.5 s (mobile p75) | Prerendered HTML; hero image as `<img loading="eager" fetchpriority="high">`; AVIF + WebP fallback ≤ 200 KB |
| CLS | ≤ 0.1 | Reserve hero image dimensions; reserve card row heights; no late-loading web fonts (use system stack or `font-display: swap` only) |
| INP | ≤ 200 ms | Defer analytics SDK; no heavy JS on the critical path; section animations CSS-only |
| First-paint JS | ≤ 100 KB gzipped | Code-split landing-specific JS; analytics loaded async after `requestIdleCallback` |
| Hero image | ≤ 200 KB | AVIF first, WebP fallback, JPEG fallback; `srcset` for retina |

Lighthouse CI runs in GitHub Actions on every PR touching `frontend/src/landing/**` or `frontend/public/{robots,sitemap}.*`. Failure thresholds: Performance < 90, SEO < 95, Accessibility < 95 (mobile preset).

---

## Implementation Plan

### Tasks

| # | Task | File(s) | Estimate |
|---|------|---------|----------|
| 1 | Extract `AppHeader` from `Dashboard.tsx` (logo + `UserSettingsMenu`) | `frontend/src/components/AppHeader.tsx`, `Dashboard.tsx` | 0.5 d |
| 2 | Extract `AppFooter` (new component) | `frontend/src/components/AppFooter.tsx` | 0.5 d |
| 3 | Extend `UserSettingsMenu` to accept an `authState` prop and render context-aware items | `frontend/src/components/UserSettingsMenu.tsx` | 0.5 d |
| 4 | Routing change — add `/` public, move `Dashboard` to `/dashboard` | `frontend/src/App.tsx` | 0.5 d |
| 5 | `LandingPage` shell + section composition | `frontend/src/landing/LandingPage.tsx` | 0.5 d |
| 6 | `content.ts` — every string in one module | `frontend/src/landing/content.ts` | 0.5 d |
| 7 | `Hero` section | `frontend/src/landing/sections/Hero.tsx` | 1 d |
| 8 | `Features` section (4 cards, responsive grid) | `frontend/src/landing/sections/Features.tsx` | 1 d |
| 9 | `HowItWorks` section (4-step horizontal/vertical layout) | `frontend/src/landing/sections/HowItWorks.tsx` | 1 d |
| 10 | `Pricing` section (3 tiers, Coming-soon treatment for Team) | `frontend/src/landing/sections/Pricing.tsx` | 1 d |
| 11 | `SocialProof` section (stats strip; hides if no data) | `frontend/src/landing/sections/SocialProof.tsx` | 0.5 d |
| 12 | SEO meta + JSON-LD `<head>` injection (React 18 native `<head>` children OR `react-helmet-async`) | `frontend/src/landing/seo.ts`, `LandingPage.tsx` | 1 d |
| 13 | `robots.txt` + `sitemap.xml` + build-time domain substitution | `frontend/public/`, `frontend/scripts/build-public-files.mjs` | 0.5 d |
| 14 | `useScrollDepth`, `useSectionInView`, `useUtmCarryThrough` hooks | `frontend/src/landing/hooks/` | 1 d |
| 15 | `analytics.ts` event helpers (typed wrappers around the SDK) | `frontend/src/landing/analytics.ts` | 0.5 d |
| 16 | `RegisterPage` extension — read `plan` + `source` + `utm_*`, pass to `signUp({ options: { data: ... } })` | `frontend/src/pages/auth/RegisterPage.tsx` | 1 d |
| 17 | Vite prerender plugin install + config (AgDR-driven choice) | `frontend/vite.config.ts`, `package.json` | 1 d |
| 18 | Lighthouse CI workflow + threshold gates | `.github/workflows/lighthouse-landing.yml`, `frontend/lighthouse.config.json` | 1 d |
| 19 | Visual regression snapshots (Playwright or Chromatic — open question) at 375 / 768 / 1280 px | `frontend/tests/visual/landing.spec.ts` | 1 d |
| 20 | Security headers — `X-Frame-Options: DENY`, `Strict-Transport-Security`, `Referrer-Policy: strict-origin-when-cross-origin` | `backend/src/middleware/security-headers.ts` (if served via backend) or hosting config | 0.5 d |
| 21 | Accessibility pass — axe-core in CI, keyboard nav, focus styles | CI workflow | 0.5 d |
| 22 | End-to-end smoke: Playwright test that visits `/`, clicks every CTA, asserts destination | `frontend/tests/e2e/landing.spec.ts` | 0.5 d |

**Total: ~14 dev days** (single engineer; parallelisable across two with the section components splitting cleanly).

### Sub-issue mapping for the epic

Each task above becomes a sub-issue under [#118](https://github.com/mohamednaseramein/issues/118). Suggested groupings (one PR per group, no more than ~400 lines diff):

| Group | Tasks | PR title |
|-------|-------|----------|
| A | 1, 2, 3, 4 | `feat(#118): extract AppHeader / AppFooter; move Dashboard to /dashboard` |
| B | 5, 6, 7, 8 | `feat(#118): LandingPage shell + Hero + Features` |
| C | 9, 10, 11 | `feat(#118): HowItWorks + Pricing + SocialProof sections` |
| D | 12, 13 | `feat(#118): SEO meta + JSON-LD + sitemap + robots` |
| E | 14, 15 | `feat(#118): scroll-depth + section-view hooks + analytics` |
| F | 16 | `feat(#118): RegisterPage captures plan + utm metadata` |
| G | 17 | `feat(#118): Vite prerender plugin for / and help routes` |
| H | 18, 21, 22 | `ci(#118): Lighthouse + axe-core + e2e gates` |
| I | 19 | `test(#118): visual regression for landing at 3 breakpoints` |
| J | 20 | `chore(#118): security headers for the public route` |

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Prerender plugin compatibility with Vite 5 + React 18 hydration | Medium | High — could need a different SSR approach | AgDR documents the choice + fallback (Astro adapter, or migrate landing to a Next.js mini-app); pin plugin version |
| Logged-in users confused by no-redirect on `/` (bookmark expectation) | Medium | Medium — minor UX friction | Soft-launch banner: "Looking for your drafts? Click the gear icon → Dashboard" for first N days post-launch; gear icon prominently shows "Dashboard" when logged in |
| Lighthouse Performance < 90 due to React hydration cost | Medium | High — blocks merge | Inline critical CSS; defer all non-critical JS; aggressive code-split; if persistent, evaluate Astro-style islands for landing only |
| `RegisterPage` plan/utm metadata diverges from final billing schema | Low | Medium | Metadata is informational — fields can be remapped in billing migration |
| Sitemap / robots not picked up by Google for weeks | High | Low — expected behaviour | Submit sitemap manually to Google Search Console at launch |
| Hero image weight blows the 200 KB budget at 2× density | Medium | Medium | Build script enforces image-size budget; CI fails on regression |
| Visual regression flakiness across CI runners | High | Low — annoyance | Pin Playwright browser version; allow ≤ 2 retries before failure; review screenshots on every PR |

---

## Security Considerations

- **No PII collected on the landing page** — no forms (newsletter / contact). All CTAs navigate to existing auth routes
- **Headers** — `X-Frame-Options: DENY` (or CSP `frame-ancestors 'none'`) prevents clickjacking of CTA buttons; `Strict-Transport-Security` enforces HTTPS; `Referrer-Policy: strict-origin-when-cross-origin` limits referrer leakage to third parties
- **`/` is uncacheable in user-content sense** — but the prerendered HTML IS public and identical for every visitor; the CDN caches it aggressively (`Cache-Control: public, max-age=300, s-maxage=3600, stale-while-revalidate=86400`). No user state is in the HTML
- **UTM passthrough** — only the canonical `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content` are forwarded; any other query param is dropped to prevent open-redirect / parameter-injection attacks
- **JSON-LD does not include user data** — only product-level info (name, category, pricing tiers)
- **Logged-in session detection is client-side only** — `useAuth()` reads the Supabase session client-side. The prerendered HTML always renders the logged-out state initially; hydration flips to logged-in if a session exists. No session token ever appears in the prerendered HTML

---

## Testing Strategy

| Layer | Tool | Coverage |
|-------|------|----------|
| Unit | Vitest + React Testing Library | Each section component renders with content.ts; UserSettingsMenu shows correct items per `authState`; hooks fire events at the right thresholds |
| Integration | Vitest | RegisterPage captures `plan` + `utm_*` from URL and passes them to Supabase signUp mock |
| Visual regression | Playwright snapshots (375 / 768 / 1280 px) | Each section at each breakpoint; full page at each breakpoint |
| End-to-end | Playwright | Visit `/`, click every CTA, assert destination URL + query params; smoke test logged-in state with stubbed Supabase session |
| Accessibility | axe-core (via Playwright) | Zero serious/critical violations on every section |
| Performance | Lighthouse CI | Performance ≥ 90, SEO ≥ 95, Accessibility ≥ 95 (mobile preset) gates merge |
| SEO validation | Manual at launch | Google Rich Results Test for JSON-LD; Google Search Console sitemap submission |

---

## AgDRs

Decisions worth recording as AgDRs before implementation begins:

| AgDR | Topic | Why it matters |
|------|-------|----------------|
| AgDR-N | Prerender approach — `vite-plugin-prerender-spa` vs `@prerenderer/vite-plugin` vs migrating landing to Astro | Affects build time, hydration behaviour, and long-term maintenance |
| AgDR-N+1 | Visual regression tool — Playwright snapshots vs Chromatic vs Percy | Cost, flakiness, and CI integration tradeoffs |
| AgDR-N+2 | Domain / hosting — same `app.<domain>` as the app, or separate `www.<domain>` | Affects cookies, analytics scope, and CDN config; ties into the open question in the PRD |
| AgDR-N+3 | Logged-in-on-`/` UX — no-redirect with soft banner vs. redirect after N seconds vs. hard redirect | UX call; PRD chose no-redirect, but worth recording the reasoning |

These will be created via `/decide` before the relevant tasks start.

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Domain choice — same domain or separate `www.`? Affects CDN, cookies, analytics scope | Tech Lead / Platform | Open (PRD-level) |
| Hero copy / brand voice — needs final Head of Product sign-off | Head of Product | Open (PRD-level) |
| Hero illustration vs real screenshot — which converts better v1? | UX Designer | Open (PRD-level) |
| Privacy / Terms / Cookies pages — do they exist? Footer links break if not | Head of Product / Legal | Open (PRD-level) |
| Lighthouse CI — runs against preview deploy URL or a local prod-mode build? | Platform | Open |
| Cookie banner — does this epic add one or inherit a global one? | Head of Security / Compliance | Open (PRD-level) |
| Should the prerender include `/help/ai-detector-rules` too for SEO consistency? | Tech Lead | Open |

---

## Estimates Summary

- **Total effort**: ~14 dev days (single engineer)
- **Parallelisable**: Yes — section components (tasks 7–11) split cleanly across two engineers; prerender plumbing (task 17) and CI gates (task 18) can run in parallel with section work
- **Critical path**: Task 4 (routing change) blocks task 5 (LandingPage shell); task 17 (prerender) blocks task 18 (Lighthouse CI thresholds)
- **Recommended team shape**: 1 senior frontend + 1 mid frontend, paired through tasks 1–4, then splitting

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Tech Lead | Mohamed Naser | 2026-05-11 | Author |
| Head of Engineering | | | Pending |
| Product Manager | | | Pending |
