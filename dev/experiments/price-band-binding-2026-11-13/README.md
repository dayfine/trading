# Price-band binding (2026-11-13): pre-registration

**Status: run 2026-11-14.** Rule 1: CLOSE-AXIS (branch 3). Rule 2: NO CONCLUSION (immaterial). `Price_band_seeded`
stays a default-off axis (§Results). The rules below were applied as written to the one cloud cell this directory launched.

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
- **Its check.** The read measures the proxy band against the ticket band (`suggested_entry`) on every placed ticket,
  meaning every entry record in `trade_audit.sexp`. That is more than the fills: the smoke has 53 records and 43
  fills. It also checks the bar lookup against `close_at_decision`. Rule 1 is not applied if the proxy agrees on fewer
  than 90 % of placed tickets.
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
   - **What L2 compares.** P's modelled funding against S's actual placements, not against the same model run on S's
     order. The model's error on cash dates therefore enters L2. The model check above indicates how large that
     error is, but it does not bound it.
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

Checked in this order. Each branch has its own reason, and `rules.txt` prints it.

1. **CLOSE-AXIS** if L2 < 0.75.
   - **Reason.** The expected direct tail effect is under about 0.1 log, half the about 0.2 log 26-year noise floor.
     No K = 5 run could separate it from seed noise.
   - **What it means for #3595.** Its gap would rest on the realised outcomes of a few systematic swaps (MERC, DINO and
     the rest of #3595 §Why 5), not on an effect the order buys in expectation.
   - **What it does not say.** Nothing about what a seed change produces. #3595 §Why 5 measured that separately:
     same-seed P−S has a median of +0.348, against 0.149 for cross-seed S−S.
2. **PARK** if L1 < 0.25 (with L2 ≥ 0.75).
   - **Reason.** The order rarely changes the top 20 on binding dates, so #3595's "binds often" correction does not
     hold. But its cash-order re-draws still carry an expected tail at or above the bar, so that is not grounds to
     close.
   - **Why T is not read on this branch.** T measures only the cut swaps, which a low L1 makes rare.
3. **CLOSE-AXIS** if T has at least 20 monsters on the two sides together, and either its ratio is below 1.0 or the
   swapped-in names' mean ride is not above the swapped-out names'.
   - **Reason.** The order binds, but among tied names it swaps in no fatter tail.
4. **FRESH PRE-REGISTRATION** if L1 ≥ 0.25, L2 ≥ 1.5 and T passes. T passes with at least 20 monsters, a ratio
   ≥ 1.5, in above out in both halves, and a higher mean ride.
   - **What it carries.** The four parts #3595 §What it implies next lists: liveness, a fixed drawdown reading, a
     name-concentration check, and broad-vs-broad confirmation cells.
   - **Its liveness bar.** It is set from this rate: one P cell with `--emit-candidates` must show the top 20 changing
     on at least 0.5 × L1 of its binding dates.
5. **PARK** otherwise.
   - **Reason.** Binding and tail are not decisive: L2 is between 0.75 and 1.5, or T falls short of its bars.

**What each outcome does to the flag** (`dev/rules/experiment-flag-discipline.md` Rule 4).

- **CLOSE-AXIS.** Either branch keeps `Price_band_seeded` as a default-off axis, the
  REJECT-as-default-but-legitimate-axis class. It is not do-not-revive, so it is not retirement-eligible. The reason is
  that this is a one-window proxy read: it rejects prioritising the axis, not the mechanism
  (`dev/rules/mechanism-validation-rigor.md` §Verdict calibration). No new pre-registration follows.
- **PARK.** Keep-as-axis as well: the axis stays default-off, no new cells are spent now, and the measured rates go into
  the ledger. Reopen it only with history the screen did not see (a pre-2000 window).

The rule is **not applied** if the band proxy agrees with the ticket band on fewer than 90 % of placed tickets.

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
- **What the L2 bars ask of the run, in tickets.** This is arithmetic from committed numbers, not a forecast.
  - **Value of one re-drawn ticket.** #3595 §Why 1 gives the band mix of its list swaps: 85.7 % of swapped-out names
    were ≥ $33, and 40.2 % of swapped-in names were < $14. With r(b) above, one re-drawn ticket is worth
    0.0291 − 0.0096 = 0.0195 expected ≥ +100 % trades.
  - **Net of fills.** S-k0 had 581 entries from 683 placed tickets (#3595 `results/read/arm_table.tsv` and
    `results/k0/chain-k0.log`), so after fills one re-drawn ticket is worth 0.0166.
  - **The bars in tickets.** L2 = 0.75 needs about 45 net re-drawn tickets over the window, about 1.7 a year. L2 = 1.5
    needs about 90, about 3.4 a year.
  - **The outcome is open.** No committed artifact counts per-date re-draws before the run, so CLOSE, PARK and FRESH
    are all live. That is intended: the bars come from the mechanism's footprint, not a headline multiplier
    (`memory/project_floor_and_refresh_screens`).

### Rule 2: the breakout sub-gate

"Cheap" means < $14. Each view (exact week, and best of weeks 0..+4) counts the cheap monster events that have a
cascade row. For a sub-gate G, its **share** is the fraction of those monsters G was first to drop, and its **lift** is
that share divided by the fraction of all cheap breakouts with a row that G was first to drop.

Checked in this order, on the inputs `rules.txt` prints:

