# PRD: Portfolio Refactor — Modern AI-Empowerment Positioning

**Status**: Draft
**Author**: Mohamed Naser (acting as Product Manager)
**Created**: 2026-05-17
**Last Updated**: 2026-05-17

---

## Overview

### Problem Statement

The current mnaser.me portfolio is a 2018-era static site built on a purchased ThemeForest template (MeetMe-Personal) using jQuery 3.3.1, Bootstrap 4, and a Prepros 6 SCSS pipeline. Three problems compound:

1. **It misrepresents the person.** The site presents Mohamed as a generic "remote web developer" focused on backend Yii work in 2018. Mohamed is now a technical leader whose differentiator is **empowering engineering teams and projects with AI** (ApexYard, Claude Code adoption, AI-augmented SDLC). The current site signals none of this.
2. **It is technically embarrassing.** A leaked Google Maps API key has been public on GitHub since 2020-04-10. A dead `contact_process.php` is hardcoded to email `rockybd1995@gmail.com` (the template author). jQuery 3.3.1 has known XSS CVEs (CVE-2020-11022, CVE-2020-11023). Bootstrap 4.1.3 has documented CVEs. A technical-leadership portfolio with public security defects is a credibility leak.
3. **Template filler dilutes the real content.** Pages advertise "3D Helmet Design", "2D Vinyl Design", "Architecture / Interior Design / Concept Design" — none of which are Mohamed's services. Testimonials from "Fanny Spencer" are template placeholders. The handful of genuine items (bio, Microverse-fellow testimonials, real photo) are buried.

This matters now because Mohamed's professional positioning has shifted from "remote backend dev" to "technical lead empowering teams with AI." The portfolio is the most-linked artefact in his professional surface area (LinkedIn, GitHub bio, email signature). Every day it stays stale, it actively undersells him.

### Target User

**Primary**: Hiring managers, CTOs, and engineering directors evaluating Mohamed for technical-lead, head-of-engineering, or AI-adoption consulting roles. They land on mnaser.me from a LinkedIn link or GitHub bio, scan for ~30 seconds, and form a "yes / maybe / no" judgement on technical depth and AI fluency.

**Secondary**: Peer engineers and open-source contributors discovering Mohamed via ApexYard, Claude Code work, or other public projects. They want to see what else he ships and whether to follow.

**Tertiary**: Prospective consulting / fractional CTO clients looking specifically for someone who can lead AI adoption in their engineering org.

### Goals

1. **Reposition as an AI-forward technical leader** — within 30 seconds of landing, the visitor understands Mohamed leads engineering teams and is differentiated by deep AI tooling adoption (Claude Code, ApexYard, agentic SDLC).
2. **Preserve 100% of authentic content** — bio narrative, the seven genuine Microverse-era testimonials (from real named individuals: Mohamed Saeed Othman, Mohamed Bakry, and others), and any real project entries. Template filler is dropped.
3. **Eliminate every known security defect** — rotate the leaked Google Maps API key before any new code ships; remove dead PHP; replace jQuery/Bootstrap 4 stack with a modern toolchain that has zero current CVEs.
4. **Modern stack with clean CI** — Astro + Tailwind, deployed via GitHub Actions to GitHub Pages on mnaser.me, with lint + build + Lighthouse checks running on every PR.
5. **Lighthouse ≥ 90 on all four categories** (Performance, Accessibility, Best Practices, SEO) on the production homepage, measured at launch.

### Non-Goals (Out of Scope)

- **CMS or admin UI** — content is authored as MDX in the repo.
- **Auth, accounts, or any user-state features** — the portfolio is a one-way marketing surface.
- **Blog auto-publishing pipeline** — existing blog posts are carried over as MDX; future posts are added manually via PR.
- **i18n / multi-language support** — English only.
- **Lead-gen forms / newsletter subscriptions / analytics-driven funnels** — a single contact route (email link or hosted form like Formspree) is sufficient.
- **Replacing mnaser.me with a new domain** — domain stays, only the implementation changes.
- **Migration of `MeetMe-doc/` template documentation** — gets removed (or relocated to a `docs/theme-original/` if licence requires attribution).
- **A/B testing or analytics-heavy instrumentation** — basic privacy-respecting analytics (e.g. Plausible, GoatCounter) only if it adds < 1 hour to scope.

### Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Lighthouse Performance | ≥ 90 | Lighthouse CI on every PR + production run at launch |
| Lighthouse Accessibility | ≥ 95 | Same |
| Lighthouse Best Practices | ≥ 95 | Same |
| Lighthouse SEO | ≥ 95 | Same |
| WCAG 2.1 AA compliance | 0 critical, 0 serious issues | axe-core CI run + `/accessibility-audit` skill |
| Active high/critical dependency CVEs | 0 | `/audit-deps` weekly cron |
| Leaked secrets in repo | 0 | Existing `check-secrets.sh` hook + manual sweep |
| Page weight (homepage, gzipped) | < 150 KB | Lighthouse + manual `curl --compressed` check |
| Time-to-Interactive (homepage, mobile 4G simulated) | < 2.5 s | Lighthouse |
| Authentic content preserved | 100% of identified items | Manual checklist in PR review |

---

## User Stories

### US-1: First-time visitor forms an AI-tech-leader impression in 30 seconds

> As a hiring manager landing on mnaser.me from a LinkedIn link, I want to understand within 30 seconds that Mohamed is a technical leader specialising in AI-augmented engineering, so that I can decide whether to dig deeper or move on.

**Acceptance Criteria**:

- [ ] Above-the-fold hero on the homepage contains a one-sentence positioning statement that names "technical lead" and "AI" (exact copy TBD in design phase).
- [ ] Hero includes a secondary tagline naming the concrete artefacts (ApexYard, Claude Code adoption work) or links to them.
- [ ] Hero CTA points to either a "How I work with AI" deep-dive page or a contact route — not both, not neither.
- [ ] Page renders meaningful content (LCP) within 2.5 s on simulated mobile 4G.
- [ ] First two screens are intelligible with images disabled.

### US-2: Visitor reads an AI-empowerment narrative with concrete case studies

> As a CTO evaluating Mohamed for an AI-adoption consulting engagement, I want to see 2–3 case studies of him empowering teams with AI, so that I can assess depth and judge whether to reach out.

**Acceptance Criteria**:

- [ ] Dedicated section or page titled along the lines of "How I empower teams with AI" exists and is linked from the homepage and nav.
- [ ] At least two case studies are published, each containing: context (team/project), what was rolled out, how AI was introduced, outcomes, lessons learned.
- [ ] First case study is **ApexYard itself** — a fork-and-govern multi-project framework powered by Claude Code, the system you are reading now.
- [ ] Second case study is a real engagement (specific project Mohamed has done — to be selected during build).
- [ ] Each case study is reachable in two clicks from the homepage and has its own URL (linkable from LinkedIn, etc.).

### US-3: Visitor sees the authentic Microverse-era testimonials

> As a peer engineer evaluating Mohamed's collaboration style, I want to read testimonials from people who have actually worked with him, so that I can trust the technical-lead positioning.

**Acceptance Criteria**:

- [ ] All seven genuine testimonials from the current site are preserved verbatim (modulo typo / grammar fixes).
- [ ] Each testimonial shows the real attributed name (Mohamed Saeed Othman, Mohamed Bakry, etc.) and where known, the context (e.g. "Microverse Ruby cohort").
- [ ] No "Fanny Spencer" or other template placeholder testimonials appear.
- [ ] Testimonials are accessible (keyboard-reachable, screen-reader-friendly, no carousel that auto-rotates without user control).

### US-4: Visitor reads the bio and understands the arc

> As any visitor, I want to read a clear bio that traces Mohamed's path from web developer to technical leader to AI-empowerment specialist, so that I understand the trajectory.

**Acceptance Criteria**:

- [ ] About page (or homepage about section) carries forward the current "5+ years experience, Microverse Ruby fellow, backend developer (Yii)" facts.
- [ ] Bio adds the post-2018 arc: senior engineer → tech lead → AI-augmented engineering focus.
- [ ] Bio names current public artefacts: ApexYard, GitHub profile, any other public projects.
- [ ] Reading time ≤ 90 seconds.

### US-5: Visitor reads existing blog posts without 404s

> As any visitor who arrives via an old blog post link, I want the post to still resolve, so that external inbound links continue to work.

