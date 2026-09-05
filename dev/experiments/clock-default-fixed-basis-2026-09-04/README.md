# clock-default-fixed-basis-2026-09-04 — `entry_order_max_rest_weeks` {0, 52} on the DEFAULT bundle, fixed basis, paired nulls

The P0 named by `exit-lever-surface-2026-09-04`: the KEEP-52 decision
(`project_clock52_promoted`, ledger `2026-08-27-entry-rest-weeks-surface`)
leans on a **universal maxDD win** measured on the pre-fix simulator. On the
record convention, fixed basis, the clock's maxDD came out **10.8 / 13.0 /
10.8pp worse** on 2019–23 (one MSTR position dominating the book) and flat
on 2000–04. That is a different config base (the record pins several knobs),
so it does not overturn the decision — this chain asks the question on the
base the decision was actually made on.

## Design

- **Build `e4984c5fe`** (pinned worktree `sweep-lever0904`; post-#2648, so
  `sim_exit_fill_next_open` and `stop_skip_entry_bar` are the inherited
  defaults — the fixed basis).
- **Arms**: the clock-surface-2026-08-27 cell-B spec (`clockB-{0,52}`, the
  "broad5y core" default bundle, every v4 axis at its no-op) verbatim for
  2019–23 × top-3000-2019; the cell-C spec (`clockC-{0,52}`) with the period
  swapped to 2000-01-03..2004-12-31 for 2000–04 × top-3000-2000. Each pair
  differs by the name line and `entry_order_max_rest_weeks` only (`specs/`).
- **Cells**: both windows × {0, 52} × salts {0,1,2} = 12 cells, the two arms
  of one window 2-concurrent (`chain.sh`). **Fresh null at every salt** —
  nothing is reused from the pre-fix clock surface.
- **Warehouses**: 2019–23 runs on the **2019-vintage warehouse**
  `/tmp/snap_top3000_2019` (built 2026-09-04 from the CSV store over a superset
  universe incl. `GSPC.INDX`: 2,209 snaps ≈ 76% of the 2019 composition vs 32%
  on the 2000-vintage warehouse —
  `project_warehouse_vintage_coverage`), the first 2019 cells whose LEVEL is
  not survivor-tilted to 2000-era names. 2000–04 runs on
  `/tmp/snap_top3000_dedup_v5thin_adj` (94% of its composition). Cross-window
  levels remain non-comparable.
- Reads: `../exit-lever-surface-2026-09-04/dissect.sh` (closed-trade
  `symbol|entry_date` join) and `unreal.sh` (open-position MTM); every delta
  ex-monster; maxDD from `actual.sexp`.

## Pre-registered decision rule (written before the first cell)

The question is the **maxDD leg** of the KEEP-52 decision, with return /
Sharpe as secondary.

- **maxDD confirmed** if c52's maxDD is ≤ null's at ≥ 2 of 3 salts on BOTH
  windows and never worse by > 3pp at any salt. Then the decision's stated
  basis holds on the fixed basis; record it and stop.
- **maxDD refuted** if c52's maxDD is worse at ≥ 2 of 3 salts on EITHER
  window by > 3pp. Then the decision's stated basis does not hold on the
  fixed basis; the return leg is read ex-monster per salt, and the finding
  goes to the user as a re-open item — this chain does NOT flip the default
  (`experiment-flag-discipline.md` R3, `config-default-blast-radius.md`).
- Anything in between: regime-dependent; record which window carries which
  sign and the named trades behind it.

## Results

_(filled in as cells land — `chain.log`; raw per-arm artifacts under `results/`)_

### Interim — 2019–23 × top-3000-2019 (2019-vintage warehouse), salt 0 (21:00 PDT): the maxDD win holds on the default bundle

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ | stops / laggard / ext |
|---|---:|---:|---:|---:|---:|---:|---|
| c0 (null) | 0.23 | 198 | 0.096 | **41.73** | −136,781 | +153,922 | 144 / 51 / 2 |
| c52 | 20.55 | 204 | 0.298 | **30.07** | +33,798 | +186,602 | 138 / 63 / 2 |

Effective universe 3,000 names (`universe.txt`; 2,208 with bars — the
first 2019 cell not confined to 2000-era survivors). Shared 152 trades drift
**−$12k** (flat); null-only 46 trades −$133k; arm-only 52 trades +$49k. No
lopsided monster — the largest cohort trades are CSIQ (+$43k null-only,
+$46k arm-only: the same name entered a week apart), BBWI +$76k and AAP
+$36k null-only, VRSK +$38k and CVE +$25k arm-only. Equity delta +$203k,
maxDD **−11.7pp** with the clock. This is the promoted claim's shape
(`project_clock52_promoted`: maxDD win, small return win on 5y broad), on
the base it was made on — the record-convention inversion in
`exit-lever-surface-2026-09-04` was the record's pins (MSTR slot effect),
not the fixed basis. Salts 1–2 and 2000–04 decide.

### 2000–04, salt 0 (21:23 PDT): byte-identical to the prior chain — and the chain is trimmed

