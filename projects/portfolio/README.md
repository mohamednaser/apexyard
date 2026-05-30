# portfolio

**Repo**: https://github.com/mohamednaser/portfolio
**Workspace**: workspace/portfolio/
**Status**: handover
**Tier**: P2

## What it is

Mohamed Naser's personal portfolio site at https://mnaser.me. Static HTML/CSS/JS pages built on a Bootstrap-based ThemeForest template ("MeetMe-Personal" / "Bitmap Photography"), with SCSS compiled by Prepros 6 and a single PHP contact form. Served via GitHub Pages from the `master` branch, with a `CNAME` pointing the custom domain.

## Who owns it

- **Tech Lead**: @mohamednaser
- **Product**: @mohamednaser
- **Stakeholders**: @mohamednaser (sole contributor)

## Tech stack

- Frontend: HTML / CSS / JS (Bootstrap, jQuery 3.3.1, ~11 vendored UI libs)
- Backend: PHP (single `contact_process.php`, currently inert on GH Pages)
- Build: Prepros 6 (commercial GUI; SCSS → CSS)
- Hosting: GitHub Pages with custom domain `mnaser.me`

## Key links

- Production: https://mnaser.me
- Staging: n/a (no staging environment)
- Monitoring: none
- Runbook: n/a
- Roadmap: n/a (post-handover)
- Handover assessment: ./handover-assessment.md
- Architecture (L2): ./architecture/container.md

## Recent activity

- Last release: 2020-04-10 (`ed0349c` — "Create CNAME")
- Last 90 days: 0 commits
- Active milestones: none — sits in `handover` status pending the integration plan in `handover-assessment.md`

## Top risks (from handover)

1. `contact_process.php` — exploitable email-header injection, no CSRF, no input validation, and the recipient is hardcoded to the template author's address (`rockybd1995@gmail.com`).
2. jQuery 3.3.1 has known XSS CVEs (CVE-2020-11022, CVE-2020-11023) — fixed in 3.5.0.
3. Build toolchain is a commercial GUI app (Prepros 6) — cannot run in CI.

See `handover-assessment.md` for the full picture.
