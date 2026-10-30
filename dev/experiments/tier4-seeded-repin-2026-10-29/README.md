# tier4-seeded-repin-2026-10-29 — paired tier-4 goldens for the Seeded tiebreak default (#3425, #3404)

#3425 made `screening_config.candidate_ranking = Seeded` (seed 0) the default and
re-pinned the goldens CI runs. The local tier-4 goldens (`goldens-broad/`,
`goldens-sp500-historical/`) have no CI consumer and still held Alphabetical-era
bands. This directory is the `config-default-blast-radius` evidence for them:
every cell run PAIRED at one build, then the failing new-arm cells re-pinned.
It is the last `[after-merge]` item of #3404.

## Method

- **Build:** pinned worktree `.claude/worktrees/sweep-t4seed` @ `cb4243309`
  (origin/main 2026-10-29). No commit under `trading/trading` or
  `trading/analysis` landed between it and this PR's base, and no golden spec
  changed.
- **New arm:** the golden spec as committed (Seeded, seed 0).
- **Old arm:** the same spec with
  `((screening_config ((candidate_ranking Alphabetical))))` prepended to
  `config_overrides`; committed copies under `specs/`.
- **Invocation:** `chain.sh`, the `exit-basis-flip-2026-09-03` chain (stage
  dir, `--parallel 1`, `--fixtures-root`, CSV bars from the run tree's
  `test_data`) plus GNU-time peak RSS. Per-arm raw artifacts under `results/`.
- **Handle cap:** phases 1–2 (`goldens-broad/` up to tier4-broad-10y, plus the
  capacity new arm and BRK-B) ran at the default `SNAPSHOT_MAX_MMAP_HANDLES=256`.
  The first 15y sp500 cell thrashed at 256 and was relaunched with every
  remaining cell at 12,000 (`chain.log` RESTART line). The cap changes no
  result (`perf_pit_smoke.sh` asserts 256 vs 12,000 byte-identical). Both arms of
  every pair ran at the same cap except the untagged `sp500-30y-capacity-1996`
  probe (new arm 256, old arm 12,000).
- **Re-pin rule:** `repin.sh` (copied from `exit-basis-flip-2026-09-03`):
  ±15 % around the new-arm actual, `total_return_pct` at least ±5 pp,
  `wall_seconds` untouched. Applied to every cell whose new arm fails its pin.

## Results

30 cells, 2026-10-29 09:37–16:46 PDT (`chain.log`). `sh table.sh results "" chain.log`:

| golden | old return% / trades / sharpe / maxDD | new return% / trades / sharpe / maxDD | Δ return (pp) | old-arm source | new arm vs OLD pin |
|---|---:|---:|---:|---|---|
| goldens-broad--bull-crash-2015-2020 | 184.82 / 172 / 0.98 / 21.13 | 73.37 / 157 / 0.63 / 28.62 | -111.45 | direct | FAIL |
| goldens-broad--covid-recovery-2020-2024 | -2.76 / 180 / -0.05 / 39.40 | 34.54 / 158 / 0.28 / 31.15 | +37.30 | direct | FAIL |
| goldens-broad--decade-2014-2023 | 1025.88 / 256 / 0.65 / 76.90 | 503.93 / 281 / 0.60 / 60.81 | -521.95 | direct | FAIL |
| goldens-broad--six-year-2018-2023 | 277.08 / 181 / 0.60 / 77.98 | 378.47 / 177 / 0.65 / 77.15 | +101.39 | direct | FAIL |
| goldens-broad--sp500-30y-capacity-1996 | 396.18 / 513 / 0.43 / 41.78 | 460.49 / 488 / 0.48 / 41.05 | +64.31 | direct | PASS |
| goldens-broad--tier4-broad-10y | 159.04 / 84 / 0.54 / 39.96 | 164.71 / 115 / 0.57 / 32.77 | +5.68 | direct | PASS |
| goldens-broad--tier4-broad-1y | -18.65 / 24 / -1.47 / 19.78 | -15.56 / 21 / -1.11 / 20.47 | +3.09 | direct | PASS |
| goldens-sp500-historical--sp500-1998-2026 | 164.87 / 531 / 0.44 / 45.09 | 145.63 / 526 / 0.41 / 45.85 | -19.24 | direct | PASS |
| goldens-sp500-historical--sp500-2000-2026-catstop-armon | 245.76 / 624 / 0.58 / 25.47 | 214.55 / 616 / 0.55 / 27.42 | -31.21 | direct | PASS |
| goldens-sp500-historical--sp500-2000-2026-catstop | 226.47 / 622 / 0.55 / 25.48 | 131.01 / 628 / 0.41 / 29.34 | -95.46 | direct | PASS |
| goldens-sp500-historical--sp500-2000-2026-longshort | 191.91 / 650 / 0.50 / 26.32 | 259.45 / 628 / 0.57 / 25.38 | +67.54 | direct | PASS |
| goldens-sp500-historical--sp500-2010-2026-longshort | 1056.36 / 611 / 0.52 / 79.16 | 1033.70 / 584 / 0.52 / 78.62 | -22.65 | direct | PASS |
| goldens-sp500-historical--sp500-2010-2026 | 899.95 / 494 / 0.50 / 78.19 | 978.73 / 472 / 0.51 / 78.18 | +78.79 | direct | PASS |
| goldens-sp500-historical--sp500-2011-2026-bah-brk-b | 486.29 / 0 / 0.70 / 29.47 | 486.29 / 0 / 0.70 / 29.47 | +0.00 | direct | PASS |
| goldens-sp500-historical--top3000-2000-2026-catstop | 250.27 / 627 / 0.55 / 31.81 | 344.56 / 621 / 0.63 / 29.45 | +94.29 | direct | PASS |

The last column is the new arm against the pin on main before this PR.

### Reading

- **Every new arm passes its pin except the four tight `goldens-broad` cells**
  (bull-crash, covid-recovery, six-year, decade). Those four are re-pinned here.
- **Those four pins were already stale before #3425.** The Alphabetical arm
  fails all four too (`chain.log`: e.g. covid-recovery old −2.76 % vs a
  37.50 floor; decade old 1,025.88 % vs a 125.11 ceiling). No workflow runs
  them, so earlier default changes moved them unnoticed. The re-pin restores a
  tripwire; it makes no return claim.
- **The cross-arm moves on those four are larger than their ±15 % bands:**
  bull-crash −111.45 pp, covid-recovery +37.30, six-year +101.39, decade
  −521.95. The tiebreak only reorders tied candidates, so these are one draw
  of path noise, the same mechanism the K-seed record measured (#3419,
  `record-kseed-2026-10-27`), not an effect of the setting. A single-draw band
  will trip again on any change that reshuffles a tie; widening these four or
  pinning them to a seed band is a separate decision.
- **Wide-band cells pass on both arms** despite moves of similar size
  (`sp500-2000-2026-catstop` −95.46 pp, `top3000-2000-2026-catstop` +94.29,
  `sp500-2000-2026-longshort` +67.54). They are not re-pinned.
- **`sp500-2010-2026` and `-longshort`: the old arm fails, the new arm passes**
  (`open_positions_value`). #3425 already re-pinned these two (they run in the
  nightly), so their pins are Seeded-era; the old-arm failure is expected.
- **BRK-B buy-and-hold is byte-identical across arms** (486.29 %, 0 trades):
  the tiebreak does not touch a strategy with no screener.
- **Perf:** 30 rows added to `dev/status/perf-long-cells.csv`; two 10y shapes
  read SLOWER, see `dev/status/backtest-perf.md` §Weekly review 2026-10-29.
