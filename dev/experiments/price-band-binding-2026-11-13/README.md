# Price-band binding (2026-11-13): pre-registration

**Status: pre-registered, the 26-year cell not run.** Only the local smoke has run (`results/smoke/`, plumbing on sp500).
The rules below are applied as written to the one cloud cell this directory launches.

## Why

The price-band tiebreak (`Price_band_seeded`, #3587; pre-registration #3588) ran K = 5 paired over 26 years. Its
reading is PR #3595 (branch `experiment/price-band-results`, `../price-band-tiebreak-2026-11-13/README.md` §Results):
**NOT LIVE as written**, because the liveness proxy was mis-set.

- **The proxy.** It was the ≤ $14 share of entries (P 14.11 % against S 11.58 %, 1.219× against a 1.3× bar). That
  share sits downstream of the cash and structural-stop gates and sees only the cheap end of the swaps.
- **The blind spot.** `entries.tsv` records the top-20 only on Fridays where an arm placed a ticket. It drops the
  score, so a cut name never appears. On the 2,011 Friday-pairs both arms recorded, the lists differed 67 % of the
  time, but 46 % of one-arm tickets (327 of 705) could not be assigned to a channel.
- **The user's decision (2026-11-13).** Before any new pre-registration or grid, run one S cell (k0, the record config,
  `candidate_ranking` default `Seeded`) with `--emit-candidates`. Its `candidates.sexp` logs every screened Friday with
  every cascade row and its score, including the `Dropped_at_top_n` rows.

On that one path the band order is applied offline. Nothing is re-run under P, so nothing diverges.

## The cell

- **Spec.** `../price-band-tiebreak-2026-11-13/specs/pb-S-k0.sexp`, unchanged (md5 `7a2d9eba…` pinned in `chain.sh`).
  It is the record config with Seeded tie order, seed 0, over 2000-01-01 → 2026-06-26, on the top-3000 PIT v12 yearly
  schedule, with `TRADING_PATH_SEED_SALT=0`. `max_buy_candidates` is the default 20.
- **Build and data.** One `origin/main` SHA that contains this directory (`PB_SHA`). The data stage is #3595's: R2
  warehouse `v12wk-9236`, corporate actions `corpact-2026-10-27`, bars `data-20261102` plus the committed `test_data`.
- **Flag.** `--emit-candidates`. It is observability only: the recorder fills a separate collector, and nothing on
  the strategy's config path changes (`trading/trading/backtest/lib/candidate_log.mli`).

### Tripwire

The cell's `trades.csv` must be byte-identical to #3595's `results/k0/pb-S-k0-s0-trades.csv`: md5
`0928cfe40333560429f5a6e57c9c18de`, 577 lines.

- **Expected to match.** Between #3595's build (`1034b458e`) and `origin/main` at writing (`71bc2eb01`), the only change
  under `trading/` is one devtools test (`git diff --stat 1034b458e 71bc2eb01 -- trading/`).
- **On a mismatch the read does not run.** Either the flag or the build moved the path, so the candidates would not
  describe #3595's S-k0. `chain.sh` logs `TRIPWIRE MISMATCH` and collects the per-arm artifacts. `FORCE_READ=1` reads
  anyway, and the log records that it did.
- **Smoke.** The flag left `trades.csv` byte-identical on sp500, 2019-07 → 2021-06 (`results/smoke/smoke.txt`).

## Self-check (a hard gate, run first)

**Where the order lives.** `trading/analysis/weinstein/screener/lib/screener_ranking.ml`:

- `compare_rankable` sorts by score descending, then applies the tiebreak.
- `Seeded` (`_seeded_cmp`) orders by `_ticker_hash (seed_key ^ ticker)` ascending, then by ticker. The seed key is
  `sprintf "%d|%s|" tiebreak_seed date`, for example `0|2010-11-12|MERC`.
- `_ticker_hash` is a 32-bit FNV-1a: offset `0x811c9dc5`, prime `0x01000193`, masked each step.
- `Price_band_seeded` (`_price_band_seeded_cmp`) orders by `price_band` ascending (the number of edges at or below the
  price; edges `[8; 14; 33]`), then by the Seeded order.
