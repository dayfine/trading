# Candidate-universe acceptance test — 2026-08-13

The builder (`trading/backtest/scenarios/candidate_universe/`) rests on one
claim: **dropping a symbol that never became a candidate cannot change the
run.** That claim is not provable from inside the module — it cannot see the
run — so the emitted fixture is a hypothesis until a re-run confirms it. This
is that confirmation.

## Procedure

1. **Capture.** `all_eligible_runner.exe --min-grade F` over the 302-symbol
   `universes/small.sexp`, window 2018-01-02..2023-12-29.
   → 17,751 candidates emitted, 3,707 grade-F rows, **291 distinct symbols**.
   Grade F, not the default C: the fixture must be the superset over *every*
   variant's gate, not just the one the default config admits.
2. **Build.** `pick.exe --capture … --from-universe universes/small.sexp` →
   `universes/small-candidates-2018-2023.sexp`, 291 symbols, 0 unresolved
   sectors.
3. **Re-run.** The same scenario spec, changed only in `universe_path` /
   `universe_size`, against the fixture.
4. **Compare.** Byte-level, every emitted artefact — not just the headline
   metrics.

## Result — every artefact byte-identical

| | baseline | fixture |
|---|---|---|
| universe | `small.sexp`, **302** symbols | `small-candidates-…`, **291** symbols |
| total_return_pct | 65.908134763030574 | **65.908134763030574** |
| total_trades | 288 | **288** |
| win_rate | 33.333333333333329 | **33.333333333333329** |
| max_drawdown_pct | 19.054595721125295 | **19.054595721125295** |
| wall_seconds | 188.040 | 185.352 |

```
actual.sexp        IDENTICAL
trades.csv         IDENTICAL   (288 trades)
equity_curve.csv   IDENTICAL
trade_audit.sexp   IDENTICAL
macro_trend.sexp   IDENTICAL
open_positions.csv IDENTICAL
```

The 11 dropped symbols changed nothing — not one trade, not one point of the
equity curve, not one digit of the return.

`macro_trend.sexp` matching is worth calling out separately: it is direct
evidence that dropping non-candidates does not degrade the macro gate. That was
the exact worry behind the module's original (wrong) decision to union the
index and sector ETFs into every fixture. The measurement settles it where the
argument had gone astray.

## What this does NOT establish

**The saving here is trivial and that is expected.** 302 → 291 symbols, 188s →
185s. The source universe was already small, so almost every symbol became a
candidate at some point. This run validates the *mechanism*, not the payoff.

The payoff case is capturing over a broad universe (top-3000) and pinning the
few hundred symbols the window actually screens; that is the next run, and it is
the one that makes per-mechanism scenarios affordable.

**One window, one config.** The identity was demonstrated for this spec. A
fixture is derived per (window × config family) and each one needs its own
acceptance run — the check is cheap (one extra scenario run) and the builder
emits the provenance header that says which inputs a given fixture belongs to.

## Reproducing

`run.sh` in this directory. Roughly 12 min for the grade-F capture plus ~3 min
per scenario run on the dev container.
