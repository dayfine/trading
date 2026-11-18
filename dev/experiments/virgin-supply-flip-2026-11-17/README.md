# virgin_supply_basis default flip: paired golden run (#3664, #3677)

The user decided on 2026-11-17 to flip `virgin_supply_basis` from `Legacy_mixed` to `One_basis` on correctness (#3664
comment 6960893659; evidence in the vsb-1 read, #3671). `config-default-blast-radius.md` requires a paired run of
every golden before such a flip merges. This directory is that run.

**Build:** the flip PR tip `08e2fac19`, checked out at `.claude/worktrees/sweep-vsb`. Both arms run on that one build.

**Arms:**
- `new` is each golden spec as committed, so it inherits the flipped `One_basis` default.
- `old` is the same spec with `((virgin_supply_basis Legacy_mixed))` prepended to `config_overrides`. These specs are in `specs-old/`.

**Runner settings** (`chain.sh`): CSV bars from the worktree's `test_data`, `--parallel 1`, no snapshot dir. These
mirror `exit-basis-flip-2026-09-03/chain.sh`.

**Cells:** 29 pairs.
- `perf-sweep` ×4, `smoke` ×3, `goldens-sp500` ×3 (pin/regression purpose only), `goldens-custom-universe-scenarios` ×3
- `goldens-small` ×3
- `goldens-sp500-historical` ×7
- tier-4 `goldens-broad` ×6

Skipped as in the precedent chain: the bah cells, the hybrid-tier spec, the capacity probe, and the runtest goldens.
The flip commit regenerates the runtest goldens, and they come out bit-identical.

## Result: no golden moves

All 29 pairs give a byte-identical `trades.csv` and identical metrics. Both arms pass every existing pin
(`results/paired.tsv`; per-arm `results/*-actual.sexp`). So no golden is re-pinned.

**Why nothing moves.** On CSV bars the panel adapter's `get_sketch` returns `None`. With no sketch,
`Stock_analysis_supply.results` takes the binary v1 path and never reads the basis knob. This is documented at
`trading/backtest/test/test_runner_hypothesis_overrides.ml` (`test_overhead_supply_defaults_armed`). The knob bites
only on snapshot-warehouse runs that carry sketch columns. That is the record and lane path, where vsb-1 measured it:
the supply path was live in 102 of 103 audit records.

**What the flip does change.** On the warehouse path, S k0 26y at `08e2fac19` reproduces vsb-1 k0's `trades.csv`
exactly: md5 `3ee10dca319e54a85f5e0a7842d8c537`, 559 round trips. The files are in trading-results
`6cad233`, under `dev/experiments/virgin-supply-flip-2026-11-17/s-k0-at-08e2fac19/`. That md5 becomes the lane
tripwire (`dev/experiments/observatory/lane.sh` `TRIP_MD5`), replacing `0928cfe4…`.

**Limit.** These goldens cannot detect a basis-knob regression, because the CSV path does not read the knob. The
guard for the knob is the unit test `test_default_is_one_basis` together with the warehouse tripwire.

## Files

- `chain.sh`: the chain. The 11-17 run used `RUN_HOST=.sweep-output/vsb-flip-run`. Two host restarts (18:24 and
  22:17 PT) killed it, and it was resumed by SKIP-ing cells whose summaries already existed. Every cell ran once to
  completion, at the same build.
- `specs-old/<family>/<name>-old.sexp`: the old-arm specs.
- `results/chain.log`: the run log. Lines marked `[reconstructed ...]` were rebuilt from finished cells' summaries
  after each restart.
- `results/paired.tsv`: the per-cell pair table.
- `results/*-actual.sexp`: the metric summary per arm.
- In trading-results `6993023`, same directory: `results/*-trades.csv`, `*-summary.sexp` and the runner logs. These
  hold prices (EODHD terms; `dev/experiments/TRADES-PRIVATE.md`).