- `filter_and_cap` keeps the first `max_buy_candidates`.
- The trace (`screener_candidate_trace.ml`) marks the kept names `Admitted` and the cut names `Dropped_at_top_n`.

`read/lib/rank.awk` re-implements these in POSIX awk. Its hash matches the OCaml function bit for bit on six test
strings (mawk, 2026-11-13). `chain.sh` refuses a HEAD where the seed key, the hash constants or the band edges moved.

**What must reproduce, on every date where longs are open.**

- **SC1.** Re-rank the pool (all `Admitted` and `Dropped_at_top_n` Long rows) under Seeded with seed 0. Its first 20
  names must be exactly the `Admitted` set.
- **SC2.** The entry walk's weekly decision record (`trade_audit.sexp` `cascade_summaries` `decisions`, #3139) lists
  the walked names in walk order. Every walked Long name must sit in the re-ranked top 20, at strictly increasing
  ranks. The post-cut gates (declining MA, liquidity, recency, delisting) only remove names, so the walk is a
  subsequence. SC2 checks the hash inside the top 20, on every date, not only at the cut.

If either fails on any date, the read stops. `results/read/selfcheck.txt` becomes the whole result, and no other table
is written.

**Power.** The read reports how many dates had the cut inside a score tie (where only the hash decides membership),
and how many dates an Alphabetical re-rank gets wrong. On the smoke:

- the cut fell inside a tie on 20 dates, and Alphabetical missed the Admitted set on 18;
- a wrong seed (1) fails SC1 on 19 dates and SC2 on 68, while seed 0 passes everywhere.

## The price used for the band

`candidates.sexp` carries no `suggested_entry`, so the band uses a proxy.

- **The proxy.** The raw close of the last bar on or before the screen date, from the run's own bar store. #3595 found
  that it agreed with the fill band in 96.2–97.3 % of cases.
- **Its check.** The read measures the proxy band against the ticket band (`suggested_entry`) on every filled entry in
  `trade_audit.sexp`. It also checks the bar lookup against `close_at_decision`. Rule 1 is not applied if the proxy
  agrees on fewer than 90 % of filled entries.
- **No cheap exact route.** The trace builds its rows from `Stock_analysis`, not from the scored candidate, so a
  `Dropped_at_top_n` row never sees the ticket price. An exact band would need `suggested_entry` added to
  `Candidate_log.signals` (a code change, not made here).

## Measurements

The population is every date where longs are open, meaning the macro gate admits longs. On a Bearish date the trace
emits no Long rows.

1. **Binding** (`results/read/binding.txt`, per date `fridays.tsv`, per swap `swaps.tsv`).
   - The cap binds when the pool exceeds 20. The read reports how often the cut falls inside a score tie, and how
     often that tie spans more than one band.
   - **L1** = the share of binding dates on which the Price_band_seeded top 20 differs from S's top 20 as a set. Also
     reported: that share over all open dates and by half (2000–12, 2013–26); the share of dates whose ordered top 20
     changes; and the share whose funded prefix changes (S's ranks 1 to its last placement, against P's first as many).
   - Names swapped per changed date (histogram), and the swapped-out and swapped-in names by band.
2. **Funded re-draw and its worth** (`binding.txt`).
   - **The tickets.** For each date the read takes the tickets P's order would fund on S's path, against the tickets
     S placed.
   - **Fundability.** A name S walked takes S's outcome: placed, or skipped for cash only, counts as fundable; any
     other skip does not. A top-20 name that a post-cut gate dropped is not fundable. A name S cut gets **Q(b)**,
     S's share of top-20 names in its band that were fundable.
   - **Cash.** When S's walk ran out of cash, both orders fund only as many tickets as S placed, in their own order.
     Otherwise every fundable top-20 name is funded.
   - **Model check.** The read applies the same model to S's own order and reports how often it reproduces S's placed
     set.
   - **L2 = E_net** = fill × Σ_b (re-drawn in_b − re-drawn out_b) × r(b), the expected net number of ≥ +100 % trades
     the re-draw buys. Here fill = entries ÷ placed tickets in this cell, and r(b) is S's ≥ +100 % trades per entry in
     band b, pooled over #3595's five S cells: 9/112, 10/217, 8/828 and 15/1,685 (§Why 2 there).
   - The read splits the re-draw into dates where the cut changed and dates where only the order changed (the cash
     order).
