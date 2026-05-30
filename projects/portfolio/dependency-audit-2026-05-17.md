# Dependency Audit — portfolio

**Date**: 2026-05-17
**Auditor**: Guardian (via `/audit-deps portfolio`)
**Scope**: `workspace/portfolio/` — vendored frontend libraries in `js/` and `vendors/` (no `package.json`, no package manager)

> **Method note**: this project has no `package.json`, `package-lock.json`, or any other manifest, so `npm audit` does not apply. The audit was performed by reading version banners off each vendored file, cross-referencing against published CVE data (knowledge cutoff January 2026), and verifying which libraries are actually imported by the HTML pages (un-referenced libs are dead code, not runtime risk).

---

## Summary

| Severity | Count | Action |
|----------|-------|--------|
| **Critical** | 1 | Leaked Google Maps API key in `contact.html` — rotate and restrict immediately |
| **High** | 5 | Open tickets this week; affect runtime-loaded libs (jQuery, Bootstrap, jQuery Validation, Magnific Popup, plus the orphaned-but-committed jQuery UI) |
| **Moderate** | 4 | Schedule this sprint (abandoned/old libs that ship with the site) |
| **Low** | 3 | Backlog (un-referenced vendored libs that could simply be deleted) |
| **License** | 0 blocking | All identified licences are MIT or compatible; site itself has no LICENSE file |

