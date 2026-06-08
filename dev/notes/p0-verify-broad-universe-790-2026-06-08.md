# P0 verify — the +790.5% honest broad-universe Cell-E baseline

**Date:** 2026-06-08
**Task:** P0 from `next-session-priorities-2026-06-07.md` — independently
verify the +790.5% top-3000 PIT 15y number, rule out a universe-construction
artifact, and run an apples-to-apples top-1000 comparison on identical
config/window/snapshot.

## TL;DR

The +790.5% **reproduces exactly** and is **not a universe-construction
artifact** — but the headline is **misleading**. Decomposed:

- **~75% of it is terminal unrealized mark-to-market**, ~entirely from a
  **single open position** (AXTI, $2.19→$79.22, ~36×, +$6.8M unrealized) that
  exists **only in top-3000, not top-1000**.
- **Realized-only** return is **+199%** (top-3000) vs **+68%** (top-1000) — the
  breadth effect is **real and ~3×** even after stripping the MTM monster.
- **Both** universes carry **stale/zombie open positions** (delisted names that
  never exit, marked at last close) — a harness correctness gap that inflates
  terminal NAV in every broad-universe run.

**Verdict:** breadth is a genuine lever (wins on *every* metric, halves MaxDD),
but the **+790.5% headline should be retired** in favor of the realized +199%
(or a stale-liquidated NAV). Pin the comparison on a metric a single open
position cannot hijack.

## 1. Apples-to-apples — identical Cell-E config, window, snapshot

Both runs: Cell-E config byte-identical except `universe_path`
(`top-1000-2011.sexp` vs `top-3000-2011.sexp`), same window 2011-01-01..2026-04-30,
same snapshot `/tmp/snap_top3000_2011` (the snapshot is per-symbol bars —
universe-agnostic — so the only variable is which symbols the spec selects).

Universe subset check: top-1000 (980 unique syms) ⊆ top-3000 (2962 unique),
**zero divergence** → same construction, broader N. Artifact ruled out at the
universe level.

| metric | top-1000 | top-3000 |
|---|---|---|
| **total_return_pct** | **142.9%** | **790.5%** |
| realized PnL (totalpnl) | +$682k (+68%) | +$1.998M (+199%) |
| unrealized_pnl | $848k | $6.146M |
| open_positions_value | $2.336M | $8.545M |
| Sharpe | 0.33 | 0.71 |
| **MaxDD** | **58.3%** | **29.2%** |
| Calmar | 0.10 | 0.53 |
| CAGR | 5.96% | 15.33% |
| force_liquidations | 18 | 2 |
| skewness | 12.4 | 5.7 |
| open positions at end | 8 (6 stale) | 9 (8 stale) |

Broadening 1000→3000 improves **every axis**: return, Sharpe, MaxDD (halved
58→29%), Calmar (5×), force-liqs (18→2). The MaxDD halving is the most
important risk finding — consistent with the "breadth = drawdown defense"
thesis (`project_cell_e_2020_stall_regime`, `project_sector_rotation_layer_attribution`).

## 2. Where the +790.5% actually comes from — AXTI

`open_positions.csv` (top-3000) lists 9 positions held at backtest end.
`final_prices.csv` contains **only one** of them — `AXTI,79.22`. The other 8
have **no live terminal bar**: they are stale zombie holds carried at last
close (`stale_holds.sexp`):

| symbol | last live bar | status at end |
|---|---|---|
| AXTI | 2026-04-30 (live, $79.22) | **live — the monster** |
| CPKI | 2011-07-07 | zombie since 2011 |
| GOLD1 | 2018-12-31 | zombie since 2018 |
| MOBI | 2016-11-16 | zombie since 2016 |
| AVID | 2023-11-07 | zombie since 2023 |
| CM / DFS / EBRB / IBN | 2025-05-16 | no bars last ~11 mo |

AXTI: entry $2.19 × 88,347 sh ($193k cost) → mark $79.22 = **$7.0M**,
**+$6.8M unrealized** ≈ the *entire* $6.146M unrealized total. So AXTI alone
drives **+591pp of the +790.5%**. AXTI's $79.22 is a **genuine, verified price** — not a data/split artifact:
`close == adjusted_close` on every row (no splits), metadata `Verified` through
2026-05-01, vol 12.4M, ramping $66→$96 over late-April 2026 (plausibly the
gallium-export semiconductor-substrate move). So the 36× is **real**. But a
result where one open MTM position decides whether you report **+199% or +790%**
is a **single-name tail outcome** (skew 5.72 / kurt 142), not a robust universe
property — *real ≠ robust*. AXTI is in **top-3000
only, not top-1000** → this is literally "breadth = one extra shot at a tail
winner," but the winner is unrealized.

