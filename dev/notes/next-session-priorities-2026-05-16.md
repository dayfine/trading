# Next-session priorities (2026-05-16) — vendor pivot

Supersedes `dev/notes/next-session-priorities-2026-05-15.md`. Carries
forward all P0/P1/P2/P3 items; the only material change is Phase 1
sourcing.

## TL;DR

**Vendor pivot — Norgate retired.** Norgate's NDU client is
Windows-only; incompatible with our Mac/Linux Docker toolchain.
Replacements:

- **SP500 PI 2000-present:** EODHD Fundamentals API
  (`GSPC.INDX?historical=1`, same client we already use).
- **Russell 3000 2006-present:** DIY iShares IWV scrape (pure HTTP,
  no vendor signup).
- **SP500 1996-1999 (optional):** `fja05680/sp500` static seed.

Full reasoning in
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

Strategic posture from 2026-05-15 unchanged: broader-first beats
more-knobs. P2 walk-forward CV (PR #1100 landed) and P3 Bayesian
optimizer continue on the existing 510-sym 2010-2026 universe while
Phase 1 lands.

## Phase 1 ordering (updated 2026-05-16)

| # | Item | Source | Status |
|---|---|---|---|
| 1.1 | SP500 PI membership 2000-present | EODHD Fundamentals `HistoricalTickerComponents` | Pending 4-item EODHD-tier verification (`dev/status/data-foundations.md` §"Blocking Refactors") |
| 1.2 | `broad-3000-2010-01-01.sexp` cohort (sectors.csv proxy) | EODHD + sectors.csv | **MERGED 2026-05-15** (PR #1103); forward-looking-biased; superseded by 1.4 |
| 1.3 | Survivorship-correct re-pin of `sp500-2010-2026.sexp` baseline | derived from 1.1 + PR #1076 active_through | Pending 1.1 |
| 1.4 | Russell 3000 true historical reconstitution | DIY iShares IWV scrape 2006-present | Pending plan-first; independent of 1.1 |
| 1.5 | SP500 1996-1999 tail (optional) | `fja05680/sp500` static seed | Deferred per broader-first pivot |

Recommended dispatch order:

1. **1.1 verification** — zero-code; hit EODHD dashboard + spot-check
   5 events (LEH 2008, KODK 2009, FB 2013, TSLA 2020, GE 2018). Once
   green, dispatch feat-data.
2. **1.4 IWV scrape** in parallel with 1.1 — spot-curl the URL
   pattern recent + 2010-01-04, then plan-first.
3. **1.3 re-pin** after 1.1 lands.

## P2 / P3 / P1 — unchanged from 2026-05-15

- **P2 walk-forward CV** — owner `feat-backtest`; PR #1100 landed
  first PR; continue scaling to ~30 rolling folds.
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
changes since 1957). Deferred until 1.1 proves out at 30y.
Institutional vendors (CRSP/WRDS, Refinitiv, Bloomberg) not viable.
See vendor-comparison doc §Option 4.

## Carry-forward in-flight from 2026-05-15

- PR #1095 / #1097 / #1098 / #1100 / #1101 / #1103 — all MERGED.
- PR #1101 (Phase 1.1 Norgate blocker note) superseded 2026-05-16
  by the vendor pivot; original analysis preserved at the bottom of
  `dev/notes/phase1.1-1996-membership-blocker-2026-05-15.md`.

## What the user said (2026-05-16)

"Norgate is OUT (Windows-only); EODHD + IWV scrape + fja05680 are
IN." Phase 1.1 re-scoped; Phase 1.4 added.