1. **UNDERPOWERED** (no conclusion) if either view has fewer than 30 cheap monster events with a cascade row.
2. **DIAL-STUDY on G** if, in **both** views, G's share is at least 20 % and its lift is at least 1.25. The study is a
   read-only screen pre-registration on the dial behind G. It never removes a spine requirement
   (`.claude/rules/weinstein-faithful-core.md` W1):
   - `Stage_setup`: the entry-freshness clock `early_stage2_max_weeks` and the admission arms. Buy-only-in-Stage-2 is
     spine item 2.
   - `Breakout_volume`: `Volume.config.adequate_threshold`. Volume confirmation is spine item 3; the threshold is a
     dial.
   - `Rs_declining`: the RS-trend cutoff (spine item 7 keeps RS selection).
   - `Failed_breakout`: `failed_breakout_tolerance_pct`.
   - `Volume_band`: `volume_ratio_exclude_range`.
   - `Price_floor`: `min_price`. It is unreachable at the default of 0.
3. **NO CONCLUSION (one view)** if a gate meets both bars in one view only. The read cannot then tell a gate effect
   from the week in which the cascade first sees the breakout.
4. **NO CONCLUSION (immaterial)** if a gate reaches the lift bar in either view but its share is under 20 %.
5. **NOTHING** otherwise. This case means at least 30 cheap monsters in both views, and no gate at lift 1.25 in either
   view. Its reading is limited to that case. Among the cheap breakouts the cascade evaluates, no sub-gate is first to
   drop monsters more often than it drops breakouts in general. As far as first-failing attribution can see, the
   breakout-phase loss of cheap monsters is breadth, not anti-selection by one gate. It does not say what loosening a
   gate would admit, because later gates still apply (§Not claimed).

Why these bars:

- **20 % share: materiality.** The 08-23 funnel lost 50.6 % of < $8 monsters and 52.4 % of $8–14 monsters at the
  breakout phase (`../price-band-tiebreak-2026-11-13/screen/results/funnel-by-price.txt`).
  - A gate that is first to drop a fifth of cheap monsters carries about 36 % of that phase loss, on one base (all
    monster events). About 92–93.5 % of cheap monsters have a cascade row (NOT_SURFACED was 8.0 % and 6.5 %), so 20 %
    of them is 18.4–18.7 % of all of them, against the 50.6–52.4 % loss. That is enough for a study of one dial to
    matter.
  - Below 20 %, no single dial's study could recover much of the loss.
- **Lift 1.25, below T's 1.5.** There are two reasons.
  - **What the bar opens.** DIAL-STUDY opens only a cheap read-only screen, which carries its own pre-registration.
    T ≥ 1.5 gates a fresh 26-year pre-registration and its confirmation cells.
  - **The lift has a ceiling.** If a gate is first to drop a fraction A of all cheap breakouts with a row, its lift can
    be at most 1/A. A 1.5 bar therefore excludes, by construction rather than by evidence, any gate that drops more than
    two thirds of them.
  - **The smoke's dominant gate.** In the exact view, `Stage_setup` dropped 83.3 % and 84.3 % of the breakouts with a
    row ($14–33 and ≥ $33; `results/smoke/funnel.txt`, and the smoke has no cheap events). That is a ceiling of about
    1.2. In the window view it dropped 75.0 % and 83.1 %, a ceiling of 1.33 and 1.20. So even 1.25 may be out of reach
    for the dominant gate. That is accepted: a gate that drops nearly everything cannot be selecting against monsters by
    much.
- **30 cheap monsters per view.** Below that, a 20 % share is six names. That is the same small-n defect as T's
  20-monster minimum.

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
  - **Each drop is attributed to the first failing gate.** `breakout_gate` names the first gate that failed, in the
    evaluation order the #2533 contract pins.
    - The authority is `trading/analysis/weinstein/screener/lib/screener_admission.mli` (the `breakout_gate` docstring),
      which `candidate_log.mli` cites.
    - On the long side the order is `Price_floor` → `Stage_setup` → `Breakout_volume` → `Rs_declining` →
      `Failed_breakout` → `Volume_band`.
    - So a gate's share is the share it was *first* to drop. A name `Stage_setup` dropped may fail later gates too, so
      a share is not what loosening that gate would admit.
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
  flag (`../top-of-funnel-2026-09-21/results/d0-funnel-decomposition.md`). 13,020 s is the fast end of that source's
  3 h 37 m–4 h 19 m range for the same cell. The slow end gives 1.72, so 2.05 is the conservative choice.
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
over 2019-07-01 → 2021-06-30, in CSV mode on the committed `test_data`. sp500 is a fixture here (U2), and every file
in `results/smoke/` carries that banner.

- **Tripwire.** `trades.csv` is identical with and without the flag (md5 `dcb8e99d…`, 41 lines).
- **Cost** (the committed run, `smoke.txt`). With the flag: wall 78 s, peak RSS 336 MB, `candidates.sexp` 13.0 MB.
  Without it: 79 s and 296 MB. The read took 55 s.
- **Self-check.** PASSED: SC1 on all 99 open dates, SC2 on all 82 dates with a walk record. Seed 1 fails as it should.
  The proxy band agreed with the ticket band on 53 of 53 placed tickets.
- **Binding on the smoke window.** The cap bound on 24 of 99 open dates (24.2 %). The top 20 changed on 10 of those 24
  (41.7 %), which is 10.1 % of open dates. The ordered top 20 changed on 47.5 % of open dates. Thirteen names swapped
  each way, all ≥ $33 out and $14–33 in. The funding model reproduced S's placed set on 82 of 83 dates with a pool.
- **Rules.** The rule code runs end to end. Rule 1 reads CLOSE-AXIS on the L2 branch. Rule 2 reads UNDERPOWERED
  because sp500 has no cheap events.
  - **How `rules.txt` was produced.** At QC rework iteration 2, only `read.sh`'s step-7 rule block changed. So
    `rules.txt` was regenerated by running that block on the gate values this run printed in its "inputs" lines,
    which are unchanged. Every other smoke file is from the run itself.
  - **The ladder test.** The step-7 block was also run on synthetic inputs, one per Rule 1 branch. Each landed where
    the README's order puts it: L1 0.20 with L2 2.0 gives PARK, and L1 0.50 with L2 0.50 gives CLOSE-AXIS on the L2
    branch.

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