**Acceptance Criteria**:

- [ ] Every blog post present on the current site is preserved at its current path or behind a permanent redirect to the new path.
- [ ] If posts are carried over: each is rendered with reasonable typography, working images, working code blocks.
- [ ] If a post is deemed not worth carrying: it 301s to the closest equivalent or to the blog index, not to a 404.

### US-6: Visitor can contact Mohamed without the dead PHP form

> As any visitor who wants to reach Mohamed, I want a working contact route, so that the path from "interested" to "in touch" is friction-free.

**Acceptance Criteria**:

- [ ] `contact_process.php` is deleted from the repo.
- [ ] Contact page offers at least one working route: hosted form (Formspree / Getform / Netlify Forms) **or** a `mailto:` link to Mohamed's verified email.
- [ ] The hardcoded `rockybd1995@gmail.com` recipient is removed everywhere it appears.
- [ ] If a hosted form is used: an AgDR records the choice + how secrets (form endpoint) are managed.

### Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Visitor lands on `/about-us.html` from a 2018 link | 301 redirect to the new about route (or same path preserved) |
| Visitor lands on `/single-blog.html` (literal template path) | 301 redirect to the blog index, since this was never a real post |
| Visitor disables JS | All pages remain readable and navigable; no JS-only nav |
| Visitor uses screen reader | All images have alt text, all interactive elements have ARIA labels, focus order is logical |
| Visitor on slow mobile network | Above-the-fold content renders before any hero image / large asset |
| Visitor in a region where mnaser.me is geo-blocked (unlikely but theoretical) | Out of scope — GH Pages availability defines reach |
| GitHub Pages outage | Out of scope — accept GH Pages SLA |
| Old Google Maps API key still public after launch | Rotation is a launch-blocking item, not a post-launch task |

---

## Requirements

### Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-1 | Homepage with hero, AI-positioning statement, links to case studies and contact | Must | |
| FR-2 | About page preserving authentic bio + Microverse / Yii / backend history | Must | |
| FR-3 | "How I empower teams with AI" section or page with ≥ 2 case studies | Must | One case study = ApexYard |
| FR-4 | Testimonials section featuring all 7 genuine Microverse-era testimonials | Must | No template placeholders |
| FR-5 | Blog with existing posts carried over as MDX | Must | Preserve URLs or 301 |
| FR-6 | Working contact route (hosted form or mailto), no PHP | Must | |
| FR-7 | Sitemap, robots.txt, Open Graph metadata, structured data (Person + WebSite) | Must | For SEO |
| FR-8 | 404 page that links back to homepage | Must | |
| FR-9 | Light/dark mode toggle | Should | Modern expectation; auto-detect system preference |
| FR-10 | RSS feed for the blog | Should | Astro has this near-free |
| FR-11 | Print stylesheet for the about page (resume-style) | Could | |
| FR-12 | Animated transitions between pages | Could | View Transitions API where supported |
| FR-13 | Privacy-respecting analytics (Plausible / GoatCounter) | Could | Only if cookieless and < 1h to add |

**Priority Key**: Must (required for launch) | Should (important) | Could (nice to have)

### Non-Functional Requirements

| Category | Requirement | Target |
|----------|-------------|--------|
| Performance | Lighthouse Performance score (homepage) | ≥ 90 |
| Performance | Largest Contentful Paint (mobile 4G) | < 2.5 s |
| Performance | Total page weight (homepage, gzipped) | < 150 KB |
| Accessibility | WCAG 2.1 conformance level | AA |
| Accessibility | axe-core critical + serious issues | 0 |
| Security | Active high/critical CVEs in dependencies | 0 at launch, audited weekly |
| Security | Secrets in committed files | 0 (enforced by existing `check-secrets.sh` hook) |
| Security | API keys for client-side services (e.g. Maps, analytics) | Restricted by HTTP referrer to mnaser.me + GH Pages preview domain |
| SEO | Lighthouse SEO score | ≥ 95 |
| SEO | Open Graph + Twitter Card metadata | Present on every page |
| SEO | Structured data (Person, WebSite, BlogPosting where applicable) | Validates in Google Rich Results Test |
| Browser support | Last 2 versions of Chrome, Safari, Firefox, Edge | Functional, no major visual regression |
| Mobile | Usable from 360px viewport upward | All interactive elements ≥ 44×44px tap target |
| Hosting | Deployment target | GitHub Pages, custom domain mnaser.me |
| Build | CI build + lint + Lighthouse run | On every PR + push to main |

