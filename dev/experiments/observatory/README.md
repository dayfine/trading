# Axis observatory: the pair reader (P2a) and the lane (P2b)

`obs_read.sh` is the mechanical read of one arm against the baseline S, as set in
`dev/plans/axis-observatory-2026-11-14.md` §1 and §3. Each read appends one mark-free row to `surface.tsv`, the
public record of every arm the observatory has run; a re-read of the same arm at the same commit replaces its row.
The price-derived detail goes to a private out dir. A results-analyst reads an arm only when its row carries a flag.
`lane.sh` (§Lane below) runs the paired cells, checks each pair and calls the reader.

It is POSIX sh plus awk (mawk, BWK awk or gawk), and needs no build or container.

## Run it

```sh
sh dev/experiments/observatory/obs_read.sh \
  -r <results dir> -p <cell prefix> -a <arm letter> \
  -l <arm label> -v '<config overlay>' -c <commit> \
  -O .sweep-output/observatory/<label> [-y <SPY years file>]
```

For example, `-r dev/experiments/price-band-confirm-2026-11-13/results -p pbc2 -a P` reads the
`Price_band_seeded` breadth cell. Its median D_end of -0.2803 matches that README's median Δ ln(1+R) of -0.280.

| flag | meaning | default |
|---|---|---|
| `-r` | run dir: per seed K, `kK/` or flat, files `<prefix>-<arm>-kK[-<salt>]-<kind>` as the chains write them | required |
| `-p` | cell prefix (`pbc2`, `sec`, ...) | required |
| `-a` | the arm's letter in the file names | required |
| `-b` | the baseline's letter | `S` |
| `-l` | arm label for the row | required |
| `-v` | the arm's config overlay, inline or `@file` | required |
| `-c` | the build's commit | required |
| `-O` | private out dir | required |
| `-k` | seeds | `0 1 2 3 4` |
| `-y` | SPY years file: one `YYYY bull` or `YYYY bear` per line, `#` comments; the lane passes `spy_years.tsv` (§Lane, SPY years) | none: the bull/bear split is NA |
| `-t` | surface file to append to | `surface.tsv` beside the script |

## Inputs, per seed and arm

Each input is a file the chains already produce:

- `equity_curve.csv`
- `trades.csv`
- `open_positions.csv`
- `summary.sexp`
- `macro_trend.sexp` (base arm only)
- the arm's V6 diff log against the base, `<arm tag>.v6diff-<base>.log`, if the chain wrote one

## Public and private: what goes where

EODHD terms forbid redistributing price data (`project_eodhd_terms_private_bucket`), and a NAV curve lets a reader
back out closes.

**Private: the `-O` out dir.** These files hold price-derived data and go to `dayfine/trading-results`, never to
this repo:

| file | content |
|---|---|
| `D.tsv` | weekly D(t), one column per seed |
| `steps-kK.tsv` | every weekly step: its macro state, its share of D_end, and the three heaviest diff positions active in its week |
| `years-kK.tsv` | yearly increment, regime, and entries and mean positions held per arm |
| `firstdiff-kK.tsv` | the keyed trades diff, which includes prices |
| `seeds.tsv` | the per-seed lines the row aggregates |
| `row.tsv` | the row that was appended |

The script refuses an out dir that git would track: any path inside a work tree that is not ignored. An ignored path
such as `.sweep-output/observatory/<label>` is fine.

**Public: `surface.tsv`.** It holds only logs, rates, shares, percentage points, counts, dates and symbols. Before it
appends, the reader refuses a row with any computed number of magnitude 10,000 or more; such a number is a leaked
level.

## Definitions

- **D(t)** = ln(NAV_A / NAV_S), sampled at the last equity-curve row of each Monday-aligned week. It starts from 0 on
  the first row, since both arms start from the same cash. The weekly steps therefore sum to D_end.
- **The pair must start from the same cash and share every equity date.** The reader checks the two `summary.sexp`
  `initial_cash` values and every curve date; if either differs, it exits 2.
- **Yearly increment**: the sum of a calendar year's steps.
  - Each seed's positive rate is the share of its years with an increment above 0; the negative rate is the mirror.
    A zero year counts as neither.
  - `yr_pos_rate` and `yr_neg_rate` pool all years across all seeds.
  - `seeds_pos60` and `seeds_neg60` count the seeds whose own rate is at least 60 %.