3. **The swap tail** (`results/read/swap_tail.txt`).
   - **Outcomes.** For every name swapped in or out at the cut, the read applies the population screen's ex-post
     outcomes (`../price-band-tiebreak-2026-11-13/screen/PREREG.md`), measured from the screen-date close.
   - **Monster.** The highest adjusted weekly close (Monday weeks) over the next 52 weeks is at least 2× the base.
   - **Ride.** The return to the first weekly close below the 30-week WMA, at most 104 weeks, capped at +190 %
     (PREREG Amendment 1).
   - **Dedup.** One row per symbol per side per 26 weeks, as the screen keeps one event per symbol per 26 weeks.
   - **Convention.** The primary convention keeps names delisted within the year, read over the weeks they traded. The
     screen's own convention (52 forward weeks only) is reported too.
   - **Reported.** n, monster rate, win rate, mean and p10/p25/p50/p75/p90 of the capped ride, by side, half and band.
     Also a paired read: per changed date, the mean capped ride of the names swapped in minus the names swapped out.
   - **T** = the monster-rate ratio in ÷ out (primary convention), with its direction in each half, the monster count
     on both sides, and the difference in mean ride.
4. **Where the screen's monsters leave the cascade** (`results/read/funnel.txt`).
   - **Events.** The population screen's own events, from its `lib/mscan.awk`, reused unchanged: every book-style
     weekly breakout of a PIT top-3000 member. That is a close above the 26-week high on ≥ 2× the prior 4 weeks'
     volume, above a rising 30-week WMA, at a raw close ≥ $5, one per symbol per 26 weeks, with 52 forward weeks.
     The monster definition is the screen's, as in Measurement 3.
   - **Join.** Each event joins the candidate row of its symbol in its own week (exact view), or the best row over that
     week and the next four (window view).
   - **Classes.** Admitted, top-N, grade, sector, the #2533 breakout sub-gate (`Stage_setup`, `Breakout_volume`,
     `Rs_declining`, `Failed_breakout`, `Volume_band`, `Price_floor`), `NOT_SURFACED` (no row that week: held,
     cooldown, phase-1, sector filter, membership or warehouse), `MACRO_BLOCKED` and `NO_SCREEN`.
   - **Shares.** Each class's share of each raw-price band (< $8, which is $5–8 here; $8–14; $14–33; ≥ $33), for
     monster events and for all events.
   - **Sub-gates.** Among events with a cascade row, the share each sub-gate drops of monster events and of all events,
     and the lift = monster share ÷ all share. Reported for < $14 pooled, $14–33 and ≥ $33.

## Decision rules (applied as written)

### Rule 1: the tiebreak axis

Checked in this order:

1. **CLOSE-AXIS** if L1 < 0.25 or L2 < 0.75. On this path the order does not bind enough to move the tail. The 26-year
   gap in #3595 is then path re-draw, which a seed change also produces. `Price_band_seeded` stays default-off, and no
   new pre-registration follows.
2. **CLOSE-AXIS** if T has at least 20 monsters on the two sides together and either its ratio is below 1.0 or the
   swapped-in names' mean ride is not above the swapped-out names'. The order binds, but on the strategy's own ties it
   swaps in no fatter tail.
3. **FRESH PRE-REGISTRATION** if L1 ≥ 0.25, L2 ≥ 1.5 and T passes: at least 20 monsters, ratio ≥ 1.5, in above out in
   both halves, and a higher mean ride. It carries the four parts #3595 §What it implies next lists (liveness, a fixed
   drawdown reading, a name-concentration check, broad-vs-broad confirmation cells). Its liveness bar is set from this
   rate: one P cell with `--emit-candidates` must show the top 20 changing on at least 0.5 × L1 of its binding dates.
