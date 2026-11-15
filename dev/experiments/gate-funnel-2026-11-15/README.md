# Gate funnel (2026-11-15): pre-registration

**Status: pre-registered, not run.** One 26-year diagnostic cell (P1 of `dev/plans/axis-observatory-2026-11-14.md`
§2.0). The rules below are fixed before the run. `chain.sh` runs it in one Claude cloud session (§Launching).

## Why

The axis observatory plan queues paired runs of dials already on main. Before it picks an order, it needs to know what
each gate of the long cascade removes, and whether the removed names were worth having (plan §2.0).

- **What the cell can now see.** #3625 and #3626 (merged as 63a608151 and 917341665) add a top-N view to
  `candidates.sexp`. Every row that cleared the cascade carries its `rank` in the order the cap cut. An `Admitted` row
  carries what the entry walk did (`walk`: `Funded`, `Skipped <reason>` or `Not_reached`) and the stop distance its
  width gate measured. A `Dropped_at_top_n` row carries a `shadow` verdict from the walk's own stop check
  (`Buyable d`, `No_structural_stop`, `Stop_too_wide d`, `Already_held`). Each week carries `tickets_placed`,
  `long_cash_left_pct` and `long_resting_reserved_pct` (the unfilled cost of long entry tickets still resting at the
  walk, as a fraction of portfolio value). Schema: `trading/trading/backtest/lib/candidate_log.mli` on main.
- **The question it settles first: gate before cap.** The screener cuts its sorted list at 20 before the walk asks
  whether a name has a valid stop. On a Friday when cash was still free, was a buyable name past rank 20 crowded out
  by unbuyable names above it? If that happens often enough to matter, a gate-before-cap dial (walk down the ranked
  list until the cash or the buyable names run out) is a candidate for the queue. If not, it is not.
- **The prior, stated before the run: CLOSE is expected.**
  - The 09-22 top-N arm (`max_buy_candidates` 20 → 40, `dev/experiments/top-of-funnel-2026-09-21/`, ledger
    `2026-09-22-top-of-funnel-capacity`) found that only 28 % of its arm-only entries came from ranks 21–40. 46 % were
    names the null had admitted the Friday before, whose tickets had not filled.
  - The book fills about 28 entries a year into about 5 slots. Slots and cash, not candidate supply, bind
    (`memory/project_top_n_capacity_verdict`).
  - **What could make it wrong.** In #3602's cell the walk ran out of cash on only 257 of 1,099 open Fridays
    (`../price-band-binding-2026-11-13/README.md` §Measurement 2), and 95 % of its top-20 slots held names that never
    fund. So on most open Fridays the walk did not run out of cash. How much it left, and whether ranks 21+ held
    anything buyable, no committed artifact measures, which is why CLOSE, PARK and BUILD are all live.
