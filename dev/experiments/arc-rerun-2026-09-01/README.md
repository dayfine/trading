# arc-rerun-2026-09-01 — rerun the arc-faithful bundle on current main and find what is wrong

User directive 2026-09-01 (overnight session): *"let's rerun and figure out
what's wrong? do some deep trade analysis and guard against typical errors
with integration tests."*

The arc bundle (`staging-arc-2026-08/top3000-2000-2026-arc-faithful.sexp`)
last ran 2026-08-21 at −62.4% / 26y (`dev/notes/arc26y-corrected-writeup-2026-08-21.md`).
Since then `#2530` flipped `initial_stop_buffer 1.0` and
`reset_anchor_on_stalled_cycle` default-on, and `entry_order_max_rest_weeks`
moved 0→52 (`#2587`; the spec pins 0). This experiment (a) re-measures the
bundle on `origin/main` @ `deb45a7ee`, (b) decomposes its three screening
knobs on the cheap broad-5y cell, and (c) dissects the trades against raw bars
to separate *faithful-but-unprofitable* from *execution defects*.

## Cells

All cells: salt 0, split-safe warehouse `/tmp/snap_top3000_dedup_v5thin_adj`,
`--parallel 1`, `--no-emit-all-eligible`, build `deb45a7ee` in the pinned
worktree `.claude/worktrees/sweep-arc0901`. Specs under `specs/` (staged at
`/tmp/arc0901-specs` for the chain, per sweep-hygiene). Chain `run.sh`,
log `/tmp/arc0901-chain.log`, artifacts `/tmp/sweeps/arc0901/<cell>-s0/`
(whole scenario output dir, including `trade_audit.sexp`).

