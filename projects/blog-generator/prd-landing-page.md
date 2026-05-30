# PRD: Landing Page — Public Marketing & Signup Conversion

**Status**: Draft
**Author**: Product Manager
**Created**: 2026-05-10
**Last Updated**: 2026-05-10
**Epic**: [mohamednaseramein/blog-generator#118](https://github.com/mohamednaseramein/blog-generator/issues/118)

---

## Overview

### Problem Statement

The blog-generator currently has **no public front door**. Auth shipped under EP-04 ([#95](https://github.com/mohamednaseramein/blog-generator/issues/95)) — `/signup` and `/login` exist — but anyone visiting the root domain lands on a bare authentication screen or directly into the draft workspace. That breaks the product in three ways:

1. **Conversion is invisible.** There is no surface that explains what the product does to a first-time visitor, so signup intent has nowhere to form. We cannot measure marketing-funnel conversion because there is no marketing funnel.
2. **Brand trust suffers.** A serious AI content product is being compared to commercial competitors (Copy.ai, Jasper, Writesonic) that all have polished landing pages. Showing up with no value-prop page makes the product look like an internal tool, not a public SaaS.
3. **SEO is forfeit.** The root domain has no indexable content. Organic discovery for keywords like "AI blog generator", "SEO-ready blog drafts", "AI content detector" is impossible because there is nothing to rank.

This epic adds a public, SEO-indexed landing page at `/` that explains the product, walks the visitor through the key features (AI generation, SEO readiness, AI authenticity check, author profiles), shows dummy pricing tiers, and funnels visitors into the existing auth flow via clear signup CTAs. A settings/gear icon in the header gives both logged-out and logged-in visitors a single, context-aware account-menu entry point so we don't need a hard redirect for returning users.

### What Already Exists (do not re-build)

| Capability | Where |
|------------|-------|
| `/signup` and `/login` routes with email verification + password reset | EP-04 ([#95](https://github.com/mohamednaseramein/blog-generator/issues/95)), shipped |
| Session cookie / JWT establishing the current user | EP-04 |
| Draft step (post-signup workspace) | EP-01 |
| Publish step with SEO & social panel, readability score | EP-03 + SEO-ready-content PRD, shipped |
| AI content detector (in flight, parallel epic) | [#115](https://github.com/mohamednaseramein/blog-generator/issues/115) |
| Author profiles | [#73](https://github.com/mohamednaseramein/blog-generator/issues/73) |

### Target User

**Primary** — Content creators, bloggers, media buyers, and account managers evaluating AI writing tools. Logged-out, arriving from search, social, or direct referral. They need to understand within 10 seconds what the product does and within 30 seconds whether it's worth signing up for.

**Secondary** — Existing users who navigate to the root URL out of habit. They should not be force-redirected (in case they want to see the marketing page or share it); instead, the settings/gear icon tells them they are signed in and offers a one-click route to their dashboard.

**Tertiary** — Search-engine crawlers and link-preview bots. The page must be fully server-rendered or pre-rendered, with meta tags, Open Graph tags, and JSON-LD structured data, so it ranks for product-intent keywords and renders nicely when shared on social media.

### Goals

1. A visitor lands on `/`, understands what the product does within 10 seconds, and reaches a primary CTA within one scroll.
2. From the landing page, ≥ 8 % of unique visitors click a primary signup CTA within 4 weeks of launch (industry baseline for B2B SaaS landing pages is 2–5 %; we aim higher because the product is in a high-intent vertical).
3. The page is fully indexable by search engines and scores ≥ 95 on Lighthouse SEO + Accessibility audits, ≥ 90 on Performance, on emulated mobile.
4. Both logged-out and logged-in visitors have a single, consistent account-access pattern: a settings/gear icon in the header that surfaces the right menu items for their session state.
5. Every section is instrumented with analytics so we can measure scroll depth, CTA-click rate by section, and signup-funnel drop-off.
6. The page renders correctly at 375 px (mobile), 768 px (tablet), and 1280 px+ (desktop) without horizontal scroll or content overflow.

### Non-Goals (Out of Scope)

- **Real billing integration.** Pricing tiers are dummy — the CTA on each tier routes to `/signup?plan=<tier>` and we capture the intent. No Stripe, no card collection, no plan-gated features yet.
- **Multi-language landing pages.** English only in v1.
- **A/B testing infrastructure.** We measure conversion against a single variant. Multi-variant testing is a Phase 2 capability.
- **Blog / changelog / docs hub** under the landing domain. The `/help/ai-detector-rules` page (from the AI detector PRD) is the only public content page outside this epic in v1.
- **Live customer chat widget.** Adds tracker weight, adds support load, deferred.
- **Cookie banner / consent banner** beyond what is already shipped at the app level. If a global consent banner exists, the landing page inherits it; we are not building a new one here.
- **Hard redirect for logged-in users.** Logged-in visitors see the same page, with the settings/gear icon showing they are signed in. They can click into the dashboard from the menu but are not force-redirected.

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Signup CTA click-through rate (unique visitors → CTA click) | ≥ 8 % within 4 weeks of launch | `recordLandingCtaClick` analytics event / unique page views |
| Signup completion from landing | ≥ 3 % of unique landing-page visitors complete signup | `recordSignupCompleted` joined with landing page view session |
| Bounce rate (% of sessions with only a landing page view, no scroll past hero) | ≤ 55 % | Analytics scroll-depth events |
| Lighthouse Performance (mobile, p75) | ≥ 90 | Lighthouse CI on every PR |
| Lighthouse SEO | ≥ 95 | Lighthouse CI |
| Lighthouse Accessibility | ≥ 95 | Lighthouse CI |
| Median scroll depth | ≥ 50 % | `recordScrollDepth` (25 / 50 / 75 / 100) |
| Time to first interactive CTA click | ≤ 30 s for the top 25 % of sessions | Analytics |

---

## User Stories

### US-1: Hero with primary value prop and CTA

> As a first-time visitor, I want to understand what the product does within 10 seconds of landing on the page, so that I can decide whether to keep reading.

**Acceptance Criteria**:

- [ ] Hero section is above the fold on a 1366×768 viewport (the modal desktop) and on a 375×667 viewport (modal mobile)
- [ ] Hero contains: H1 with the primary value prop (≤ 12 words), one supporting sub-headline (≤ 25 words), primary CTA button ("Get started — it's free"), secondary CTA link ("See how it works" — anchor link to the how-it-works section)
- [ ] The H1 is a real `<h1>` element (one per page); analytics events fire `recordLandingCtaClick` with `cta_id: "hero_primary"` and `cta_id: "hero_secondary"` respectively
- [ ] Primary CTA links to `/signup?source=landing_hero`; secondary CTA scrolls smoothly to `#how-it-works`
- [ ] A subtle, optional hero illustration / product screenshot is shown to the right of the copy on desktop, and stacked below on mobile (lazy-loaded if below the fold on small screens, eager-loaded if above)
- [ ] Hero passes WCAG 2.1 AA contrast on all text against its background

### US-2: Feature highlights

> As a visitor evaluating the product, I want to scan a short list of what it can do, so that I can quickly judge whether it has the capabilities I need.

**Acceptance Criteria**:

- [ ] A "Features" section sits directly below the hero with 4 feature cards: **AI Blog Generation**, **SEO-Ready Content**, **AI Authenticity Check**, **Author Profiles**
- [ ] Each card has: an icon (decorative, `aria-hidden`), a card title (`<h3>`), a one-sentence description (≤ 20 words), and a "Learn more" link that anchors to the corresponding deep-dive section further down the page
- [ ] On desktop, cards are a 4-up grid; on tablet, 2×2; on mobile, stacked single column
- [ ] Each card is keyboard-focusable and announces its title + description to screen readers in a single utterance
- [ ] Analytics: `recordLandingFeatureClick` with `feature_id` on any card click

### US-3: "How it works" walkthrough

> As a visitor who's intrigued by the features, I want to see the actual workflow before signing up, so that I can build a mental model of the product without committing.

**Acceptance Criteria**:

- [ ] A "How it works" section with the anchor `#how-it-works` is rendered below the features section
- [ ] Four sequential steps are shown: **1. Tell us your topic and audience** · **2. Generate a draft** · **3. Review SEO and authenticity** · **4. Publish or export**
- [ ] Each step has a title, a 2–3 sentence description, and a small illustration or product screenshot
- [ ] Steps are arranged horizontally on desktop (4-up), vertically on mobile (stacked)
- [ ] At least one step includes a real screenshot of the existing product (Publish step with the SEO panel is a good candidate); placeholder graphics are acceptable for v1 if real screenshots are not ready by ship date, but the PRD treats the screenshots as a v1 requirement
- [ ] Analytics: `recordSectionViewed` with `section_id: "how_it_works"` fires when ≥ 50 % of the section is in viewport for ≥ 1 s

### US-4: Pricing tiers (dummy)

> As a visitor with budget in mind, I want to see pricing before I sign up, so that I know what I'm committing to.

**Acceptance Criteria**:

- [ ] A "Pricing" section with the anchor `#pricing` shows three tiers in a 3-up card layout (single column on mobile):
  - **Free** — "Try the product. 3 blog drafts / month."
  - **Pro** — "$19 / month — 50 blog drafts / month, full AI authenticity check, SEO export."
  - **Team** — "$49 / user / month — everything in Pro, plus team workspaces and admin controls." Marked **"Coming soon"** with a disabled CTA tooltip explaining the tier is not yet purchasable.
- [ ] Each tier has: tier name (`<h3>`), price ($/month), 3–5 feature bullets, a CTA button
- [ ] **Free** CTA: "Start free" → `/signup?plan=free&source=landing_pricing`
- [ ] **Pro** CTA: "Start Pro trial" → `/signup?plan=pro&source=landing_pricing` (no payment captured in v1; the URL param is recorded against the signup for later billing wiring)
- [ ] **Team** CTA: "Notify me" → opens a `mailto:` or routes to `/signup?plan=team_waitlist&source=landing_pricing`; visually disabled-looking but accessible to keyboard / screen readers with an `aria-label` clarifying the "coming soon" status
- [ ] Analytics: `recordLandingPricingCtaClick` with `plan: "free" | "pro" | "team_waitlist"`
- [ ] A short disclaimer below the tiers reads: "Pricing is illustrative for v1 — billing not yet enabled. All paid features are free during this preview."

### US-5: Social proof / testimonials placeholder

> As a visitor weighing trust signals, I want to see that other people use the product, so that I am more confident it works.

**Acceptance Criteria**:

- [ ] A "Trusted by" section sits between How-It-Works and Pricing, containing one of: a row of customer logos, a 2–3-card testimonial carousel, or a stats strip ("10,000+ blogs generated")
- [ ] In v1 with no real customers yet, the section renders a stats strip with **placeholder-but-honest** numbers (e.g. "Open beta — drafts generated this week"). No fabricated logos, no fake testimonials
- [ ] If no real data is available, the section is hidden entirely rather than showing a placeholder vacuum
- [ ] When real testimonials or logos arrive (post-launch), they slot in without requiring a layout change
- [ ] Analytics: `recordSectionViewed` with `section_id: "social_proof"` on view

### US-6: Footer

> As a visitor checking the legitimacy or contact details of the product, I want a footer with legal links and contact info, so that I can find them without searching.

**Acceptance Criteria**:

- [ ] Footer pinned to the bottom of the page (not sticky) with: company name, copyright year (auto-updated), and three columns of links:
  - **Product** — Features (anchor), Pricing (anchor), How it works (anchor)
  - **Resources** — AI Detector Rules (`/help/ai-detector-rules`), Help (`/help`), Changelog (link is optional in v1 — hide if no changelog page exists)
  - **Legal** — Privacy Policy, Terms of Service, Cookie Policy (each is a real page; if the page doesn't yet exist, link to a `mailto:` for now with a clear label)
- [ ] Footer also contains a contact link (`mailto:hello@<domain>`) and links to social profiles (LinkedIn, X, GitHub) if they exist; hide social links entirely if there are no profiles to link to (no broken icons)
- [ ] Footer renders at all breakpoints (single column on mobile, multi-column on desktop)
- [ ] Analytics: `recordFooterLinkClick` with `link_id`

### US-7: SEO foundations

> As a content marketer responsible for organic acquisition, I want the landing page to rank for product-intent keywords, so that we can build a sustainable signup pipeline from search.

**Acceptance Criteria**:

- [ ] HTML `<head>` includes: `<title>` (≤ 60 chars, includes primary keyword), meta `description` (≤ 155 chars), `meta viewport`, `link rel="canonical"`
- [ ] Open Graph meta tags: `og:title`, `og:description`, `og:type` (= `website`), `og:image` (1200×630, < 200 KB), `og:url`
- [ ] Twitter Card meta tags: `twitter:card` (= `summary_large_image`), `twitter:title`, `twitter:description`, `twitter:image`
- [ ] JSON-LD structured data of type `SoftwareApplication` with: `name`, `applicationCategory`, `operatingSystem`, `offers` (representing the dummy tiers — `Offer` entries with `price` and `priceCurrency`), `aggregateRating` (optional — omit if no ratings yet)
- [ ] A `/sitemap.xml` exists at the site root and includes `/`, `/help/ai-detector-rules`, and any other indexable pages (privacy, terms, etc.). The dashboard is **not** in the sitemap.
- [ ] A `/robots.txt` exists at the site root, allowing all user-agents on `/` and other indexable pages, **disallowing** `/dashboard`, `/draft`, `/publish`, `/signup`, `/login`, `/api/*`
- [ ] Page passes [Google's Rich Results Test](https://search.google.com/test/rich-results) for the `SoftwareApplication` schema with zero errors
- [ ] Heading hierarchy is valid: one `<h1>`, multiple `<h2>` (one per major section), `<h3>` for sub-items. No skipped levels.

### US-8: Account access via settings/gear icon

> As any visitor (logged in or out), I want a single consistent way to reach my account, so that I don't have to look for different buttons depending on whether I'm signed in.

**Acceptance Criteria**:

- [ ] A settings/gear icon button sits at the top-right of the header, present on every breakpoint
- [ ] The icon button has `aria-label="Account menu"` and opens a dropdown menu on click or Enter / Space when focused
- [ ] When **logged out**, the menu shows: **Sign in** (→ `/login?source=landing_account_menu`), **Sign up** (→ `/signup?source=landing_account_menu`)
- [ ] When **logged in**, the menu shows: **Dashboard** (→ `/dashboard`), **Settings** (→ `/settings` if it exists; otherwise `/dashboard` for v1), **Log out** (calls the existing logout endpoint, then redirects to `/`)
- [ ] Session state is detected from the existing auth cookie or JWT — the same mechanism used by `/dashboard`. No new endpoint
- [ ] Menu closes on `Esc`, on outside-click, and on selecting an item
- [ ] Analytics: `recordAccountMenuOpened` with `auth_state: "logged_in" | "logged_out"`; `recordAccountMenuItemClicked` with `item_id`

### US-9: Analytics instrumentation

> As a product analyst, I want every section of the landing page instrumented for engagement events, so that I can measure where visitors drop off and which features draw the most interest.

**Acceptance Criteria**:

- [ ] On page load, fire `recordLandingPageViewed` with `auth_state`, `referrer`, `utm_source`, `utm_medium`, `utm_campaign` (parsed from the URL)
- [ ] Fire `recordScrollDepth` at 25 %, 50 %, 75 %, and 100 % page scroll; payload includes scroll percent (each fires at most once per page view)
- [ ] Fire `recordSectionViewed` when each major section (`hero`, `features`, `how_it_works`, `social_proof`, `pricing`, `footer`) crosses ≥ 50 % visibility for ≥ 1 second; payload includes `section_id` (each fires at most once per page view)
- [ ] Fire `recordLandingCtaClick` on every CTA click; payload includes `cta_id` (e.g. `hero_primary`, `pricing_pro`), `destination_url`, `current_section_id`
- [ ] Fire `recordAccountMenuOpened` and `recordAccountMenuItemClicked` per US-8
- [ ] All events are routed through the existing analytics layer (same SDK as `recordExportEvent`); no new vendor

### US-10: Performance budget enforcement

> As a SRE responsible for site reliability, I want the landing page to meet a published Core Web Vitals budget, so that we don't ship a marketing page that's slower than the app itself.

**Acceptance Criteria**:

- [ ] LCP ≤ 2.5 s on emulated mobile (Lighthouse moto-g4 throttling) at the p75 of CI runs over the past 7 days
- [ ] CLS ≤ 0.1
- [ ] INP ≤ 200 ms (synthetic measurement)
- [ ] Largest image on the page ≤ 200 KB after compression; all images served as WebP or AVIF with a JPEG fallback
- [ ] Below-the-fold images are lazy-loaded (`loading="lazy"`)
- [ ] JavaScript bundle delivered on first paint ≤ 100 KB gzipped; analytics SDK loaded asynchronously / deferred
- [ ] No render-blocking third-party scripts in `<head>`
- [ ] Lighthouse CI runs on every PR that touches the landing module and gates merge if Performance < 90 or SEO < 95 or Accessibility < 95

### US-11: Responsive layout

> As a mobile visitor, I want every section to render correctly without horizontal scroll or overlapping content, so that I can read and tap CTAs comfortably.

**Acceptance Criteria**:

- [ ] At 375 px width: no horizontal scroll, every CTA tap target ≥ 44×44 px, all text readable without zooming
- [ ] At 768 px: tablet layout — feature cards 2×2, pricing tiers stacked or 2-up
- [ ] At 1280 px+: full desktop layout
- [ ] Visual regression snapshots stored for each breakpoint at the home route; CI fails on unintended diffs
- [ ] No content (other than the cookie banner, if applicable) is sticky / fixed at any breakpoint; the page reads top-down naturally

### US-12: Accessibility (WCAG 2.1 AA)

> As a visitor using a screen reader or keyboard, I want every section, link, and CTA to be navigable and announced clearly, so that I can use the page without sighted assistance.

**Acceptance Criteria**:

- [ ] Lighthouse Accessibility ≥ 95
- [ ] Every interactive element is reachable by keyboard in a logical tab order
- [ ] Focus styles are visible on all interactive elements (no `outline: none` without a replacement)
- [ ] All images have an `alt` attribute (descriptive for content, empty `alt=""` for decorative)
- [ ] All form controls (the account menu trigger, all CTAs implemented as `<button>` or `<a>`) have accessible names
- [ ] Colour contrast ratios meet WCAG AA (4.5:1 for body text, 3:1 for large text and UI components)
- [ ] The page has a "Skip to main content" link as the first focusable element

---

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Visitor arrives with a valid session cookie | Page renders normally; settings icon shows "logged in" menu; no redirect |
| Visitor arrives with an expired session cookie | Page renders as logged-out; expired session is cleared client-side; no auth error shown on the landing page |
| Visitor clicks a CTA with `cta_id=pricing_team_waitlist` | URL routes to `/signup?plan=team_waitlist`; signup form pre-fills nothing; the `plan` param is recorded against the new user record on signup |
| Visitor blocks all third-party cookies / has analytics blocked | Page still renders and is fully usable; analytics events fail silently; no visible error |
| Search-engine bot crawls the page | Page is fully rendered via SSR / pre-render; bot sees real content (not a JS shell); JSON-LD validates; sitemap and robots.txt are present |
| Visitor opens the page in an iframe / embed | Page sets `X-Frame-Options: DENY` (or CSP `frame-ancestors 'none'`) to prevent clickjacking of CTAs |
| Visitor lands with a `utm_*` query string | UTM params are parsed and included in the `recordLandingPageViewed` event; params persist into the signup flow via `localStorage` or signed redirect so attribution survives the page transition |
| Hero illustration / screenshot fails to load | Layout does not break; image area shows the alt text or collapses gracefully without shifting CTA position |
| Visitor on a very wide screen (≥ 2560 px) | Content max-width is capped (e.g. 1280 px) and centred; no comically-wide rows of text |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Public route `/` serves the landing page server-side-rendered or pre-rendered (not a CSR shell) so search bots see real content | Must |
| FR-2 | The landing page is implemented as a new module / package inside the existing blog-generator project (same repo, same deploy, separate directory) | Must |
| FR-3 | Page sections rendered in order: Header → Hero → Features → How-it-works → Social proof (if data available) → Pricing → Footer | Must |
| FR-4 | A settings/gear icon in the header opens a context-aware account menu (US-8) | Must |
| FR-5 | All CTAs route to existing endpoints: `/signup`, `/login`, anchor links (`#features`, `#how-it-works`, `#pricing`), or `/help/ai-detector-rules`. No new auth endpoints are introduced by this epic | Must |
| FR-6 | `<head>` includes the SEO meta, OG, Twitter Card, and JSON-LD per US-7 | Must |
| FR-7 | `/sitemap.xml` and `/robots.txt` are served at the site root | Must |
| FR-8 | Analytics events per US-9 are wired to the existing analytics SDK | Must |
| FR-9 | Performance budget (US-10) is enforced via Lighthouse CI on every PR touching `landing-page/**` paths | Must |
| FR-10 | Responsive layout per US-11; visual-regression snapshots committed | Must |
| FR-11 | Accessibility per US-12; axe-core or equivalent runs in CI and fails the build on serious / critical violations | Must |
| FR-12 | Logged-in users are NOT force-redirected; settings icon surfaces "Dashboard" as the route into the app | Must |
| FR-13 | Pricing tier CTAs include a `plan` query parameter that is captured by `/signup` and persisted with the new user record for future billing wiring | Must |
| FR-14 | UTM params on the landing URL are preserved into the signup flow (via `localStorage` or redirect carry-through) | Should |
| FR-15 | Page sets `X-Frame-Options: DENY` (or CSP `frame-ancestors 'none'`) and `Strict-Transport-Security` headers | Must |

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | LCP (mobile p75) | ≤ 2.5 s |
| Performance | CLS | ≤ 0.1 |
| Performance | INP | ≤ 200 ms |
| Performance | First-paint JS bundle | ≤ 100 KB gzipped |
| Performance | Largest hero image | ≤ 200 KB |
| SEO | Lighthouse SEO score | ≥ 95 |
| SEO | JSON-LD validates with zero errors | Verified by Google Rich Results Test |
| Accessibility | Lighthouse Accessibility score | ≥ 95 |
| Accessibility | axe-core serious / critical violations | 0 |
| Security | Headers — X-Frame-Options, HSTS, X-Content-Type-Options, Referrer-Policy | Present and correct |
| Security | No PII captured on the landing page (no contact forms; CTAs only navigate to auth) | Verified |
| Compatibility | Modern browsers (Chrome / Edge / Firefox / Safari, last 2 major versions) | Full support |
| Compatibility | Older browsers (Safari ≥ 14, Chrome ≥ 100) | Renders without JS errors; graceful degradation acceptable |
| Mobile | Renders at 375 px width without horizontal scroll | Verified |
| i18n readiness | All strings extracted to a single content module (even if English-only in v1) | Verified — sets up Phase 2 multi-language |

---

## Design

### Page Structure (top to bottom)

```
┌─ Header ─────────────────────────────────────────────────────────┐
│  [Logo]            Features  How it works  Pricing      [⚙]      │
└──────────────────────────────────────────────────────────────────┘

┌─ Hero ───────────────────────────────────────────────────────────┐
│                                                                  │
│   H1: Ship blog drafts that don't read like AI.                  │
│   Sub: Generate SEO-ready, authentic-sounding posts in minutes.  │
│   [ Get started — it's free ]   [ See how it works ↓ ]           │
│                                                                  │
│                      [ Product screenshot / illustration ]       │
└──────────────────────────────────────────────────────────────────┘

┌─ Features (4-up grid on desktop) ────────────────────────────────┐
│   [icon] AI Blog       [icon] SEO-Ready     [icon] AI            │
│   Generation           Content              Authenticity Check   │
│   1-line desc          1-line desc          1-line desc          │
│   Learn more →         Learn more →         Learn more →         │
│                                                                  │
│   [icon] Author Profiles                                         │
│   1-line desc                                                    │
│   Learn more →                                                   │
└──────────────────────────────────────────────────────────────────┘

┌─ How it works (4 steps, horizontal on desktop) ──────────────────┐
│   1. Topic & Audience  2. Generate  3. Review SEO + AI  4. Publish│
│   [screenshot]         [screenshot]  [screenshot]       [screenshot]│
└──────────────────────────────────────────────────────────────────┘

┌─ Social proof (only if real data) ───────────────────────────────┐
│   [stat strip OR logo wall OR testimonials]                      │
└──────────────────────────────────────────────────────────────────┘

┌─ Pricing (3-up) ─────────────────────────────────────────────────┐
│   Free          Pro              Team (Coming soon)              │
│   $0/month      $19/month        $49/user/month                  │
│   • feature     • feature        • feature                       │
│   • feature     • feature        • feature                       │
│   • feature     • feature        • feature                       │
│   [Start free]  [Start Pro]      [Notify me]                     │
└──────────────────────────────────────────────────────────────────┘

┌─ Footer ─────────────────────────────────────────────────────────┐
│   Product        Resources           Legal                       │
│   Features       AI Detector Rules   Privacy                     │
│   Pricing        Help                Terms                       │
│   How it works   Changelog (opt)     Cookies                     │
│                                                                  │
│   © 2026 <Company>   hello@<domain>   [social icons if exist]    │
└──────────────────────────────────────────────────────────────────┘
```

### Account Menu (settings/gear icon — top right)

```
Logged out                       Logged in
┌─────────────────────┐         ┌─────────────────────┐
│  Sign in            │         │  Dashboard          │
│  Sign up            │         │  Settings           │
└─────────────────────┘         │  ──────             │
                                │  Log out            │
                                └─────────────────────┘
```

### User Flow — first-time visitor

```
[Visitor arrives at /]
    |
    v
[Hero renders, primary CTA visible]
    |
    +--> [Click "Get started — it's free"]
    |        |
    |        v
    |    [/signup?source=landing_hero]  -- enters auth flow (EP-04)
    |
    +--> [Scroll past hero]
            |
            v
    [Features, How-it-works, Pricing reviewed]
            |
            v
    [Click pricing CTA "Start Pro"]
            |
            v
    [/signup?plan=pro&source=landing_pricing]  -- enters auth flow
```

### User Flow — returning logged-in visitor

```
[Visitor with valid session arrives at /]
    |
    v
[Page renders normally; settings icon shows logged-in menu]
    |
    v
[Click ⚙ → Dashboard]
    |
    v
[/dashboard]  -- enters the dashboard (separate epic, #119)
```

### Wireframes / Mockups

To be produced by the UX Designer before implementation begins. Key screens:

- Hero on desktop (1280 px) and mobile (375 px)
- Features grid (4-up desktop, 2×2 tablet, stacked mobile)
- How-it-works horizontal step layout
- Pricing tiers (3-up desktop, stacked mobile) — with "Coming soon" treatment on the Team tier
- Settings/gear icon menu (both logged-out and logged-in states)
- Footer (multi-column desktop, stacked mobile)

---

## Technical Notes

### Dependencies

| Dependency | Type | Status | Notes |
|------------|------|--------|-------|
| Auth (EP-04 / #95) | Internal | Shipped | Provides `/signup`, `/login`, session detection |
| Existing analytics SDK | Internal | Ready | Same as `recordExportEvent` pattern |
| Existing app frontend stack (React + TypeScript + Vite) | Internal | Ready | Landing module is a new package / folder inside the same project |
| Image optimisation pipeline (WebP / AVIF + JPEG fallback) | Internal | Ready or trivial | Use existing image tooling; if none, add `sharp` or `@vite-plugin/imagetools` |
| Lighthouse CI integration | Internal | New | Add a GitHub Action that runs Lighthouse against a preview deploy on every PR touching `landing-page/**` and fails on score regressions |
| `sitemap.xml` and `robots.txt` generation | Internal | New | Static files or build-time generated; live at the site root |
| Visual-regression test suite | Internal | New (or extend existing) | Per-breakpoint screenshot tests for the landing page; integrated into CI |
| JSON-LD content source | Internal | New | A single TypeScript module that exports the structured-data object, consumed by both the page `<head>` and any future automation |

### Technical Constraints

- **New module in the existing blog-generator project**: the landing page lives as its own directory (e.g. `frontend/src/landing/`) inside the existing blog-generator repo. No new repo, no new deploy. Routing is added to the existing router config.
- **Server-side rendered or pre-rendered**: a pure CSR shell ranks badly. The landing route must serve fully-rendered HTML to bots. If the rest of the app is CSR, the landing route should be pre-rendered at build time (static-site generation) and served as a flat HTML file — this is also the cheapest path to a high Performance score.
- **No new backend endpoints**: the landing page is fully static / pre-rendered. Session detection uses the existing auth cookie / JWT and a small client-side check (the page is identical on the server; the menu toggles after hydration).
- **Content is in a single content module**: every string on the page (headings, descriptions, CTAs, pricing copy) is sourced from one TypeScript / JSON content file. This sets us up for Phase 2 multi-language and keeps copy edits diff-friendly.
- **Lighthouse CI gates merge**: the Performance / SEO / Accessibility budget is enforced at PR time, not discovered post-launch.
- **Pricing is dummy**: no Stripe, no billing logic, no plan-gating in the app. The `plan` query param is recorded on the new user record so we have signup-time intent data when real billing arrives.
- **No PII collection on the landing page**: there are no forms (newsletter, contact, etc.). The page is purely navigational.

---

## Launch Plan

### Rollout Strategy

- **Phase 1 — Soft launch**: deploy to production. Update DNS / routing so `/` serves the landing page (current root behaviour, whatever it is, moves to `/app` or behind auth). Internal team smokes the page. No marketing push.
- **Phase 2 — Public launch**: announce on existing channels (LinkedIn, X, ProductHunt if appropriate). Begin organic SEO indexing window (allow 2–4 weeks for Google to crawl and rank).
- **Phase 3 — Iterate on conversion**: review analytics weekly for the first 4 weeks. Identify the highest drop-off section (likely Features or Pricing) and ship a targeted iteration.

### Rollout Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| New `/` route breaks existing user bookmarks for the app | Detect logged-in session client-side; settings icon shows "Dashboard" prominently; consider also adding a one-time banner for the first N days saying "Looking for your drafts? They're in your dashboard." |
| SEO indexing is slow / page doesn't rank | Submit sitemap to Google Search Console on launch day; expect 2–4 weeks for first impressions; measure organic traffic monthly |
| Lighthouse CI flakiness blocks valid PRs | Allow up to 2 retries before gating; investigate any systematic regressions before relaxing thresholds |
| Real pricing differs from dummy tiers when billing ships | Communicate upfront ("preview pricing"); record `plan` intent at signup so we can grandfather or offer matching tiers when billing arrives |

---

## Resolved Decisions

| Decision | Resolution |
|----------|------------|
| Where the landing page lives | New module inside the existing blog-generator project (same repo, same deploy) |
| Auth dependency | Auth (EP-04 / #95) is shipped; CTAs route to real `/signup` and `/login` from day one |
| Pricing | 3 dummy tiers (Free / Pro / Team-coming-soon); real billing deferred |
| Logged-in handling | No hard redirect; settings/gear icon in header surfaces a context-aware account menu |
| Sequencing | Ships in parallel with the dashboard epic ([#119](https://github.com/mohamednaseramein/blog-generator/issues/119)); both target the same launch window |
| Analytics | Routed through the existing SDK; no new vendor |
| SEO approach | Server-side rendered or pre-rendered (not CSR shell); sitemap, robots, JSON-LD all present |

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Final hero copy (H1 + sub-headline) — needs Head of Product sign-off on positioning | Head of Product | Open |
| Hero illustration vs. real product screenshot — which converts better for v1? | UX Designer + Product Manager | Open |
| Brand voice and visual system — does an existing design system / token set exist, or does this epic also need a baseline brand pass? | Head of Design | Open |
| Domain for hosting — is the landing page served from the same domain as the app (`app.<domain>`), or a separate marketing domain (`www.<domain>`)? Affects routing, cookies, and analytics scope | Tech Lead / Platform | Open |
| Privacy Policy / Terms / Cookie Policy — do these pages already exist, and where? If not, this epic's footer links break. Out of scope to write them, but we need to know whether they exist | Head of Product / Legal | Open |
| Real customer logos / testimonials — do any exist that we can use with permission, or do we ship the placeholder stats strip in v1? | Head of Product | Open |
| Cookie banner / consent — does a global one exist? If not, do we add one as part of this epic or defer? | Head of Security / Compliance | Open |
| Pricing copy — final feature bullets per tier need a pricing-specific sign-off | Head of Product | Open |

---

## Timeline

| Milestone | Target | Status |
|-----------|--------|--------|
| PRD Approved | 2026-05-13 | Pending |
| Tech Design Complete | 2026-05-17 | Pending |
| Wireframes Complete | 2026-05-17 | Pending |
| Dev Complete (MVP — all sections + SEO + analytics + a11y) | 2026-06-01 | Pending |
| QA Complete | 2026-06-04 | Pending |
| Soft Launch (production deploy, internal smoke) | 2026-06-05 | Pending |
| Public Launch | 2026-06-10 | Pending |

---

## Phase 2 — Backlog (Not In Scope for This Release)

| Feature | Rationale for Deferral |
|---------|----------------------|
| Real billing integration (Stripe) | Pricing is dummy in v1; real billing is a separate, larger epic |
| Multi-language landing pages (ES, FR, AR, …) | Content module is i18n-ready; translation + localisation is its own project |
| A/B testing infrastructure | First measure baseline conversion against the single variant; introduce experimentation after we have 4–6 weeks of data |
| Blog / changelog under the landing domain | Adds content scope; consider after launch when there's a content cadence |
| Live chat / customer support widget | Adds tracker weight and support load; revisit when signup volume justifies it |
| Customer logo wall / case study deep-dives | Needs real customers willing to be named; revisit post-launch |
| Newsletter signup form on the landing page | Distracts from the primary signup CTA; if added, A/B test first |
| Animation / motion / scroll-triggered effects beyond the basics | Adds bundle weight and accessibility risk; defer until baseline conversion is healthy |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser | 2026-05-10 | Author |
| Head of Product | | | Pending |
| Tech Lead | | | Pending |
| Head of Design | | | Pending |