## Results

**Rule 1 reads CLOSE-AXIS, on branch 3, and Rule 2 reads NO CONCLUSION (immaterial).** `Price_band_seeded` stays a
default-off axis, in the REJECT-as-default-but-legitimate-axis class: not do-not-revive, so not retirement-eligible.
No new pre-registration follows, and nothing changes a default.

- **The order binds.** The top-20 cut falls inside a score tie on 84 % of open dates, and the band order changes the
  top-20 set on 69 % of them (L1 0.690), in both halves.
- **The funded re-draw is small.** 1,744 names swap each way. But 95 % of S's top-20 slots hold names that never fund,
  and cheap names fund least. So the order re-draws 84 tickets in 26 years, worth E_net = 0.953 expected net
  ≥ +100 % trades (L2): about 0.10–0.14 log by the pre-registration's conversion.
- **The promoted names have a fatter tail, not a better ride.** They double 3.07× as often as the names they replace
  (205 monsters, both halves), but their mean capped ride is +4.0 % against +4.1 %. Branch 3 fires on that −0.1 pp.
  The difference is a zero, and a read defect touches it (§Defects found 1). Corrected, the rule could only move to
  PARK, which also keeps the axis default-off and spends no cells.

**Paths.**
- **Per-arm artifacts.** `results/cell/pbb-S-k0-s0-*` and `results/cell/chain.log`.
- **The read's tables.** `results/cell/read/*.txt`, with the per-date file `fridays.tsv` and the per-swap file
  `swaps.tsv`.
- **Figures marked †.** They are derived from committed files only (this cell's and #3595's) by
  `results/cell/analysis/analyst_checks.sh`; its output is `analyst_checks.txt`.

### The cell (`chain.log`, `pbb-S-k0-s0-*`)

- **Same as #3595's pb-S-k0.**
  - `trades.csv` has md5 `0928cfe40333560429f5a6e57c9c18de` and 577 lines (`TRIPWIRE MATCH`).
  - Every other per-arm artifact is byte-identical to `../price-band-tiebreak-2026-11-13/results/k0/pb-S-k0-s0-*`†:
    actual, summary, equity curve, splits, open positions, entries, macro trend and both validator reports.
  - `params.sexp` differs only in `code_version` and `data_dir`.
  - The snapshot-cache counters match to the unit: hits 148,059,516, misses 20,622, `n_symbols_absent=1`
    (`pbb-S-k0-s0.log` line 204).
- **Build and data.** HEAD 645065bb2, image `sha256:3865e48e8a61`, warehouse `v12wk-9236` (9,236 entries),
  `corpact-2026-10-27`, bars `data-20261102`. No dividends or splits file was removed (`td-ca-extra.txt` is empty).
- **Result** (`pbb-S-k0-s0-actual.sexp`). +1,472.76 % (ln 2.7554), max drawdown 27.22 %, Sharpe 0.634, Calmar 0.403,
  576 closed trades plus 5 open.
- **Validator** (`pbb-S-k0-s0.validator.log`). V1–V6, V12, V19 and V20 pass. The per-trade checks carry #3595's counts:
  V7 36, V9 115, V13 39, V21 64 and V22 104. The audit join is 576/576.
- **Cost** (`chain.log`).
  - Wall 7,477 s, peak RSS 9.06 GB, `candidates.sexp` 974.5 MB, read 516 s.
  - The README budgeted 16,500 s (2.05×). #3595's S-k0 without the flag took 8,058 s, in another session on the
    same image.
  - So the flag cost about +3.3 GB of RSS and no measurable wall time.

### Self-check (`read/selfcheck.txt`): passed

- **SC1 and SC2.** SC1 holds on all 1,099 longs-open dates and SC2 on all 1,099 with a walk record. The preflight
  passed both on 10 dates (`chain.log`).
- **Power.** The cut fell inside a score tie on 921 dates, and the Alphabetical control misses the Admitted set on 877.
- **Band proxy.**
  - 621 of the 644 placed tickets with a bar agree with the ticket band (96.4 %).
  - 39 of the 683 placed tickets have no bar in the read's store. Counted as misses, agreement is
    621/683 = 90.9 %†.
  - Either way the 90 % precondition holds. The bar lookup also matches `close_at_decision` on 644 of 644.
- **No price.** 40,229 of 498,225 pool rows (8.1 %) have no close in the read's store, and the read ranks them as
  ≥ $33 (§Defects found 2).

### Measurement 1: binding (`read/binding.txt`, `read/fridays.tsv`)

- **Dates.** 1,335 screened, 236 macro-blocked for longs, 1,099 open (471 in 2000–12, 628 in 2013–26). Pools average
  453 names (25–946)†, so the cap binds on every open date.
- **Ties.** The cut falls inside a score tie on 921 dates (83.8 %), and the tie spans more than one band on 898
  (81.7 %).
- **L1 = 0.690.**
  - The top-20 set changes on 758 of 1,099 binding dates: 71.8 % in 2000–12, 66.9 % in 2013–26, and at least 47 %
    in every calendar year†.
  - The ordered top 20 changes on 1,097 dates (99.8 %).
  - The funded prefix changes on 261 of the 474 dates with a placement (55.1 %).
- **Swaps.** 1,744 each way, 2.30 per changed date. By swaps per changed date: 281 dates with 1, 223 with 2, 118 with
  3, 68 with 4, 39 with 5 and 29 with 6 or more.

| swaps at the cut | < $8 | $8–14 | $14–33 | ≥ $33 |
|---|---:|---:|---:|---:|
| out (S kept, P cut) | 0 | 5 | 151 | 1,588 |
| in (S cut, P kept) | 354 | 444 | 946 | 0 |

