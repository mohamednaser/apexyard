# portfolio — Handover Assessment

**Date**: 2026-05-17
**Assessor**: Mohamed Naser
**Status**: handover

## Origin

- **Where it came from**: Personal portfolio site, originally authored by Mohamed Naser
- **Original owner**: Mohamed Naser (`mohamednaser` on GitHub)
- **Repo location**: `git@github.com:mohamednaser/portfolio.git` (public, no license)
- **Live URL**: https://mnaser.me (GitHub Pages, custom domain via `CNAME`)
- **First commit date**: 2020 (12 commits total)
- **Last commit date**: 2020-04-10 (no activity in ~6 years)

## Current State

### Tech stack
- Language: HTML / CSS / JavaScript / PHP (one file)
- Runtime: Static site (GitHub Pages) + PHP for contact form
- Framework: Bootstrap-based theme (jQuery 3.3.1 vendored)
- Database: none
- Test framework: none
- CI: none (no `.github/workflows/`)
- Build tool: **Prepros 6** (commercial GUI app, compiles `scss/style.scss` → `css/`) — not CI-friendly

### Build status
- `npm install`: n/a (no `package.json`)
- `npm run build`: n/a — build is performed by the Prepros GUI app outside the repo
- `npm run test`: n/a
- `npm run lint`: n/a

### Test coverage
- Estimated: 0% (no tests exist)

### Repo activity
- Commits in last 90 days: 0
- Commits all-time: 12
- Open issues: 0
- Open PRs: 0
- Top contributors: Mohamed Naser (sole contributor)
- Default branch: `master` (not `main`)
- Disk size: ~22 MB local, ~9.4 MB on GitHub

### Surface area
- 13 SCSS partials in `scss/` → compiled to `css/`
- 11 vendored UI libraries in `vendors/` (animate-css, bootstrap-datepicker, counter-up, flaticon, isotope, jquery-ui, lightbox, linericon, nice-select, owl-carousel, popup) — sources committed, not pinned to versions
- 8 HTML pages at repo root (`index.html`, `about-us.html`, `blog.html`, `contact.html`, `elements.html`, `portfolio.html`, `services.html`, `single-blog.html`)
- 1 PHP file: `contact_process.php`
- `MeetMe-doc/` folder appears to be the original theme's documentation (recycled, ~1 MB) — likely safe to delete
- `prepros-6.config` references the project as `98-MeetMe-Personal` (template origin)

## Quality Risks

### Security — **CRITICAL**

`contact_process.php` has multiple exploitable issues:

1. **Email header injection**: `$from = $_REQUEST['email']; $headers = "From: " . $from . "\r\n";` — an attacker can inject `\r\n` and add arbitrary headers (BCC spam, hijack `Reply-To`, etc.). Classic CWE-93.
2. **XSS in outgoing email body**: `$name`, `$cmessage`, `$csubject` are interpolated into HTML email without escaping.
3. **No CSRF protection**: the endpoint accepts cross-origin POSTs.
4. **`$_REQUEST` instead of `$_POST`**: cookies and GET params can satisfy the inputs, broadening the attack surface.
5. **Hardcoded recipient is `rockybd1995@gmail.com`** — that's the **original theme author's** address, not the owner's. Any visitor who submits the contact form sends mail to a stranger. This is almost certainly a copy-paste oversight from the purchased template.
6. **Endpoint is dead on production anyway**: GitHub Pages serves only static files. `contact_process.php` cannot execute at `mnaser.me/contact_process.php` — the form has been broken for 6 years, and visitors who fill it out see silence.

### Dependencies — known CVEs

- **jQuery 3.3.1** (vendored at `js/jquery-3.3.1.min.js`) is affected by:
  - CVE-2020-11022 (XSS via `.html()` from untrusted sources) — fixed in 3.5.0
  - CVE-2020-11023 — fixed in 3.5.0
- **Bootstrap version unconfirmed** — `js/bootstrap.min.js` is bundled without a version marker; needs identification to check against CVE-2019-8331 and friends.
- Eleven other vendored libraries are similarly un-pinned and un-audited.

### Technical debt

- No `README.md`, no `LICENSE`, no `CONTRIBUTING.md`.
- `MeetMe-doc/` template docs committed alongside source — adds noise to the repo and inflates the search surface.
- `.DS_Store` files committed throughout (`MeetMe-doc/.DS_Store`, root `.DS_Store`).
- Build tool (Prepros 6) is a commercial GUI app; the SCSS → CSS step is not reproducible without a developer running Prepros locally. Cannot wire into CI as-is.
- Default branch is `master`, not `main` — non-blocking but inconsistent with current convention.
- Compiled CSS is committed alongside source SCSS — duplicates source-of-truth.
- The `MeetMe-doc/` and `prepros-6.config` naming reveal the site is built on a purchased ThemeForest template; the `<meta>`, footer copyright, and elements likely still reference the template author. Worth a content audit.

### Operational

- No CI, no automated tests, no linter, no formatter.
- No deploy automation — relies on GitHub Pages serving `master` directly.
- No monitoring, no analytics consent banner, no privacy policy (despite the contact form previously collecting PII).
- No error tracking — even if the PHP form worked, mail-send failures are silently swallowed (`$send = mail(...)` is never checked).