- **Macro split**: each step is assigned the base's `macro_trend.sexp` state from the latest record on or before the
  previous sample date, which is the state in force when the week was traded. `d_mac_bull`, `d_mac_neut` and
  `d_mac_bear` sum the steps under Bullish, Neutral and Bearish.
- **Bull/bear years**: `d_bull_yr` and `d_bear_yr` sum the yearly increments of the years the `-y` file marks bull or
  bear. Without `-y` they are NA.
- **Step share**: step / D_end. It is NA when |D_end| < 0.00005.
  - The per-seed maximum (`step_max_seeds`, median `step_max_med`) is the largest share toward D_end.
  - `top5_steps` lists the five largest shares of the median-D_end seed (`top5_seed`) as `week-end share [positions]`.
  - Each step names up to three diff positions held at some point in its week, heaviest first, as
    `SYM@entry_date/class`. The class is `A` (arm only), `S` (base only, i.e. crowded out) or `C` (both arms, but
    the rows differ).
  - The weight is the position's whole-trade contribution as a percentage of entry NAV; an open position uses its
    size instead.
  - This is a pointer to where to look, not a decomposition of the step.
  - The step clause of the flag rule measures one-week concentration, not one-trade concentration. A lottery that lands
    in one week, like the fixture's MONSTR, carries a large share. A monster ridden over many weeks spreads its D across
    them, each week under half, so the clause cannot see it; `top5_steps`, `s_out` and `a_new` are where to look.
- **Positions**: keyed by symbol and entry date, the firstdiff key. A shifted position_id is not a change.
  - `s_out` counts the base's positions the arm lacks; `a_new` counts the arm's positions the base lacks.
  - `d_pos_held` is the change in the mean count of positions held at the weekly samples.
  - `d_entries_yr` is the change in positions entered per year.
- `d_maxdd_pp` and `d_ulcer` come from the two `summary.sexp` files, arm minus base.
- **Cross-seed values**: every value without a per-seed list is the median over seeds.
- `v6` is `ok` when every seed's V6 log passed, `unchecked` when none had one, and `partial` otherwise. A failed log
  stops the read.
- `arms_run` is the row's ordinal in the surface. A flagged read quotes it, per plan §3, "Multiple comparisons".
  - A re-read of the same arm (label) at the same commit replaces its row in place and keeps its ordinal, so a fix-and-
    re-read does not inflate the count. The same arm at another commit is a new row: a new build is a new measurement.
  - Two lanes that append at once can give two rows the same ordinal (the files merge as a union, §Lane); count rows,
    not the largest ordinal.

## The flag rule (plan §3: set before any arm ran; change it only before P3 starts)

**UP** when all three hold:

- median D_end is at least 0.20;
- `seeds_pos60` is at least 4;
- the median over seeds of the largest step share is under 0.5.

**HARM** is the mirror: median D_end of -0.20 or less, `seeds_neg60` at least 4, and the same step clause. Every other
row is `none`. The constants live in `read/lib/row.awk`.

A flag opens a pre-registration on a disjoint window. It is not a promotion.

## Check

`trading/devtools/checks/obs_read_check.sh` runs under `dune runtest`.

