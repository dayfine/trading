# path-stability-2026-10-23: #3404 Step 2, pre-registered

Status: **PRE-REGISTERED, NOT RUN.** This directory holds the chain, the four p0 specs and this read rule. Nothing has
run. The chain is launched by the dispatcher when the container is free (no agents, no other backtest), after #3406
(Step 1, `Seeded` tiebreak) merges: `launch` aborts otherwise.

The read rule is `dev/plans/path-stability-fixes-2026-10-23.md` at commit `b5ce359b7` (#3407, the amended plan), §"Step 2",
§"Metrics" and §"Decision rule". Those three sections are copied verbatim below. Where the plan left a detail open, the
choice made before any run is listed under "Implementation choices"; nothing there changes an arm, K, the window or a
threshold.

## How to run

```sh
sh dev/experiments/path-stability-2026-10-23/chain.sh launch    # pins .claude/worktrees/sweep-ps at origin/main, starts `run`
tail -f /tmp/ps-run/chain.log
# afterwards (run does these itself at the end; rerunnable):
sh dev/experiments/path-stability-2026-10-23/chain.sh collect dev/experiments/path-stability-2026-10-23/results
sh dev/experiments/path-stability-2026-10-23/chain.sh summary dev/experiments/path-stability-2026-10-23/results
sh dev/scripts/perf_long_cells.sh update /tmp/ps-run/chain.log
```

`sh chain.sh validate` (parse + override check of the four p0 specs and a negative control) needs a built run tree and
the warehouse in the container; it was not run by the author.

## Pre-registered design (verbatim from the plan at `b5ce359b7`)

#### Step 2: the stability experiment (one chain, after Step 1 merges)

**Arms.** Four, on one pinned build:

| arm | tie order | `entry_fill_size_to_available` | `max_position_pct_long` | role |
|---|---|---|---|---|
| A | Alphabetical | false | 0.14 (record) | reference: today's yardstick |
| S | Seeded | false | 0.14 | **null**: honest noise |
| SR | Seeded | true (min fraction 0.5) | 0.14 | candidate stabiliser: resize |
| SC | Seeded | false | **0.07** | candidate stabiliser: capacity, about twice the names at half the size |

**Perturbations.** K = 6 per arm:
- p0: unperturbed;
- p1–p5: each deletes **one traded, minor name** from the lists.
  - The five names are fixed by rule before any run: from arm A p0's trade list on the window, the five traded symbols
    with the smallest |total-return P&L|, ties broken by ticker.
  - The same five deletions are used in every arm.
- In S, SR and SC, each perturbation pk also sets `tiebreak_seed = k`, so the tie draw varies along with the list.
  In A the seed is inert.

**Window and universe.** Top-3000 PIT v12 schedule, 2019-01-01 → 2024-12-31 (6y), record spec (`rb1-26.sexp` body)
with the window changed.

**Cost.** 24 cells at about 1.7 h each (1,031 s per simulated year, #3381) ≈ **41 h**, sequential, alone in the
container.

**Validity.** Each perturbed cell is gated on `validator_diff -check V6` against its arm's p0. Each arm's p0 is gated
on V6 against A p0. A mismatch excludes the cell and names the specimen.

#### Metrics (pre-registered)

Per arm, over its K = 6 cells:

- **spread** = SD of ln(1 + total return) (primary), with the max − min range as secondary;
- the median ln(1 + R), Sharpe and max DD (secondary, read only for do-no-harm);
- **divergence onset:** for each p1–p5, the first date its NAV differs from the arm's p0 (descriptive).

#### Decision rule (written before any run)

- **Yardstick (A vs S).** Report spread(S) / spread(A). If it is ≥ 1.5, the alphabetical yardstick is recorded as
  understating path noise. From then on, chains measure noise with seeded perturbations (seeds plus list deletions)
  in place of path salts.
- **Seeded order as the default.** Seeded removes an arbitrary A→Z bias. It is recommended as the new default **on
  user approval as a correctness fix**, whatever its spread or return. This is an explicit exception to
  `experiment-flag-discipline.md` R3, recorded here.
- **Stabiliser (SR, SC vs S).** An arm **stabilises** if:
  - spread(arm) ≤ 0.6 × spread(S); **and**
  - its median ln(1 + R) is not below S's median by more than spread(S).

  A ratio between 0.6 and 0.85 is "inconclusive", never a win.
- **Promotion.** A stabilising arm is recommended for default on user approval, the same R3 exception.
  - If both stabilise, the recommendation is the one with the smaller spread. A combined SRC cell set is a follow-up
    only if both pass.
  - SC changes sizing, which the June capacity surface showed trades return for drawdown. So its do-no-harm read also
    reports max DD and Calmar against S. A stabiliser that deepens the median max DD by more than spread(S) in
    percentage points is reported "stabilises with a DD cost": a user decision, not an automatic recommendation.
  - Promotion moves the record, so it is followed by the record re-baseline (with #3388 if decided by then).
- **Small n.** K = 6 gives a wide CI on an SD. The thresholds are set so that only a large effect counts.


## Implementation (what the chain does)

- **Specs.** `specs/ps-<arm>-p0.sexp` = the `rb1-26.sexp` body (`../breadth-fix-rb1-2026-10-11/specs/`, the record N),
  name and description changed, window `2019-01-01 → 2024-12-31`, the full 1999–2025 top-3000 pit-v12 schedule kept
  (main's #3391-deduped lists), plus the arm's overrides:
  - A: `((screening_config ((candidate_ranking Alphabetical))))` (the default, stated explicitly);
  - S: `((screening_config ((candidate_ranking Seeded) (tiebreak_seed 0))))`;
  - SR: S plus `((entry_fill_size_to_available true))` and `((entry_fill_min_size_fraction 0.5))`;
  - SC: S with `max_position_pct_long` 0.14 → 0.07 (`max_long_exposure_pct` 0.70 and `min_cash_pct` 0.30 unchanged).

  Knob paths are #3406's (`Screener_ranking.Seeded`, `screening_config.tiebreak_seed`, pinned in its
  `test_seeded_tiebreak_overlays.ml`). No A-D fixture swap: every cell reads the run tree's test_data (main's fixture).
- **Order.** Sequential, one cell at a time: preflight of the four p0 specs (2024-10-01 → 2024-12-31), A-p0, the
  perturbation names, A p1–p5, then S, SR, SC each p0–p5. 24 cells, tag `ps-<arm>-p<k>-s0`, path salt 0 everywhere.
- **Perturbation names, by rule, after A-p0.** From `ps-A-p0-s0-trades.csv`: per symbol, total-return P&L = sum over its
  rows of `pnl_dollars + dividends_received`; the five with the smallest |total-return P&L| (rounded to cents), ties
  by ticker. Written to `results/perturb-names.txt` (k, symbol, P&L, trades, lists holding it) with the whole ranking
  in `results/perturb-ranking.csv`. pk deletes the k-th name from all 27 scheduled lists; each cut list is checked to
  differ from the original by exactly that symbol's entries. In S/SR/SC, pk sets `tiebreak_seed k`; A sets no seed.
- **Warehouse.** `/tmp/snap_top3000_pit_v12wk` (the #3266 rerun's build) reused: its manifest must hold 9,236 symbols
  and equal the set derived from the run tree's lists; every cell's cache line must read `n_symbols_absent=1` (MEL),
  else the cell is VOID.
- **V6 gates.** `validator_diff -check V6`: each pk vs its arm's p0, each S/SR/SC p0 vs A-p0. Exit 1 (mismatch) or 2
  (a report missing or unreadable) logs `EXCLUDED <tag>` with the specimen; the chain continues. `summary` drops
  EXCLUDED, VOID and failed cells.
- **Cell guard.** `CELL_TIMEOUT=14400 s`: the slowest same-spec cell ran 39,142 s over 26 y (#3381) ≈ 1,505 s/yr, so
  6 y ≈ 9,030 s, ×1.5 ≈ 13,545 s, rounded up to 4 h. The #3266 rerun cell measured 1,031 s/yr
  (`dev/status/perf-long-cells.csv`, row `v3266-Mpre3339-s0`), so a cell should take about 1.7 h and the chain about 41 h.
- **Review packs.** One per arm, from its p0, under `.sweep-output/review-ps-<arm>-p0/` (site + rendered PNGs), to be
  looked at before the read (`backtest-result-review.md`).

## Implementation choices (plan details left open, fixed here before any run)

1. **"|total-return P&L|"** is the trades.csv sum `pnl_dollars + dividends_received` per symbol (the review pack's
   `tradeTR`, #3175: `pnl_dollars` is price-only). Cash interest is in no trade row.
2. **Names held at the window end are not eligible.** A symbol in A-p0's `open_positions.csv` has part of its P&L
   unrealised and outside trades.csv, so its |total-return P&L| is not known from the trade list. A traded symbol in
   no scheduled list (impossible in practice) is also skipped. Both are marked in `perturb-ranking.csv`.
3. **Spread** is the sample SD (n − 1) of ln(1 + R), R = `total_return_pct` / 100, over the arm's included cells.
4. **"Deepens the median max DD by more than spread(S) in percentage points"** is read as median max DD(arm) −
   median max DD(S) > 100 × spread(S) pp (spread is in log units, about a fraction).
5. **Divergence onset** is the first equity-curve date at which a pk's portfolio value differs from its arm's p0 at
   all (the written cents differ), or "never".
6. **How a perturbed cell sees its lists.** Universe paths resolve under `--fixtures-root`, so a perturbed cell runs with
   a container fixtures root (`/tmp/ps-fix`) that symlinks every entry of the run tree's and adds `ps-lists/p<k>/`;
   its spec's universe paths point at `ps-lists/p<k>/`. p0 cells use the run tree's fixtures root unchanged.
7. **V6 exit 2** (a partner report missing or unreadable) excludes the cell like a mismatch: the gate could not pass.
8. The 20 generated specs are not preflighted (they differ from a preflighted p0 spec only by name, list paths and
   seed); a parse error fails in seconds and is logged as GUARD-KILLED/FAILED.

## Results

_Placeholder: filled by the results PR (results-analyst read, `summary.txt`, review-pack look, `Verifies` line)._