- **Two descriptive reads come free with the same file.** The funnel by gate and year, with what each gate's removed
  names did next, and score against outcome over the whole post-cascade pool. The second re-tests ranking after the
  RS-trend fix (#2380, 2026-08-26): every earlier selection test ran with a constant RS term.

## The cell

- **Spec.** `../price-band-tiebreak-2026-11-13/specs/pb-S-k0.sexp`, unchanged (md5 `7a2d9eba…`, pinned in
  `chain.sh`). It is #3602's pbb-S-k0 and #3595's pb-S-k0: the record config, `candidate_ranking` `Seeded` with seed 0,
  2000-01-01 → 2026-06-26, top-3000 PIT v12 deduplicated yearly lists, `TRADING_PATH_SEED_SALT=0`,
  `max_buy_candidates` 20. Nothing is added: `--emit-candidates` is observability only.
- **Build.** The `origin/main` commit that contains this directory (`GF_SHA`), after this pre-registration merges. It
  contains #3625 and #3626, which merged first. `chain.sh` refuses a HEAD without 63a608151 and 917341665, or whose
  `candidate_log.mli` lacks any of `rank`, `walk`, `shadow`, `long_cash_left_pct` or `long_resting_reserved_pct`.
- **Data.** #3595's and #3602's stage: R2 warehouse `v12wk-9236`, corporate actions `corpact-2026-10-27`, bars
  `data-20261102` plus the committed `test_data`.

## Validity (gates the read)

`chain.sh` checks these after the cell. If either gate fails, the read does not run (`READ SKIPPED`), and the
artifacts and log are still published. `FORCE_READ=1` reads anyway, and the log records that it did. A forced read is diagnostic only: it decides nothing, and
no outcome from it enters the ledger or the observatory queue.

- **TRIPWIRE.** The cell's `trades.csv` must be byte-identical to #3602's `pbb-S-k0-s0-trades.csv` and #3595's
  `pb-S-k0-s0-trades.csv`: md5 `0928cfe40333560429f5a6e57c9c18de`, 577 lines.
  - **Expected to match.** The top-N capture runs after the walk, on its finished output, and is pure: it places no
    order, debits no cash and consumes no position id (`cascade_trace.mli`, `with_top_n`). #3626's
    `test_trade_audit_capture` pins `trades.csv` and `equity_curve.csv` byte-identical with the collector on and off.
  - **What a match proves.** It is the 26-year proof that the new capture changes no trade.
  - **What the dispatcher checks when picking `GF_SHA`.** `git log --oneline 645065bb2..<GF_SHA> -- trading/` (645065bb2
    is #3602's build). At the time of writing that range holds two default-off flags (#3604, #3609), a demo with two
    read-only accessors (#3623), the top-N view (#3625, #3626) and harness changes; #3621's S cells, built at
    aab060262 with both flags in, reproduced #3595's md5. A behaviour-changing merge in the range fails the tripwire
    and stops the read, so expect a re-run if one lands first.
  - **The cost probe already saw it hold** on a top-3000 quarter: the same `trades.csv` with and without the flag, and
    with the pre-#3626 build (§Smoke).
- **n_symbols_absent.** Every snapshot-cache line in the cell log must read `n_symbols_absent=1`, as #3602's did (the
  record's one absent symbol).
- **Parity (logged, not gating).** `actual.sexp`, `summary.sexp`, `macro_trend.sexp`, `entries.tsv`,
  `equity_curve.csv`, `open_positions.csv` and `splits.csv` are compared with #3602's committed copies.
- **Cost (recorded).** Wall time, peak RSS and the size of `candidates.sexp` go on the `RESULT` line (§Cost).

## Self-check (a hard gate, run first)

The read checks the top-N view against the screener's order and against `trade_audit.sexp`'s own record of the walk.
If SK1, SK2 or SK3 fails, the read stops and `results/cell/read/selfcheck.txt` is the whole result.

- **SK1, rank.** On every open Friday, the pool (`Admitted` + `Dropped_at_top_n` Long rows) is ranked exactly 1..n,
  `Admitted` is exactly rank ≤ 20, and consecutive ranks are in the Seeded order: score descending, then the 32-bit
  FNV-1a hash of `"0|<date>|<ticker>"` ascending, then the ticker (`../price-band-binding-2026-11-13/read/lib/rank.awk`,
  reused unchanged; `chain.sh` refuses a HEAD where the seed key or the hash constants moved).
- **SK2, walk.** Every `Admitted` row's `walk` equals the weekly decision record for that name
  (`cascade_summaries` `decisions`, #3139: `Placed` ↔ `Funded`, `Skipped R` ↔ `Skipped R`), in both directions.
  `Not_reached` rows have no decision.
- **SK3, fields.** `tickets_placed` equals the Friday's `cascade_summary.entered`; every `Admitted` row has a `walk`
  and every cut row a `shadow`; every open Friday has `long_cash_left_pct`.
- **SK4 and SK5 (reported, not gating).** SK4 counts the Fridays on which the trace's rows by phase equal the
  `cascade_summary` counts, and on which Long rows exist exactly when `long_macro_admitted > 0`. SK5 prints the largest
  `Buyable` and the smallest `Stop_too_wide` distance, and the same for walked rows: the width gate should separate
  them.
- **Power.** The smoke runs SK1 with the wrong tie seed (1); it must fail (§Smoke).

## Definitions

- **Open Friday.** A screened Friday on which the macro gate does not block the long side. The trace omits a
  macro-blocked side entirely (`cascade_trace.mli`, `of_screen`), so a Friday is open when it has Long rows and no
  `Dropped_at_top_n` row sits at rank ≤ 20. Such a row would mean a live long-tightening macro flag blocked the side
  while the trace's own gate admitted it. The record sets neither flag, so none are expected; SK4 counts them.
- **m.** The median, over every placed long ticket in this cell (each `trade_audit.sexp` entry record, filled or not),
  of `initial_position_value` divided by the portfolio value (`equity_curve.csv`) on its decision date. The read also
  prints p10, p25, p75 and p90.
- **f.** Placed → filled for long tickets: (`trades.csv` rows + `open_positions.csv` rows) ÷ placed long tickets. In
  #3602 that was 581 / 683 = 0.851.
- **Free cash, two conventions.** Both are fractions of portfolio value at the walk.
  - **Gross:** `long_cash_left_pct`, what this Friday's walk left unspent.
  - **Net:** `max(0, long_cash_left_pct − long_resting_reserved_pct)`. On the default path
    (`reserve_cash_for_resting_tickets`, G3, off) the walk's budget is the portfolio's cash, which still includes the
    cost of tickets resting from earlier Fridays, so gross overstates what is truly free. With G3 on, the walk's budget
    already excludes them and net equals gross. The read takes G3 from the cell's `params.sexp`; the record leaves it
    off.
  - **Two caveats on net** (`candidate_log.mli`). A ticket that this same Friday's own cancels retire (the F2 rescreen,
    the TTL clock, the macro suspension) is still counted in `long_resting_reserved_pct`, because the walk reads the
    book before those cancels apply; on such Fridays net understates the free cash, which only lowers X net. And the
    G3-off difference can go negative when resting tickets over-commit the cash; the read floors it at 0.
  - **The decision uses net.** Both versions of X are reported, so the effect of resting tickets is visible.
- **Free-cash Friday.** An open Friday whose free cash is at least m.
- **Slots.** `floor(free cash / m)` on a free-cash Friday, else 0.
- **Crowded-out name.** A `Dropped_at_top_n` row whose shadow is `Buyable` on a free-cash Friday.
- **X.** The sum, over free-cash Fridays, of `min(crowded-out names, slots)`. The leftover cash is shared among the
  Buyable cut names in rank order, so on each Friday the first `min(…)` of them by rank are the would-be-funded set,
  **C\***. `X gross` and `X net` use the two cash conventions.
- **s.** The share of `Admitted` rows on open Fridays whose `walk` is `Not_reached`: an entry-assembly gate
  (liquidity, bar recency, delisting, declining MA; the short side is off) removed them before the walk. The shadow
  skips those gates, so it is an upper bound on buyability.
- **X ref** (net only). Each crowded-out name survives the entry-assembly gates independently with probability
  1 − s, so a Friday contributes `E[min(B, slots)]` with `B ~ Binomial(crowded-out names, 1 − s)`. Its bounds,
  `(1 − s)·min(n, slots)` below and `min((1 − s)·n, slots)` above, bracket the exact value the read uses.
- **Yardstick.** This cell's own `ln(1 + R)` over its closed trades. #3602's is ln(15.7276) / 576 = 0.0048 log per
  trade. The read computes it from `actual.sexp`, and `rules.txt` prints `X·f × yardstick` with each outcome.
- **Bear years.** 2000, 2001, 2002 and 2008. Their share of X ref is the sum of their Fridays' contributions over the
  total; their share of open Fridays is a count.
- **Outcomes (what a removed name did next).** The population screen's definitions
  (`../price-band-tiebreak-2026-11-13/screen/PREREG.md`), read from the screened Friday's close by
  `../price-band-binding-2026-11-13/read/lib/fwd.awk`, reused unchanged:
  - **monster:** a weekly close at least 2× the base within 52 weeks;
  - **ride:** the return to the first weekly close below the 30-week WMA, at most 104 weeks, **capped at +190 %**
    (PREREG Amendment 1);
  - **coverage:** the primary convention keeps a name delisted inside the 52 weeks (D, read over the weeks it traded)
    with the full-coverage rows (F). Rows the store truncates (T) or with no bar (X) are counted and left out.
    `STORE_END` is the run's end, 2026-06-26, so a live name is never read as delisted (#3602's defect 1);
  - **dedup:** one row per symbol per population per 26 weeks, the first kept, as the screen keeps one event per
    symbol per 26 weeks.
- **Halves.** 2000–2012 and 2013–2026.

## Decision rule (applied as written)

`results/cell/read/rules.txt` prints the inputs and the mechanical outcome of both rules. The reading and the why
belong to `results-analyst`.

### Rule 1: gate before cap

Checked in this order:

0. **NOT APPLIED** if `long_resting_reserved_pct` is missing on any open Friday. X net cannot be computed; X gross is
   reported only. (`chain.sh` refuses a build without the field, so this branch exists for a re-read of an older file.)
1. **CLOSE** if `X net · f < 25` over the 26 years. A no-build decision: even the upper-bound shadow finds too few crowded-out
   buyable names, so nothing is built and the observatory's queue drops the "gate-before-cap, not built" row.
2. Otherwise **REFINE** before any build. Measure s, compute X ref, and compare C\* (net) with the funded names
   (`walk` `Funded`) on mean capped ride. The monster rate is printed beside the ride but enters no clause. **BUILD** only
   if all three hold:
   - `X ref · f ≥ 40`;
   - C\*'s mean capped ride ≥ the funded names' mean − 1 pp;
   - the bear years' share of X ref ≤ their share of open Fridays + 10 pp (C\* is not concentrated in bear years).
   BUILD means a default-off flag and a K = 5 paired pre-registration, never a promotion
   (`dev/rules/experiment-flag-discipline.md`, `dev/rules/promotion-confirmation.md`).
3. **PARK** otherwise, with the numbers: X·f was at least 25, but a refined bar failed. Nothing is built now; the rates
   go into the ledger.

A bar met exactly counts as met (the read compares with a 1e-9 tolerance, so a float subtraction cannot flip a tie).

**Why these bars.**
- **In trades.** X·f is the number of extra filled tickets the free cash could have bought. At the yardstick, 25
  trades are about 0.12 log over 26 years and 40 about 0.19 log. 0.2 log is the single-path floor below which an
  untraced 26-year delta is noise (`memory/project_26y_path_noise_floor`); the measured seed SD is 0.225
  (`memory/project_record_kseed_band`).
- **CLOSE at 25.** Below it, even an upper bound (the bullet after next) buys about half the floor, so no paired run
  could separate a gate-before-cap arm from seed noise.
- **BUILD at 40, after refining.** A build costs a flag, a K = 5 run and a read. It is worth that only when the refined
  count reaches the floor itself.
- **X is an upper bound in two ways, and that is deliberate.** The shadow ignores the entry-assembly gates, cash
  sizing and the share-class rule (s refines the first). And X sums each Friday's free cash as if earlier Fridays'
  would-be-funded names had not spent it. So a CLOSE is robust: the true count is lower. A BUILD only opens a
  pre-registered paired test, which measures the real effect. The read also prints a path-aware X, in which each
  would-be-funded name holds m of cash for the cell's `avg_holding_days`. It is information only and enters no
  branch.
- **The ride clause.** A gate-before-cap fills free slots with names the screener ranked lower. If they ride worse than
  the names it already funds, more of them is not worth building. The 1 pp tolerance gives a mean-difference clause the
  margin #3602 lacked (`../price-band-binding-2026-11-13/README.md` §For future pre-registrations): there, a −0.1 pp
  difference decided the branch.
- **The bear clause.** The stale-E K = 5 read found a lever whose whole effect sat in 2000–02 and 2008 (#3621). Extra
  long entries concentrated in bear years would be a regime bet, not a funnel fix.

### Rule 2: score against outcome (the ranking lever)

Over the post-cascade pool (`Admitted` + `Dropped_at_top_n` Long rows on open Fridays), by score tier: the row's own
`grade`, which the screener derives from the score (A+ ≥ 85, A 70–84, B 55–69, C 40–54; min grade C). The top tier is
A+ and the next is A. One row per symbol per tier per 26 weeks.

1. **UNDERPOWERED** if A+ or A has fewer than 100 rows in either half, or the two together have fewer than 20 monsters
   in either half. No ranking lever follows.
2. **RANKING LEVER** if A+'s mean capped ride beats A's by at least 2 pp in both halves, and A+'s monster rate is at
   least 1.3× A's over the whole window. A ranking lever then gets its own later pre-registration; this read decides
   nothing more.
3. **NO RANKING LEVER** otherwise.

The minimum counts are this pre-registration's addition to the bars: #3602's Rule 2 let a two-event cell decide
(`../price-band-binding-2026-11-13/README.md` §Defects found 4).

## Descriptive reads (no verdict; tables fixed in advance)

1. **The funnel by year** (`read/funnel.txt`, per year `read/funnel_year.tsv`). Name-Fridays entering the long cascade
   (`candidates_after_held`) and removed at each gate: macro, each #2533 breakout sub-gate (`Price_floor`,
   `Stage_setup`, `Breakout_volume`, `Rs_declining`, `Failed_breakout`, `Volume_band`, first failing gate), sector,
   grade, the top-N cut, then each walk outcome (`Not_reached`, `No_structural_stop`, `Stop_too_wide`, cash, held,
   other skips, funded). Each as a share of entering and of what reached it.
   - Macro comes from `trade_audit.sexp`'s `cascade_summaries` counts, because the trace has no names for a blocked
     side. Every later gate is counted from the trace's rows on open Fridays. SK4 says whether the two agree.
2. **What each gate's removed names did next** (`read/counterfactual.txt`). For every population (each sub-gate, sector,
   grade, the cut by shadow verdict, C\* gross and net, each walk outcome, and every evaluated row as a baseline): rows,
   kept rows, coverage, monster rate, win rate, mean capped ride, p10 / p50 / p90, each half, and the difference from
   the funded names.
   - **Macro is a proxy.** The trace names no macro-blocked candidate, so the macro population is the population
     screen's own book-style breakouts (`../price-band-tiebreak-2026-11-13/screen/lib/mscan.awk`, reused unchanged)
     in the weeks of Fridays that were not open, read from that Friday's close.
3. **Score against outcome** (`read/score.txt`). The same columns by tier (deduplicated per tier, and row-weighted)
   and by score value. Rule 2 reads the tier rows.

Also written: `read/gate_before_cap.txt` (m, f, s, the yardstick, the per-year table of free-cash Fridays, cut rows,
Buyable cut rows, crowded-out names and X gross / net / ref, C\* by cut rank 21–40 / 41–100 / 101+, the bear shares and
the path-aware X), `read/fridays.tsv` (one row per open Friday: counts and cash fractions, no names),
`read/selfcheck.txt` and `read/inputs.txt`.

## Not claimed

- **No return verdict.** One path and one seed. Nothing here says a gate-before-cap arm beats S, and nothing changes a
  default. BUILD opens a paired pre-registration; it is not evidence of an effect.
- **The shadow is an upper bound on buyability.** It skips the entry-assembly gates (s refines that), cash sizing
  (`Sized_to_zero`), the share-class rule, sector caps and the `freeze_entry_at_first_breakout` re-pin (off in the
  record).
- **X ignores path.** It is counted on S's path and treats each Friday's cash as fresh, and the same name can count on
  consecutive Fridays. Funding a crowded-out name changes later cash, later walks and later tickets.
- **Outcomes are the screen's ex-post read**, not stop-managed trades: a weekly-close doubling and a 30-week-WMA ride
  from the screened Friday's close, for names that were listed, not filled.
- **The macro counterfactual is a proxy** on the screen's breakout predicate, not the strategy's.
- **First failing gate.** A name `Stage_setup` dropped may fail later gates too, so a gate's removed population is not
  what loosening that gate alone would admit.
- **In-sample.** The same 2000–2026 history every earlier screen used.
- **The smoke is plumbing** (`.claude/rules/universe-discipline.md` U2). No smoke number bears on a rule.

## Rigor checks (`dev/rules/mechanism-validation-rigor.md`)

1. **Estimand.** A gate-before-cap dial changes which names fill free slots on Fridays when the top 20 holds nothing
   buyable. X counts exactly those slots on one path; the gap to realised P&L (path, fills, stops) is named above.
2. **Distribution.** Quantiles of the capped ride for every population, per-Friday counts in `fridays.tsv`, X by year.
3. **Scale.** X·f is in filled trades and converted to log NAV with the cell's own yardstick.
4. **Selection.** Delisted names stay in (convention FD); outcomes are ex post and never inputs.
5. **Surface.** One cell at the record's settings; the cap (20) is the setting the dial would change. The 09-22 arm
   already tried 40.
6. **Paired.** Not applicable to a single cell; C\* is compared with the same cell's funded names.
7. **Power.** Rule 2 has minimum counts; Rule 1's ride clause has a tolerance; the self-check has a negative control.
8. **V6.** A single cell: its validator runs and its report is collected; there is no pair.

## Cost (`dev/rules/sweep-hygiene.md`)

The run is one Claude cloud session.

- **Expected cell wall time.** #3602's cell with `--emit-candidates` ran 7,477 s. The shadow adds one stop check per
  cut row per open Friday: about 476,000 over the run (498,225 pool rows less about 22,000 admitted), 350–480 per open
  Friday. The local cost probe (§Smoke, `results/smoke/cost.txt`) could not separate the shadow from the container's
  noise: between nothing and about 9 s per weekly cycle. Over about 1,430 cycles the cell should take 7,500–21,000 s,
  2.1–5.8 hours. Its `RESULT` line records the real wall, peak RSS and CPU time.
- **`CELL_TIMEOUT` = 50,000 s**, 2.4 times the slow end. A cell that reaches it logs `CELL FAILED … exit 124`.
- **Memory.** #3602's cell peaked at 9.06 GB on a 15 GB session (`mem=15G`). The shadow reads a symbol's bars and drops
  them; the cost probe saw no change in peak RSS with it. The new fields add a few per cent to `candidates.sexp`, which
  is written at the end. Expected peak: 9–10 GB. `MEM_MIN_GB` = 12: a smaller machine aborts in the first minute.
- **If the VM runs out of memory.** The kernel kills the runner, the cell ends with `exit=137` and no `actual.sexp`, and
  `chain.sh` logs `CELL FAILED … most likely out of memory` and aborts. Do not relaunch: the same cell on the same VM
  would fail again after the same hours. Push the log; the dispatcher re-runs it on a larger session or locally.
- **Disk.** At least 8 GB free before the cell (`DISK_CELL_GB`). #3602 had 16 GB free after staging. `candidates.sexp`
  was 974.5 MB; the read's scratch (all Long rows, forward outcomes for about a million symbol-dates) is about 2 GB.
- **The read.** #3602's took 516 s; this one computes forward outcomes for every population and scans every PIT member
  for the macro proxy. Expected 15–40 min.
- **Session total.** Stage 7 min, build 1–2 min, preflight 6–10 min, the cell, the read, the publish: about 3–7 hours.
- **Never committed or pushed anywhere.** `candidates.sexp` and `trade_audit.sexp` (`chain.sh collect` leaves them out).
  The read's scratch holds raw closes and stays in `.sweep-output/`.

## Smoke (`results/smoke/`, plumbing and cost only)

`smoke.sh` runs inside the dev container on a local build. Every file in `results/smoke/` carries the banner: nothing
in it bears on a rule.

**Plumbing, on main at 917341665** (`smoke.txt` and the read's tables). `specs/smoke-sp500.sexp` is the record config
on `universes/sp500.sexp` over 2019-07-01 → 2021-06-30, in CSV mode on the committed `test_data`; sp500 is a fixture
here (U2).

- **Tripwire.** `trades.csv` is identical with and without the flag: md5 `dcb8e99d…`, 41 lines, the same file #3602's
  smoke produced on the old build.
- **Self-check.** SK1 passes on all 99 open Fridays (1,329 pool rows), SK2 on 1,120 walked rows (13 `Not_reached` rows
  have no decision), SK3 passes, and SK4 agrees on 99 of 99 Fridays. `long_resting_reserved_pct` is present on all 99.
  With the wrong tie seed (1), SK1 fails on 422 rows, so it has power.
- **SK5.** No `Stop_too_wide` row appears on this window. The largest `Buyable` distance is 0.1472 and the largest
  `Funded` one 0.1491, both inside a 15 % width gate.
- **The read runs end to end** in 57 s. m 0.0816, f 0.811, s 0.0115. Free-cash Fridays: 90 gross, 50 net, so resting
  tickets matter. X gross 6, X net 1, X ref 1.0. Rule 1 reads CLOSE and Rule 2 UNDERPOWERED, as plumbing.
- **Rules.** `rules_check.txt`: eleven fabricated cases, one per branch of both rules plus the boundaries (X·f exactly
  25; the ride exactly 1 pp under the funded mean), each landing where §Decision rule puts it.
- **Cost on sp500 says little.** With the flag 81 s and 345 MB peak, without it 75 s and 294 MB; but sp500 cuts about
  two rows a Friday, against about 470 at top-3000.
- **Earlier runs.** The same smoke on #3626's branch gave the same tables at 95e4ff816, and Rule 1 NOT APPLIED at
  0ce303929, before the field existed, as step 0 says. Neither is committed.

**Cost probe** (`cost.txt`, four runs). The cell's own spec cut to 2000-01-01 → 2000-03-31 (runs 1–3) or → 2000-06-30
(run 4), on top-3000 PIT v12, against the container's v12wk warehouse (the source of R2 `v12wk-9236`) and the
committed `test_data`. The 364-day warm-up screens too, so the quarter is 65 weekly cycles; its window alone has 12
screened Fridays, 6 open, with 2,834 cut rows (472 per open Friday). Timings and counts only. The arms are `plain`
(no flag), `emit` (the flag, with the top-N view) and `base` (the flag on 63a608151, #3625 without #3626: the trace
without the shadow). `emit` ran on #3626's branch in runs 1–3 (0ce303929, then 95e4ff816) and on main in run 4; the
shadow code is the same in all of them.

- **Every arm of every run wrote the same `trades.csv`**, including `base`, the build before #3626: the flag and the
  top-N view change no trade on top-3000 either.
- **The extra reads are exact.** The shadow adds 345,546 snapshot-cache hits on the quarter (+5.3 %) and 390,266 on the
  half year (+5.0 %).
- **Peak RSS does not move.** 3.13 GB with the shadow and without it on the quarter (run 3), 3.33 GB against 3.29 and
  3.31 GB on the half year (run 4).
- **The wall cost is inside the container's noise.** Flag on minus flag off, per pair: +610 s (run 1, flag first),
  +602 s (run 2, other agents building), +280 s of CPU against `base` (run 3), and −75 and −28 s of CPU against the two
  `base` runs around it (run 4). In run 3 `plain`, which does the least work, took 1,110 s and `base` 332 s: the
  machine's speed moved by more than the effect. The shadow costs between nothing and about 9 s per weekly cycle here.
- **For the cell** that is 0 to about 13,500 s on top of #3602's 7,477 s, over about 1,430 cycles: 2.1 to 5.8 hours.
  The cell's own `RESULT` line will give the real figure.

## Files

- **`chain.sh`.** The cloud chain: `run`, `stage`, `read`, `collect` and `publish`. Derived from
  `../price-band-binding-2026-11-13/chain.sh`, with the same stage, build, preflight, flock, SHA pin and resume. Its
  header says what changed.
- **`read/read.sh`.** The read driver, POSIX sh + awk. It writes mark-free aggregates to OUT and row-level tables to
  PRIV.
  - `lib/cands.awk` (the streaming `candidates.sexp` extract, top-N fields included) and `lib/summ.awk` (cascade counts
    and ticket costs from `trade_audit.sexp`).
  - `lib/check.awk`: the self-check. `lib/gbc.awk`: Rule 1's inputs. `lib/fy.awk`: the funnel by year.
    `lib/classes.awk`, `lib/mweek.awk` and `lib/cf.awk`: the populations and their outcomes. `lib/rules.awk`: both
    rules.
  - Reused unchanged: `../price-band-binding-2026-11-13/read/lib/{audit,rank,dates,fwd}.awk` and
    `../price-band-tiebreak-2026-11-13/screen/lib/{mscan,gspc_weekly}.awk`.
- **`read/rules_check.sh`.** Runs `lib/rules.awk` on fabricated gate lines through every branch of both rules.
- **`smoke.sh` and `specs/smoke-sp500.sexp`.** The local smoke and the cost probe.
- **Where the run's files go** (EODHD terms, user decision 2026-11-14; `../stale-e-cap-k5-2026-11-14/README.md` §Files).
  `chain.sh collect` splits them and `chain.sh publish` pushes both halves:
  - **Public, this repo, branch `experiment/gate-funnel-results`, under `results/cell/`.** `actual.sexp`,
    `summary.sexp`, `params.sexp`, `macro_trend.sexp`, `entries.tsv`, the `.rss` file, the validator log,
    `td-ca-extra.txt`, `chain.log`, and `read/`: the read's mark-free tables (counts, fractions, ride percentages by
    population, no names with returns).
  - **Private, dayfine/trading-results `main`, same path.** `equity_curve.csv`, `trades.csv`, `open_positions.csv`,
    `splits.csv`, `force_liquidations.sexp`, the cell log, the validator report (`validator.sexp.md`,
    `validator.sexp.sexp`), and `read/`'s row-level tables, gzipped: `pool_outcomes.tsv.gz` (every pool row with its
    outcome) and `crowd_outcomes.tsv.gz` (every Buyable cut row on a free-cash Friday). A row-level table goes there
    only under 90 MB gzipped; otherwise it is kept nowhere, and `read/inputs.txt` says so.
  - **Nowhere.** `candidates.sexp`, `trade_audit.sexp`, the read's scratch.