91 % of the names cut are ≥ $33, and every name promoted is below $33. That is #3595's list signature (85.7 % and
5.6 %), now without path effects.

### Measurement 2: the funded re-draw (`read/binding.txt`)

| band | S top-20 slots | walked | placed | fundable (Q) |
|---|---:|---:|---:|---:|
| < $8 | 1,397 | 85.2 % | 1.7 % | 3.0 % |
| $8–14 | 1,851 | 94.1 % | 2.6 % | 4.2 % |
| $14–33 | 6,678 | 97.9 % | 2.9 % | 5.2 % |
| ≥ $33 | 12,054 | 99.4 % | 3.4 % | 5.8 % |

- **Model check.** The funding model run on S's own order reproduces S's placed set on 1,077 of 1,099 dates (98.0 %).
  S's walk ran out of cash on 257 of them.
- **Fill.** 581 entries / 683 placed tickets = 0.851.

| band | re-drawn in | re-drawn out | r(b) | fill × (in − out) × r† |
|---|---:|---:|---:|---:|
| < $8 | 8.81 | 0.00 | 9/112 | +0.602 |
| $8–14 | 16.58 | 4.00 | 10/217 | +0.493 |
| $14–33 | 50.08 | 9.00 | 8/828 | +0.338 |
| ≥ $33 | 8.79 | 72.13 | 15/1,685 | −0.480 |
| total | 84.3 | 85.1 | | **E_net = L2 = 0.953** |

That is 3.3 re-drawn tickets a year. Of the in-tickets, 77.3 fall on dates where the cut changed and 7.0 on dates where
only the order changed; the out-tickets split 78.1 and 7.0.

### Measurement 3: the swap tail (`read/swap_tail.txt`)

Deduped rows: in 1,526 (F 1,416, D 108, T 2, X 0); out 1,616 (F 1,380, D 89, T 0, X 147). The table uses the primary
convention FD, with the ride capped at +190 %.

| | n | monster | win | mean ride | p10 | p25 | p50 | p75 | p90 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| in | 1,524 | 10.2 % | 38.5 % | +4.0 % | −17.3 | −10.1 | −4.1 | +7.8 | +33.2 |
| out | 1,469 | 3.3 % | 42.0 % | +4.1 % | −12.3 | −7.7 | −2.1 | +7.8 | +26.6 |
| in, 2000–12 | 722 | 10.4 % | 38.2 % | +3.6 % | −17.7 | −10.2 | −4.3 | +7.1 | +32.9 |
| out, 2000–12 | 630 | 3.7 % | 39.8 % | +4.1 % | −11.9 | −7.8 | −2.2 | +7.8 | +25.8 |
| in, 2013–26 | 802 | 10.1 % | 38.8 % | +4.4 % | −16.9 | −9.8 | −4.0 | +8.3 | +35.4 |
| out, 2013–26 | 839 | 3.1 % | 43.6 % | +4.2 % | −13.0 | −7.5 | −1.9 | +7.8 | +27.3 |
| in, < $8 | 294 | 23.5 % | 37.8 % | +5.9 % | −27.4 | −15.5 | −6.0 | +13.8 | +64.8 |
| in, $8–14 | 379 | 7.1 % | 37.7 % | +3.0 % | −18.8 | −10.5 | −4.6 | +6.2 | +32.0 |
| in, $14–33 | 851 | 7.1 % | 39.1 % | +3.9 % | −13.4 | −8.8 | −3.4 | +7.7 | +28.9 |
| out, $8–14 | 5 | 40.0 % | 60.0 % | +41.8 % | −21.2 | −9.2 | +3.7 | +74.3 | +161.3 |
| out, $14–33 | 148 | 8.1 % | 48.6 % | +10.3 % | −11.7 | −6.0 | −0.3 | +11.6 | +43.7 |
| out, ≥ $33 | 1,316 | 2.7 % | 41.2 % | +3.3 % | −12.3 | −7.8 | −2.5 | +7.1 | +25.7 |

- **Screen convention F** (52 forward weeks only). In: 1,416 rows, monster 10.3 %, mean +4.0 %. Out: 1,380 rows,
  3.3 %, +3.7 %.
- **T.** Ratio 3.07 (F: 3.16), in above out in both halves, 205 monsters (156 in, 49 out), mean-ride difference
  −0.0010.
- **Paired, per changed date.** Over 725 dates with both sides covered (every swap date, not deduped), in minus out
  averages +0.9 pp, with median −1.4 pp, p10 −24.8 and p90 +26.3. In leads on 46.8 % of dates.

### Measurement 4: where the screen's monsters leave the cascade (`read/funnel.txt`)

18,957 screen events fall in the screened weeks. Monster events by band: 212, 275, 494, 484. The table gives the share
of monster events by class, exact week, with weeks 0..+4 in brackets.

| class | < $8 | $8–14 | $14–33 | ≥ $33 |
|---|---:|---:|---:|---:|
| admitted | 6.1 (9.9) | 4.4 (10.2) | 5.7 (9.7) | 5.8 (10.3) |
| top-N cut | 34.9 (48.1) | 40.7 (54.2) | 48.4 (62.3) | 60.1 (71.5) |
| breakout sub-gates | 37.3 (31.6) | 34.6 (28.0) | 24.3 (20.0) | 16.9 (12.2) |
| not surfaced | 8.5 (1.9) | 11.3 (2.9) | 11.7 (3.4) | 9.5 (4.1) |
| macro-blocked | 11.8 (8.5) | 8.0 (4.7) | 8.1 (4.3) | 6.6 (1.7) |
| grade, no screen | 1.4 (0.0) | 1.1 (0.0) | 1.8 (0.2) | 1.0 (0.2) |

- **The breakout phase is `Stage_setup`.** It takes 36.8 / 34.2 / 22.9 / 16.3 % (exact). `Breakout_volume` takes
  0.4–1.4 %, and the other four sub-gates take nothing.