---

## Design

### Information Architecture

```
mnaser.me (Home)
├── About (bio + arc + photo)
├── How I empower teams with AI
│   ├── Case study: ApexYard
│   └── Case study: [TBD — real engagement]
├── Projects (concise list with links)
├── Blog
│   ├── /blog (index)
│   └── /blog/<slug> (each post)
├── Contact
└── /404
```

Nav exposes: Home · About · AI · Projects · Blog · Contact. Six items max.

### User Flow — Hiring-manager primary path

```
Land on mnaser.me
    |
    v
Read hero positioning statement (≤ 5 s)
    |
    v
[Decision: stay or bounce]
    |
    +---> Stay: scroll past hero
    |        |
    |        v
    |    Scan about-snippet + AI-section preview + testimonials
    |        |
    |        v
    |    [Decision: dig deeper or contact]
    |        |
    |        +---> Click "How I empower teams with AI"
    |        |        |
    |        |        v
    |        |    Read ApexYard case study
    |        |        |
    |        |        v
    |        |    Click contact route
    |        |
    |        +---> Click contact directly
    |
    +---> Bounce (acceptable; we filter ourselves)
```

### Wireframes / Mockups

To be produced during the Design phase by the UX/UI Designer role. Reference style: clean modern personal site, generous whitespace, monospace accents for technical work, system font stack or one carefully chosen serif/sans pair. Examples to discuss in design review: jasonpamental.com, paulstamatiou.com, brittanychiang.com, leerob.io.

---

## Technical Notes

### Dependencies

| Dependency | Type | Status | Owner |
|------------|------|--------|-------|
| Astro framework | External | Ready (mature, v4+) | — |
| Tailwind CSS | External | Ready | — |
| GitHub Pages | External | Already hosting | — |
| GitHub Actions | External | Already available | — |
| Contact form provider (Formspree or similar) | External | TBD via AgDR | — |
| New AgDR-0001: stack choice (Astro + Tailwind) | Internal | To be written before Build | Tech Lead |
| New AgDR-0002: contact form provider | Internal | To be written before US-6 build | Tech Lead |
| Google Maps API key rotation | External (Google Cloud Console) | Required before launch | Mohamed |

### Technical Constraints

- **Must deploy to GitHub Pages** — preserves mnaser.me without DNS changes. Constrains stack to static-output frameworks.
- **No server runtime** — no Node/PHP/Ruby at request time. Pure static.
- **CNAME file must survive build** — `CNAME` containing `mnaser.me` must end up in the published `dist/` or equivalent.
- **`master` → `main` rename** — current repo default branch is `master`. Rename happens as part of this refactor (low-risk, ApexYard standard).
- **Existing inbound links** — Google has indexed the current site; preserve URLs or 301-redirect aggressively.

### Migration Strategy

