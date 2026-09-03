# Arc-faithful rerun + dissection — what is actually wrong (2026-09-01/02)

Experiment: `dev/experiments/arc-rerun-2026-09-01/` (README = design + cells;
this note = the findings). User directive: *"rerun and figure out what's
wrong; deep trade analysis; guard against typical errors with integration
tests."*

**TL;DR.** The arc bundle loses for three separable reasons, two of which are
execution defects in the simulator/strategy plumbing (they move EVERY arm,
including the record) and one of which is the faithful mechanism meeting
modern data:

| # | what | kind | first-order size (26y arc, 08-21 artifacts) |
|---|---|---|---|
| D1 | Friday-decided exits fill at **Friday's open**, dated Saturday (stale bar on a calendar-day step) | simulator defect | arc **+$525k** if filled Monday open (its whole realised loss is −$417k); record **−$601k** |
| D2 | a fresh position's stop is judged against its **own entry bar's pre-fill low** | strategy-plumbing defect | 173 of 3,029 entries killed on day 0 with the stock closing above the stop |
| D3 | only **6.5%** of fill weeks carry §4.2 volume; the resting buy-stop fills on the first intraday touch of the range top, which is rarely the volume week | faithful mechanism × data | 72% of all entries ejected at ≈ +$400/trade; the fills that survive are then 4%-stopped |
| D4 | 58–84% of tickets get the flat 4% fallback stop (no qualifying structural floor) | known (#2408) | 151/162 stop-outs on the 5y cell are fallback-stop trades |

Fresh numbers (build `deb45a7ee`, split-safe warehouse, salt 0):

| cell | return | trades | win | Sharpe | MaxDD | notes |
|---|---:|---:|---:|---:|---:|---|
| `b5-arc` (2019–2023 × top-3000-2019) | **−24.4%** | 689 | 41.1% | −0.53 | 38.0% | exit mix: 517 eject / 162 stop / 10 laggard |
| `arc26y` (2000–2026 × top-3000-2000) | **−29.2%** | 2,625 | 40.7% | −0.06 | 57.4% | 15.0h wall (an 11h stall inside it, see §8); realised −$85.5k; exit mix 1,899 eject (+$763k) / 617 stop (−$2.54M, 233 same-day) / 100 laggard (+$1.50M); fill-week confirmed 221/2,210 (10%); fallback stop 2,350/2,835 (83%). Prior basis 08-21: −62.4% / 3,029 / MaxDD 67.7% — the 33pp move sits inside the 132.5pp 26y null and rides the #2530 `reset_anchor_on_stalled_cycle` flip; not a claim. |
| 5y ladder + 26y no-volume control | _pending_ | | | | | |

## 1. D1 — the Saturday fill (simulator)

**Observation.** Exit weekdays, 26y arc (08-21 artifacts): `volume_eject`
2192/2192 Saturday, `laggard_rotation` 154/154 Saturday, `stop_loss`
Tue–Sat with 148 Saturday and **zero Monday**. Same on the fresh 5y cell
(517/517 ejects Saturday) and on the record convention (269/269 laggard
exits, 98/503 stops). The warehouse has no weekend bars.

**Price basis.** All 2,500 Saturday-dated arc exits equal the preceding
Friday's OPEN at 2 dp (2,231 exact at 4 dp, 268 within rounding, one 2-dp
tie with Friday's close — PCTI 2023-12-09); none equal Monday's open. E.g. ZQKSQ ejected 2011-07-23 at 5.50 = Fri open
(close 5.45, Mon open 5.36); WAFD entered Fri 2024-08-23 at 37.49 and
"stopped" Sat at 35.35 = that Friday's open.

**Mechanism (code).** `simulator.ml:443` advances `current_date` by one
calendar day; `_get_today_bars` finds no bars on Saturday;
`Market_state.update` (`engine/lib/market_state.ml:33-36`) clears only the
generated paths and keeps Friday's bars; `process_orders` fills the
Friday-submitted Market sell against that stale bar's open;
`_extract_trades ~date` re-stamps it Saturday. `Next_open_fill_gate` (Fix #1,
`sim_entry_fill_next_open`, plan `fill-model-faithfulness-2026-08-07` §C)
closes this for Market ENTRIES and exempts exits by design
(`test_sim_entry_next_open.test_exit_unaffected_when_flag_on`). A 05-13 note
(`longshort-cascades-investigation-2026-05-13.md:73`) read Saturday-dated
fills as "executed Monday" — the date moved, the price did not.

**Size.** Repricing every Saturday-dated exit at the next trading day's open
(quantities fixed; `results/reprice-*-saturday-exits.csv`):

| arm | n | Δ realised if Monday open | by trigger |
|---|---:|---:|---|
| arc 08-21 (26y) | 2,500 | **+$524,745** | ejects +$534,581, laggards −$23,075, stops +$29,185 |
| record 08-24 (26y) | 373 | **−$601,280** | stops −$336,865, laggards −$262,955 |

| **arc fresh (26y, build deb45a7ee)** | 2,144 | **+$1,051,441** | ejects +$1,223,346, laggards −$58,228, stops −$93,733 (realised total of the run: −$85,545) |

Opposite signs: the arc's ejected weak-volume pokes keep rising into Monday
(the stale fill forfeits that), the record's Friday stop/laggard triggers
are selloffs that continue Monday (the stale fill is optimistic). This is
first-order only — the definitive number is a rerun with the fix armed
(§6).

## 2. D2 — the entry-bar stop (strategy plumbing)

**Observation.** 261 of 668 arc stop-losses (39%) exit within one day.
Joined to the entry-day bar (`results/sameday-stops-arc0821.csv`): 214 closed
ABOVE their stop that day; 173 are the pure artifact shape — entry-day low <
stop ≤ entry-day close, then sold at the next open above the stop (net
realised +$45k, i.e. harmless in dollars, but 173 breakout entries — 5.7% of
all — destroyed on day 0); 156 had the entry-day OPEN below the stop (the
stock opened >4% under E and ran up through it: the breakout-day shape).
Examples: WSM 2010-09-20 O 30.07 / L 29.73 / C 31.23, filled 31.29 at E, stop
30.04, sold 09-21 at 31.29; WAFD above. 5y cell: 66/162. Fresh 26y run:
233 of 617 stops same-day, 192 closed above the stop, 166 pure artifacts
(`results/arc26y-s0/sameday-stops.csv`).

**Mechanism (code).** Each step runs fills before the strategy
(`simulator.ml:401-410`); a ticket filled intraday at E is `Holding
{entry_date = D}` when the stop runner reads D's completed bar and
`check_stop_hit` compares `bar.low` with the stop (`weinstein_stops.ml:35-40`,
via `stops_runner._handle_stop`). For a buy-stop the day's low is by
construction before the fill.

## 3. D3 — volume arrives in a different week than the fill (faithful × data)

**Observation (5y cell, `results/b5-arc-s0/audit_extract.csv`).** 583 fill
weeks evaluated: 545 Unconfirmed (spike ratio p50 0.97 / p90 1.58), 38
confirmed (34 spike, 4 build-up). The runner judges the right bar — hand
recomputation from daily bars matches the audit to 4 dp (AAON 1.0966, AB
1.3815, ABT 0.7855). The confirmed 38 did not rescue the arm: 28 of their 36
closed trades were 4%-stopped.

**What the screener's "volume" number is.** `trades.csv.entry_volume_ratio`
(median 2.16 on 26y) is the ratio at the **peak-volume bar inside an 8-week
lookback** (`stock_analysis.ml:356-361`, `_find_peak_volume_offset_callback`,
`breakout_event_lookback = 8`), i.e. a lookback maximum — AB's 2.60 belongs to
a week five weeks before placement; the placement week was 1.07×. So the
screen grade and the fill-week verdict measure different weeks by design, and
the comparison "screen says 2×, fill says 1×" is not a contradiction.

**What is NOT the cause.** The 2% limit band: of 112 never-filled tickets,
2 gapped above the band within 90 days, 72 never reached E, 33 crossed E
intraday and were still not filled (the funding layer —
`project_ticket_dies_on_cash_shortfall`). Of 681 fills, 86% opened below E
and crossed intraday, 13% opened inside the band, 1% above.

**Standing reading.** The resting buy-stop fills on the *first intraday
touch* of the local range top. That is an early poke; the §4.2 volume week,
when it comes, comes later (`results/b5-arc-s0/fwdvol.csv`: within the next
4 weeks a ≥2× week follows only 11.5% of fills, ≥1.5× 33%, and the 4-week
forward close is up 52.4% of the time, mean +0.6% — no exploitable edge
either way). The eject rule then sells the
poke at ordinary volume for ≈ +$400, and the position that would have been
there for the real breakout is gone. The bundle is structurally unable to
hold anything: the fill event and the book's confirmation event are
different weeks by construction. The `b5-arc-novol` and `arc26y-novol`
cells measure what holding those fills is worth (with the 4% stop still on).

## 3b. D5 — the ticket anchor is a 4-week high

`suggested_entry = local_range_top × 1.005`, and `local_range_top` is the max
high over the last `entry_anchor_local_range_weeks` bars — **4** in the arc
spec (the ladder-v4 rt arms' value; the knob's docstring example is 26 and
calls the anchor "the top of the current trading range"). The book's ticket
(§4.1/§4.7) sits at the top of a months-long base's resistance zone. A
4-week high is a different, much more frequent event — which is why the
first touch shows no forward edge (§3) and why the bundle generates 3,000+
tickets over 26y. `b5-arc-anchor26` isolates the anchor window on the 5y
cell.

## 4. D4 — the fallback stop is the common path

5y cell: `stop_floor_kind` Buffer_fallback 669 / Support_floor 126 (84%);
26y: 1,764 / 3,029 at exactly 0.0400. Stop-outs by floor kind (5y):
fallback 151 (−$526k), support 7 (−$41k). Known (#2408, blind-judge #2630):
the book's rule for a far floor is "prefer other candidates", the
implementation installs a 4% flat stop instead.

## 5. What the ladder says (filled in when cells land)

_pending: b5-arc-dup (determinism), b5-arc-novol, b5-arc-macross,
b5-fullbook, arc26y, arc26y-novol._

## 6. Guards built (integration tests) and the fix-armed rerun

Three PRs, all default-off / behaviour-preserving, goldens untouched
(agent wave 2026-09-02 14:07–16:10 PDT):

| PR | what | tests |
|---|---|---|
| #2644 `feat/sim-exit-fill-next-open` | `sim_exit_fill_next_open` — `Next_open_fill_gate.make ~defer_entries ~defer_exits`; a Market order closing an `Exiting` position is held until a fresh bar. No engine change. | `test_sim_exit_next_open.ml`: OFF pins the Friday-open/Saturday fill (R1); ON fills Monday open; entries unaffected; two round trips across two weekends + a mid-week hole assert no trade date without a bar. Paired run of both docstring-flagged goldens bit-identical (table in PR). |
| #2642 `feat/stop-skip-entry-bar` | `stops_config.stop_skip_entry_bar` — the stop-hit exit is masked on the bar whose date = the position's entry_date (structural, weekly trigger-only, catastrophic; short mirror); state machine still advances. | `test_stops_runner.ml` +9 (each ON case paired with an OFF R1 pin); `test_stop_skip_entry_bar_sim.ml` drives `Simulator.run` over four days: fills per step `[0;1;1;0]` OFF vs `[0;1;0;1]` ON. |
| #2641 `feat/validator-v13-v14` | V13 (INV): every trade's entry/exit date has a bar for that symbol and the fill price lies inside that bar's [low, high]; V14 (EXP): a ≤1-day stop-out whose entry-day close is at/above the installed stop. `bars.daily` became a raw-OHLC record; V14 reads `stop_fill_distance_pct` (fill-basis) first. | `test_post_run_validator.ml` +7 (32 total), injected lookups. |

Side findings from the wave: `goldens_affected_check.sh` false-positives on
a NEW nested `[@sexp.default]` field under an armed outer knob (issue
#2643; `paired-run-done` applied on #2642 and #2644 with the reasoning in
the PR comments); `goldens-sp500/sp500-2019-2023-armed-stoplimit` reports
`open_positions_value` below its band on the committed CSV basis on
`origin/main` itself (identical on base and PR) — a pre-existing band
drift, not touched here.

_Pending: QC gates → merge → pin main → `arc26y-fix` / `b5-arc-fix`
(specs in `dev/experiments/arc-rerun-2026-09-01/specs/`, both flags
armed)._

## 8. Ops: the 26y cell took 15.0h wall for ~40 min of compute

`arc26y` started 23:05 PDT, finished 14:06 PDT (`wall 54067s`). At 11:24
PDT it had completed 468 of 1,434 weekly cycles (2007-12) and the runner
process inside the container reported **51 min** of process age; from
11:24 it ran 52 cycles per 90 s. The host never slept (Amphetamine held a
no-idle-sleep assertion for 71 h) and the harness delivered no wake-ups to
this session for 11 h. The Docker VM's process clock, not the host's,
excluded the gap — consistent with the VM being suspended/throttled rather
than the runner being slow. Cause not established; recorded so the next
15h wall on a 40-minute run is recognised as a stall, not as a slow build
(`feedback_two_stall_classes_check_clock`).

## 7. Why this transfers

- D1/D2 are **plumbing**, not Weinstein. They bias every arm; D1 flatters the
  record by ~$0.6M and taxes the arc by ~$0.5M on a 26y path. No verdict that
  compares a high-turnover arm against the record is clean until D1 is fixed.
- D3 is the real faithfulness lesson: **"judge volume at the fill" is only
  meaningful if the fill IS the breakout week.** A GTC buy-stop at the range
  top fills on the first tick above it; the book's breakout is the decisive
  weekly close above resistance on volume. Two different events. Any
  at-fill confirmation must either (a) wait for the weekly close to confirm
  before treating the poke as a breakout, or (b) trigger the ticket off the
  weekly bar, not the intraday touch.
- D4 compounds D3: whatever survives the eject is then held on a 4% leash
  below a level that is, by construction, a range top the stock just poked.