## Integration Plan

### Roles that apply
- `tech-lead` — overall stewardship of changes
- `frontend-engineer` — SCSS/HTML/JS refactors
- `backend-engineer` — replacing or removing `contact_process.php`
- `security-auditor` — first-pass review of the contact form rewrite and the vendored library audit

(No `platform-engineer` or `sre` until we wire in CI and a deploy pipeline — both currently absent.)

### Workflows that kick in
- [ ] PR workflow (`.claude/rules/pr-workflow.md`) — every change goes through a PR (no more direct pushes to `master`)
- [ ] AgDR for technical decisions (build-tool replacement, contact-form replacement)
- [ ] Code Reviewer agent on every PR
- [ ] Security Reviewer agent on the contact-form rewrite specifically
- [ ] `/audit-deps` on adoption and monthly thereafter

### Hooks to enable
- [x] `block-git-add-all`
- [x] `block-main-push` (note: branch is `master`, not `main` — confirm the hook covers `master` or rename the branch)
- [x] `validate-branch-name` — set `ticket_prefix: GH` for this project's tracker
- [x] `validate-pr-create`
- [x] `pre-push-gate`
- [x] `check-secrets`

### CI templates to copy in
- [ ] `golden-paths/pipelines/ci.yml` — adapted for HTML/CSS validation (no JS test stage)
- [ ] `golden-paths/pipelines/security.yml` — Semgrep + secrets detection
- [ ] `golden-paths/pipelines/pr-title-check.yml`

### Registry entry

```yaml
- name: portfolio
  repo: mohamednaser/portfolio
  workspace: workspace/portfolio
  docs: projects/portfolio
  status: handover
  tier: P2
  roles:
    - tech-lead
    - frontend-engineer
    - backend-engineer
    - security-auditor
  tags:
    - personal
    - static-site
    - github-pages
  ticket_prefix: GH
```

## Next Steps

1. **Disarm the contact form immediately.** Either delete `contact_process.php` outright (it's already dead on GH Pages) or replace it with a static form action pointing at a hosted service (Formspree, Netlify Forms, Getform) and **fix the hardcoded `rockybd1995@gmail.com` recipient** before the form is reactivated anywhere.
2. **`/audit-deps portfolio`** — triage the jQuery 3.3.1 XSS CVEs (CVE-2020-11022, CVE-2020-11023) and identify the Bootstrap version + its CVE exposure before any new feature work.
3. **`/decide` on the build toolchain** — replace Prepros 6 (commercial GUI) with `sass` CLI (or Vite) so the SCSS step runs in CI.
4. **Re-enable / introduce CI** — copy in `golden-paths/pipelines/ci.yml` adapted for a static site (HTML lint, SCSS compile, link check).
5. **Write a minimum-viable README** — what the site is, who owns it, how to develop locally, how it deploys (GH Pages from `master` via `CNAME` → mnaser.me).
6. **Audit template attribution** — confirm the purchased theme's licence permits public source publication and that author attribution is preserved where required (the `MeetMe-doc/` folder and SCSS comments may need to stay or be relocated).
7. **`/code-review` a sample diff as Rex** to calibrate review standards before the first real PR lands.
8. **Stakeholder sync with yourself** (you're the sole contributor) — decide whether this is worth keeping as a maintained portfolio site or whether to retire it. If maintained: there's meaningful security work below.

## Post-Handover Checklist

- [ ] Review this assessment (self-review — you're the original author)
- [ ] **Disarm or fix `contact_process.php`** before the first feature PR — this is the top risk
- [ ] **Audit vendored libs** (`/audit-deps`) and upgrade jQuery to ≥ 3.5.0 within the first 2 weeks
- [ ] **Replace Prepros with a CLI build** so CI can compile SCSS
- [ ] Delete committed `.DS_Store` files and add `.DS_Store` to `.gitignore`
- [ ] Decide on the fate of `MeetMe-doc/` (delete vs. relocate as `docs/theme-original/`)
- [ ] Add `portfolio` to the weekly `/stakeholder-update` rollup
- [ ] Onboard the four roles above into the review rotation (in practice: you, in different hats)
- [ ] Add a `LICENSE` file (MIT or CC-BY for a personal site is conventional) — required before accepting external contributions
- [ ] Run `/audit-deps portfolio` monthly for the next 3 months
- [ ] Decide whether to rename `master` → `main` (low effort, brings the repo in line with the rest of the portfolio)

## Open Questions

- Is the contact form expected to work? If yes, what mailbox should it deliver to? (Currently delivers to `rockybd1995@gmail.com` — the template author.)
- Is the site actively used as a portfolio, or is it dormant and only kept live because mnaser.me points at it?
- Is there a newer portfolio (Next.js / Astro / etc.) that should supersede this, or is the intent to revive and modernise this codebase?
- The theme appears to be a ThemeForest purchase ("Bitmap Photography" / "MeetMe-Personal"). Is the licence permissive enough to keep the source public on GitHub?
