# Next-session priorities (2026-05-16) — Option B pivot

Supersedes `dev/notes/next-session-priorities-2026-05-15.md`. Revised
2026-05-16 evening after the Phase 1.1 (EODHD Fundamentals) and Phase
1.4 (IWV scrape) verifications landed. Carries forward all P0/P1/P2/P3
items; the only material change is **Phase 1 sourcing**.

## TL;DR

**Phase 1.1 FAILED at verification (PR #1106).** Our EODHD subscription
is the EOD-only tier; the Fundamentals endpoint returns HTTP 403
across every variant probed. Tier upgrade rejected per the Option B
decision.

**Phase 1.4 PASSED verification (PR #1108).** iShares IWV URL pattern
works HTTP 200 across the full 2006-09-29 → 2026-05-08 range with
byte-identical line-10 headers. Pure HTTP, no auth, free.

**Result — Option B pivot.** Russell 3000 via DIY IWV scrape is now
the **primary** survivorship-correct universe source. SP500 PI 2000-
present via EODHD Fundamentals is parked indefinitely. SP500 1996-1999
tail (fja05680) remains deferred. Strategy can now pin a 20y × 3000-
name baseline that strictly contains every SP500 member.

Strategic posture from 2026-05-15 unchanged: broader-first beats
more-knobs. P2 walk-forward CV (PR #1100 / #1107 landed) and P3
Bayesian optimizer continue on the existing 510-sym 2010-2026
universe in parallel.

Full reasoning + ranked vendor table in
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

## Phase 1 ordering (revised 2026-05-16 evening)

| # | Item | Source | Status |
|---|---|---|---|
| 1.1 | SP500 PI membership 2000-present | EODHD Fundamentals `HistoricalTickerComponents` | **FAILED at verification (PR #1106)** — subscription tier does not include Fundamentals; tier upgrade rejected per Option B. Parked. |
| 1.2 | `broad-3000-2010-01-01.sexp` cohort (sectors.csv proxy) | EODHD + sectors.csv | **MERGED 2026-05-15** (PR #1103); forward-looking-biased; superseded by 1.4 |
| 1.3 | Survivorship-correct re-pin of `sp500-2010-2026.sexp` baseline | derived from 1.1 + PR #1076 active_through | **DEFERRED** until 1.4 lands (no longer downstream of 1.1) |
| 1.4 | Russell 3000 true historical reconstitution | DIY iShares IWV scrape 2006-present | **IN_PROGRESS (PRIMARY PATH)** — URL pattern verified (PR #1108); next step is plan-first dispatch to `feat-data` |
| 1.5 | SP500 1996-1999 tail (optional) | `fja05680/sp500` static seed | Deferred per broader-first pivot |

Recommended dispatch order (revised):

1. **1.4 PR 1 (client)** — plan landed as PR #1109
   (`dev/plans/iwv-scraper-2026-05-16.md`, 4-PR stack). Dispatch
   `feat-data` against the first PR: `ishares_holdings_client.{ml,mli}`
   (cohttp HTTPS GET + CSV decode + pinned fixture). Authority for
   the URL pattern / sentinel / header stability:
   `dev/notes/phase1.4-iwv-url-probe-2026-05-16.md`.
2. **1.4 PR 2-4** — `ishares_membership_replay` →
   `fetch_iwv_history` CLI → `build_iwv_universe` CLI, per the plan.
   Each PR aims for 400-500 LOC. Backfill ~3 hr at 2s polite spacing.
3. **1.3 re-pin** — once 1.4 lands, re-pin the 2010-2026 baseline
   on the IWV-derived Russell 3000 cohort (now wider than SP500,
   so the baseline numbers will differ; this needs fresh
   sign-off, not a like-for-like comparison).

## P2 / P3 / P1 — unchanged from 2026-05-15

- **P2 walk-forward CV** — owner `feat-backtest`; PR #1100 landed the
  first PR; PR #1107 landed the 30-fold rolling extension. Continue
  scaling.
- **P3 Bayesian optimizer** — owner `feat-backtest`; scale
  `bayesian_runner.exe` to full Cell E knob set with MaxDD-penalized
  loss on walk-forward CV.
- **P1 sector cap** — MERGED 2026-05-15 PR #1098 (optimizer can now
  set it).
- **P1 short-side margin Phase 1** — per
  `dev/plans/short-side-margin-2026-05-13.md`.

## P2 / defer

Unchanged. Synthetic data, more single-axis sweeps, hand-tuned Cell
F variants all explicitly deferred. See
`memory/project_m5-5-tuning-exhausted.md` and
`memory/project_continuation_combined_rejected.md`.

## 30-100y data note

The only credible >30y step-up for non-institutional pricing is
**Sharadar via Nasdaq Data Link** ($150–$300/mo personal; SP500
changes since 1957). Deferred until 1.4 proves out at 20y.
Institutional vendors (CRSP/WRDS, Refinitiv, Bloomberg) not viable.
See vendor-comparison doc §Option 4.

## Carry-forward in-flight

- PR #1095 / #1097 / #1098 / #1100 / #1103 / #1105 / #1106 / #1107 /
  #1108 / #1109 — all MERGED.
- PR #1101 (Phase 1.1 Norgate blocker note) — superseded 2026-05-16
  by the vendor pivot; original analysis preserved at the bottom of
  `dev/notes/phase1.1-1996-membership-blocker-2026-05-15.md`.

## What the user said (2026-05-16, evening)

"Option B — IWV scrape is the primary path. No Fundamentals tier
upgrade. Park Phase 1.1; promote Phase 1.4." Phase 1.1 retired;
Phase 1.4 promoted to primary; Phase 1.3 deferred until 1.4 lands.