- **The shape matches the 08-23 funnel.** That funnel (`../price-band-tiebreak-2026-11-13/screen/results/funnel-by-price.txt`)
  used the older config and a different event set. It too lost cheap monsters more at the breakout phase (50.6 /
  52.4 % against 33.6 % above $33) and less at the top N (36.9 / 37.1 % against 49.9 %).

The sub-gates among cheap (< $14) events with a cascade row, as share of monsters / share of all / lift:

| view | cheap monsters with a row | `Stage_setup` | `Breakout_volume` | others |
|---|---:|---|---|---|
| exact | 385 (all: 2,498) | 44.7 / 45.3 / 0.99 | 0.5 / 0.4 / 1.18 | 0 |
| weeks 0..+4 | 444 (all: 2,905) | 32.0 / 36.5 / 0.88 | 0.5 / 0.1 / 3.27 | 0 |

### The rules, as written

**Precondition.** The proxy agrees on 96.4 % of placed tickets with a bar and on 90.9 % of all placed tickets†. Both
are at least 90 %, so Rule 1 is applied.

**Rule 1**, checked in the README's order on the inputs `read/rules.txt` prints:

| # | branch | test | input | result |
|---|---|---|---|---|
| 1 | CLOSE-AXIS | L2 < 0.75 | L2 = 0.953 | not met |
| 2 | PARK | L1 < 0.25 | L1 = 0.690 | not met |
| 3 | CLOSE-AXIS | T ≥ 20 monsters, and ratio < 1.0 or in mean ride not above out | 205 monsters; ratio 3.07; +4.0 % against +4.1 % (−0.0010) | **met** |
| 4 | FRESH | L1 ≥ 0.25, L2 ≥ 1.5, T passes | not reached (L2 0.953 < 1.5 would fail it anyway) | |
| 5 | PARK | otherwise | not reached | |

`read.sh` step 7 encodes the same order and bars; its "not above" is a difference ≤ 0. **Outcome: CLOSE-AXIS** ("the
order binds, but among tied names it swaps in no fatter tail"). By the README's flag clause, `Price_band_seeded` stays
a default-off axis in the REJECT-as-default-but-legitimate-axis class. It is not retirement-eligible, and no new
pre-registration follows.

**Rule 2**, in order:

1. **UNDERPOWERED?** No. There are 385 and 444 cheap monsters with a row, both at least 30.
2. **DIAL-STUDY?** No. No gate has share ≥ 20 % and lift ≥ 1.25 in both views. `Stage_setup` has the share, but its
   lift is 0.99 and 0.88.
3. **NO CONCLUSION (one view)?** No. No gate meets both bars in either view.
4. **NO CONCLUSION (immaterial): yes.** `Breakout_volume` reaches lift 3.27 in the window view at a 0.5 % share.

### The verdict, calibrated

- **What this run establishes** on one path (top-3000 PIT v12, 2000–2026, the record config, seed 0):
  - The band order binds routinely, at a cut that falls inside a score tie, and it replaces ≥ $33 names with cheaper
    ones.
  - Inside the strategy's own ties, the names it promotes double about three times as often as the names it cuts, in
    both halves.
  - Its funded footprint is about 84 tickets in 26 years, worth about one expected doubler. That is 0.10–0.14 log by
    the README's conversion, or 0.14–0.18 at the median and mean value of S's own ≥ +100 % trades in #3595 (0.149 and
    0.189 log each)†.
- **What it does not establish:** that the promoted names do better as held positions. On the capped 30-week-WMA ride
  they tie.
- **The deciding margin is zero.**
  - Branch 3 turned on −0.1 pp. A normal reading of the interdecile ranges puts the standard error of that difference
    near 0.64 pp†, more with the capped tail.
  - Its sign flips under the screen convention F (+0.3 pp), in 2013–26 (+0.2 pp) and in the paired per-date mean
    (+0.9 pp; median −1.4 pp).
  - A read defect sits in exactly this input (§Defects found 1): 2025–26 swaps that the store truncates are counted
    as delisted. The out side's 89 D rows average +8.7 to +11.9 %†, against +3.7 % for its F rows, so the D class sets
    the sign.
- **What the pre-registration allows.**
  - It has no tolerance band and no discretion: "not above" includes a tie. On the committed read the outcome is
    CLOSE-AXIS.
  - Re-reading T under the README's own convention (truncated rows as T) would be a correction, not an adaptation. It
    can only move the outcome between CLOSE-AXIS (branch 3) and PARK (branch 5), because FRESH needs L2 ≥ 1.5 and L2
    is 0.953.
  - Both outcomes keep the axis default-off and spend no cells. They differ only in that PARK names a reopen route, a
    pre-2000 window. The rule reopens nothing by itself.
  - The correction was not run: it needs the cell's WORK files (raw closes, never committed) or a bar store matching
    the run's `data-20261102`, and it cannot change what is spent.
- **Scope.** One path, one seed, one window, and in-sample: the trait was found on this history. A proxy read rejects
  prioritising the axis, not the mechanism (`dev/rules/mechanism-validation-rigor.md` §Verdict calibration). It is not
  a return verdict on P.
- **V6.** This is a single cell, so there is no paired delta; its own report passes V6. The traces in §Why compare
  P-k0 and S-k0 trades on #3595's pair, whose `validator_diff -check V6` agrees
  (`../price-band-tiebreak-2026-11-13/results/k0/pb-P-k0-s0.v6diff-S.log`).

### Why

#### 1. The cut is a tie, and the order settles it by band

Pools average about 450 names against a cap of 20, so the twentieth slot almost always lands inside a group of equal
scores. On 2009-10-30, one score-80 group straddled the cut eight names deep (`swaps.tsv`):

