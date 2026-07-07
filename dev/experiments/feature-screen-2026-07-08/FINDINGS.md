# All-eligible multivariate feature screen — the powered closure of entry-selection (2026-07-08)

**P0 of the corrected 2026-07-07 priorities.** Question: over the largest
population we can generate, does ANY decision-time feature — jointly, not
one-at-a-time — predict the counterfactual outcome of an eligible ticket?

**Verdict (screen-rigor calibrated): NO-BUILD DECISION, with power.
Entry-selection tuning for return is closed.** No attribute escalates to
WF-CV. The one both-margins-positive feature (continuous RS magnitude)
already failed the real portfolio test (tiebreak grid REJECT, ledger
2026-06-29) — and this screen explains *why* it had to fail.

## Population

- Generation: `all_eligible_runner --grade-sweep` on
  `top3000-2000-2026-catstop` (26y, top-3000-2000 PIT, delisting-complete
  warehouse rebuilt 2026-07-07), ~21.5h CPU. 884,083 raw (symbol, week)
  breakout firings → 162,632 deduped tickets at grade-F floor (each ridden
  through the counterfactual exit machinery: Stage-3 / stop / end-of-run;
  fixed $10k per ticket).
- Features per ticket (PR #1878): cascade_score, rs_value, rs_trend,
  volume_ratio, weeks_advancing, stage2_late, resistance_quality
  (+ passes_macro).
- Analysis: `feature_screen` exe (PR #1880) — standardized OLS with
  HC1-robust SEs on return_pct, logistic on win, era-split sign stability.
  Complete-case n = **118,729**.

## Base rates (grade-F cell)

| metric | value |
|---|---|
| win rate (return > 0 after exits) | **6.5%** |
| mean return / ticket | +0.63% |
| median return / ticket | **−0.17%** |
| tickets with >100% return | 1,382 (**0.85%**) — these carry essentially all the P&L |

The eligible-population EV is a lottery: median ticket loses, the 0.85%
right tail pays for everything. (Broad-universe junk makes the 6.5% win
rate lower than the 2026-05-07 sp500 read of 11.8% — same shape.)

## Result 1 — return magnitude is unpredictable (the powered null)

OLS of return_pct on all usable features jointly: **R² = 0.0034** at
n = 118,729. No coefficient is convincingly nonzero against the fat-tail
variance (largest |t| = 2.2 among 10 terms, sign-unstable across eras for
the tail categories). `cascade_score` is directionally **negative** (t = −0.7)
once RS/resistance are controlled — the composite score adds nothing beyond
its ingredients. This is the definitive, jointly-fit, large-N version of the
one-attribute-at-a-time nulls (`project_accuracy_is_unreachable`,
score-anti-predictive, decision-audit FAITHFUL): **at entry, per-ticket
return magnitude is noise.**

## Result 2 — win FREQUENCY is predictable, and that is a trap

Logistic on win: in-sample **AUC = 0.745**, with strong z-stats (rs_value
+24, resistance dummies +25–33, rs_trend Positive_rising +10.7). Features
CAN sort which tickets win *more often*.

But compare margins per feature — the frequency-positive features carry
NEGATIVE return coefficients:

| feature | logistic (win freq) | OLS (return) |
|---|---|---|
| rs_trend = Positive_rising | **+0.42** (z +10.7) | **−10.1** (t −2.1) |
| rs_trend = Positive_flat | −0.18 | −8.1 |
| rs_value (continuous) | +0.39 (z +24) | +16.2 (t +1.7, ns) |

Strong-RS-momentum names win more often and win **smaller** — frequency and
magnitude trade off, netting ≈ zero EV (that's why R² ≈ 0). This is the
mechanism behind the 2026-06-29 tiebreak REJECT: RS-primary ranking
preferentially picks extended names → more frequent small wins → taxes the
fat tail → worse Calmar in all 3 grid cells. The screen and the real test
now triangulate: **selection levers that chase win-rate select against the
tail.** (10th-ish independent confirmation of `project_edge_is_the_fat_tail`.)

`rs_value` is the only feature positive on both margins and era-stable
(+/+/+), but its return t-stat is 1.7 (not significant even at n = 119k)
and its portfolio-level implementation is exactly the ranked-Quality
tiebreak the WF-CV grid already rejected. No escalation.

## Result 3 — grade floors work at the bottom, not the top

Cross-grade sweep: per-ticket mean return rises F 0.63% → C 0.73% → B 1.45%
→ A 2.50% while **total PnL stays flat** (~$1.02–1.10B): floors drop
low-EV junk without touching the tail names (which are retained at every
floor). Consistent with the min_grade=C default and with the decision-audit
FAITHFUL verdict at the funding margin. The gradient is real but already
harvested; pushing the floor higher trades breadth (ticket count) for
per-ticket mean at flat total — the capacity question, not a selection one.

## Caveats (screen-rigor)

- **In-sample** fits; AUC/R² optimistic by construction. The null is the
  robust direction (optimism can only overstate signal, and there is none).
- **Complete-case**: 26.9% of tickets lack RS (young/short-history names +
  the warmup artifact, `project_rs_warmup_gap` — ~1.6% of a 26y window).
- **passes_macro degenerate** (all-true): the scanner path ran without
  breadth/A-D inputs → macro never Bearish. Harness note; does not affect
  the within-population regressions (it was excluded as constant).
- **weeks_advancing ≡ 1 by construction** (the scanner fires at the
  Stage1→2 transition) — this population cannot test entry-freshness; that
  axis was separately validated (early_stage2 ≤ 4, 2026-07-06).
- Fixed-$ tickets ≈ selection value, NOT portfolio return (no capacity,
  sizing, or cash interaction).
- Tooling nit: `feature_screen` fails with "singular matrix" on constant
  features instead of dropping them with a warning — small follow-up.

## Forward guidance (the transferable why)

1. **Stop proposing selection levers.** Frequency-sortable ≠ EV-sortable;
   the tail is unpredictable at entry and the tail is the edge. Any future
   "better picks" idea must first answer: does it beat this screen's null
   on the same population?
2. The levers that remain are the ones the frame already names: breadth
   (have), concentration (have), holding discipline (closed —
   weekly-close/vol-stop rejected), **orthogonal layers (barbell — passed
   its grid, still parked)**, and explicit capacity.
3. The win-frequency signal (AUC 0.745) is real but only useful for something
   that VALUES frequency over magnitude — nothing in the current program
   does; do not bolt it onto entry ranking.