**Fixture.** `trading/devtools/checks/fixtures/obs_read/gen_fixture.sh` builds five seeds of made-up NAVs, with no
bars, over seven years. Its eleven arms (table in the generator's header) pin every clause of the flag rule in both
directions, and a second, five-year run (`gen_fixture.sh DIR five`) adds two:

- a slope arm, which must flag UP, and a harm arm, which must flag HARM;
- an UP arm and a HARM arm that sit on every boundary (median D_end ±0.2000, exactly 4 seeds at 60 % or more with
  three at 5/7, largest step share 0.499), which must flag;
- for each clause and each direction, an arm that misses only that clause by a hair and must not flag: median D_end
  ±0.1999; 3 seeds at 60 % or more, with two at 4/7 = 0.571; a step share of 0.500, or the one-step lottery at 0.85;
- a zero year (seed k0 of each seeds near-miss is identical to S through 2010), which must count as neither sign;
- the five-year arms F and G, which must flag UP and HARM: their fourth seed at or above 60 % is k0 at exactly
  3/5 = 0.60, so the per-seed rate must be compared with `>=`, not `>`.

The appended rows must equal `expected_surface.tsv` beside it.

**Refusals.** Each of these must leave the surface it targets byte-identical:

- a failed V6 log;
- an out dir that git would track;
- unpaired equity curves;
- a surface with another header;
- a max-drawdown delta the size of a price or NAV level, read end to end through `obs_read.sh`;
- arms that start from different cash.

**Re-reads.** Re-reading an arm at the same commit replaces its row, keeps its ordinal and leaves every other row
alone; the same arm at another commit appends a row.

## Lane

`lane.sh` is the observatory's runner (plan §2.1, §2.2, §4): POSIX sh in the shape of
`../gate-funnel-2026-11-15/chain.sh` (`dev/rules/sweep-hygiene.md` §"Chains that publish"). One Claude cloud session
runs one arm with the chain detached, and no analyst reads a cell.

### Launch

The session needs `dayfine/trading-results` checked out beside the repo (`TR=../trading-results`) and the R2
credentials in its environment.

```sh
git checkout <LANE_SHA>
mkdir -p .sweep-output/observatory-lane
LANE_SHA=<LANE_SHA> setsid nohup sh dev/experiments/observatory/lane.sh run > .sweep-output/observatory-lane/lane.out 2>&1 &
```

- `lane.out` goes in the gitignored out dir, not the repo root, where a session's Stop hook flags it as untracked.

- Launch consecutive arms at the same `LANE_SHA`, so they reuse S. A new SHA runs S again, which is also the next
  drift point.
- `sh lane.sh run --dry-run` prints the arm, every cell's reuse decision, the batches, the checks and the publish
  lists. It runs nothing and needs no container, network or credentials.
- `sh lane.sh drift` runs S at HEAD and the drift read only (plan §2.1).
- `sh lane.sh read [LABEL]` repeats the checks and reads on finished cells. `stage`, `docker`, `collect` and `publish`
  repeat one step, under the same lock as a run.
- A relaunch reuses every finished cell, replaces its own surface row and commits only what changed.

### What one run does

1. **Guards.** HEAD is `LANE_SHA` and on origin/main, and the checkout is clean. trading-results must fast-forward and
   accept a dry-run push; a failed check is fatal, because a lane that cannot publish privately would strand its cells
   in a session that ends (`TR_PUSH_OPTIONAL=1` overrides). MemTotal must be at least `CELL_GB + MEM_RESERVE_GB`.
2. **The arm.** The first `pending` row of `queue.tsv`. The lane reads HEAD's queue but takes each arm's status from
   the `observatory/lane-results` branch when that branch has one, so an arm finished there is not run again before
   the branch merges. With no pending arm it runs the drift mode.
3. **Stage, SPY years, docker, build.** The record's data stage (warehouse v12wk-9236, corpact-2026-10-27, bars
   data-20261102). If `docker info` fails, the lane starts `dockerd` and logs why it had to.