- **Cut by P.** S's top 20 held AKR, AMZN, AOS, AWI, DECK, GIS, SHEL and TTE, all ≥ $33, at S ranks 9–20. P's order
  moves them to ranks 30–37.
- **Promoted by P.** BBVA, CASY, CXT, DINO, HCSG, NUS, PNR and TYL, all $14–33, move from S ranks 22–33 to P ranks
  13–20.

Measurement 1's split, where 91 % of the names cut are ≥ $33 and no promoted name is, is this pattern repeated on 758
dates.

#### 2. The funding gates absorb almost all of it

- **95 % of S's top-20 slots never fund.** Of 21,980 slots on open dates, 1,163 (5.3 %) held a name that was placed or
  skipped only for cash†. On S's placement Fridays, 8,259 of 9,271 walk rows (89 %) are `No_structural_stop` skips
  (`pbb-S-k0-s0-entries.tsv`†).
- **Cheap names fund least.** Q runs 3.0 / 4.2 / 5.2 / 5.8 % from < $8 to ≥ $33. Also, 14.8 % of < $8 top-20 names
  fail a post-cut gate before the walk, against 0.6 % at ≥ $33.
- **So 1,744 swaps become 84 tickets, and the mix gets dearer on the way.** 46 % of the swapped-in names are below
  $14, but only 30 % of the re-drawn tickets†.
- **This is a known law.** `project_floor_and_refresh_screens` found that a name reaches the book only through a
  top-20 slot and the structural-stop gate, and top-N 40, Nearest and the monthly refresh all behaved that way. The
  band order is a fourth case.

#### 3. What the re-draw is worth, and how firm the number is

- **The value sits in about 21 net tickets under $14.** They carry +1.10 of the 0.953.
  - The largest exchange is 41 net tickets into $14–33 against 63 out of ≥ $33. It nets −0.14, because at the
    strategy's rates those two bands convert alike: 0.97 % against 0.89 % of entries end ≥ +100 %.
- **Each ticket was worth less than the README assumed:** 0.0113 net doublers after fills, against 0.0166†.
  - The count came in near the ~90 tickets the FRESH bar asked for (84–85).
  - But the funded mix is dearer than #3595's list mix (30 % against 40 % under $14), because cheap names fund least.
- **The rates are thin.**
  - r(b) pools 9, 10, 8 and 15 trades. Those are 3, 2, 4 and 5 distinct trades repeated across the five S cells; the
    < $8 rate is BGO 2003, MERC 2010 and ADMA 2023†.
  - A Poisson band on the pooled counts is ±0.31. With every rate one SE in P's favour, E_net is 1.55†. So FRESH's L2
    bar sits about 1.8 such SEs up.
