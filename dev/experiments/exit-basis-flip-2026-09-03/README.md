# exit-basis-flip-2026-09-03 — paired goldens for the D1/D2 default flip (PR #2648)

User decision 2026-09-03 (P0 of `dev/notes/next-session-priorities-2026-09-03.md`):
flip `sim_exit_fill_next_open` (D1, #2644) and `stops_config.stop_skip_entry_bar`
(D2, #2642) default ON. Ledger record:
`dev/experiments/_ledger/2026-09-03-exit-basis-d1d2-correctness.sexp`
(verdict `Inconclusive` = human-gated R3 override, same convention as the
2026-08-24 stops-basis entry). This directory is the
`config-default-blast-radius` evidence: every golden the flip moves, run
PAIRED at one build.

## Method

- **Build:** pinned worktree `.claude/worktrees/sweep-d1d2` @ `398f57111`
  (= the flip commit, the first commit of #2648). Both arms of every pair
  share this build; only the two knobs differ.
- **New arm:** the golden spec as committed (inherits the flipped defaults).
- **Old arm:** the same spec with
  `((sim_exit_fill_next_open false)) ((stops_config ((stop_skip_entry_bar false))))`
  prepended to `config_overrides` (`Overlay_validator.apply_overrides`
  deep-merges, so the golden's own `stops_config` fields survive). Staged
  outside any VCS tree at `/tmp/d1d2-run/specs/<family>/<name>-old.sexp`
  during the run; committed copies under `specs/`.
- **Old-arm provenance, two classes.** (a) The 12 cells #2587 ran at
  `5dc61da07` (`dev/experiments/clock-surface-2026-08-27/results/goldens/
  *-actual.sexp`) are the current-main old arm by R1 — every merge since
  (#2641 validators, #2642/#2644 default-off flags, #2645/#2647/#2637
  docs/tests) is bit-identical on the default path — validated by ONE direct
  old-arm re-run (`sp500-2019-2023-armed-stoplimit-old`, below). (b) Every
  other cell (weinstein-2019-armed-e, goldens-small ×3, smoke tier-2 ×3,
  perf-sweep bull-1y/3y, goldens-broad tier-4 ×6) ran both arms directly.
- **Invocation:** `chain.sh` — mirrors `golden_sp500_postsubmit.sh` /
  `perf_tier*.sh` (stage dir, `--parallel 1`, `--fixtures-root`, CSV bars via
  `TRADING_DATA_DIR=<worktree>/trading/test_data`, no snapshot-dir) so numbers
  are pin-comparable. Per-arm raw artifacts (`*-actual.sexp`, `*-trades.csv`,
  `*-summary.sexp`, runner log) under `results/`
  (`feedback_commit_raw_per_arm_artifacts`).
- **Re-pin rule:** `repin.sh <golden> <new-arm actual.sexp> "<comment>"`
  rewrites each metric band to ±15% around the NEW-arm actual (the existing
  convention; it reproduces the current armed-stoplimit maxDD pin
  digit-for-digit from the #2587 actual). `wall_seconds` untouched.
  Bah_benchmark cells carry no strategy config and are not re-run.

## Cells and phases

| phase | family | cells | CI consumer | old arm |
|---|---|---|---|---|
| 1 | goldens-sp500, goldens-custom-universe-scenarios | armed-stoplimit, long-only, sp500-2019-2023, full-pool, top-500, armed-e | postsubmit on push to main | #2587 artifacts (+ direct re-run for armed-stoplimit, armed-e) |
| 2 | goldens-sp500-historical (tagged) | sp500-2010-2026, -longshort | nightly | #2587 artifacts |
| 3 | goldens-small, smoke (tier 2) | 3 + 3 | perf-nightly | direct |
| 4 | perf-sweep (tier 3) | bull-1y, bull-3y | perf-weekly | direct |
| 5 | goldens-sp500-historical (untagged) | 2000-2026-catstop, -armon, -longshort, 1998-2026, top3000-2000-2026-catstop | none (kept pinned) | #2587 artifacts |
| 6 | goldens-broad (tier 4) | tier4-broad-1y, bull-crash, covid-recovery, six-year, decade, tier4-broad-10y | local release gate | direct |

Skipped on purpose: `goldens-hybrid-tier-experiment/*` (no CI consumer;
`test_scenario.ml` parses the spec only), `goldens-broad/sp500-30y-capacity-1996`
(untagged capacity probe), all `bah-*` cells. Runtest goldens
(`panel_goldens/*.sexp`) were regenerated in the flip commit itself.

## Results

All 27 cells landed 2026-09-03 01:09–03:44 PDT (2h35m wall, `chain.log`; raw per-arm artifacts under `results/`).

### Lineage check — armed-stoplimit old arm vs the #2587 artifact

Direct old-arm re-run at `398f57111` (2026-09-03 01:30, wall 215s):
`total_return_pct 38.800852319920438 / total_trades 187 / win_rate
31.550802139037433 / sharpe_ratio 0.51774917358632655 / max_drawdown_pct
21.459555977954711` — **digit-for-digit** the #2587 artifact
(`clock-surface-2026-08-27/results/goldens/sp500-2019-2023-armed-stoplimit-actual.sexp`,
run at `5dc61da07`). The R1 claim holds: nothing merged between the two
builds moved the default path, so the 12 committed #2587 actuals are valid
old arms for this table.

### Paired table

| golden | old return% / trades / sharpe / maxDD | new return% / trades / sharpe / maxDD | Δ return (pp) | old-arm source | new arm vs OLD pin |
|---|---:|---:|---:|---|---|
| goldens-broad--bull-crash-2015-2020 | 10.63 / 179 / 0.19 / 39.78 | 56.90 / 184 / 0.52 / 35.06 | +46.27 | direct | FAIL |
| goldens-broad--covid-recovery-2020-2024 | 41.35 / 161 / 0.45 / 32.22 | 44.12 / 148 / 0.47 / 32.04 | +2.78 | direct | FAIL |
| goldens-broad--decade-2014-2023 | 154.39 / 304 / 0.54 / 35.81 | 108.79 / 288 / 0.47 / 35.31 | -45.60 | direct | FAIL |
| goldens-broad--six-year-2018-2023 | 76.93 / 193 / 0.54 / 36.90 | -20.29 / 221 / -0.12 / 39.47 | -97.22 | direct | FAIL |
| goldens-broad--tier4-broad-10y | 229.04 / 49 / 0.47 / 63.79 | 77.36 / 77 / 0.42 / 29.96 | -151.67 | direct | PASS |
| goldens-broad--tier4-broad-1y | -15.48 / 24 / -1.08 / 18.19 | -19.07 / 24 / -1.37 / 20.08 | -3.60 | direct | PASS |
| goldens-custom-universe-scenarios--weinstein-2019-armed-e | 79.20 / 187 / 0.80 / 19.88 | 59.31 / 177 / 0.66 / 19.83 | -19.89 | direct | FAIL |
| goldens-custom-universe-scenarios--weinstein-2019-full-pool | 51.16 / 193 / 0.57 / 26.81 | 41.75 / 198 / 0.48 / 26.39 | -9.41 | #2587 artifact | PASS |
| goldens-custom-universe-scenarios--weinstein-2019-top-500 | 475.48 / 173 / 0.78 / 77.23 | 40.60 / 189 / 0.48 / 38.17 | -434.87 | #2587 artifact | FAIL |
| goldens-small--bull-crash-2015-2020 | 3.65 / 232 / 0.11 / 33.57 | -9.91 / 235 / -0.04 / 36.41 | -13.56 | direct | FAIL |
| goldens-small--covid-recovery-2020-2024 | 3.86 / 217 / 0.13 / 32.49 | 5.44 / 206 / 0.15 / 35.68 | +1.58 | direct | FAIL |
| goldens-small--six-year-2018-2023 | -17.55 / 261 / -0.14 / 32.49 | -26.59 / 255 / -0.26 / 35.72 | -9.04 | direct | FAIL |
| goldens-sp500--sp500-2019-2023-armed-stoplimit | 38.80 / 187 / 0.52 / 21.46 | 29.40 / 185 / 0.41 / 26.46 | -9.40 | direct | FAIL |
| goldens-sp500--sp500-2019-2023-long-only | 76.07 / 126 / 0.68 / 35.88 | 78.08 / 125 / 0.70 / 33.59 | +2.02 | #2587 artifact | PASS |
| goldens-sp500--sp500-2019-2023 | 76.80 / 181 / 0.71 / 23.87 | 61.82 / 184 / 0.61 / 25.02 | -14.99 | #2587 artifact | FAIL |
| goldens-sp500-historical--sp500-1998-2026 | 66.36 / 479 / 0.27 / 45.76 | 55.05 / 468 / 0.24 / 47.19 | -11.31 | #2587 artifact | PASS |
| goldens-sp500-historical--sp500-2000-2026-catstop-armon | 107.64 / 612 / 0.38 / 24.90 | 146.45 / 608 / 0.42 / 25.41 | +38.81 | #2587 artifact | PASS |
| goldens-sp500-historical--sp500-2000-2026-catstop | 108.35 / 609 / 0.38 / 23.12 | 150.04 / 608 / 0.42 / 25.41 | +41.69 | #2587 artifact | PASS |
| goldens-sp500-historical--sp500-2000-2026-longshort | 155.52 / 685 / 0.43 / 24.82 | 73.63 / 692 / 0.28 / 28.66 | -81.90 | #2587 artifact | PASS |
| goldens-sp500-historical--sp500-2010-2026-longshort | 737.36 / 648 / 0.48 / 78.92 | 406.02 / 668 / 0.42 / 79.08 | -331.34 | #2587 artifact | FAIL |
| goldens-sp500-historical--sp500-2010-2026 | 541.84 / 452 / 0.49 / 63.39 | 388.79 / 462 / 0.45 / 62.33 | -153.05 | #2587 artifact | FAIL |
| goldens-sp500-historical--top3000-2000-2026-catstop | 1600.18 / 571 / 0.33 / 30.73 | 1640.26 / 568 / 0.33 / 29.33 | +40.08 | #2587 artifact | PASS |
| perf-sweep--bull-1y | -2.91 / 3 / -0.52 / 7.75 | -2.91 / 3 / -0.52 / 7.75 | +0.00 | direct | PASS |
| perf-sweep--bull-3y | -9.58 / 12 / -0.62 / 15.23 | -10.56 / 12 / -0.70 / 16.14 | -0.98 | direct | PASS |
| smoke--bull-2019h2 | -2.80 / 22 / -0.37 / 6.38 | -4.49 / 22 / -0.66 / 8.25 | -1.69 | direct | PASS |
| smoke--crash-2020h1 | -9.21 / 27 / -0.64 / 19.46 | -9.69 / 27 / -0.68 / 19.59 | -0.48 | direct | PASS |
| smoke--recovery-2023 | -4.25 / 49 / -0.24 / 16.01 | -4.74 / 49 / -0.28 / 15.67 | -0.48 | direct | PASS |

## Reading the deltas — what to expect and what NOT to claim

D1 moves every Friday-decided Market exit from Friday's open to Monday's
open: for stops/laggards that were selloffs continuing Monday this is a
loss (the record's −$601k first-order), for ejected weak-volume breakouts
that kept rising it is a gain (arc +$525k). D2 removes entry-bar stop-outs,
converting ~5.7% of breakout entries from day-one losses into real holds
(both signs downstream). The direction and size per golden depend on the
mix of exit triggers in that cell; a large top-line swing on one cell is a
**path reshuffle on a corrected basis**, not evidence about any mechanism
(`project_lever_reads_invert_on_fixed_sim`). No return-improvement claim
attaches to these re-pins.

### Dissection — weinstein-2019-top-500 (475.48% → 40.60%)

The old arm's 475% was **one trade**: GME 2020-09-12 → 2021-08-07, 32,098 sh
@ 6.21 → 154.59, **+$4,762,643** (the cell's realised total was $4.24M; the
other 172 trades net −$0.5M). The new arm has no GME trade. Join on
`symbol|entry_date`: 119 shared / 54 old-only / 70 new-only entries, first
divergence 2019-07-27 (DXCM, old-only), so by Sept 2020 the two books differ
by path. GME was screened six times in the new arm (`trade_audit.sexp`: grade
A, scores 75–85) but never funded: on 2020-09-11 the new book held 7
positions (ZS TMO SHOP RH GLW FDX CDNS) vs the old book's 6, and the old arm
spent $199k on GME + $112k on NVS on the 09-12 step where the new arm could
fund only NVS. **The 435pp gap is a missed monster on a survivor-biased
composition cell** (`project_composition_golden_survivor_bias`,
`project_funding_grid_monster_lottery`: 1 monster ≈ the whole spread) —
a path reshuffle downstream of the corrected exit basis, not a property of
D1/D2. Re-pinned at ±15% around the new-arm actuals like every other cell;
no claim attaches to the level.

### Dissection — sp500-2010-2026 (541.84% → 388.79%, realised $4.80M → $3.63M)

Join on `symbol|entry_date`: **396 shared / 56 old-only / 66 new-only**
entries, first divergence 2010-12-04 (GME, one week apart — the GME 2020
monster is present in BOTH arms, +$2.52M vs +$2.54M). The −$1.17M realised
gap decomposes as (a) **−$314k exit-price drift on the 396 shared trades**
— the D1 direction the record repricing predicted (Friday stop/laggard
triggers were selloffs that continued Monday; largest LLY 2025-03 −$73k,
VFC 2024-08 −$78k) — and (b) **~−$860k cohort reshuffle**, dominated by one
old-only monster, KLAC 2025-05-24 → 2026-04-15 **+$1.04M**, which the
fixed-basis book never funded; the new-only cohort's best (CHRW +$459k,
PM +$363k) does not replace it. maxDD is unchanged (63.4 → 62.3). Same
shape as the top-500 cell: the shared-trade drift is the mechanism, the
level gap is a missed monster.

### Tier-2 pins were already stale before this flip

`goldens-small/bull-crash-2015-2020`'s **old arm** (both knobs pinned false)
reads 3.65% / 232 trades / maxDD 33.6 against a pin of [41.4, …] / ≥248 /
≤22.7 — it fails its own pin before D1/D2 touch anything. The pin was last
re-centred 2026-07-08 (warmup fix) and never re-pinned for the 2026-08-24
stops-basis (#2530) or 2026-08-26 fill-model (#2569) default flips;
`perf-nightly.yml` runs tier 2 with `continue-on-error: true`, so the drift
was invisible (last three nightly runs report `success`). The direct old-arm
actuals committed under `results/goldens-small--*-old-actual.sexp` are the
authoritative pre-flip basis for these cells; the paired delta (old → new) is
the D1/D2 effect, the pin → old gap is the inherited staleness. Both are
closed by re-pinning to the new arm here.

### Dissection — goldens-broad/six-year-2018-2023 (tier 4, top-1000: 76.93% → −20.29%)

Realised $413k → −$296k. Join on `symbol|entry_date`: **143 shared / 51
old-only / 79 new-only**, first divergence 2018-06-30 (FDS). The shared
trades drift **+$79k** under the fixed basis (here D1 helps: the ejected
names kept rising into Monday). The gap is entirely cohort: old-only entries
net **+$911k** — MSTR 2020-09-05 → 2021-05-01 +$452k, BBWI 2020-08-01
+$221k, ON +$129k, FDX +$128k, TTD +$113k, the 2020 melt-up monsters — vs
+$128k for the 79 new-only entries. The fixed-basis book, already
divergent for two years by then, did not hold the cash/slots for that
cluster. Third instance of the same pattern in this table (top-500 GME,
sp500-2010-2026 KLAC): **shared-trade drift is small and mixed-sign; level
gaps are missed monsters.** No claim attaches to the level.

### Re-pin decisions

- **Re-pinned (14, all FAIL-at-old-pin or tight-pinned):** goldens-sp500
  armed-stoplimit, long-only (PASS but tight-pinned; re-centred), sp500-2019-2023;
  goldens-custom-universe-scenarios top-500, armed-e; goldens-sp500-historical
  sp500-2010-2026, sp500-2010-2026-longshort; goldens-small ×3; goldens-broad
  bull-crash, covid-recovery, six-year, decade. Bands: ±15% around the new-arm
  actual, `total_return_pct` at least ±5pp (`repin.sh`).
- **Kept as is (13, wide sentinel bands, PASS on both arms):** full-pool;
  the five untagged historical cells; tier4-broad-1y and tier4-broad-10y;
  smoke ×3; perf-sweep ×2. Their old→new deltas are recorded above; the
  sentinel purpose (crash / runtime / gross-sanity) is unaffected.
- **Stale before this flip (9):** the three goldens-small and four
  goldens-broad tight cells failed their pins on the OLD arm too (never
  re-pinned after #2530 / #2569; tier 2 runs `continue-on-error`, tier 4 has
  no CI consumer). The old-arm actuals committed here are the first
  post-August record of those cells.

### Direction of the deltas (what the corrected basis did)

19 of 27 cells move down, 7 up, 1 flat (bull-1y, bit-identical) — a ~3:1 skew
to the downside, as the record repricing (−$601k first-order) predicted for
stop/laggard-heavy books. Shared-trade
drift (same `symbol|entry_date` in both arms) is small and mixed-sign
(−$314k on sp500-2010-2026's 396 shared trades, +$79k on six-year's 143);
every large level gap dissected to a **missed or gained monster** after the
two books diverged (GME on top-500, KLAC on sp500-2010-2026, the 2020
melt-up cluster on six-year). The 26y catstop cells gain ~+40pp and
sp500-2000-2026-longshort loses −82pp on the same window — opposite signs on
one period, which is the monster-lottery signature, not a mechanism. maxDD
is unchanged within a few pp on every cell except the two broad lottery
cells (top-500 77→38, broad-10y 64→30), where the missed monster also
removed its drawdown. **No return-improvement or degradation claim attaches
to this flip; it corrects the fill/stop basis every future measurement runs
on** (`project_lever_reads_invert_on_fixed_sim`).
