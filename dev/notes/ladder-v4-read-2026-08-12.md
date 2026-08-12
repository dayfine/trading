# Ladder-v4: what the run can and cannot tell us — 2026-08-12

**Bottom line: ladder-v4's Stage-A one-axis table supports exactly one of its
conclusions.** The 26y run's noise floor is ~278 percentage points of return,
measured from the sweep's own cells. Every Stage-A delta except volume-confirm's
is smaller than that.

In particular **"cell 09 nearfloor IS the result" is not established**, and an
independent deterministic run at a smaller scale actively reverses it.

## 1. The sweep contains its own null probe

Cells 07 and 08 are **the same configuration expressed two ways**:

| | cell 07 `maxstop50-diag` | cell 08 `sizedown50-diag` |
|---|---|---|
| `stop_width_mode` | `Drop_over_max` | `Size_down` |
| `stop_width_size_down_max_pct` | 0.0 | 0.50 |
| `stops_config.max_stop_distance_pct` | 0.50 | 0.15 |

Per F3's own contract (#2258): `Size_down` moves the drop threshold from
`max_stop_distance_pct` to `stop_width_size_down_max_pct`, and **sizing is
untouched** — fixed-risk sizing already keys off the installed stop in both
modes, so a wide stop mechanically buys fewer shares either way. So:

- Cell 07 admits `stop_distance <= 0.50`.
- Cell 08 admits `<= 0.15` outright plus `0.15 < d <= 0.50` tagged
  `sized_down`, i.e. also `<= 0.50` — and `_gate_and_build` routes both verdicts
  into the same `_size_and_build_entry`. The flag sets an **audit tag**, nothing
  else.

Identical admitted population, identical sizing. **Confirmed empirically:** at
500-symbol/5y on the determinism-fixed build the two cells' `actual.sexp` files
are byte-for-byte identical (`cmp` clean).

### What they returned at 26y/top-3000

| | cell 07 | cell 08 | difference |
|---|---|---|---|
| total_return_pct | 726.24 | 448.08 | **278.16 pp** |
| total_trades | 1442 | 1463 | 21 |
| sharpe_ratio | 0.612 | 0.390 | 0.222 |
| max_drawdown_pct | 34.72 | 42.49 | 7.77 pp |