- **One input is mis-banded.** ADSK 2003-09-15's five doublers sit in $8–14 because `trades.csv` restates its entry
  price ($8.83) for the 2004 split (#3595 §Defects 2). With ADSK in its decision band, $14–33, E_net is 0.920†: the
  same branch.

#### 4. Why T fails on the ride while the doubling rate is three times higher

- **The top is fatter.** Monsters are 10.2 % of swapped-in rows against 3.3 %, and p90 is +33.2 % against +26.6 %. 69
  of the 156 swapped-in monsters are < $8 names, which make up 19 % of the rows.
- **The middle and the bottom are worse.**
  - p10 is −17.3 % against −12.3 %, the median −4.1 % against −2.1 %, and the win rate 38.5 % against 42.0 %.
  - The bottom deepens as price falls. p10 is −27.4 % for swapped-in < $8 names, −18.8 % at $8–14 and −13.4 % at
    $14–33, against −12.3 % for the ≥ $33 names cut.
  - A volatile name that fails falls further before a weekly close crosses the 30-week WMA.
- **A doubling is not a kept gain.**
  - The monster flag asks whether the weekly close doubled at any point in 52 weeks. The ride asks what a holder
    keeps at the first weekly close below the WMA.
  - In the population, price-Q1 breakouts double 15.9 % / 13.6 % of the time but ride to ≥ +100 % only 3.7 % / 3.8 %
    (`../price-band-tiebreak-2026-11-13/screen/results/ytrait-capped.txt`).
  - The strategy keeps a similarly small share: 8 % of its < $8 entries end ≥ +100 % (r), while 23.5 % of the
    swapped-in < $8 names double.
- **The cap.** The ride is capped at +190 %, the population's p99.5, set by PREREG Amendment 1 against vendor-splice
  errors. That limits what one ride adds to about 0.12 pp of a 1,500-row mean. The committed read does not show how
  many rows reach the cap, so its share in the tie is not measured.
- **The band mix dilutes the trait.** 56 % of the swapped-in rows are $14–33 (monster 7.1 %, ride +3.9 %), a band
  whose population ride shows no edge (+1.5 / +3.8 % in `price-bands.txt`). The < $8 rows that carry the trait
  (+5.9 %) are a fifth of the total.
- **The out side is not all ≥ $33.**
  - 153 of its rows are cheaper names displaced by cheaper ones still: 148 at $14–33, mean +10.3 %.
  - 53 of those 156 swaps fall in 2009–10†, when cheap names flood the ties and most names rose.
  - They lift the out mean by about 0.8 pp. Against the ≥ $33 rows alone (+3.3 %), the in side leads by 0.7 pp.
- **Pairing by date removes that date effect.** In minus out then averages +0.9 pp (SE about 0.74†). But the median
  date is −1.4 pp, and in leads on only 46.8 % of dates, about 1.7 SE below half. That is the fat-tail profile: it
  loses a little more often and wins bigger when it wins.

So the order buys more doublings. But at a 30-week-WMA exit the extra doublings are paid for by deeper failures, and
the capped mean ties.

#### 5. What this says about #3595's +0.348

- **The expectation is a third to a half of the gap.** E_net is about 0.10–0.18 log over 26 years, under the 0.2 log
  single-draw floor (`project_26y_path_noise_floor`). #3595's median Δ is +0.348.
- **The rest is one realization, repeated.** By seed, P ended with +2, +3, +2, +2 and +2 more ≥ +100 % trades than S†,
  against about 0.95 expected. The cross-band order is the same at every seed (#3595 §Why 5), so the five P cells
  share that draw.

**Seed 0, end to end** (#3595 `results/k0/`):

- **MERC, 2010-11-12.**
  - In S-k0's list MERC sat at rank 25, cut by the seeded draw. MD (≥ $33, S rank 18) is the name P drops to make
    room. S-k0 walked 19 names that Friday and placed none (`fridays.tsv`).
  - P's order ranks MERC 17th. P-k0 placed it; it filled 2010-11-15 at $6.39 and made +111 % (MERC-wein-477), about
    0.15 log by entry-NAV contribution.
  - So #3595's "unresolved channel" for MERC was the cut, not cash.
- **ADMA, 2023-08-18.**
  - S rank 22, P rank 12; SUN (≥ $33, rank 20) drops out.
  - P-k0 filled it 2023-12-19 at $4.35, and it made +300 % (ADMA-wein-1207), about 0.25 log.
  - It is the record band's largest seed lottery (`project_record_kseed_band`); the order makes it certain.
- **2009-10-30, both gates at once.** S-k0 placed DECK (+52.6 %, DECK-wein-373), which P's order cuts. P-k0's list held
  DINO but skipped it for cash; P placed DINO in k1–k4 (+117 %).
- **LGND, 2012-12-14, the other side.**
  - On S's path the order cuts LGND (S rank 16, P rank 21) in favour of PPC, CTRN, RVT and BBD.
  - S-k0 placed LGND and made +232.8 % (LGND-wein-595).
  - P-k0, on its own path, placed it too (LGND-wein-618).
- **Net for seed 0.**
  - P-k0 placed 43 of the 1,744 swapped-in (date, name) pairs. At S's per-band rates they were worth 1.14 doublers,
    and they delivered two: MERC and ADMA.
  - S-k0 placed 59 of the swapped-out pairs, worth 0.45. They delivered one, LGND, which P kept by path†.
- **The largest one-arm names are swaps.** Four of the five largest P-only contributors in #3595's k0 (ADMA, MERC,
  WAL, HOS) are swap-ins here. Three of the five largest S-only ones (CVNA, EME, DECK) are swap-outs.

**Reading.**
- The order's systematic swaps carry #3595's gap, as #3595 said. In expectation they buy about one doubler per 26
  years.
- On seed 0 the realized gain is about one doubler above that (LGND kept by path), plus a large draw on size (ADMA's
  +300 %).
- The same swaps recur in every seed.

#### 6. Where the cheap monsters go before the cut

- **`Stage_setup` is nearly the whole breakout-phase loss, and it does not select.** It is first to drop cheap monsters
  about as often as cheap breakouts in general (lift 0.99 exact, 0.88 window).
- **It is harsh on cheap breakouts in general.** It drops them about three times as often as ≥ $33 ones (45.3 %
  against 16.4 % of those with a row).
- **So the extra breakout-phase loss of cheap monsters is breadth.** Cheap breakouts are more often not in a
  qualifying stage setup.
- **The rule cannot say NOTHING.** Branch 4 fires first, on a two-event cell (§Defects found 4). Nothing here says what
  loosening `Stage_setup` would admit.

### How it fits what we know

- **Confirms #3595's "binds often", without path effects** (`project_trait_y_low_price`). L1 is 0.69, against the 67 %
  #3595 saw on the lists it could observe. It also resolves #3595's unresolved channel for MERC: it was the cut.
- **Confirms the funnel law** of `project_floor_and_refresh_screens` and `project_top_n_capacity_verdict`, where the
  top-N loss is a slot loss. Like top-N 40, Nearest and the monthly refresh, the band order reaches the list and then
  mostly dies at the funding gates.
- **Confirms gate 1** of `project_path_stability_seeded_noise` and `project_record_kseed_band`. The cut sits inside a
  score tie on 84 % of open dates, and ADMA 2023-08-18 (S rank 22) is the record band's tie-cut lottery.
- **Confirms `project_edge_is_the_fat_tail` and `project_entry_selection_closed_powered`** from a new angle. The
  promoted names win less often and double more often, and the capped mean does not move.
- **Largely settles the contradiction #3595 flagged** with the tiebreak ledger rows
  (`2026-06-29-candidate-ranking-tiebreak-grid`, `2026-06-29-earliness-ranking-tiebreak-grid`,
  `2026-06-30-tiebreak-noise-floor`). In #3595 an informative tiebreak did end above every baseline seed. But what it
  buys in expectation is about one doubler per 26 years, below what a 26-year K = 5 read can resolve.
- **Refines `project_26y_path_noise_floor`.** #3595's gap was traced to the lever's own trades, and those trades are
  still mostly a draw. A traced gap is not an expected one.
- **Refines `project_monster_funnel_top_of_funnel`.** On the current record config, the breakout-phase loss of cheap
  monsters is `Stage_setup`, as the 08-25 smoke pointed (94 % `Stage_setup`), and it is not selective. That answers the
  "which sub-gate" question in `project_trait_y_low_price`.
- **Contradicts a cost note** in `project_top_n_capacity_verdict` ("`--emit-candidates` doubles a cell"). On this build
  it added about 3.3 GB of RSS and no measurable wall time.

### What it implies next

These are options; the choice is the user's.

- **Stop on this axis (the rule's outcome).** Keep `Price_band_seeded` default-off, record the rates, and write no new
  pre-registration. The why supports it: the order's whole funded footprint is about 3 tickets a year, so no band-edge
  sweep, extra seed or longer window on this history can lift its expected effect above the floor.
- **#3598 is read on its own rule.** This read predicts nothing about its outcome.
  - If #3598 returns ESCALATE, the clash rule holds: nothing escalates, and the user gets both reads.
  - What this read adds to that call is the size of the expectation. The re-draw splits about evenly between the
    halves (838 / 906 swaps; 180 / 174 swapped-in < $8 names†). So a 13.5-year C1 window carries roughly half of an
    expectation that is already below δ.
  - A C1 gap at δ would therefore have to be traced to named trades. #3598's own name-concentration bar is the test
    of whether it is the same kind of shared draw.
  - This read says nothing about the top-1000 cell (C2) beyond the mechanism. Any other #3598 outcome cannot conflict
    with it.
- **Settle the label, only if it matters.**
  - Re-running read steps 2 and 5 with `STORE_END=2026-06-26` applies the README's own convention: truncated rows
    become T.
  - It needs the cell's WORK files, or a bar store matching `td-full`.
  - It can only move CLOSE-AXIS to PARK, and both spend nothing now, so it is not worth a new cell.
- **The low-price trait itself.**
  - This read places the leak at three points:
    - `Stage_setup`: breadth, with no lift.
    - The top-N slot: re-drawable only through ties, about one doubler per 26 years.
    - Post-cut fundability: cheap names fund at about half the rate of dear ones.
  - Fundability is the gate where floor-nearest (NOT LIVE) and the stop-width work already found the binding
    constraint. "Nothing further" is the honest default.
  - The one unmeasured link is why cheap top-20 names fail the walk: no floor found, or a floor beyond the 15 % stop
    gate, by band. That is a read-only count on a `trade_audit.sexp`, not a run. Its likely answer, deep bases on
    volatile names, points at the stop-width dial, a risk dial already studied.
- **Ruled out by this read.**
  - Another ordering or tiebreak lever on price.
  - A sweep of `ranking_price_band_edges`: the edges change the swap mix, not the funding gates.
  - More seeds on 2000–2026.
  - More generally, a lever that re-orders the top N without changing who can be funded reaches the book through about
    5 % of its swaps.
- **For future pre-registrations.**
  - Give a lift bar a minimum event count.
  - Give a mean-difference clause a tolerance or a paired statistic.
  - Class coverage against an end date that every name in the store reaches.

### Defects found

1. **Truncated swaps read as delisted (Measurement 3; the input branch 3 turned on).**
   - **Where.** `read/lib/fwd.awk` line 29 classes a row D when its symbol's last bar is more than 14 days before
     STORE_END. `read/read.sh` lines 39–41 default STORE_END to the latest last bar among the pool's names, 2026-09-11
     (`inputs.txt`). Most names' bars end earlier in the read's store.
   - **What it does.** 2025–26 swaps that lack 52 forward weeks are read as delisted, over the few weeks that exist.
   - **Specimens.**
     - 33 in-rows and 34 out-rows dated after 2025-09-12 survive the dedup†, and none of them can have 52 forward
       weeks. Yet `swap_tail.txt` classes only 2 rows T (in: T 2, X 0; out: T 0).
     - The 2026 rows are live names: VSH, XHR and NN on 2026-04-17 and HELE on 2026-05-22 (in); VRT on 2026-04-17,
       and AAON and CRDO on 2026-05-08 (out) (`swaps.tsv`).
     - Up to 51 rows a side from 2025-06-27 on may be affected.
   - **Effect.** The FD means and T's ride difference include truncated outcomes that the README's convention leaves
     out (T: "monster and ride are NA"). The direction is unknown.
   - **Fix.** Set `STORE_END=2026-06-26`, the run's end, which `read.sh` already accepts. Or class D only when a
     delisting record confirms it.
2. **No-price pool rows ranked as ≥ $33 (Measurements 1–3).**
   - **Where.** `read/lib/bind.awk` line 33 ranks a pool row with no close as ≥ $33. The README does not specify this
     case.
   - **Size.** 40,229 of 498,225 pool rows (8.1 %), and 39 of the 683 placed tickets (`selfcheck.txt`). Such names
     can only be swapped out: they are 147 of the 1,616 deduped out-rows (`swap_tail.txt`, X 147). `swaps.tsv` writes
     them as band 3, so they cannot be told apart there.
   - **Effect.** Bounded. L1 has a wide margin, T leaves X rows out, and a rough bound on E_net is ±0.1, which keeps
     the same branch.
   - **Fix.** Write band NA in `swaps.tsv`, and read prices from the warehouse the run used.
3. **r(b) bands use split-restated entry prices** (a pre-registration input; #3595 §Defects 2, #3384). ADSK
   2003-09-15, recorded at a restated $8.83 because of a 2:1 split on 2004-12-21, puts five of the ten $8–14 doublers
   in the wrong band. Corrected, E_net is 0.920†.
4. **Rule 2's order lets a two-event cell block NOTHING** (a pre-registration design issue). `Breakout_volume`'s window
   lift of 3.27 is two cheap monster events among four drops, worked back from the printed shares and lift†. Branch 4
   comes before branch 5, so it decides. A minimum count, like T's 20 monsters, would have prevented it.
5. **The cost budget is stale** (not a results defect). The budget assumed 2.05×; the cell ran at about 0.93×
   (7,477 s against #3595's 8,058 s). `CELL_TIMEOUT` (49,500 s) came out at 6.6× the wall.
6. **No defect in the cell itself.** It is byte-identical to #3595's S-k0, its validator counts match, and the audit
   join is complete.

### Review-pack look

No pack was built for this cell, and the pre-registration's §After the run does not ask for one.

- **Why none is needed.** Every per-arm artifact is byte-identical to #3595's pb-S-k0, which #3595's ten-cell pack
  covered (§Review-pack look there).
- **What this read uses.** No run-level figure is read here that the pack did not already show, and no images were
  given to this read.
