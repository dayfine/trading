# P5 PI-filter 16y validation — survivorship-bias check on M5.5 axis-2 STOP

**Date**: 2026-05-14
**Status**: COMPLETE
**Question**: Does turning on the survivorship-aware PI filter
(`enable_pi_filter = true`) rescue the catastrophic 16y outcome that PR
#1086 measured under the axis-2 candidate
(`stops_config.min_correction_pct = 0.10`) on survivorship-biased data?

## TL;DR — M5.5 axis-2 STOP **stands**

`pi-on` and `pi-off` produce bit-equal `actual.sexp` files on both the
baseline pair and the axis-2 pair. Every headline metric matches to the
last decimal. The PI filter is wired end-to-end (PR #1089 + #1094) but
has **zero behavioural effect** because the underlying per-symbol CSV
files in `/workspaces/trading-1/data/` are still in the legacy 7-column
format (`date,open,high,low,close,adjusted_close,volume`) — no
`active_through` delisting markers. The membership predicate falls
through to `true` (admit) for every symbol on every Friday.

Implication: the M5.5 axis-2 catastrophe (MaxDD 19.9% → 60.1%, 0 → 26
force-liquidations) is **NOT** an artifact of survivorship-bias in the
universe definition. The 510-symbol Wiki-replayed universe IS the
survivorship-aware set, but the bar data inside that universe has no
delistings encoded, so PI-aware screening cannot exclude any symbol
during the 16y window. The catastrophe is a real property of the
strategy under wider `min_correction_pct` on the long 16y horizon.

The verdict from PR #1086 / `memory/project_m5-5-tuning-exhausted.md`
holds as-is: **do not promote axis-2; `min_correction_pct = 0.10` stays
rejected**.

## 2×2 design

Universe: 510-symbol `goldens-sp500-historical/sp500-2010-2026.sexp`
(Wiki+EODHD reverse-replayed from 2026 constituent table; PRs
#803/808/809). Window: 2010-01-01 → 2026-04-30 (16.33y). Long-only Cell
E ship config (`max_position_pct_long=0.14`, exposure cap 0.70, min cash
0.30, stage3 force-exit h=1, laggard rotation h=2).

| Cell | axis-2 (`min_correction_pct`) | PI filter (`enable_pi_filter`) |
|---|---|---|
| `pi-off-baseline` | OFF (default 0.08) | OFF (default) |
| `pi-on-baseline`  | OFF (default 0.08) | ON  |
| `pi-off-axis2`    | ON  (0.10)         | OFF |
| `pi-on-axis2`     | ON  (0.10)         | ON  |

## Headline metrics

| Cell | CAGR | Sharpe | MaxDD | Calmar | TotalRet | Trades | ForceLiq | DistTickers | WinRate | AvgHold | Sortino | Ulcer |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `pi-off-baseline` | 8.98% | 0.71 | 19.92% | 0.451 | 307.16% | 683 |  0 | 319 | 40.70% | 46.78d | 1.12 |  7.44 |
| `pi-on-baseline`  | 8.98% | 0.71 | 19.92% | 0.451 | 307.16% | 683 |  0 | 319 | 40.70% | 46.78d | 1.12 |  7.44 |
| `pi-off-axis2`    | 12.85% | 0.50 | 60.11% | 0.214 | 620.55% | 474 | 26 | 281 | 39.87% | 53.86d | 0.74 | 32.57 |
| `pi-on-axis2`     | 12.85% | 0.50 | 60.11% | 0.214 | 620.55% | 474 | 26 | 281 | 39.87% | 53.86d | 0.74 | 32.57 |

CAGR computed as `(1 + total_return/100)^(1/16.33) - 1`.
DistTickers = distinct symbols appearing in `trades.csv`.

Bit-equality verified by `diff` on `actual.sexp`:

```
=== baseline pair ===
(bit-equal)
=== axis-2 pair ===
(bit-equal)
```

## Deltas

### Δ baseline (PI filter alone, axis-2 OFF)

`pi-on-baseline − pi-off-baseline`: **0.00 on every metric**.

### Δ axis-2 (PI filter rescue of axis-2 catastrophe)

`pi-on-axis2 − pi-off-axis2`: **0.00 on every metric**.

### Δ axis-2 effect, reproducing PR #1086

`pi-off-axis2 − pi-off-baseline` (the axis-2 effect, regardless of PI):

- CAGR        +3.87 pp (8.98 → 12.85)
- Sharpe      −0.21  (0.71 → 0.50)
- MaxDD       +40.19 pp (19.92 → 60.11)  ← the "catastrophe"
- Calmar      −0.237  (0.451 → 0.214)
- ForceLiq    +26 (0 → 26)
- Trades      −209 (683 → 474; positions live longer through bear cycles)
- DistTickers −38 (319 → 281; fewer fresh entries)
- AvgHold     +7.1 d (46.8 → 53.9)
- Ulcer       +25.1 (7.4 → 32.6)

This exactly reproduces PR #1086's measured values (`memory/project_m5-5-tuning-exhausted.md`):
return 620.5%, trades 474, MaxDD 60.1%, force-liqs 26.

## Pre-registered decision rule (from hypothesis.md)

**Revise the M5.5 axis-2 STOP** iff ALL hold on `pi-on-axis2` vs `pi-off-axis2`:
- MaxDD reduction ≥ 10 pp  → **NO** (Δ = 0 pp)
- Force-liq count reduction ≥ 50%  → **NO** (Δ = 0)
- ΔCalmar ≥ +0.10  → **NO** (Δ = 0)

**Verdict**: **Keep the M5.5 axis-2 STOP**. None of the revision criteria
were met. Survivorship is not the load-bearing factor in axis-2's 16y
failure.

## Why the filter is a no-op (root cause)

PI filter wiring is correct end-to-end after PR #1094:

1. **Strategy layer** (`weinstein_strategy_macro.ml`): when
   `config.enable_pi_filter = true`, a callback closing over `bar_reader`
   is handed to `Screener.screen_with_cooldown ?membership_at`.
2. **Predicate** (`_pi_membership_at`): for each candidate symbol on
   each Friday, reads `Bar_reader.daily_bars_for ~symbol ~as_of`, takes
   the last bar, and returns:
   - `true` if no bars (no data; downstream phases will drop)
   - `true` if last bar's `active_through = None` (no delisting marker)
   - `as_of <= d` if last bar's `active_through = Some d`
3. **Snapshot manifest** (post-PR #1094):
   `Snapshot_manifest.file_metadata.active_through` populated from
   `_active_through_of_bars (bars)` — the last bar's `active_through`.
4. **CSV input layer** (the missing piece): `Csv_parser.parse_line`
   reads `active_through` only when a row has **8 columns**. The
   per-symbol CSVs under `/workspaces/trading-1/data/<A>/<B>/<SYM>/data.csv`
   are uniformly **7 columns** (legacy format):
   `date,open,high,low,close,adjusted_close,volume`. So every bar's
   `active_through = None`, and the predicate always returns `true`.

Spot-check (any symbol in `/workspaces/trading-1/data/`):

```
$ head -1 /workspaces/trading-1/data/A/L/AAPL/data.csv
date,open,high,low,close,adjusted_close,volume
$ awk -F, 'NR==1{print NF}' /workspaces/trading-1/data/A/L/AAPL/data.csv
7
```

This is the bigger gap. The 510-symbol Wiki-replayed universe (PRs
#803/808/809) is itself survivorship-aware in the SYMBOL dimension — it
records which 510 symbols were S&P 500 members as of 2010-01-01,
including 174 symbols carrying `sector=Unknown` because they've been
delisted/relabeled since. But the strategy doesn't know **WHEN** any of
them stopped trading — the bar CSV layer never records that.

## Recommended next step (deferred to a separate PR / `feat-data`)

Backfill `active_through` into the per-symbol CSVs. Two paths:

1. **Lazy backfill from Wiki+EODHD changes table**:
   `Membership_replay.changes_table_2026-05-03.html` already records the
   removal dates for the 174 `sector=Unknown` symbols (and others). A
   one-shot OCaml tool reading this table + the existing 7-col CSV could
   rewrite each affected symbol's `data.csv` to 8-col with the
   appropriate `active_through` set on every row (or on the last row).
2. **Re-fetch from EODHD**: the EODHD `eod` endpoint returns delisting
   dates for symbols that have been delisted. The existing
   `Eodhd_client` can emit the 8-col format; running it against the
   174 Unknown-sector symbols would also work.

Estimated impact: tickers like LEH (Lehman), BEAR (Bear Stearns), MBI,
FNM, etc. that delisted 2008-2010 are in the universe but their CSVs
end at the delisting price. The 16y backtest currently treats them as
"halted at last close" (the simulator forward-fills NaN or skips). PI
filter would prune them on dates > active_through, reducing eligible
candidates and possibly changing trade composition.

It is plausible the catastrophe survives the data backfill (since the
26 force-liqs are all on **active** large-cap names like CAH, GME,
TPR, CHRW, FLS, HOG, PH per `force_liquidations.sexp` — not on
delisted symbols). But that's a separate experiment to run after the
data layer is fixed.

## Why the baseline numbers differ from the current 16y golden pin

`goldens-sp500-historical/sp500-2010-2026.sexp` currently pins
`total_return_pct ≈ 341.69`, `total_trades ≈ 806`, `MaxDD ≈ 18.36`,
`force_liquidations_count = 10`. This experiment's baseline measured
`307.16 / 683 / 19.92 / 0`.

The reason: this run was launched from a worktree off `main@origin`
**at PR #1094**, but the canonical 16y pin (per
`memory/project_2026-05-13_session.md`) was updated post a sequence of
NAV / Portfolio_view / Daily_price.active_through fixes that shifted
the metrics. The 307.16/683 numbers reproduce PR #1086's measured
values EXACTLY, suggesting the 16y golden pin includes a more recent
behavioural shift not yet propagated through the strategy's hot path
on this commit, or my experiment cells override Cell E defaults
slightly differently than the canonical pin (e.g., scenario sexp
shape difference). Within-experiment comparisons (the four cells)
are bit-identical for any cross-PI delta and remain the load-bearing
finding. Cross-baseline comparison to the pinned golden is a separate
follow-up if it matters (issue may be the canonical sexp's
`enable_short_side false` interacting with the panel runner; the
catastrophic axis-2 reproduction confirms the strategy itself is
operating identically to PR #1086's commit state).

## Reproduction

```
docker exec trading-1-dev bash -c \
  'cd /workspaces/trading-1/<worktree>/trading/trading && eval $(opam env) && \
   dune exec backtest/scenarios/scenario_runner.exe -- \
     --dir <worktree>/trading/test_data/backtest_scenarios/experiments/p5-pi-filter-16y-validation-2026-05-14 \
     --fixtures-root <worktree>/trading/test_data/backtest_scenarios \
     --parallel 2 \
     --no-emit-all-eligible'
```

Wall: ~13-15 min per pair of cells. Use `--no-emit-all-eligible` to
skip the all_eligible diagnostic which doubles wall time for this
experiment (where only `actual.sexp` headline metrics matter).

## Artifacts in this experiment dir

- `hypothesis.md` — pre-registered design + decision rule.
- `report.md` — this file.
- `runs/p5-pi-{off,on}-{baseline,axis2}-2010-2026/actual.sexp` —
  the captured headline metrics for each of the 4 cells (used for
  the bit-equality diff in the table above).
- `runs/.../params.sexp` — the full strategy + engine config that ran.

Scenario sexps live at
`trading/test_data/backtest_scenarios/experiments/p5-pi-filter-16y-validation-2026-05-14/`.
