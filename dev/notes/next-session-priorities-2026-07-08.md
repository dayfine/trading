# Next-session priorities — 2026-07-08

**Supersedes** `next-session-priorities-2026-07-07.md` (its corrected P0/P0a/P0b
are now DONE). Main green.

## What 2026-07-07→08 shipped (all merged, 3 gates each)

- **#1877** — corrected the stale P0 (weekly-close stop was already built +
  REJECTED 2026-06-19; stop-tuning thread closed).
- **#1878** — all-eligible/optimal records capture decision-time features
  (rs_value, rs_trend, volume_ratio, weeks_advancing, stage2_late,
  resistance_quality), sexp-backward-compatible.
- **#1879** — RS warmup gap decision note (see Decision items below).
- **#1880** — `feature_screen` exe (standardized OLS + HC1, logistic + AUC,
  era-split; one QC rework cycle — HC1 golden hand-verified, no numerics bug).
- **Data recovery:** ~2014 deleted delisted-name CSVs re-fetched from EODHD
  (99.2%, death-dates verified); warehouse `/tmp/snap_top3000_1998_2026`
  rebuilt (2999 syms). Watch: container `/tmp` is ephemeral — the warehouse
  had been silently lost again; CSVs now persist in repo-root `data/`.

## The P0 RESULT — entry-selection is CLOSED with power

26y × top-3000 all-eligible generation (884k firings → 162,632 tickets,
~21.5h CPU) + joint multivariate screen (n = 118,729):
`dev/experiments/feature-screen-2026-07-08/FINDINGS.md`.

- **Return magnitude: powered null.** Joint R² = 0.0034; cascade_score adds
  nothing beyond RS/resistance (directionally negative).
- **Win frequency IS predictable (AUC 0.745) — and is a trap:** the
  frequency-positive features carry negative return coefficients
  (Positive_rising: +0.42 win-logit vs −10.1 return-pp). Frequency and
  magnitude trade off to ≈ zero EV. This mechanistically explains the
  2026-06-29 RS-tiebreak WF-CV REJECT (chasing win-rate selects against
  the fat tail).
- Base rates: 6.5% win, median ticket −0.17%, 0.85% of tickets (>100%)
  carry all the P&L.
- **Directive: no new selection levers.** Any future "better picks" idea
  must beat this null on the same population first.

## P0 — barbell deployment gates (the passed-but-parked lever, was P1)

The ONLY lever that ever passed a promotion grid (70/30, 2026-06-20), parked
since. Remaining gates: (a) breadth-confirm cell on the top-3000 basis
(warehouse is rebuilt and ready), (b) deployable overlay design (how the
SPY-floor + engine-NAV blend operates live). This is now unambiguously the
highest-value open thread — everything else in the entry/exit/funding space
has been closed with evidence.

## Decision items (human)

1. **Warmup 210→364** (`dev/notes/rs-warmup-gap-2026-07-07.md`): fixes RS
   silently absent for the first 22 weeks of every window/fold (~21% of each
   2y WF-CV fold screens without spine item 7). One constant; re-pins all
   goldens + warehouse rebuilds. Recommend A (bump). Relative experiment
   verdicts stay valid either way.
2. **check_limits wire-or-delete** (carried; DELETE now natural).

## Carried / small

- `feature_screen` nit: constant feature → "singular matrix" failwith;
  should drop-with-warning (bit us on passes_macro/stage2_late/weeks_advancing,
  all constant on this population).
- Scanner path runs macro without breadth/A-D inputs → passes_macro
  degenerate all-true. Harness note; fine for within-population regressions.
- P4 continuous-RS display (live-picks UX only). Note: the screen found
  rs_value is the only both-margins-positive feature — fine for DISPLAY,
  but its ranking use is WF-CV-rejected; don't re-propose.
- Faithful per-week universes (M6.6). Deferred.
- `write_ledger_entry.exe` doesn't regen `index.sexp`.

## Standing constraints (now stronger)

Entry-selection tuning CLOSED (powered joint null, this session); scale-in
closed; reallocation exhausted; envelope closed; stop-tuning closed;
funding-side knobs rotate lottery tickets. Weinstein spine fixed. The open
frontier is exactly: **barbell deployment** + capacity/breadth economics.
