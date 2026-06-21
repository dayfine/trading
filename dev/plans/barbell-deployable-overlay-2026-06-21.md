# Barbell deployable overlay — design note (gate #2)

Status: **DESIGN / proposal — needs human greenlight before build** (touches the
strategy/portfolio composition surface; flag per CLAUDE.md "propose well-scoped
refactors to core as decision items").

## Context

The barbell (SPY-timing FLOOR + Cell-E ENGINE) is now validated:
- Promotion grid PASSED — 70/30 robust across period + macro regime (#1670,
  `dev/backtest/barbell-grid-2026-06-20/FINDINGS.md`).
- Breadth-confirm PASSED — 70/30 transfers to top-3000 (6× breadth); optimum
  w∈[0.6,0.8] wherever the engine has edge (#1673,
  `dev/backtest/barbell-breadth-2026-06-21/FINDINGS.md`).

Both results are **post-hoc**: `blend.awk` blends the daily returns of two
*separate* backtests. There is no runnable barbell — no `enable_barbell` config,
no two-strategy capital allocation. Gate #2 makes it deployable.

## Key equivalence (what the validation actually proved)

The validated metric is `r_blend(t) = w·r_floor(t) + (1−w)·r_engine(t)`, NAV
compounded daily. **That is mathematically a 70/30 portfolio of the two strategy
return streams, rebalanced to constant weight every day.** So a deployable
overlay that reproduces the validated numbers (modulo rebalance-transaction cost)
is: *run each strategy on its own capital sleeve; rebalance the two sleeves back
to 70/30 on a cadence.* Daily rebalance = the validated curve exactly; weekly /
monthly = a small tracking drift (cheaper, fewer transfers).

## Two architectures

### Option A — sleeve orchestration (RECOMMENDED)
Two independent strategy runs on split capital, with a periodic rebalance
transfer between them. A new coordinator (e.g.
`trading/trading/backtest/barbell/` or a `simulation` overlay) owns:
- two `Runner`/portfolio instances: sleeve_F (Spy_only_weinstein, capital = w·C),
  sleeve_E (full Weinstein engine, capital = (1−w)·C);
- a rebalance step on cadence: compute each sleeve's NAV, move cash so the split
  returns to w:(1−w) (sell-down the over-weight sleeve's cash / inject to the
  under-weight — only *cash* is transferred, positions untouched);
- a combined NAV/equity-curve + metrics writer.

**Pros:** matches the validated math directly; each sleeve reuses the existing,
already-tested strategy + portfolio code **unchanged** (respects "build
alongside, don't modify core"); the engine sleeve keeps its own position sizing
relative to *its* sleeve capital, exactly as the standalone backtest. **Cons:**
runs two simulators (≈2× compute); needs a clean "transfer cash between two
portfolios" primitive (new, but small and well-scoped).

### Option B — composite STRATEGY (NOT recommended)
One `STRATEGY` that internally runs both sub-strategies and scales/merges their
`transition` lists by the sub-allocation. **Cons:** position sizing in each
sub-strategy reads the *shared* portfolio's cash/NAV, so to split correctly each
sub-strategy must see only its sub-allocation — there is no sub-portfolio view in
the `STRATEGY` interface today (`strategy_interface.mli` exposes one
portfolio_view). Faking it means reimplementing sizing semantics inside the
composite → exactly the kind of core-sizing change the guardrails warn against,
and it would NOT cleanly reproduce the validated independent-sleeve math.

## Recommendation

Build **Option A**. Scope:
1. A `barbell_overlay` coordinator (new module, no core edits) running two
   portfolio/runner instances + a cash-rebalance step on a configurable cadence
   (default weekly; daily reproduces the validated curve).
2. A config behind a **default-off flag** per `experiment-flag-discipline.md`:
   `enable_barbell : bool [@sexp.default false]` + `barbell_floor_weight : float`
   (default the no-op, e.g. 1.0=pure-floor or 0.0=pure-engine so default changes
   nothing) + `barbell_rebalance_weeks : int`. R3 ACCEPT is satisfied by the grid
   + breadth results; the default flip to 70/30 is a *separate* decision.
3. Tests: (a) daily-rebalance overlay reproduces `blend.awk` at w=0.70 within
   tolerance on a known cell; (b) w=1.0 ≡ pure floor and w=0.0 ≡ pure engine
   (backward-compat); (c) a rebalance-cadence sweep shows weekly tracks daily.
4. Deploy guard (from breadth FINDINGS): the engine sleeve must run on an **edge
   universe (SP500/top-3000), never top-1000** — encode as a doc/runtime note,
   not a hard block.

## Open decisions for the human
- Where the coordinator lives (`backtest/barbell/` vs a `simulation` overlay).
- Rebalance cadence default (daily = exact-match but more transfers; weekly =
  cheaper, recommended live default).
- Whether to also expose the floor-weight as a `Variant_matrix` axis (per
  experiment-flag-discipline R2) so 70/30 vs neighbours stays searchable.
- Live-vs-backtest parity: the same coordinator must drive both (the system's
  "same pipeline" principle) — confirm the live path can host two sleeves.
