# Next-session priorities — 2026-09-05 (post exit-lever surface, 09-04)

Supersedes `next-session-priorities-2026-09-04.md`. Its P0 (re-measure the
exit levers on the fixed basis) is DONE; its P1 (vintage warehouses) is
half-done (built from the CSV store; the EODHD gap fetch is open); P2 carries.

## What landed 2026-09-04

- **`dev/experiments/exit-lever-surface-2026-09-04/`** (this session's PR):
  the record convention's exit mechanisms one knob at a time on the fixed
  basis, 18 cells (lagoff / s3off / extoff / clock52 × 2019–23 + 2000–04 ×
  salts 0–2; nulls reused from record-rebase + stop-width at the same build
  `e4984c5fe`). **Every mechanism the record arms survives the fix**:
  laggard rotation and the extension stop are regime dials worth
  $320–370k on 2000–04 (keep on); stage-3 force-exit is inert (0–1 fires);
  clock 52 is an MSTR lottery on 2019–23 (ex-MSTR loses 3/3, maxDD +11–13pp)
  and neutral on 2000–04 (record keeps the clock-0 pin). No arm won both
  windows → no 26y run; record convention unchanged. Memory:
  `project_exit_stack_survives_fixed_basis`. Tools: `dissect.sh` (closed-trade
  join) + `unreal.sh` (open-position MTM — the lagoff arm's +97pp was one
  unsold NVDA, invisible to the closed-trade join).
- **Vintage warehouses** `/tmp/snap_top3000_2019` (2,209 snaps ≈ 76% of the
  2019 composition, 513 MB) and `/tmp/snap_top3000_2009` (2,033 ≈ 73%, 891 MB),
  built fresh from the CSV store over a superset universe (composition +
  `GSPC.INDX`), bars from vintage−1. Gotcha on the way: a 1-symbol
  `-incremental` top-up REPLACED each manifest with one entry (#2669,
  `project_build_snapshots_incremental_clobbers_manifest`); fixed by a full
  superset rebuild. Check `grep -c "(symbol " manifest.sexp` vs the `.snap`
  count before pointing a chain at any warehouse. CSV
  store coverage measured 2026-09-04: 2009 vintage 1932/2780 (69%), 2019
  vintage 2177/2904 (75%) — vs 44% / 32% on the 2000-vintage warehouse.
- Housekeeping: five stale locked agent worktrees + three orphaned
  `dune build @fmt` processes from earlier sessions removed.

## P0 — the clock-52 maxDD rationale on the fixed basis — DONE 2026-09-04 evening

**Ran the same evening** (`dev/experiments/clock-default-fixed-basis-2026-09-04/`,
paired c0/c52, salts 0–2, 2019–23 on the NEW 2019-vintage warehouse + the
2000–04 record-lineage pairs): maxDD Δ −11.66 / +0.55 / +0.33pp on 2019–23,
+0.1 / 0.0 / +0.1 on 2000–04. Never materially worse; the salt-0 win is a
null path-lottery. **KEEP-52 stands; no re-open.** The record-convention
worsening was the record's pins, not the clock. Cite the clock as a drawdown
floor, not a win. Original framing kept below for the record.

### (original P0 text)

`project_clock52_promoted` keeps 52 on a "universal maxDD win" measured
pre-fix on the DEFAULT bundle. On the record convention, fixed basis, the
clock's maxDD is 10.8 / 13.0 / 10.8pp WORSE on 2019–23 (one MSTR position
dominating the book) and flat on 2000–04. Different base, so the decision
stands — but run the default-bundle pair (clock 0 vs 52, fixed basis,
salts 0–2, 2019–23 + 2000–04; the 5y cells take ~22 min 2-concurrent) before
52 is quoted as a drawdown lever again. **Use the new 2019-vintage
warehouse for the 2019 window** (first level-valid 2019 cells). If maxDD is
worse there too, the KEEP-52 decision needs re-opening with the user.

## P1 — vintage warehouse gap fetch (carried)

~600 (2009) / ~730 (2019) names in each composition have no CSV — delisted
names the EODHD delisted endpoint can supply (`fetch-historical-data`
skill, `project_eodhd_delisted_unlock`). Fetch, then rebuild the two
warehouses with `-incremental`. Until then label every 2019-vintage number
with its effective name count (`universe.txt` in the cell output).

## P2 — carried

- Now that the exit stack AND the clock are settled on the fixed basis, the
  next measurement is entry-side on the 2019-vintage warehouse (level-valid
  2019 cells for the first time): re-run the default-bundle null at 26y? No —
  5y broad first per the user; the c0 cells here (0.23 / 11.86 / 5.40%) are
  the new 2019–23 default-bundle nulls at salts 0–2.

- Entry-side / top-of-funnel: the record's exit stack is settled, so the
  remaining gap vs the record is `project_monster_funnel_top_of_funnel`
  (breakout gate 51% + top-N 36% of monster deaths). Entry-side levers
  (weekly-close trigger, base-top anchor) on 1y/3y/5y broad, now with a
  level-valid 2019 warehouse.
- #2650: widen `goldens_affected_check.sh` to tier-2/tier-4 or declare
  them out of scope; graduate `perf-nightly` from `continue-on-error`.
- V15 follow-up (#2649 review): `bars_of_daily` weekly-close docstring
  bullets unpinned.
- `stage3_force_exit` hysteresis 1 is a dead knob on the record convention
  (one fire in six window-salts). Candidate for the mechanism-flag
  inventory as "inert on record; keep as axis".

## Ops notes

- Chain scripts: a mechanism that never fires yields the null digit-for-digit
  at every salt — check salt 0's exit-trigger histogram before spending salts
  1–2 on it (saved ~70 min today by trimming six cells; recorded in the README).
- A hold-longer arm's edge sits in `open_positions.csv` × `final_prices.csv`;
  the chain now archives both per cell (`archive_extra.sh` pattern).
- Core `Command` exes take single-dash flags (`-universe-path`); the
  vintage launcher's first run died in 1 s on `--universe-path`.
- Pinned worktree `.claude/worktrees/sweep-lever0904` (e4984c5fe) holds the
  chain's output roots and the vintage build exe; remove after the PR merges.

## Do not

- Do not quote the lagoff 2019–23 +97pp or the clock52 +51pp as anything but
  one trade (NVDA / MSTR).
- Do not compare 2019-window levels across the 2000-vintage and 2019-vintage
  warehouses; different name sets.