## 3. Harness gap — zombie open positions inflate terminal NAV (secondary)

Delisted/stale symbols are **never exited**; they sit as open positions for
years (CPKI: 15 years) and are **marked at their last available close** in the
terminal NAV. `trading/trading/simulation/lib/stale_hold.ml` is a **detector
only** — it records an `event` when a held symbol's last bar is ≥5 days old, but
emits **no exit**. The position is carried at last close indefinitely.

This affects **both** universes (top-1000: 6 of 8 open are stale; top-3000: 8 of
9), but for top-3000 it is the **secondary** issue: the 8 zombies mark to
~$1.5M of the $8.5M open value; the dominant distortion is the **live** AXTI
($7.0M, §2). Still, before any broad-PIT number is pinned as a golden, the
simulator should **force-exit a position at last close once it goes stale beyond
a threshold** (realistic delisting behavior) so the exit shows up as a realized
trade rather than an indefinite mark. **Filed as issue #1484.**

Note on framing: `total_return_pct` *is* the "liquidate everything at last
available mark" number. It is legitimate **iff** you believe you could exit at
those marks — true for AXTI (liquid, 12M vol) but dubious for delisted zombies.
The point is not that it's "wrong" but that it's **not robust**: strip the one
unrealized AXTI position and it drops +790% → +199%.

## 4. Discrepancy with the priorities-doc 29.6% top-1000 figure

The priorities doc and `macro-bearish-trim-grid-2026-06-07.md` cite
**top-1000 PIT 15y = 29.6% / 42.2% MaxDD / Calmar 0.04**. My identical-config
run gives **142.9% / 58.3% / 0.10**. Same universe file, same window — so the
gap is **data-vintage or config drift** between 2026-06-07 and now (the
snapshot now extends to 2026-05-01; AXTI-class late-window moves changed). The
practical consequence: the priorities-doc framing **"+790.5% vs 29.6% = ~27×
breadth effect" is inflated**. The honest apples-to-apples is **790 vs 143
(~5.5×)**, or **199 vs 68 (~3×) realized-only**. The breadth lever is real;
the magnitude was overstated by comparing against a stale 29.6 baseline.

## 5. Reproduction

```
# specs (Cell-E, identical except universe_path):
#   /tmp/p1verify_t3k/cell-e-top3000-2011-15y.sexp   (universe top-3000-2011, size 3000)
#   /tmp/p1verify_t1k/cell-e-top1000-2011-15y.sexp   (universe top-1000-2011, size 1000)
SNAPSHOT_CACHE_MB=4096 dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
  --dir /tmp/p1verify_t3k --snapshot-dir /tmp/snap_top3000_2011 \
  --fixtures-root test_data/backtest_scenarios --no-emit-all-eligible --parallel 1
```

Fresh re-run on current main (post-#1481): **bit-identical** to last night's
`actual.sexp` — every digit matches (`total_return_pct 790.50019936153831`,
`sharpe 0.71183449635588791`, `max_drawdown 29.176872710358587`,
`open_positions_value 8545223.45`, `force_liquidations 2`, `crashed false`).
829/829 cycles, 0 OOM, RSS bounded. Determinism confirmed.
Last-night reference: `dev/backtest/scenarios-2026-06-08-042448/cell-e-top3000-2011-15y/actual.sexp`;
fresh re-run: `dev/backtest/scenarios-2026-06-08-071339/cell-e-top3000-2011-15y/actual.sexp`.

## 6. Recommendations

1. **Retire the +790.5% headline; report realized +199%** (top-3000) as the
   honest broad-universe baseline. State unrealized/MTM separately.
2. **Liquidate stale/delisted open positions** (or last-close-realize) so
   terminal NAV isn't inflated by zombies — prerequisite for pinning any
   broad-PIT golden. **Filed as issue #1484.**
3. **Re-pin the top-1000 15y baseline** (29.6 vs 142.9 reconcile) before using
   it as the breadth-comparison denominator.
4. **The breadth lever survives all of the above** (realized 3×, MaxDD halved,
   Calmar 5×, force-liqs 18→2) — continue the broad-PIT re-baseline agenda, but
   on realized / stale-corrected metrics and across start years (start-date
   robustness is the primary lens per `evaluation-objective-and-metrics-2026-06-07`).