Two behaviourally identical configurations, one warehouse, one HEAD, one sweep
— **278pp apart**. That is a direct measurement of the 26y/top-3000 noise floor
produced by the unseeded intraday-path RNG
(`dev/notes/backtest-nondeterminism-2026-08-11.md`, fixed in #2279). It is the
number task #3 was going to spend ~5h of dedicated re-runs to obtain; the sweep
had already paid for it.

## 1b. How a one-cent fill becomes 278pp

"Two identical configs differed by 278pp" is not credible on its face, so here is
the divergence traced end to end in the two cells' `trades.csv`. It is not that
the noise is large. **It is that the outcome is a lottery over which five trades
you own, and a cent re-runs the lottery.**

**Step 1 — cent-level fill noise.** Same name, same entry and exit dates,
different fill price:

```
ZIXI 2019-01-29   entry 7.13  vs  7.14
ZIXI 2020-12-23   entry 9.38  vs  9.35
```

**Step 2 — the share count moves.** Fixed-risk sizing keys off entry and stop, so
a cent changes the share count and therefore the cash the position consumes.

**Step 3 — capital is the binding constraint.** The 08-11 dissection counted
13,852 `Insufficient_cash` skips: the funding queue is saturated, and the
tiebreak at the boundary is alphabetical
(`project_screener_alphabetical_tiebreak`). So a few dollars flips *which
candidate gets funded*. That is a discrete branch, not a small perturbation.

**Step 4 — the paths diverge wholesale.** Of ~1,450 trades, only **946 are
shared** (same symbol + entry date). 496 exist only in cell 07, 517 only in cell
08 — a third of the portfolio path differs between two identical configurations.

**Step 5 — and ~half the PnL is five trades.**

| | total PnL | top 5 trades | share of total |
|---|---|---|---|
| cell 07 | $7,017,691 | $3,045,302 | **43.4%** |
| cell 08 | $3,845,171 | $1,931,508 | **50.2%** |

Cell 07 happened to own CIEN +$559,864, BCSI +$372,477, TUPBQ +$366,193, IONS
+$305,836. Cell 08 owned DDS +$408,388, WSM +$351,416, ANF +$318,356, OSPN
+$201,784. Neither *selected* better — they are the same configuration. PnL on
the divergent trades: **$3.56M vs $1.73M**. That $1.8M gap is the 278pp.

This re-derives `project_edge_is_the_fat_tail` from a new direction: the edge is
the fat tail, so anything that changes *which* tail events you fund dominates
everything else a mechanism might do.

### The consequence for the experiment program

Fixing determinism (#2279 and its unfinished follow-up) makes the lottery
**reproducible**, not **representative**. Even on a fully deterministic build,
one 26y run per cell cannot rank cells whose effect is smaller than "changes
which monsters you own" — which is very nearly all of them, since owning one
different monster is worth more than any knob tested so far.

Ranking therefore needs a **distribution per cell**, not a number: multiple
path seeds, rolling start dates (`project_rolling_start_matrix_first_run`), or a
block bootstrap. A single-run 26y ladder is structurally underpowered for the
question it is being asked, and no amount of determinism fixes that — determinism
only stops the same cell from moving between reruns.

## 2. Reading Stage A against that null

Deltas versus cell 00 (343.90):

| cell | 26y return | Δ vs cell 00 | vs the 278pp null |
|---|---|---|---|
| 01 anchor-w8 | 456.65 | +112.7 | **inside** |
| 02 fresh-rangetop | 302.7 | −41.2 | **inside** |
| 03 ttl4 | 278.2 | −65.7 | **inside** |
| 04 ttl8 | 207.3 | −136.6 | **inside** |
| 05 maxstop25 | 402.3 | +58.4 | **inside** |
| 09 nearfloor | 669.98 | +326.1 | marginal (1.17×) |
| 10 volconf | −47.62 | −391.5 | **outside**, plus a sign flip |

Sharpe and drawdown are contaminated in the same proportion — the identical pair
differed by 0.222 Sharpe and 7.8pp of drawdown, which is larger than most of the
Stage-A spread on those axes too.

**Only cell 10 survives.** And it survives on more than magnitude: 3145 trades
against 1136 (2.8×) and average holding 8.4d against 47.8d are
mechanism-scale signatures no path-noise term produces.

**Cell 09 does not survive.** +326pp against a null whose single observed draw
is 278pp is a 1.17× ratio — not a detection at n=1.

## 3. An independent deterministic run reverses cell 09

All 24 v4 cells were re-run on the fixed build at 500-symbol/5y (sp500,
2019-2023, CI's committed bar data) — deterministic, so every number below is
reproducible:

| cell | ret | trades | sharpe | maxDD |
|---|---|---|---|---|
| 00 core-w4 | **112.28** | 240 | 1.105 | 16.98 |
| 01 anchor-w8 | 90.28 | 230 | 0.970 | 13.49 |
| 02 fresh-rangetop | 45.33 | 233 | 0.603 | 21.43 |
| 03 ttl4 | 98.62 | 210 | 1.113 | 12.50 |
| 04 ttl8 | 43.07 | 243 | 0.610 | 19.01 |
| 05 maxstop25 | 65.98 | 267 | 0.785 | 21.46 |
| 07 maxstop50 | 59.36 | 305 | 0.711 | 19.70 |
| 08 sizedown50 | 59.36 | 305 | 0.711 | 19.70 |
| **09 nearfloor** | **38.64** | 207 | 0.531 | 16.23 |
| 10 volconf | −9.96 | 750 | −0.177 | 26.06 |
| 15 rt-ttl4-nearfloor | 24.68 | 138 | 0.403 | 26.35 |
| 16 rt-ttl4-nearfloor-volconf | −9.55 | 250 | −0.462 | 13.51 |

Two sign reversals against the 26y table:

- **Cell 09 goes from best (+95% over cell 00) to worst-but-one (−66%).**
- **Cell 01 goes from +33% to −20%.**

Cell 10 stays catastrophic (−9.96, 3.1× the trades, holding collapsed to 5.8
days) — the same mechanism signature, at a different scale. That consistency is
what a real effect looks like; cells 09 and 01 do not have it.

A scale caveat, stated plainly: 500/5y is a different universe and regime, so
its reversal is **not proof** that nearfloor fails at 26y. It is a second
independent reason not to believe the 26y ranking, alongside the null.

## 3b. The two rankings barely agree — and the control says why

Spearman rank correlation between the 26y single-run ranking and the 500/5y
deterministic ranking, over the 16 cells finished at the time of writing:

**rho = 0.239.**

| cell | rank 26y | rank 5y | move |
|---|---|---|---|
| 00 core-w4 | 10 | **1** | −9 |
| 03 ttl4 | 12 | **2** | −10 |
| 01 anchor-w8 | 6 | 3 | −3 |
| 11 anchor-w8-rangetop | 3 | 4 | +1 |
| 05 maxstop25 | 8 | 5 | −3 |
| **07 maxstop50** | **1** | 6.5 | +5.5 |
| **08 sizedown50** | **7** | 6.5 | −0.5 |
| 06 maxstop35 | 9 | 8 | −1 |
| 02 fresh-rangetop | 11 | 9 | −2 |
| 04 ttl8 | 13 | 10 | −3 |
| 12 rt-ttl4 | 14 | 11 | −3 |
| **09 nearfloor** | **2** | **12** | **+10** |
| 13 rt-nearfloor | 5 | 13 | +8 |
| 15 rt-ttl4-nearfloor | 4 | 14 | +10 |
| 14 rt-volconf | 15 | 15 | 0 |
| 10 volconf | 16 | 16 | 0 |

**Only the two volconf cells hold their rank exactly** (16th and 15th at both
scales). Everything else moves, several by 8-10 places.

A rank disagreement between two scales could in principle be a real
scale/regime effect rather than noise — 26y/top-3000 and 5y/sp500 are genuinely
different problems. **The identical pair separates the two explanations.** Cells
07 and 08 are the same configuration, so their rank gap is pure noise by
construction, and at 26y they land **1st and 7th** — a six-position spread with
zero configuration difference. Whatever fraction of the disagreement is scale,
a large part of it is demonstrably noise.

Note also that all three nearfloor-containing cells (09, 13, 15) move the same
direction, +8 to +10 — they rank much worse at 500/5y. A consistent direction
across three cells is more interesting than a single reversal and is worth a
proper look, but it is a hypothesis about scale/regime, not a verdict: the
500/5y run is one universe and one 5-year window.

## 3c. Nearfloor is a risk mechanism, not a return mechanism

Cell 00 vs cell 09 re-run in a **second independent context** — the 302-symbol
`goldens-small` universe over 2018-2023, three path salts each:

| | salt 0 | salt 1 | salt 2 | mean | range |
|---|---|---|---|---|---|
| 00 core-w4 | 47.3 | 41.5 | 48.1 | **45.6** | 6.6 |
| 09 nearfloor | 25.2 | 24.9 | 24.9 | **25.0** | 0.3 |

Core wins every draw by ~20pp against a draw-spread of at most 6.6pp. Decisive
at this scale — and note nearfloor is remarkably *stable* across draws (0.3pp),
which is itself informative.

### The mechanism signature is consistent everywhere; only the return flips

| context | trades | win rate | maxDD | **return** |
|---|---|---|---|---|
| 26y / top-3000 | 967 < 1136 | 40.4 > 34.0 | 27.0 < 44.3 | **670 > 344** |
| 500 / 5y | 207 < 240 | — | — | **38.6 < 112.3** |
| 302 / 6y | 235 < 291 | 37.9 > 31.4 | 15.2 < 19.1 | **25.0 < 45.6** |

In all three contexts `Nearest` does the same thing: **fewer trades, higher win
rate, lower drawdown.** That is exactly what a better-anchored stop should do —
it is more selective and it cuts risk, and it reproduces across universes,
windows, and path draws. The mechanism is real.

**The return advantage does not reproduce.** It appears in exactly one context,
the 26y single draw — which is the measurement most exposed to the monster
lottery (§1b), and the one whose noise floor we measured at 278pp.

So the honest characterisation is neither "nearfloor is the result" nor
"nearfloor is noise":

> **Nearfloor is a reproducible risk-reduction dial that trades away return in
> every context where we can measure return reliably. Its apparent return edge
> rests on a single draw in the one regime where a single draw means least.**

That reframes what to test. The question is not "does nearfloor make more
money" — two independent contexts say no. It is "is the risk reduction worth the
return it costs", which is a Calmar/Sharpe question, and at 26y its Sharpe was
0.582 vs 0.457 with drawdown 27.0 vs 44.3. That is a genuinely interesting
trade to evaluate — on distributions, in the target regime.

**Caveat, stated plainly:** 26y/top-3000 is the target regime, and neither
smaller context is proof about it. The salted 26y runs (cells 00 and 09 x 3
salts) chained behind the sweep are the test that settles it.

## 4. What survives from the 08-11 reading

- **F5 / volume-confirm is a REJECT** — and the narrower diagnosis stands: the
  defect is the placement waiver, not at-fill confirmation itself. A variant
  keeping the screen-time gate *and* adding fill confirmation was never tested.
- **The mechanism observation under `Nearest` is still real**: `stop_floor_kind`
  moves from 867 `Buffer_fallback` / 558 `Support_floor` to 108 / 1158. Most
  candidates genuinely could not find a qualifying floor under `Window_extreme`
  and fell back to an arbitrary buffer. That is a true statement about stop
  *placement*. What is not supported is the *return* claim attached to it.
- **Capital, not admission, is the binding constraint** (F1 armed adds 1,181
  candidates and moves final trades by 2). That is a count-level observation, not
  a return delta, so the noise term does not touch it.

## 5. What to do next

1. **Nearfloor deserves a real test, not a promotion.** It is a coherent,
   book-faithful stop-placement dial with a verified mechanism. Run it as a
   proper surface on the fixed build under WF-CV → Deflated Sharpe → the
   confirmation grid (`promotion-confirmation.md`). Do not carry the 670.0
   forward as evidence.
2. **Re-run the cells that matter on the fixed build** before any further
   reading of Stage B.
3. **Put a deliberate duplicate cell in every future sweep.** Cells 07/08 were an
   accident — two spellings of one config — and they turned out to be the single
   most informative cells in the run, because they measured the noise floor at
   full scale for free. Make that deliberate: one cell per sweep that repeats
   another exactly. It costs 1/24th of the budget and it is the only thing that
   tells you which of your deltas are real.

## 6. Method note

The 08-11 reading of Stage A was not careless — it dissected mechanisms, checked
`stop_floor_kind` distributions, and correctly flagged the fragility of the 50%
cell. It went wrong at one step: it compared cell returns without ever asking
what two identical cells would return. The sweep contained that experiment
already.

Cross-reference: `feedback_run_the_null_control_first`,
`project_backtest_nondeterminism_intraday_path`.