| cell | window × universe | diff vs the committed arc spec | why |
|---|---|---|---|
| `b5-arc` | 2019-01-02..2023-12-29 × top-3000 PIT-2019 | period/universe only | smoke of the fresh build; the cheap decomposition base |
| `arc26y` | 2000-01-01..2026-06-26 × top-3000 PIT-2000 | none (spec verbatim) | **the deliverable** — the arc on current main |
| `b5-arc-dup` | as `b5-arc` | none | determinism tripwire (must be bit-identical to `b5-arc`) |
| `b5-arc-novol` | as `b5-arc` | `volume_confirm_at_fill false` | isolates the §4.2 fill-week eject gate |
| `b5-arc-macross` | as `b5-arc` | `entry_freshness_basis Ma_cross` | isolates the screen-under-the-range-top basis (anchor 4 kept) |
| `b5-fullbook` | as `b5-arc` | anchor / rt / vol-at-fill all removed | the `fullbook-graded` ticket-half alone on this cell |
| `b5-arc-anchor26` | as `b5-arc` | `entry_anchor_local_range_weeks 26` | added 23:40 after D5: the ticket anchor as a 26-week range top (the knob's documented example) instead of a 4-week high |
| `arc26y-novol` | as `arc26y` | `volume_confirm_at_fill false` | 26y control for the eject gate (runs last, if time allows) |
| `b5-arc-fix` | as `b5-arc` | `sim_exit_fill_next_open true` + `stops_config.stop_skip_entry_bar true` | D1 + D2 fixes armed — build pinned at main `94a8c6857` (#2642 + #2644 merged), chain `run3.sh`, worktree `sweep-arc0901fix` |
| `arc26y-fix` | as `arc26y` | same two flags | **the definitive size of D1 + D2** on the 26y arc (the first-order repricing said +$1.05M realised) |

Order in the chain: `b5-arc` → `arc26y` → 5y ladder → `arc26y-novol`
(`run.sh`); the chain is stopped after `arc26y` for the agent wave and
relaunched as `run2.sh` (same cells + `b5-arc-anchor26`; completed cells are
skipped off the log's RESULT lines).

## Fast grid (2026-09-02 evening, user: iterate on 1y/3y/5y before more 26y)

Three disjoint broad 5y windows × four arms, all on the **fixed simulator**
(D1 + D2 flags armed, build `94a8c6857`), chain `run4.sh`, ~25 min per cell.
26y runs become confirmation-only. `g19-fix` = the `b5-arc-fix` cell above.

| window | universe | regime | warehouse coverage |
|---|---|---|---:|
| `g00` 2000-01-03..2004-12-31 | top-3000-2000 | dot-com bust + recovery | 94% |
| `g05` 2005-01-03..2009-12-31 | top-3000-2005 | pre-GFC run-up + GFC | 54% |
| `g19` 2019-01-02..2023-12-29 | top-3000-2019 | covid + 2022 bear | 32% |

Arms: `fix` (arc + both fixes, the base), `novol` (fill-week eject off),
`s6` (`initial_stop_buffer 0.98` → 5.9% fallback stop, the book band's upper
half), `novol-s6`. Decision rule (pre-registered): a lever is promoted to one
26y confirmation only if it beats the window's `fix` base in ≥2 of 3 windows
by ≥1.5× the broad-5y return null (~15pp, `rt-freshness-broad5y-2026-08-20`),
is never badly dominated in any window, and does not worsen MaxDD; the winner
then gets salts {1,2}.

**⚠ Warehouse-vintage caveat (measured 2026-09-02, not previously written
down).** `/tmp/snap_top3000_dedup_v5thin_adj` holds 2,908 snaps = the
**2000-vintage** composition. Coverage of `top-3000-<v>` decays monotonically:
2000 94%, 2001 72%, 2004 58%, 2005 54%, 2009 44%, 2013 39%, 2019 32%, 2023
28%. The runner silently skips absent symbols, so every "broad-5y cell B"
result in this and prior experiments (sa2408, clock cell B, today's ladder)
effectively ran on ~980 names that are 2000-vintage members surviving into
2019 — survivor-tilted in level. Within-cell A/B comparisons stay valid
(`project_composition_golden_survivor_bias`: the bias hits both arms); absolute
levels and cross-window comparisons do not. Proper fix = vintage-specific
warehouses (a warehouse-rebuild task, not tonight).

## Read-before-verdict obligations

1. **26y return null on this base is 132.5pp** (`project_ladder_v4_null_278pp`
   discipline). No 26y arm-vs-arm return delta below that is interpretable.
   The 5y ladder is for *mechanism decomposition* (exit mix, trade counts,
   eject share), not for a return verdict — 5y windows nest in 26y and
   flatter/penalise exits by horizon (`project_entry_cap_horizon_reversal`).
2. **Never compare to CSV-basis golden numbers** (`project_clock52_promoted`:
   ~54pp warehouse-vs-CSV gap on a 5y broad book).
3. **Execution-defect findings are separated from faithfulness findings.**
   A defect (a fill at a price that predates the decision) is a bug in the
   simulator and moves EVERY arm including the record; it is not evidence
   about Weinstein's method.

## Interim findings from the 2026-08-21 artifacts (before the rerun finished)

Recorded here so the rerun's dissection can confirm or refute each one on
fresh artifacts. Source: `inspect-6mo-2026-08-21/results/arc26y-corrected-trades.csv`
+ raw bars via `dump_snap`.

### D1 — exits decided on a Friday fill at FRIDAY'S OPEN, dated Saturday (simulator defect)

Every `volume_eject` (2192/2192), `laggard_rotation` (154/154),
`liquidity_exit`, `stage3_force_exit` and `extension_stop` exit is dated a
**Saturday**, and 148 of 668 `stop_loss` exits are too. The warehouse holds no
weekend bars. Sample of 25 Saturday-dated exits joined to raw bars: **every
exit price equals the preceding Friday's OPEN** (ZQKSQ 5.50, ZION 84.17,
XEL 46.62, WMT 130.55, WAFD 35.35, …), never Friday's close nor Monday's open.

Mechanism (code-verified): the simulator advances one *calendar* day per step
(`simulator.ml:443`); on the Saturday step `Market_state.update` receives an
empty bar list and keeps Friday's bars (`market_state.ml:33-36`); the exit
Market order submitted at the Friday tick fills against that stale bar's open
and is re-stamped with the Saturday date (`simulator.ml:361`). The
next-bar-open gate that closes exactly this hole for Market **entries**
(`next_open_fill_gate.ml`, `sim_entry_fill_next_open`, Fix #1 of
`dev/plans/fill-model-faithfulness-2026-08-07.md`) explicitly exempts exits
(`test_sim_entry_next_open.test_exit_unaffected_when_flag_on`).

The same holds in the record convention (`record-baseline-2026-08-24`:
269/269 laggard exits and 98/503 stops Saturday-dated), so this is a
system-wide fill-basis defect, not an arc-specific one. Direction: a Friday
trigger sells at Friday's open — for stops that is *above* the stop level on a
down day (flattering), for ejects/laggards it is whichever way Friday moved.
**Quantification** (`results/reprice-*-saturday-exits.csv`; every Saturday-dated
exit repriced at the next trading day's open, quantities held fixed —
first-order, no path/compounding effect):

| arm | Saturday exits | at Friday open | Δ realised P&L if filled Monday open | arm's total realised P&L |
|---|---:|---:|---:|---:|
| arc 08-21 (26y) | 2,500 | 2,500 at 2 dp (2,231 exact at 4 dp, 268 within rounding, 1 tie with Friday's close) | **+$524,745** (ejects +$534,581; laggards −$23,075; stops +$29,185) | −$417,063 |
| record 08-24 (26y) | 373 | 373 | **−$601,280** (stops −$336,865; laggards −$262,955) | +$5,566,862 |
| arc fresh 09-02 (26y, `results/arc26y-s0/`) | 2,144 | 2,144 at 2 dp (1,904 exact at 4 dp, 239 within rounding, 1 tie with Friday's close) | **+$1,051,441** (ejects +$1,223,346; laggards −$58,228; stops −$93,733) | −$85,545 |

The defect moves the two arms in opposite directions: the arc's ejected
weak-volume breakouts keep rising into Monday (selling at Friday's open
forfeits it), while the record's Friday stop/laggard triggers are selloffs
that continue Monday (selling at Friday's open is optimistic). First-order,
the arc's whole realised loss is smaller than this one defect's cost; that is
a claim to VERIFY by rerunning with the fix armed, not a result.

### D2 — the initial stop is evaluated against the ENTRY bar's pre-fill low

The step order is fills → strategy (`simulator.ml:401-410`), so a ticket
filled intraday at E is already `Holding` when the stop runner reads the
same day's completed bar (`stops_runner._handle_stop`, `check_stop_hit` on
`bar.low`). For an E-anchored buy-stop the day's low is by construction
*before* the fill (price rises through E), so a >4% intraday range below E
"stops out" the position on its entry bar.

08-21 run: 261 of 668 stop-losses (39%) exit within one day. Joined to the
entry-day bar: 214 closed **above** the stop; 173 are the pure artifact shape
(low < stop ≤ close, sold next open above the stop; net realised +$45k —
harmless in dollars, but 173 breakout entries (5.7% of all) destroyed on
their first day); 156 had the entry-day OPEN below the stop (the stock opened
>4% under E and ran up through it — the breakout-day shape).

### D3 (revised on the fresh 5y cell) — 6.5% of fill weeks are volume-confirmed

`b5-arc-s0` audit (`results/b5-arc-s0/audit_extract.csv`, 795 tickets, 689
trades; extractor `audit_extract.pl` — note the audit renders confirmed
verdicts as `Confirmed_spike` / `Confirmed_buildup`, an earlier pass of this
note mis-parsed them as zero): of 583 evaluated fill weeks, **545 Unconfirmed
(513 ejected, 32 skipped by a same-tick exit), 38 confirmed** (34 spike, 4
build-up; 29 held, 9 skipped), plus 112 tickets never filled and ~100 trades
closed before their first Friday evaluation. The runner judges the RIGHT bar —
hand recomputation from raw daily bars matches the audit's `spike_ratio` to
4 decimals on AAON (1.0966), AB (1.3815), ABT (0.7855). The Unconfirmed spike
ratios sit at p50 0.97 / p90 1.58: fill weeks are *average-volume weeks*. The
38 confirmed fills did not save the arm either: 28 of their 36 closed trades
ended in `stop_loss` (−$82k), 8 in `laggard_rotation` (+$108k).

Two things the 08-21 reading got wrong, corrected here:

- The trades.csv `entry_volume_ratio` (median 2.16) is NOT the screen week's
  ratio. `Stock_analysis` grades volume at the **peak-volume bar within
  `breakout_event_lookback` (8 weeks)** — a lookback maximum
  (`stock_analysis.ml:356-361`, `_find_peak_volume_offset_callback`). AB's
  audit ratio 2.60 corresponds to a week five weeks before placement; the
  placement week itself was 1.07×.
- The 2% limit band is not what filters out volume-confirmed weeks: of 112
  never-filled tickets only 2 gapped above the band within 90 days (72 never
  reached E, 33 crossed E intraday but were not filled — the funding layer,
  `project_ticket_dies_on_cash_shortfall`); of 681 fills, 86% opened below
  E and crossed intraday, 13% opened inside the band, 1% above it.

Standing hypothesis (tested by `results/b5-arc-s0/fwdvol.csv`): the resting
buy-stop fills on the **first intraday touch** of the local range top — an
early poke — and the decisive volume week, if it comes, comes AFTER the
position has already been ejected on the poke week's ordinary volume. If so
the arc is structurally unable to hold anything: the fill event and the
book's confirmation event are different weeks by construction.

### D5 — the ticket anchor is a 4-week high, and the first touch of it has no edge

`suggested_entry = local_range_top × 1.005` (A: 149 → 149.74; AAON: 59.19 →
59.49), and `local_range_top` is the split-safe max high over the last
`entry_anchor_local_range_weeks` bars — **4** in the arc spec (inherited from
the ladder-v4 rt arms; the knob's own docstring gives 26 as the example and
describes the anchor as "the top of the current trading range"). Book §4.1's
ticket is written at the top of the base's resistance zone (months); a
4-week high is a different event. Forward check on the 5y fills
(`results/b5-arc-s0/fwdvol.csv`, 601 fills): close 4 weeks after the fill
week vs the fill-week close is up 52% of the time, mean +0.6%; a ≥2× volume
week follows within 4 weeks for 11%; the 30 spike-confirmed fills average
−1.2%. The touch of a 4-week high is not a breakout event on this
universe. `b5-arc-anchor26` measures the 26-week anchor on the same cell.

### D3 (original 08-21 reading, superseded above) — the §4.2 fill-week gate ejects the screen-week's volume spike

Ejected trades carry a screen-week `entry_volume_ratio` median 2.16
(p25 1.79 / p75 2.63; 65% ≥ 2.0) — indistinguishable from the stop-loss and
laggard cohorts (p50 2.26 / 2.16). Under the range-top basis the screen week
is the approach week; `Volume.confirms_breakout` on the fill week divides by
the prior 4 weeks, which now *contain* the approach-week spike, and the
build-up branch additionally requires the fill bar to exceed the bar before it
(the spike). The implementation is a faithful reading of "prior 4 weeks"; the
finding is that on a broad modern universe the volume arrives in the approach
week, so the gate ejects 72% of fills at ≈ +$162/trade. Confirmation needs
the rerun's `trade_audit.sexp` fill-week classification
(Spike / Buildup / Unconfirmed / no-verdict) — the 08-21 artifacts lack it.

### D4 — the 4% flat fallback stop is the common path

`stop_initial_distance_pct` = 0.0400 on 1,764 of 3,029 trades (58%): no
structural floor qualified (or it was filtered by `max_stop_distance_pct`),
so §5.3's flat stop applies. Book §5.1 says a >15% structural risk means
*prefer other candidates*; the implementation instead installs a 4% flat stop
on the same trade (issue #2408; blind-judge screen #2630 agrees the
re-anchor is an adaptation, not a book reading).

## Status

See `writeup.md` (written when the cells land) and the ledger entry for the
verdict. Chain state: `grep RESULT /tmp/arc0901-chain.log`.
