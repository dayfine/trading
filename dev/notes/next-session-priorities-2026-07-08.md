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

## P0 — the floor-quality program (user-directed 2026-07-08; barbell gates PARKED)

**User review of the barbell numbers rejected deploying it as-is.** The 70/30
blend buys Calmar, not wealth: deep 2000-2026 frontier = pure engine 917.9%/37.3%DD
vs 70/30 533.6%/17.8% vs pure timed-SPY floor 386.9%/18.8% — every 10pp moved
to the floor costs ~55pp of 26y return. Worse: the BAH-SPY comparator (394%)
is RAW CLOSE (no dividends); against total-return SPY the 30wk-MA-timed floor
lags outright (whipsaw tax + missed dividends in cash). The floor leg is the
weak component; fix the floor before blending anything.

**P0a — deep re-screen of the faithful short gates (UNBLOCKED, cheap, first).**
#1696 (`neutral_blocks_shorts` Bearish-only + slow-grind gate) screened
NEEDS-DEEP-DATA on 2010-26 (gates admit ~0 shorts; benefit case = 2000-02 +
2008). The blocker was the deep delisted data — **restored 2026-07-07** (2,014
CSVs re-fetched; warehouse `/tmp/snap_top3000_1998_2026` rebuilt, 2999 syms).
Read-only screen on the deep window; also re-run Build2 arming-speed
(`fast_v_arm_on_rate_alone`, #1708) deep re-screen, same unblock.

**P0b — fast circuit-breaker SPY sleeve (design + default-off build + screen).**
A long-only SPY sleeve gated by FAST signals instead of the slow 30wk MA:
ingredients already built + individually validated as detection machinery —
decline-character classifier (Slow_grind/Fast_v, #1692), catastrophic stop
(#1695), A-D-live breadth (default macro basis; confirmed edge IS short-timing,
ledger 2026-06-23), factor-lens edge~forward-DD r=−0.79. Success bar
(standalone, before any blend): **match total-return SPY, cut the left tail**
— not Calmar. Per `experiment-flag-discipline`: default-off mechanism → lens
screen vs TOTAL-RETURN SPY (dividends in — do not repeat the raw-close
comparator mistake) → WF-CV only if promising.

**P0c — only then revisit blending/regime-switching**, with a floor worth
blending (and/or an effective short sleeve as the offset leg). The
regime-barbell screen's +1295% single-path number stays a direction, not a
verdict (2008-concentrated, `project_regime_barbell_direction`).

### Barbell gates (PARKED, was P0)
70/30 passed its grid on worst-cell Calmar/Sharpe — the wrong scoreboard for
the program's return-first objective. Do not run the breadth-confirm cell or
overlay design until P0b produces a better floor; the blend arithmetic is
post-hoc NAV and can be re-run cheaply whenever the legs improve.

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
frontier is exactly: **floor quality (fast circuit breaker + effective
shorts)** → then blending; plus capacity/breadth economics. Scoreboard =
absolute return + start-date robustness with tail control — NOT Calmar
(`project_evaluation_methodology_reframe`); benchmark comparators must be
TOTAL-RETURN (dividends), never raw close.
