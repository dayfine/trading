# Next-session priorities (2026-05-15) — strategic pivot

Supersedes `dev/notes/next-session-priorities-2026-05-14.md`.

## TL;DR

Two cross-window inversions this week — M5.5 axis-2's 5y→16y blowup
(PR #1086) and today's continuation-buy combined-axis sweep
(PR #1095) — have made the diagnosis explicit:

**Cell E is locally near-optimal on the levers it exposes. The limiting
factor is what the optimizer is looking at, not what knobs we give it.**

Lean broader-first:

- **P0** — broader survivorship-correct universes + walk-forward CV +
  multi-parameter ML tuning. Build the data foundation that lets the
  validation discipline scale beyond single-axis sweeps.
- **P1** — sector-concentration cap + short-side margin Phase 1.
  Useful features in their own right, but no longer load-bearing for
  the next breakthrough. Land them so the multi-parameter optimizer
  can choose to set them, not as human-tuned cells.
- **P2 / defer** — synthetic data, more single-axis sweeps,
  hand-tuned "Cell F" variants.

## P0 — broader-universe + ML-discipline tuning

Treat as a coherent 2-4 week track, dispatched in PR-sized increments.

### Phase 1 — universe extension (~5-10 PRs, 1-2 weeks)

Extend `dev/notes/historical-universe-status-2026-05-13.md` work from
the 510-symbol 2010-2026 universe to a broader / longer cohort:

1. **`sp500-1996-01-01.sexp` membership data.** Mirror PR #1076's
   per-symbol `active_through` columns back to 1996. Need historical
   SP500 membership change-log (likely from Wikipedia changelog via
   PR #813's `Changes_parser` infra). Authority: same hypothesis as
   PR #1076 — survivorship bias inflates losses by ~13 pp CAGR on 16y
   (verified by today's P3-followup data).
2. **`broad-3000-2010-01-01.sexp` cohort.** Expand beyond SP500
   constituents to the full Russell 3000 universe with PI-aware
   active-through data. The current 510-sym universe artificially
   constrains cross-sectional dispersion the Weinstein cascade
   depends on.
3. **Survivorship-correct re-pin of pinned baselines.** Replace the
   current `goldens-sp500-historical/sp500-2010-2026.sexp` pinned
   baseline with one where PI filter is ON by default. Today's
   pinned baseline was measured on survivorship-biased data — every
   downstream tuning conclusion stacks on it.

Track owner: `feat-data` per `dev/decisions.md` 2026-05-03 §"Agent
scope".

### Phase 2 — walk-forward CV harness (~3-5 PRs, 1 week)

The existing `dev/experiments/cell-e-walk-forward-2026-05-08/` has
8 half-period folds. Scale to ~30 rolling folds with explicit
out-of-sample windows. Output a `walk_forward_report.md` per
configuration that surfaces:

- Per-fold Sharpe / CAGR / MaxDD / Calmar.
- Rolling-fold stability (variance across folds).
- Cross-fold parameter sensitivity (does cell X win on every fold or
  just the average?).
- Explicit go/no-go gate: "wins on ≥M of N folds with no fold worse
  than baseline by Δ" — the gate language matters because it's the
  one thing both M5.5 axis-2 and continuation-combined would have
  failed.

Track owner: `feat-backtest`.

### Phase 3 — multi-parameter Bayesian optimizer (~3-5 PRs, 1 week)

Scale up `bayesian_runner.exe` (PR #914) from 4-D bounds to the full
Cell E config knob set (~15-25 tunable parameters). Score on
walk-forward CV from Phase 2, with explicit MaxDD penalty term in
the loss function. Acceptance criterion: converges to a cell that
beats Cell E on walk-forward Sharpe by ≥0.05 with MaxDD no worse.

Track owner: `feat-backtest`.

## P1 — feature work that the optimizer will tune over

These are still wanted as features, but no longer load-bearing for
the next breakthrough. Land them so Phase 3 can choose to set them.

### Sector-concentration cap

Per the prior priorities doc §P4. New config field
`max_sector_exposure_pct : float option`, gate in `portfolio_risk`.
M effort. Touches `Portfolio_risk` (core watchlist — qc-structural
A1 will FLAG, qc-behavioral judges generalizability).

### Short-side margin Phase 1

Per `dev/plans/short-side-margin-2026-05-13.md`. Default-off
`enable_margin_accounting` flag + Reg-T initial/maintenance margin
+ borrow fee. L effort. Touches `Portfolio` (core — same A1 flag
pattern).

The plan's hypothesis (realistic margin makes shorts strictly
negative-EV at current Stage-4 entry edge) is testable after Phase 3
runs — let the optimizer decide if shorts should be on at all.

## P2 / defer

- **Synthetic data with proper statistical attributes** — research
  project (regime switching, fat tails, sector rotations, correlation
  structure). Defer until P0 surfaces a specific failure mode that
  requires synthetic to study. Current Synth-v1/v2/v3 (PRs #755 /
  #775 / #1028) already provide block-bootstrap + HMM-GARCH +
  multi-symbol factor model — sufficient for unit testing but not
  for strategy validation.
- **More single-axis sweeps under Cell E** — explicitly REJECTED.
  See `memory/project_m5-5-tuning-exhausted.md` and
  `memory/project_continuation_combined_rejected.md`.
- **Hand-tuned Cell F variants** — same. Hand-tuning produces
  cells that look good on the eyeballed window and fail validation.
  Pass this work to Phase 3.

## What the user said (2026-05-15)

User framing: "we should lean broader-first; sector cap / margin /
etc. are P1; defer synthetic". This note records the agreement.

## Recommended sequencing

1. **Spin up `feat-data` on Phase 1.1** (1996 membership data) — the
   single most expensive prerequisite. Most other Phase 1 work
   blocks on it.
2. In parallel, **dispatch `feat-backtest` on Phase 2** (walk-forward
   harness) — independent of Phase 1; can run on the existing
   510-sym 2010-2026 universe to start, then re-baseline once Phase 1
   lands.
3. **Sector cap (P1)** is a good "small win" dispatch when you want
   a feature PR on the side of the data-foundation work. It's
   orthogonal to the universe extension.
4. **Margin Phase 1 (P1)** waits until the broader universe lands —
   margin behavior across regimes (2000-2002 + 2008 windows) is the
   point, and those windows need real per-symbol membership data to
   evaluate honestly.

## Open follow-ups still in flight when this was written

- PR #1095 (P3-followup combined sweep, REJECTED on 16y) — awaits
  CI + qc-structural + qc-behavioral. Will merge for the record.
- PI-filter 16y validation experiment — `feat-backtest` agent running
  in background. Tests whether M5.5 axis-2's 16y STOP verdict was
  a survivorship artifact. Once it lands, that data informs Phase 1.3
  (the survivorship-correct re-pin).