4. **PARK** otherwise. The axis stays default-off, no new cells are spent now, and the measured rates go into the
   ledger. Reopen it only with history the screen did not see (a pre-2000 window).

The rule is **not applied** if the band proxy agrees with the ticket band on fewer than 90 % of filled entries.

Why these bars:

- **L1 ≥ 25 %.** #3595 saw the lists differ on 67 % of the Friday-pairs it could observe, path effects included.
  Held names explained at most a tenth of that. A pure-order rate below 25 % would mean most of the visible change was
  path divergence, not the order, and the "binds often" correction in #3595 would not hold.
- **L2 bars (0.75 and 1.5).** One ≥ +100 % trade at the strategy's position size adds about 0.10–0.15 to ln(1 + R).
  For example, MERC +111 % at 15.9 % of entry NAV is 0.15, and WAL is 0.09 (#3595 §Why 3). So 1.5 expected trades is
  about 0.2 log, the 26-year noise floor (`dev/agent-memory/project_26y_path_noise_floor.md`). Below 0.75, about
  0.1 log, no 26-year K = 5 run could separate the direct effect from seed noise.
- **T ≥ 1.5.** It is the population screen's own pass bar (monster-rate lift ≥ 1.5), now asked of the strategy's own
  tie groups.
- **20 monsters minimum.** Below it the ratio rests on a handful of names, which is the defect #3595 §Why 5 names.
- **A rough expectation, not a bar.** With #3595's list-swap mix and a ~4 % placement rate per list slot, L2 comes to
  about 0.2 from cut swaps alone. The cash-order channel is what can lift it toward 1. CLOSE and PARK are both live
  outcomes. That is intended: the bars come from the mechanism's footprint, not a headline multiplier
  (`memory/project_floor_and_refresh_screens`).

### Rule 2: the breakout sub-gate

- **DIAL-STUDY on sub-gate G** if, in **both** the exact and window views, there are at least 30 cheap (< $14)
  monster events with a cascade row, G drops at least 20 % of them, and G's lift is at least 1.25. That is, G drops
  cheap monsters at least 1.25 times as often as it drops cheap breakouts in general. The study is a read-only screen
  pre-registration on the dial behind G. It never removes a spine requirement (`.claude/rules/weinstein-faithful-core.md`
  W1):
  - `Stage_setup`: the entry-freshness clock `early_stage2_max_weeks` and the admission arms. Buy-only-in-Stage-2 is
    spine item 2.
  - `Breakout_volume`: `Volume.config.adequate_threshold`. Volume confirmation is spine item 3; the threshold is a dial.
  - `Rs_declining`: the RS-trend cutoff (spine item 7 keeps RS selection).
  - `Failed_breakout`: `failed_breakout_tolerance_pct`.
  - `Volume_band`: `volume_ratio_exclude_range`.
  - `Price_floor`: `min_price`. It is unreachable at the default of 0.
- **NOTHING** otherwise. The breakout gates then drop cheap monsters at about the rate they drop cheap breakouts, so
  the 50.6 % breakout-gate loss in the 08-23 funnel is breadth, not anti-selection, and loosening a gate would admit
  monsters and non-monsters alike.

`results/read/rules.txt` prints the inputs and the mechanical outcome of both rules. The reading, and the why, belong
to `results-analyst`.

## Reported regardless of the verdict

- **Self-check.** SC1 and SC2, the power counts, and the band-proxy agreement.
- **Measurement tables.** All four, with their per-date and per-swap files.
- **Funnel by band.** In the shape of `../price-band-tiebreak-2026-11-13/screen/results/funnel-by-price.txt`, on the
  current record config. That table was built on the 08-23 config.
- **The cell itself.** R, max drawdown, Sharpe and trades from `actual.sexp`, which must equal #3595's S-k0, plus the
  validator report, peak RSS, wall time and the size of `candidates.sexp`.

## Not claimed

- **No return verdict.** One path and one seed: nothing here says P beats S in expectation, and nothing changes a
  default.
- **E_net is an expectation on S's path.** It values the re-drawn tickets at S's per-band rates and ignores the path
  divergence any re-draw sets off. The rates come from small counts (9, 10, 8 and 15 trades) on the same 26-year
  history.
- **The funding model is approximate.** It uses one Q(b) for names S never walked and S's placement count as the cash
  budget. The model check reports how well it reproduces S.
- **The swap tail is the screen's ex-post outcome.** It is a weekly-close doubling, not a stop-managed trade, and it
  applies to names that were listed, not filled.
- **The funnel uses the screen's breakout predicate, not the strategy's.**
  - `NOT_SURFACED` lumps several causes together.
  - The screen's events need 52 forward weeks, which tilts them toward survivors. Measurement 3's primary convention
    does not.
- **In-sample.** It is the same 2000–2025 history the screen and #3595 used.
- **The smoke is plumbing** (`.claude/rules/universe-discipline.md` U2). No smoke number bears on a rule.

## Rigor checks (`dev/rules/mechanism-validation-rigor.md`)

1. **Estimand.** The mechanism changes which tied names make the top 20 and which of them get cash. Measurements 1–2
   measure exactly that on one path. The gap to realized P&L (path divergence, stops) is named above.
2. **Distribution.** Quantiles of the capped ride per side; the per-date paired distribution; the histogram of swaps
   per date.
3. **Scale.** L2 is in ≥ +100 % trades, converted to log NAV in the bar's rationale.
4. **Selection.** Delisted names stay in Measurement 3's primary convention. Outcomes are ex-post and never inputs.
5. **Surface.** The band edges stay at the pre-registered [8; 14; 33]. This diagnostic measures binding at the axis
   point #3595 ran. #3595 §Why 2 already swept the ≤ $X cut-off of the entry share. An edge sweep belongs to a fresh
   pre-registration, if Rule 1 opens one.
6. **Paired.** The swap tail is paired per changed date, and the funded re-draw is per date.
7. **Power.** Minimum counts are written into both rules (20 monsters, 30 cheap monsters). The self-check reports
   its own power and has a negative control.
8. **V6.** There is a single cell and no pair. The validator runs, and its report is collected.

## Cost (`dev/rules/sweep-hygiene.md`)

The run is a Claude cloud session, not local.

- **Expected cell wall time.** 8,058 s (pb-S-k0-s0, #3595 `chain-k0.log`) × 2.05 ≈ 16,500 s, about 4.6 h. The 2.05 is
  the `--emit-candidates` wall factor measured 2026-09-21: d0-funnel-diag ran 26,681 s against 13,020 s without the
  flag (`../top-of-funnel-2026-09-21/results/d0-funnel-decomposition.md`).
- **`CELL_TIMEOUT` = 49,500 s**, 3× the expected wall time, the price-band chain's convention.
- **Session total.** About 6 h: stage 0.5 h, build 0.3 h, preflight 0.3 h, cell 4.6 h, read 0.5 h.
- **Memory.** Peak RSS about 9.2 GB: 5.77 GB for pb-S-k0-s0, plus the 3.4 GB emission added on 09-21 (7.60 GB against
  about 4.2 GB). `chain.sh` aborts at start if MemTotal is under 11 GB (`MEM_MIN_GB`). That costs a minute, not a
  4-hour OOM.
- **Disk.** At least 8 GB free before the cell (`DISK_CELL_GB`). `candidates.sexp` was 945 MB on 09-21; with
  `trade_audit.sexp` and the read's scratch the total is about 2 GB. The k0 session had 14 GB free after staging.
- **Never committed or pushed.** `candidates.sexp` and `trade_audit.sexp`; `chain.sh collect` leaves them out. The
  read's scratch holds raw closes and stays in `.sweep-output/`.
- **Preflight.** A 3-month run with the flag, then the full read on it (self-check included), before the 4.6-hour cell
  starts.

## Smoke (`results/smoke/`, plumbing only)

`smoke.sh` runs inside the dev container. It uses `specs/smoke-sp500.sexp`: the record config on `universes/sp500.sexp`
over 2019-07-01 → 2021-06-30, in CSV mode on the committed `test_data`. sp500 is a fixture here (U2), and every table
in `results/smoke/` carries that banner.

- **Tripwire.** `trades.csv` is identical with and without the flag (md5 `dcb8e99d…`, 41 lines).
- **Cost.** With the flag: wall 73–86 s, peak RSS 343–357 MB, `candidates.sexp` 13.0 MB. Without it: 71–129 s and
  293–295 MB, over four runs on a shared container. The read took 43–53 s.
- **Self-check.** PASSED: SC1 on all 99 open dates, SC2 on all 82 dates with a walk record. Seed 1 fails as it should.
  The proxy band agreed with the ticket band on 53 of 53 filled entries.
- **Binding on the smoke window.** The cap bound on 24 of 99 open dates (24.2 %). The top 20 changed on 10 of those 24
  (41.7 %), which is 10.1 % of open dates. The ordered top 20 changed on 47.5 % of open dates. Thirteen names swapped
  each way, all ≥ $33 out and $14–33 in. The funding model reproduced S's placed set on 82 of 83 dates with a pool.

## Files

- **`chain.sh`.** The cloud chain: `run`, `stage`, `read` and `collect`. It is derived from
  `../price-band-tiebreak-2026-11-13/chain.sh`, with the same stage, build, preflight, flock, `PB_SHA` HEAD pin and
  resume.
- **`read/read.sh`.** The read driver, POSIX sh. It writes aggregate tables only, never a bar, a price or a per-name
  return.
  - `lib/cands.awk` and `lib/audit.awk`: the streaming sexp extracts.
  - `lib/rank.awk`: the screener's order.
  - `lib/bind.awk`: the self-check and Measurements 1–2.
  - `lib/fwd.awk` and `lib/tail.awk`: Measurement 3.
  - `lib/funnel.awk`: Measurement 4.
  - `lib/dates.awk`: the screen's week numbering.
  - It also reuses `../price-band-tiebreak-2026-11-13/screen/lib/{mscan,gspc_weekly}.awk` unchanged.
- **`smoke.sh` and `specs/smoke-sp500.sexp`.** The local smoke.
- **`results/smoke/`.** The smoke's tables.
- **`results/cell/`** (after the run). The cell's per-arm artifacts (actual, trades, params, summary, splits, open
  positions, equity curve, macro trend, entries, log, rss, validator), `read/` and `chain.log`.

## Launching (one cloud session)

The dispatcher picks one SHA on `origin/main` that contains this directory and puts it in the brief as `<PB_SHA>`.

```
Repo checkout of dayfine/trading. Run: git fetch origin main && git checkout <PB_SHA>. Do not edit tracked files.
In a normal Bash call (not a background task: those are killed at 2 h), launch the chain detached:
  mkdir -p .sweep-output/price-band-binding && PB_SHA=<PB_SHA> setsid nohup sh dev/experiments/price-band-binding-2026-11-13/chain.sh run >> .sweep-output/price-band-binding/run.out 2>&1 < /dev/null &
It takes about 6 h (the cell about 4.6 h). Wait with a Monitor until-loop on .sweep-output/price-band-binding/chain.log
for "PRICE-BAND-BINDING DONE", "PRICE-BAND-BINDING READ ABORT" or "ABORT:", plus a 30-minute send_later heartbeat
that re-arms both. After any restart, run the same launch command again (it resumes). Never print R2 or EODHD
credentials. Never docker kill every container: trading-1-dev is this session's own. When the chain ends, copy
.sweep-output/price-band-binding/results/ into dev/experiments/price-band-binding-2026-11-13/results/cell/ on a new
branch experiment/price-band-binding-results, commit and push that branch. Never commit candidates.sexp or
trade_audit.sexp (collect leaves them out). Do not open a PR, merge, label or push to main. If the chain logs ABORT,
push the log the same way and stop.
```

After the run:

1. The dispatcher opens the results PR from that branch.
2. `results-analyst` reads `results/cell/read/` against the rules above.
3. `qc-results` reviews the PR (`dev/rules/model-routing.md`).