4. **Specs.** `obs-S-kK` is `rk-kK` below the header. `obs-<label>-kK` is `obs-S-kK` with the arm's overrides added
   after the `tiebreak_seed` line.
   - An override of a field the record config already sets replaces it, scalar or not (`hysteresis_weeks 3` over the
     record's 2, `stale_exit_after_days (10)` over `(5)`). The record's line for the same field path is dropped, so the
     arm's value is the only one in the spec, and the lane logs `OVERRIDE <field>: <record> -> <arm>`.
   - The field path is the full chain of single-field records down to the value, one override form per spec line, as
     `rk-kK` writes them. Only that exact path is replaced: a sibling under the same parent, or a field that shares
     only the leaf name, stays.
   - Refused: a form that sets more than one field at once (write one form per field), and `tiebreak_seed`, which
     the lane sets per seed.
5. **Cells.** For S and for the arm, each of k0–k4 is reused when this HEAD's cell is finished in the out dir, else in
   trading-results (`runs/<head>/<arm>/`), and run otherwise. S therefore runs once per HEAD. The cells to run go
   `PAR` at a time, after a three-month preflight of the arm's k0: the spec parses, the overrides reach
   `params.sexp`, and the cache line is the record's (`n_symbols=9200`, one absent).
   - **Validator gate.** V12 compares each stop with `gate_max_stop_distance_pct`, which defaults to 0.15, the record's
     `stops_config.max_stop_distance_pct`. An arm that sets `stops_config.max_stop_distance_pct` X is validated with
     `-config` carrying `((gate_max_stop_distance_pct X))`, so **V12 follows the arm's gate**; without it msd-18 showed
     274-294 false V12 INV violations per seed (#3648). The lane logs one
     `VALIDATOR CONFIG <label> gate_max_stop_distance_pct X` line per arm and writes the file into each cell's dir as
     `<cell>-validator-config.sexp` (public: it is the arm's own number). S, and an arm that does not set the dial,
     run the validator's defaults with no `-config`. V6, the paired gate, is unaffected.
6. **Validity, before any read.**
   - **Tripwire.** S k0's `trades.csv` md5 is compared with the S k0 of the last HEAD published to trading-results, or
     with the record's `0928cfe40333560429f5a6e57c9c18de` when there is none. A mismatch is a `baseline-drift`
     event in `events.tsv`. The pair is still read, since S and the arm share the build.
   - **V6** on every seed, arm against S. A failure marks the arm `invalid@<head>`.
   - **Liveness.** The arm's `trades.csv` must differ from S's on at least one seed. Otherwise the dial is dead: the
     lane logs DEAD, marks `dead@<head>`, writes a `dead` event and reads nothing.
   - Equal starting cash and paired curves: `obs_read.sh` checks both.
7. **Read.** `obs_read.sh` writes the arm's row to `surface.tsv`, and the arm becomes `done@<head>`.
8. **Drift read** (plan §2.1). S at HEAD is read against S at the last HEAD whose S is in trading-results: the same
   read with A = the new S, labelled `drift@<prev>`, into `drift.tsv`. If the trades are identical on every seed, the
   lane writes a `drift-none` event instead; if `obs_read.sh` refuses the pair, a `drift-read-failed` event.
9. **Collect and publish.**

### Files

| where | what |
|---|---|
| branch `observatory/lane-results` of dayfine/trading (public) | `surface.tsv`, `drift.tsv`, `events.tsv`, `queue.tsv`, `spy_years.tsv`; per cell under `runs/<head>/<arm>/`: `actual.sexp`, `summary.sexp`, `params.sexp`, `macro_trend.sexp`, `.rss`, `.validator.log`, the V6 logs, `-validator-config.sexp` (arms that set the stop gate); `lane-logs/<head>-<label>.log` |
| dayfine/trading-results main (private), same paths | every file above, plus each cell's `trades.csv`, `equity_curve.csv`, `open_positions.csv`, `splits.csv`, `force_liquidations.sexp`, validator reports, runner log and `.ok` marker; `obs_read.sh`'s out dirs `reads/<label>@<head>/` and `drift/<head>-vs-<prev>/` |
| nowhere | `trade_audit.sexp`, `candidates.sexp` |

- `classify` in `lane.sh` draws this line once, and the dry run prints it file by file.
- `surface.tsv`, `drift.tsv` and `events.tsv` merge as a union (`.gitattributes`), so two lanes that publish at once
  both keep their rows.
- Publish commits this session's files on the branch commit the state was read from, then merges HEAD and any newer
  branch tip.
- The branch reaches main through a results PR.

### SPY years

`spy_years.tsv` is the `-y` file.

- **Rule.** Year Y is `bull` when SPY's last close in Y (on or before the run's end, 2026-06-26) is at or above its
  last close in Y−1, and `bear` otherwise. A year whose prior year is not in the bar file gets no label.
- **Close, not adjusted close.** The label follows the index level a reader sees on a chart. So 2011 (−0.2 %) and 2015
  (−0.8 %) are bear years, although their total return was positive.
- **Source.** The lane writes the file from the staged archive's `S/Y/SPY/data.csv`. It saves that file before the
  committed `test_data` overlay replaces SPY with one that starts in 2009. It logs any difference from the committed
  copy, and publishes only the labels.
- The committed copy came from `sh lane.sh years data/S/Y/SPY/data.csv` on the local bar store.
- **Weakness.** 2011 and 2015 sit within 1 % of the prior close, so the bear years mix two flat years with 2008 and
  2022, and `d_bear_yr` is diluted by chop. 2026 is a half year. The labels feed only the descriptive `d_bull_yr` and
  `d_bear_yr` columns, never the flag rule; the regime read of record is `d_mac_*`, from the base's `macro_trend`.

### Cost

- **Parallelism.** `PAR = (MemTotal − MEM_RESERVE_GB 3) / CELL_GB 6`, which is two cells at a time on the 15 GB VM.
  A record cell peaked at 5.7–5.9 GB and ran 7,161–8,058 s (#3595).
- **Wall time.** At a new HEAD an arm is 10 cells in five batches, about 12 h. At a HEAD whose S is published, it is
  5 cells in three batches, about 7 h.
- **Timeout.** `CELL_TIMEOUT` is 20,000 s, 2.5 times the slowest cell, since two cells share the host.
- **Tokens.** The plan asks for the first lane's token cost (launch, heartbeats, finish) to go in the perf ledger
  before more lanes are added.

### Check

`trading/devtools/checks/observatory_lane_check.sh` runs under `dune runtest`, with no container and no network. It
builds a two-commit git repo in a temp dir from the lane, the reader, the record specs and a fixture queue
(`fixtures/observatory_lane/queue.tsv`), plus a made-up trading-results dir.

- **Dry runs.**
  - Arm choice: the first pending arm, and a branch status overrides HEAD's.
  - Each cell's reuse decision: run, trading-results, or finished in the out dir.
  - The batches at 15 GB and at 14 GB, where the reserve leaves one cell at a time.
  - The tripwire's md5 and source, and the drift pair.
  - The publish lists, and that a dry run copies nothing.
- **Specs.** The arm is the record plus exactly its overrides. An override of a field the record sets (a scalar,
  `hysteresis_weeks`, and a list, `stale_exit_after_days`) replaces the record's line: the field appears once, with the
  arm's value, and the lane logs the `OVERRIDE`. The match is on the full path: `pos-arm` swaps exactly one of the three
  `portfolio_config` lines, and `leaf-arm` (`stage3_force_exit_config.hysteresis_weeks`) replaces nothing. A form
  setting two fields, and an arm setting `tiebreak_seed`, are refused.
  A `screening_config` sibling of `tiebreak_seed` (`sib-arm`, the queue's `cap-40` and `fbt-05` shape) is added beside
  it and replaces nothing. Every pending arm of the real `queue.tsv` must pass the same spec checks.
- **The validator config.** An arm that sets `stops_config.max_stop_distance_pct` 0.18 (`msd-arm`) gets
  `((gate_max_stop_distance_pct 0.18))`, logged once as `VALIDATOR CONFIG`, passed as `-config` in the validator
  command the dry run prints (the string `run_cell` runs) and published with the cell. S and the arms that do not set the
  dial get none. The check fails if the config is dropped, if the command omits `-config`, or if a no-stop arm gets one.
- **`read` on synthetic cells** (the obs_read fixture's S, U and H):
  - a live arm's row and `done@`;
  - the drift row;
  - one baseline-drift event;
  - a dead arm's `dead@` and no row;
  - a re-read over the branch's surface that replaces its row and keeps another;
  - a collect whose public tree holds no price-bearing file.
- **The gates on their failing side**, in the same `read` path:
  - a live arm with one failing V6 log ends `invalid@`, with one `invalid` event, no row and no read dir;
  - a would-be-dead arm with a failing V6 log is `invalid`, not `dead`, since V6 runs before liveness;
  - an arm that differs from S on one seed only is live and read;
  - a parent S identical to HEAD's gives a tripwire match with no `baseline-drift` event, and a `drift-none` event
    with no drift row;
  - a failing drift V6 log gives a `drift-invalid` event and no drift row.
  - a drift pair that `obs_read.sh` refuses (unequal starting cash) gives a `drift-read-failed` event and no drift row.
- **`years`.** The label rule on a made-up bar file: a fall, a tie, a gap, the run-end cut and a bad header, and
  that `years` writes nothing under the out dir.
- **The lock** (where `flock` exists). `run`, `read`, `stage`, `docker`, `collect` and `publish` refuse to run beside
  another holder.
  A `dockerd` that the docker preflight starts (a stub on PATH) must not keep `lane.lock` once the lane has exited; the
  lane launches it with the descriptor closed. The cells keep it on purpose: if the lane is killed, a relaunch is
  refused until the cells still running finish, instead of starting them again.
- **Parse.** `lane.sh` is outside `posix_sh_check.sh`'s scan dirs, so the check runs `dash -n` on it.