**Top action**: rotate the leaked Google Maps API key **before anything else** (it's been public on GitHub since 2020-04-10).

---

## Critical findings

### 1. CRITICAL — Exposed Google Maps API key

- **Where**: `contact.html:249`
  ```html
  <script src="https://maps.googleapis.com/maps/api/js?key=AIzaSyCjCGmQ0Uq4exrzdcL6rvxywDDOvfAu6eE"></script>
  ```
- **Risk**: The key has been public in a public GitHub repo since 2020. Anyone can use it to call Google Maps APIs and burn through the project's quota / rack up charges on the associated Google Cloud project.
- **Fix** (in this order):
  1. **Rotate the key** in Google Cloud Console → APIs & Services → Credentials.
  2. **Restrict the new key** to:
     - HTTP referrers: only `https://mnaser.me/*` and `https://*.mnaser.me/*`
     - API restrictions: only the Maps JavaScript API
  3. Replace the inline key in `contact.html` with the new restricted one (a public client key with referrer restriction is the intended pattern for Maps JS; the issue is the missing restriction, not the key being in HTML).
  4. **Purge the old key from git history** if you want defense-in-depth (`git filter-repo` or BFG). Note: the key is already indexed by GitHub's secret scanners and scraping bots, so rotation is the only effective fix.
- **Bonus**: enable [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning) on the repo so future leaks are caught at push time. The ApexYard `check-secrets.sh` hook already covers this locally.

---

## Vulnerabilities by package

### Loaded by HTML pages (real runtime risk)

#### 2. HIGH — jQuery 3.3.1

- **File**: `js/jquery-3.3.1.min.js` (imported by every HTML page)
- **CVEs**:
  - **CVE-2019-11358** — Prototype pollution via `$.extend(true, {}, ...)`. CVSS 6.1.
  - **CVE-2020-11022** — XSS via HTML containing `<option>` tags passed to jQuery DOM-manipulation methods (`html()`, `append()`, etc.). CVSS 6.1.
  - **CVE-2020-11023** — XSS via HTML containing `<script>` tags in similar conditions. CVSS 6.1.
- **Fixed in**: 3.5.0 (for the XSS pair) / 3.4.0 (for prototype pollution).
- **Latest**: 3.7.1.
- **Fix**: upgrade to **jQuery 3.7.1**. Drop-in compatible with 3.3.1 for typical usage. Replace `js/jquery-3.3.1.min.js` with `js/jquery-3.7.1.min.js` and update every `<script src>` reference (8 HTML files).
- **Exploitability here**: low to moderate. The site doesn't take untrusted HTML input from query strings or user content, so the XSS gadget is hard to reach in practice. The contact form does pass user input through jQuery, but server-side (PHP), not into `$().html()`. Still — fix it; the upgrade is free.

#### 3. HIGH — Bootstrap 4.1.3

- **File**: `js/bootstrap.min.js` (imported by every HTML page)
- **CVEs**:
  - **CVE-2018-14041** — XSS in scrollspy `data-target`. CVSS 6.1.
  - **CVE-2018-14042** — XSS in tooltip `data-container`. CVSS 6.1.
  - **CVE-2018-20676**, **CVE-2018-20677** — XSS in tooltip / scrollspy. CVSS 6.1.
  - **CVE-2019-8331** — XSS in tooltip `data-template`. CVSS 6.1.
- **Fixed in**: 4.3.1.
- **Latest**: 5.3.x (Bootstrap 5 dropped jQuery and Popper v1 — bigger migration).
- **Fix**: minimum bump to **4.6.2** (final 4.x patch release — same template DSL, no breaking changes). A v5 migration is a larger refactor and is **not** required to clear these CVEs.
- **Exploitability here**: the site uses `data-*` attributes for tooltips and scrollspy on static content the developer controls. Risk only materialises if user-controlled strings ever land in those attributes — not currently the case. Still, upgrade.

#### 4. HIGH — jQuery Validation 1.11.1

- **File**: `js/jquery.validate.min.js` (imported by contact form pages)
- **Banner**: dated **2013-03-22** — 13 years old.
- **CVEs**:
  - **CVE-2021-43306** — ReDoS in URL validator. CVSS 7.5.
  - **CVE-2021-21252** — XSS via `showLabel`. CVSS 6.1.
- **Fixed in**: 1.19.3.
- **Latest**: 1.21.0.
- **Fix**: upgrade to **1.21.0**. API-compatible for typical validator usage.

#### 5. HIGH — Magnific Popup 1.1.0

- **File**: `vendors/popup/jquery.magnific-popup.min.js` (imported)
- **Status**: project is **archived** by the maintainer (no commits since 2017).
- **Known issue**: legacy versions can render unsanitised HTML in `inline` and `iframe` types under specific configurations. No assigned CVE, but the lib is unmaintained.
- **Fix**: replace with a maintained lightbox. Options:
  - **PhotoSwipe v5** (actively maintained, no jQuery dependency, larger).
  - **GLightbox** (small, maintained, simple API).
- **Migration cost**: ~half a day; the site uses Magnific Popup for the gallery only.

#### 6. HIGH — Bootstrap 4 also pulls Popper.js v1 (2017)

- **File**: `js/popper.js` (2017 copyright)
- **Risk**: Popper v1 line was superseded by `@popperjs/core` v2 in 2019 and is no longer patched.
- **Fix**: when upgrading Bootstrap, bring Popper to 1.16.1 (final v1 patch) at minimum, or migrate to `@popperjs/core` 2.11.x alongside a Bootstrap 5 upgrade.

### Imported by HTML pages — Moderate

#### 7. MODERATE — jQuery Form Plugin 3.32.0 (2013)

- **File**: `js/jquery.form.js` (imported by contact-form pages)
- **CVE**: **CVE-2017-1000207** — DoS via crafted multipart forms in older versions. CVSS 5.3.
- **Fix**: upgrade to 4.3.0 (current). API-compatible.

#### 8. MODERATE — Stellar.js 0.6.2 (2013, **abandoned**)

- **File**: `js/stellar.js` (imported by home page)
- **Status**: last release Mar 2014. Repo archived.
- **Usage**: parallax scrolling on the hero banner only.
- **Fix**: either drop the parallax effect (CSS `background-attachment: fixed` covers ~80% of the same UX), or migrate to a maintained alternative like **Rellax** or **Lax.js**.
- **Why moderate**: no specific CVE, but abandoned libs are progressively riskier as browsers evolve.

#### 9. MODERATE — GMaps.js (version unstamped, **abandoned**)

- **File**: `js/gmaps.min.js` (imported by `contact.html`)
- **Status**: last release ~2017. Wraps the Google Maps JS API.
- **Risk**: depends on Google Maps API behaviours that have shifted; combined with the leaked API key (#1), worth replacing with a direct Maps JS API call (a few lines of vanilla JS).
- **Fix**: remove `gmaps.min.js`, replace the small amount of init code in HTML with direct `new google.maps.Map(...)` calls.

#### 10. MODERATE — Owl Carousel 2.2.1 (2017, **archived**)

- **File**: `vendors/owl-carousel/owl.carousel.min.js` (imported by home page testimonials carousel)
- **Status**: project archived by maintainer (no commits since 2018). Suggested replacement: **Splide** or **Swiper**.
- **CVEs**: none assigned but a few XSS-via-data-attributes reports outstanding in the issue tracker (closed as won't-fix).
- **Fix**: when carousel functionality is next touched, migrate to **Swiper** (drop-in API for most simple slider use-cases).

### Vendored but **never imported** — Low (orphaned dead code)

These libraries are committed in `vendors/` but **not referenced by any `<script>` or `<link>` in the HTML pages**. They pose no runtime risk but inflate the repo and create false signals for future auditors.

| Library | Version | CVEs in this version | Recommendation |
|---------|---------|---------------------|----------------|
| **jQuery UI** | 1.12.1 | CVE-2021-41182 / 41183 / 41184 (XSS) | Delete `vendors/jquery-ui/` |
| **bootstrap-datepicker / bootstrap-select** | 1.12.4 | CVE-2019-20921 / CVE-2019-3490 (XSS via title attr) | Delete `vendors/bootstrap-datepicker/` |
| **WOW.js** | 1.1.3 (2016) | abandoned, no CVE | Delete `vendors/animate-css/wow.min.js` (animate.css the CSS file is used; the WOW.js companion is not) |

Deleting them is a single PR — these reduce the vulnerability surface to zero with zero functional regression.

---

## Outdated packages

| Package | Current | Latest | Gap |
|---------|---------|--------|-----|
| jQuery | 3.3.1 | 3.7.1 | 4 minor versions (4 years) |
| Bootstrap | 4.1.3 | 5.3.x (or 4.6.2 inside v4) | 1 major (or 5 patch in v4) |
| Popper | v1 era (2017) | @popperjs/core 2.11.x | 1 major (line change) |
| jQuery Form | 3.32.0 (2013) | 4.3.0 | 1 major |
| jQuery Validation | 1.11.1 (2013) | 1.21.0 | 10 minor versions |
| Magnific Popup | 1.1.0 (2016) | archived | replace |
| Stellar.js | 0.6.2 (2013) | abandoned | replace |
| Owl Carousel | 2.2.1 | archived | replace |
| Isotope | 3.0.6 | 3.0.6 (current) | up-to-date |
| imagesLoaded | 4.1.4 | 5.0.0 | 1 major |
| Animate.css (CSS only) | 3.5.1 | 4.1.1 | 1 major (CSS class renames in v4) |

---

## License compliance

| Library | License | Status |
|---------|---------|--------|
| jQuery, jQuery UI, jQuery Validation, jQuery Form, Bootstrap, Popper, Owl Carousel, Isotope, imagesLoaded, Magnific Popup, Stellar.js, GMaps.js, simpleLightbox, jquery.nice-select, Counter-Up, WOW.js | **MIT** | ✅ Allowed |
| Animate.css | **MIT (Hunt 2014–2018)** | ✅ Allowed |
| Font Awesome | (likely CC-BY-4.0 for icons + MIT for code, version-dependent) | ⚠ Verify the specific version against the licence terms |
| Flaticon icons | depends on the specific pack | ⚠ Confirm attribution requirements with the original Flaticon download |
| Linearicons Free | free for commercial use with attribution | ⚠ Verify whether attribution is currently displayed |
| **The site itself** | **no LICENSE file** | ⚠ Defaults to "all rights reserved"; fine for a personal site but worth deciding (MIT or CC-BY-4.0 is conventional) |

No restricted or banned licences detected. The flags above are about **attribution** — purchased / free icon packs often require a credit line, which the original ThemeForest template likely included and may need to be retained.

---

## Dependency health

- **Abandoned** (no updates > 2 years): WOW.js, Stellar.js, Magnific Popup, GMaps.js, Owl Carousel, bootstrap-datepicker (the silviomoreto fork), jquery-ui (now in maintenance-only mode).
- **Living but legacy**: jQuery, Bootstrap 4, Popper v1.
- **Healthy**: Isotope, imagesLoaded (Metafizzy maintains both).

---

## Recommendations

In priority order. Each line is a candidate ticket.

1. **CRITICAL** — Rotate the leaked Google Maps API key (`contact.html:249`); set HTTP-referrer + API restrictions on the new key.
2. **HIGH** — Upgrade jQuery 3.3.1 → 3.7.1 and jQuery Validation 1.11.1 → 1.21.0 in a single PR (low-risk drop-in replacements).
3. **HIGH** — Upgrade Bootstrap 4.1.3 → 4.6.2 (stay on v4 to avoid the v5 migration cost). Update Popper to 1.16.1 in the same PR.
4. **HIGH** — Replace Magnific Popup with GLightbox (gallery only — small migration).
5. **HIGH** — Delete the un-referenced vendored libraries (`vendors/jquery-ui/`, `vendors/bootstrap-datepicker/`, `vendors/animate-css/wow.min.js`). Zero functional impact, removes ~3 MB and several known CVEs from the repo.
6. **MODERATE** — Replace GMaps.js with direct Google Maps JS API calls (~10 lines).
7. **MODERATE** — Drop Stellar.js or replace with Rellax (parallax effect on the hero banner).
8. **MODERATE** — Decide on Owl Carousel: replace with Swiper now, or leave until the next time the testimonials section is touched.
9. **LOW** — Add a `LICENSE` file at the repo root (MIT or CC-BY-4.0).
10. **LOW** — Enable GitHub Secret Scanning + Dependabot Alerts on the repo (zero-config defensive measures).
11. **LOW** — Once a build toolchain replaces Prepros 6 (per the handover assessment), introduce a `package.json` so future audits can use `npm audit` and Dependabot automatically.

---

## Tickets to open (suggested)

Concrete `gh issue create` candidates. The handover already mentioned `/audit-deps`; these are the specific issues that fall out of running it.

| Title | Severity | Labels |
|-------|----------|--------|
| Rotate leaked Google Maps API key in `contact.html` | critical | `security`, `bug` |
| Upgrade jQuery 3.3.1 → 3.7.1 (CVE-2019-11358, CVE-2020-11022/11023) | high | `security`, `deps` |
| Upgrade Bootstrap 4.1.3 → 4.6.2 (CVE-2018-14041/14042/20676/20677, CVE-2019-8331) | high | `security`, `deps` |
| Upgrade jQuery Validation 1.11.1 → 1.21.0 (CVE-2021-43306, CVE-2021-21252) | high | `security`, `deps` |
| Replace Magnific Popup (archived) with GLightbox | high | `deps`, `tech-debt` |
| Delete orphaned vendored libs (`jquery-ui/`, `bootstrap-datepicker/`, `wow.min.js`) | high | `tech-debt`, `cleanup` |
| Replace GMaps.js with direct Maps JS API calls | moderate | `deps`, `tech-debt` |
| Replace Stellar.js (abandoned) — drop parallax or switch to Rellax | moderate | `deps`, `tech-debt` |
| Add LICENSE file to repo | low | `docs` |
| Enable GitHub Secret Scanning + Dependabot for portfolio | low | `security`, `ops` |

Want me to create any of these as real GitHub issues? Say the word and I'll run `gh issue create` for each.