- **`results/smoke/`.** The smoke's mark-free tables.

## Launching (one cloud session)

The dispatcher picks the `origin/main` commit that contains this directory (it then contains #3625 and #3626 too),
checks it against §Validity, and puts it in the brief as `<GF_SHA>`. The session needs both repos checked
out: dayfine/trading, and dayfine/trading-results as a sibling directory (`../trading-results`; another path goes in
`TR=`).

```
Repo checkout of dayfine/trading, with dayfine/trading-results checked out beside it as ../trading-results. Run:
git fetch origin main && git checkout <GF_SHA>. Do not edit tracked files.
In a normal Bash call (not a background task: those are killed at 2 h), launch the chain detached:
  mkdir -p .sweep-output/gate-funnel && GF_SHA=<GF_SHA> setsid nohup sh dev/experiments/gate-funnel-2026-11-15/chain.sh run >> .sweep-output/gate-funnel/run.out 2>&1 < /dev/null &
It takes about 3-7 h (the cell about 2-6 h). Wait with a Monitor until-loop on .sweep-output/gate-funnel/chain.log for
"GATE-FUNNEL DONE", "GATE-FUNNEL READ ABORT", "GATE-FUNNEL PUBLISH ABORT" or "ABORT:", plus a 30-minute send_later
heartbeat that re-checks the log and the clock and re-arms both. After a session or container restart, run the same
launch command again: it resumes (stage, preflight, cell, read and publish are each skipped once logged done). If it
logs "CELL FAILED" with exit=137 (out of memory), do not relaunch. Never print R2 or EODHD credentials. Never docker
kill every container: trading-1-dev is this session's own.
The chain publishes by itself: mark-free outputs to branch experiment/gate-funnel-results of dayfine/trading (pushed),
price-bearing ones to dayfine/trading-results main (pushed). Check both pushes landed (PUBLISH public / PUBLISH private
lines). If it logs PUBLISH ABORT, fix the cause and run:
  GF_SHA=<GF_SHA> sh dev/experiments/gate-funnel-2026-11-15/chain.sh publish
If it logs any other ABORT, run GF_SHA=<GF_SHA> sh dev/experiments/gate-funnel-2026-11-15/chain.sh collect, then the
publish command above, once, and stop. Never commit or push candidates.sexp, trade_audit.sexp, a bar file, or any
price-bearing file to dayfine/trading. Do not open a PR, merge, label, or push to main of dayfine/trading.
```

After the run:

1. The dispatcher opens the results PR from `experiment/gate-funnel-results`, naming the trading-results commit.
2. `results-analyst` reads `results/cell/read/` against the rules above (`dev/rules/model-routing.md`).
3. `qc-results` reviews the PR.

## Where I was unsure (decisions taken before the run)

- **Open Friday.** Defined from the trace (Long rows present, no cut row inside the cap), not from `macro_trend.sexp`,
  because the trace's rows are what every count here is made of. SK4 reports any disagreement with
  `long_macro_admitted`.
- **Refinement.** s is the `Not_reached` share only, as the rule names the entry-assembly gates. Other skips the shadow
  also ignores (`Sized_to_zero`, `Share_class_held`, sector caps) are reported beside it, not applied. Applying s as an
  independent removal rate inside each Friday's minimum (the binomial expectation) is exact under independence and
  sits between the two simple versions.
- **C\* in rank order.** When a Friday has more crowded-out names than slots, the ride clause reads the first ones by
  rank, the names the extra cash would have bought.
- **The macro proxy.** The only way to read what the macro gate removed, given the trace. It is labelled as a proxy
  everywhere it appears.