1. New stack is built on a long-lived feature branch (`feature/portfolio-refactor`).
2. Content is migrated page-by-page; the current production site stays live on `master` until cutover.
3. At cutover, the feature branch is merged to a new `main` (renamed from `master` in the same PR), and GH Pages is repointed at `main`.
4. The leaked Google Maps API key is rotated **before** the new site ships (independent of stack work — it's a security item).
5. The dead `contact_process.php` is removed in the same merge.

---

## Launch Plan

### Rollout Strategy

- [x] **All users at once** — it's a personal portfolio with no rollout primitives. Cutover happens by merging the refactor branch and repointing GH Pages.
- [ ] Phased rollout — N/A
- [ ] Beta program first — N/A

### Pre-Launch Checklist

- [ ] Rotate the leaked Google Maps API key (security blocker)
- [ ] All Must FRs implemented
- [ ] Lighthouse ≥ 90 on all four categories (verified on a preview deploy)
- [ ] axe-core CI run clean
- [ ] `/audit-deps portfolio` shows 0 high/critical
- [ ] All current blog post URLs either preserved or 301'd
- [ ] CNAME file present in production output
- [ ] 404 page links back to homepage
- [ ] LinkedIn / GitHub bio links still work
- [ ] Open Graph image previews correctly on LinkedIn + Slack + Twitter
- [ ] Mobile usability check on real iPhone + real Android device

### Post-Launch

- Monitor Plausible / GoatCounter for the first 7 days.
- Watch for 404s in GH Pages access logs (if available) or via Search Console.
- `/audit-deps portfolio` becomes a weekly cron via existing `/loop` infrastructure.

---

## Open Questions

| Question | Owner | Status | Resolution |
|----------|-------|--------|------------|
| Which second case study (beyond ApexYard)? | Mohamed | Open | Decide during build of US-2 |
| Contact form provider — Formspree vs Getform vs mailto-only? | Tech Lead (AgDR) | Open | AgDR-0002 |
| Is the ThemeForest licence permissive enough to keep `MeetMe-doc/` history in git? | Mohamed | Open | If unclear, scrub the dir on rename to `main` |
| Should the current Google Analytics tag (if any) be removed in favour of Plausible / GoatCounter? | Mohamed | Open | Resolve during US-1 build |
| Carry forward the existing photograph or commission a new one? | Mohamed | Open | Resolve during design phase |
| Rename repo from `mohamednaser/portfolio` to something more on-brand (e.g. `mnaser-me`)? | Mohamed | Open | Out of scope; defer |

---

## Timeline

Indicative only — single-contributor project, real dates depend on Mohamed's availability.

| Milestone | Target Date | Status |
|-----------|-------------|--------|
| PRD Approved | 2026-05-19 | Draft |
| AgDR-0001 (stack) approved | 2026-05-19 | Pending |
| Tickets created on `mohamednaser/portfolio` | 2026-05-20 | Pending |
| Design phase complete (wireframes + content outline) | 2026-05-24 | Pending |
| Build phase complete (all Must FRs) | 2026-06-07 | Pending |
| QA + Lighthouse + accessibility audit clean | 2026-06-09 | Pending |
| Google Maps API key rotated | 2026-06-09 (blocker) | Pending |
| Cutover to new site live on mnaser.me | 2026-06-10 | Pending |

---

## Approvals

| Role | Name | Date | Status |
|------|------|------|--------|
| Product Manager | Mohamed Naser | 2026-05-17 | Author |
| Head of Product | Mohamed Naser | — | Pending |
| Tech Lead | Mohamed Naser | — | Pending (will sign on AgDR-0001) |
| Head of Design | Mohamed Naser | — | Pending |

---

## Appendix A — Authentic content inventory

Items that **must** carry over to the new site (verbatim, modulo grammar / typo fixes):

**Bio facts**:
- 5+ years experience in web development (as of original writing; should be uplifted in new copy)
- Microverse Ruby program fellow
- Backend developer, Yii framework experience
- Full-stack remote web developer

**Testimonials** (all from `index.html` of current site; attributions preserved where present):
- "Mohamed has an impressive problem solving skills coupled with…" — attributed
- "Mohamed is a really motivated person, he has proved to me that…" — attributed
- "student fellow with Mohamed while learning about Ruby at the Microverse program. I think Mohamed can be a great asset for…" — **Mohamed Saeed Othman**
- "Nasser as we call him is a very skilled backend developer…" — attributed
- "Naser one of the best web developers ever, and he geek in yii…" — **Mohamed Bakry**
- "Mohamed is a committed person who tries his best to finish his…" — attributed
- "Mohamed is very good challenger and has a very friendly…" — attributed
- "Mohamed Is a very creative character and an important part in…" — attributed
- "Mohamed one of the most successful keys that supported…" — attributed

Items to **drop** (template filler, not authentic to Mohamed):
- "3D Helmet Design", "2D Vinyl Design", "Creative Poster Design", "Embosed Logo Design", "3D Disposable Bottle", "3D Logo Design" — these are template designer-portfolio entries.
- "Architecture / Interior Design / Concept Design" services — these are not Mohamed's services.
- "Fanny Spencer" testimonials — template placeholders.
- "Proud To Collaborate With Awesome Companies" client logo strip — unless Mohamed has actual client logos to put there.
- Newsletter signup widget in footer — out of scope (FR-10 RSS replaces this).
