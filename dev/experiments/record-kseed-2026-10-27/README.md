# record-kseed-2026-10-27: the record as K = 5 tie-order seeds on the Seeded default

**Pre-registration.** Nothing has run. Everything below is fixed before the first cell launches.

## Why

The path-stability read (`../path-stability-2026-10-23/`, #3419) found the 26y record path chaotic in our own
mechanics: the alphabetical tiebreak picked among equal-score candidates, and one draw moved the 6y end NAV by up to
0.2 log. The user approved `candidate_ranking Seeded` (seed 0) as the default on 2026-10-25, and #3425 (`cae75ca2a`)
flipped it. The remaining `[after-merge]` item of #3404 is this run: re-baseline the record as K seeds, at least 5,
on the Seeded build, so that every later 26y lever read is paired per seed against a measured band rather than one
draw (`project_path_stability_seeded_noise`). It is also the 26y seeded null that `../path-stability-2026-10-23/`
§"What next" item 5 asks for before the next 26-year verdict.

This is a re-baseline, not a lever test: no accept or reject.

## Design

- **Spec.** The record N (`../breadth-fix-rb1-2026-10-11/specs/rb1-26.sexp`), byte for byte, with name, description
  and one added override `((screening_config ((tiebreak_seed k))))`. `candidate_ranking` is main's default (Seeded).
  `specs/rk-k0.sexp` .. `specs/rk-k4.sexp`; `launch` checks each body equals rb1-26's up to the seed line.
- **Cells.** k = 0, 1, 2, 3, 4. Window 2000-01-01 → 2026-06-26, top-3000 PIT v12 schedule (27 yearly lists, broad,
  U1 passes), path salt 0 everywhere. Tags `rk-k<k>-s0`. k0 is what the default config produces.
- **Build.** A pinned worktree at origin/main when launched (must contain #3425 and the template's fixes, #3391
  dedupe included). #3388 (the full rename-twin dedupe) is still open and is not applied: the universe is the same
  27 lists as the old record (`results/lists-md5.txt`).
- **Warehouse.** `/tmp/snap_top3000_pit_v12wk` (the #3266 rerun's build, 9,236 symbols), reused and checked against
  the run tree's lists.
- **Order.** Preflight k0 and k1 on the last half-year (a non-zero seed must reach `params.sexp`), then k0 .. k4,
  one cell at a time, alone in the container.
- **Cost.** About 35–45 h: the latest same-spec 26y cell took 27,309 s (#3266 rerun, 10-23), the slowest 39,142 s.
  `CELL_TIMEOUT` 60,000 s = 1.5 × the slowest.

## What is read

1. **V6 gate.** Each k1..k4 runs `validator_diff -check V6` against k0 and must exit 0 (seeds change which
   candidates win ties, never the instrument set). A mismatch excludes the cell and names the specimen.
2. **The record band** over the included seeds: per seed total return, ln(1 + R), Sharpe, max DD, Calmar, trades;
   then median, sample SD and min–max of ln(1 + R), and the medians of Sharpe, max DD and Calmar
   (`sh chain.sh summary`).
3. **Reference, descriptive only.** The old record N (Alphabetical, path salts 0–2, `../breadth-fix-rb1-2026-10-11/results/`):
   where its median ln(1 + R) falls against the seed range. Salts and seeds re-draw different things and the
   arms are not paired, so this states a level shift, not an effect.
4. **Divergence onset:** the first date each seed's NAV leaves k0's.
5. **Review pack** (all five seeds), rendered and looked at per `backtest-result-review.md`; each signal bullet is
   confirmed, refined or rejected in the writeup.

## What it decides

- **≥ 4 seeds included:** the K-seed set replaces the single-run record. The headline is the median ln(1 + R) with
  its range and SD; k0 is the default-config run. Every later 26y lever read on the record config runs the same
  seeds and is read paired per seed. The record memory, the #3404 issue and the ledger take the band.
- **Fewer than 4 included:** the record is not replaced; an issue names the failing cells.
- **The band's width is the finding,** whatever it is. A 26y SD of ln(1 + R) near the 6y one (0.21) would mean a
  single 26y cell cannot resolve a lever smaller than about 0.4 log, and every 26y verdict needs K ≥ 5.

Out of scope: re-pinning the tier-4 local goldens (`goldens-sp500-historical`, `goldens-broad/`), which still hold
Alphabetical-era bands. That is a separate run after this one, on the same build.

## How to run

```sh
PREREG=<this commit> sh dev/experiments/record-kseed-2026-10-27/chain.sh launch   # host; detaches `run`
tail -f /tmp/rk-run/chain.log
```

`run` copies results into `/tmp/rk-run/results` and writes `summary.txt`; the pack goes to
`.sweep-output/review-record-kseed-build/`.

## Log

- 2026-10-27: pre-registered.
