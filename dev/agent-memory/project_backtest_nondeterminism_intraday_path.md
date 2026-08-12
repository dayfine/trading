---
name: project-backtest-nondeterminism-intraday-path
description: Armed-StopLimit backtests were nondeterministic until 2026-08-11 (unseeded intraday path RNG) — every armed comparison before the fix carries an unmeasured noise term
metadata: 
  node_type: memory
  type: project
  originSessionId: d7d8f2bb-6b58-4fde-8e01-c50e796e5faa
  modified: 2026-08-12T10:06:40.606Z
---

Until PR #2279 (2026-08-11), **armed-StopLimit backtests returned a different
answer every run.** `Price_path.default_config` had `seed = None`, which selects
`Random.State.make_self_init ()` per generated path; nothing in the backtest
ever supplied a seed. Four runs of one binary on a 6y/302-symbol armed probe:
49.2846 / 50.0589 / 49.3444 / 49.3723 — spread **0.774pp**.

**Why no gate caught it:** market orders fill at the bar's open/close and never
walk the intraday path. Only resting stop/limit orders do — i.e. exactly the
armed-StopLimit entry family, which no golden arms. Goldens were verifiably
bit-identical run to run, so the whole gate surface was blind by construction.
This is the mechanism behind "zero of the 10 golden specs arm that family".

**Fix:** `Market_state` derives the seed from the bar (`Price_path.seed_for_bar`
= ticker + four prices) when none is configured — path is a function of the bar,
noise still independent across bars/symbols. Explicit `seed = Some s` still
wins. Unarmed golden bit-identical pre/post (100.63260509255689), armed probe
now reproducible (48.969233055332253 twice).

**How to apply:** any armed-StopLimit result produced before #2279 — including
the whole ladder-v3 / ladder-v4 program — carries an unmeasured noise term.
Large effects survive on magnitude (v4 cell 09 nearfloor 670.0, cell 10 volconf
−47.6); small ones do not. Before reading any modest cell-to-cell delta as
signal, measure the null at that scale (repeat one cell k times) or re-run on
the fixed build. The ladder-v3-vs-v4 cell-00 gap is **not** attributable to a
code regression on current evidence — the five-commit bisect that chased it
returned per-commit deltas (0.06–1.12pp, n=1 each) sitting inside a 0.774pp
null.

**Verified complete** (2026-08-12): three independent post-fix measurements
agree exactly — 302/6y and 500/5y under the local warehouse, and 500/5y under
CI's committed data (`112.28323995525771` / 240 trades twice, byte-identical
`trades.csv`). An earlier "residual source" claim was my own error: those runs
were built from branches cut off main *before* the fix merged, so they exercised
a pre-fix binary. A determinism check must hold the binary fixed — check
`git log main` for the merge before treating a moving number as a new defect.
The armed-StopLimit golden that closes the gate hole is PR #2291.

Writeup: `dev/notes/backtest-nondeterminism-2026-08-11.md`. Probe spec:
`trading/test_data/backtest_scenarios/experiments/armed-stoplimit-repro-2026-08-11/`
(~3.5 min a run). Related: [[project-faithful-ticket-structural-exclusion]],
[[feedback-run-the-null-control-first]].