c0 = 76.64 / 98 / 0.655 / 28.36 and c52 = 73.65 / 91 / 0.642 / 28.48 — both
`trades.csv` files are **byte-identical** to `record-rebase-2026-09-03`'s
`rec5y-2000-new-s0` and `exit-lever-surface-2026-09-04`'s
`xl5y-2000-clock52-s0`. The clock-surface cell-C lineage IS the record
convention (same overrides, clock the only axis), so this window adds
nothing new here beyond a cross-chain determinism tripwire, which passed.
**Chain trimmed after salt 0:** the 2000–04 salts 1–2 are the already
committed `sw5y-2000-b1.0-s{1,2}` (null) and `xl5y-2000-clock52-s{1,2}`
pairs (neutral: realised +$15k / +$4k, maxDD flat); only the 2019–23 pairs
run at salts 1–2 (`chain-v2.sh`).

### 2019–23, salt 1 (21:40 PDT): a near-identical book, maxDD slightly WORSE

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ |
|---|---:|---:|---:|---:|---:|---:|
| c0 (null) | 11.86 | 196 | 0.214 | 32.77 | −48 | +132,305 |
| c52 | 8.96 | 195 | 0.184 | **33.33** | −13,266 | +116,660 |

191 shared trades, drift −$6k; 5 null-only (−$24k) vs 4 arm-only (−$31k) —
the clock removed almost nothing at this salt. Equity delta −$29k, maxDD
**+0.55pp**. Read with salt 0: the null's own maxDD moved 41.7 → 32.8
between salts, so the salt-0 −11.7pp was mostly the null's bad path, not a
property of the clock. 1/2 so far on the primary (maxDD) statistic; salt 2
decides between "confirmed" and "regime/path-dependent".

### 2019–23, salt 2 (21:58 PDT) — chain complete

| arm | return % | trades | sharpe | maxDD % | realised $ | unrealised $ |
|---|---:|---:|---:|---:|---:|---:|
| c0 (null) | 5.40 | 198 | 0.146 | 32.48 | −56,561 | +123,719 |
| c52 | 3.13 | 197 | 0.122 | **32.81** | −65,741 | +110,300 |

193 shared (drift −$4k); the same five null-only (BANR, AVAV, FLEX …) and
four arm-only (CPB, IMGN, TDS …) names as salt 1. Equity −$23k, maxDD
**+0.33pp**.

## Verdict (pre-registered rule)

| window | salt | null maxDD | c52 maxDD | Δ maxDD | Δ equity | shape |
|---|---|---:|---:|---:|---:|---|
| 2019–23 (2019-vintage wh) | 0 | 41.73 | 30.07 | **−11.66** | +$203k | 46 / 52 unique trades; no monster; null's drawdown = 2021-02-16 → 2023-10-23 grind, c52's = 2021-06-08 → 2022-10-26 |
| 2019–23 | 1 | 32.77 | 33.33 | +0.55 | −$29k | 5 / 4 unique trades — near no-op |
| 2019–23 | 2 | 32.48 | 32.81 | +0.33 | −$23k | 5 / 4 unique trades — near no-op |
| 2000–04 (record lineage, from `exit-lever-surface`) | 0 / 1 / 2 | 28.36 / 19.56 / 28.36 | 28.48 / 19.56 / 28.50 | +0.12 / 0.00 / +0.14 | −$30k / −$20k / −$31k | neutral |

- **Not "confirmed"** (c52 better at 1 of 3 salts on 2019–23, never on
  2000–04) and **not "refuted"** (never worse by more than 0.6pp anywhere).
  The rule's middle branch applies: **path-dependent**. The "universal
  maxDD win" leg of the KEEP-52 decision is, on the fixed basis and the
  first level-valid 2019 universe, "**never materially worse, occasionally
  much better**" — a weaker but still true statement, and the 10.8–13.0pp
  *worsening* seen on the record convention does not appear on the default
  bundle: that was the record's pins (the MSTR book-slot effect), not the
  clock.
- **KEEP-52 stands.** No re-open item for the user; the decision's other
  legs (empty default-path radius, weekly live re-issue) are untouched.
  What changes is the wording future writeups may use: cite the clock as a
  drawdown *floor* ("does not add drawdown"), not a drawdown *win*.

### Why the salts disagree

At salts 1 and 2 the clock cancels four or five tickets over five years
and the books are otherwise identical — the default bundle (with
`freeze_entry_at_first_breakout`, anchor 4, `Drop_over_max`) issues few
tickets that rest 52 weeks. At salt 0 the null's path diverged early
(46 null-only entries — BBWI +$76k, AAP +$36k, CSIQ +$43k — vs 52 arm-only)
and then rode a 2021-02 → 2023-10 drawdown to 41.7% that the c52 book, one
ticket lighter in the right weeks, did not: it peaked later (2021-06) and
troughed in 2022-10 at 30.1%. One salt of three is a path lottery, the
same shape as cell A at 26y in the clock surface
(`project_clock52_promoted`: "A = 26y salt-LOTTERY"). The mechanism's
direct footprint is tiny; its portfolio-level effect is whatever the
reshuffled book happens to hold.

### Forward guidance

- Cite the clock for "no added drawdown", not for a drawdown win; the only
  cell where the win was large was a single salt.
- The 2019-vintage warehouse is now the base for 2019-window levels
  (c0 = 0.23 / 11.86 / 5.40 % across salts — the level of the default
  bundle on a 2,208-name 2019 universe is roughly flat; the survivor-tilted
  2000-vintage reads of the same window are not comparable).
- Both chains today reproduced prior cells byte-for-byte across separate
  runs (`rec5y-2000-new-s0`, `xl5y-2000-clock52-s0`): the pinned-worktree
  + committed-params discipline is holding.
