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
| D1 | Friday-decided exits fill at **Friday's open**, dated Saturday (stale bar on a calendar-day step) | simulator defect — **fixed, #2644** | first-order: arc +$525k (08-21) / +$1.05M (fresh) if filled Monday open; record −$601k. **Measured with the fix armed (26y, §5): ejects +$763k → +$1.66M ex-phantom, realised ex-all-phantom +$84k → +$86k — **neutral at 26y** (raw +$217k / −0.6% carries a +$513k CHS splice phantom exposed by the Monday-open fill, and both runs carry a −$0.17M ICT phantom; issue #2646); the fixes are honest and the arc still loses** |
| D2 | a fresh position's stop is judged against its **own entry bar's pre-fill low** | strategy-plumbing defect — **fixed, #2642** | 173 of 3,029 (08-21) / 166 of 2,625 (fresh) entries killed on day 0 with the stock closing above the stop. **Measured with the fix armed: day-0 stops 233 → 1**; the survivors stop later and larger (stops −$2.54M → −$3.68M), MaxDD 57 → 61% |
| D3 | only **6.5%** of fill weeks carry §4.2 volume; the resting buy-stop fills on the first intraday touch of the range top, which is rarely the volume week | faithful mechanism × data | 72% of all entries ejected at ≈ +$400/trade; the fills that survive are then 4%-stopped |
| D4 | 58–84% of tickets get the flat 4% fallback stop (no qualifying structural floor) | known (#2408) | 151/162 stop-outs on the 5y cell are fallback-stop trades |

Fresh numbers (build `deb45a7ee`, split-safe warehouse, salt 0):

| cell | return | trades | win | Sharpe | MaxDD | notes |
|---|---:|---:|---:|---:|---:|---|
| `b5-arc` (2019–2023 × top-3000-2019) | **−24.4%** | 689 | 41.1% | −0.53 | 38.0% | exit mix: 517 eject / 162 stop / 10 laggard |
| `arc26y` (2000–2026 × top-3000-2000) | **−29.2%** | 2,625 | 40.7% | −0.06 | 57.4% | 15.0h wall (an 11h stall inside it, see §8); realised −$85.5k; exit mix 1,899 eject (+$763k) / 617 stop (−$2.54M, 233 same-day) / 100 laggard (+$1.50M); fill-week confirmed 221/2,210 (10%); fallback stop 2,350/2,835 (83%). Prior basis 08-21: −62.4% / 3,029 / MaxDD 67.7% — the 33pp move sits inside the 132.5pp 26y null and rides the #2530 `reset_anchor_on_stalled_cycle` flip; not a claim. |
| 5y ladder, fix-armed cells, 3-window fast grid | see §5 | | | | | dup-null bit-identical; eject gate is the whole 5y deficit (novol +48pp); anchor window and freshness basis are not levers; fixes verified at 5y and 26y |

## 1. D1 — the Saturday fill (simulator)

**Observation.** Exit weekdays, 26y arc (08-21 artifacts): `volume_eject`
2192/2192 Saturday, `laggard_rotation` 154/154 Saturday, `stop_loss`
Tue–Sat with 148 Saturday and **zero Monday**. Same on the fresh 5y cell
(517/517 ejects Saturday) and on the record convention (269/269 laggard
exits, 98/503 stops). The warehouse has no weekend bars.

**Price basis.** All 2,500 Saturday-dated arc exits equal the preceding
Friday's OPEN at 2 dp (2,231 exact at 4 dp, 268 within rounding, one 2-dp
tie with Friday's close — PCTI 2023-12-09); none is explained by Monday's
open (40 rows coincide with it at 2 dp only where Friday's and Monday's
opens round alike). E.g. ZQKSQ ejected 2011-07-23 at 5.50 = Fri open
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

| cell | return | trades | win | Sharpe | MaxDD | read |
|---|---:|---:|---:|---:|---:|---|
| `b5-arc` | −24.39% | 689 | 41.1% | −0.533 | 38.0% | base |
| `b5-arc-dup` | −24.39% | 689 | 41.1% | −0.533 | 38.0% | **bit-identical** — determinism tripwire passes on the fresh build |
| `b5-arc-novol` | **+23.64%** | 199 | 29.6% | +0.348 | 28.8% | eject gate OFF (same fills): **+48pp** vs base, ≈3× the broad-5y return null (14.65pp, `rt-freshness-broad5y-2026-08-20`, different base config — order of magnitude only). Exit mix 61 laggard (+$755k) / 137 stop (−$732k); realised +$29k, the rest is open-position MTM. Trades 689→199: the positions that were being ejected and re-entered are simply held. Still 71% fallback stops (215/302) and 137 stops paying $732k — D3 is the biggest single lever on this cell, D4 the next. Salt-0 only. |
| `b5-arc-macross` | −26.60% | 686 | 41.1% | −0.536 | 40.9% | freshness basis `Ma_cross` instead of `Range_top_breakout` (anchor 4 kept): **≈ base** (−2.2pp, inside the 5y null). The screen basis is not the lever on this cell; the same tickets fill and the same eject gate removes them. |
| `b5-fullbook` | **+13.81%** | 174 | 33.9% | +0.234 | 33.9% | the `fullbook-graded` ticket-half alone (no 4-week anchor, no range-top basis, no fill-week eject). Arc − fullbook = −38pp; novol − fullbook = +10pp (inside the 5y null). Read: on this cell the eject gate accounts for the whole arc deficit; anchor-4 + range-top screening without the eject is indistinguishable from the plain ticket. Salt-0 only. |
| `b5-arc-anchor26` | −13.05% | 627 | 40.2% | −0.154 | 34.7% | ticket anchor = 26-week range top instead of 4-week: +11pp vs base (inside the 5y null), tickets 689→627 only, same eject-dominated exit mix. The anchor window moves little on this cell; D5 is a faithfulness point, not the P&L lever. Salt-0 only. |
| `b5-arc-fix` | **−10.38%** | 670 | 47.5% | −0.159 | 26.4% | D1 + D2 fixes armed on main `94a8c6857` (`sim_exit_fill_next_open` + `stops_config.stop_skip_entry_bar`): +14pp vs base (≈ the 5y null), win rate +6.4pp, MaxDD −11.6pp. **Both defects verified absent in the artifacts:** zero Saturday-dated exits (ejects fill Monday 486 / Tuesday-after-holiday 45), stops 162 → 129 and day-0 stops 66 → 1 (a genuine gap-down). Ejects +$531k vs +$223k on the base (the Monday-open effect, first-order predicted); stops −$756k vs −$589k (day-0 artifacts become later real stops); realised −$119k vs −$258k. D3 still dominates: 531 ejects of 670 trades. Salt-0 only. |
| `arc26y-fix` | −0.59% ⚠ | 2,518 | 46.4% | +0.065 | 61.2% | **D1 + D2 fixes armed at 26y** (build `94a8c6857`). **⚠ CONTAMINATED: one trade, CHS 2004-12-17→12-20, is a +$513,550 ticker-splice phantom (raw close 11.29→45.16 AND adj_close 4.07→15.88 on 12-20, volume 5M→1M — a different security under the same symbol; issue filed). The unfixed run exited CHS on the Saturday step at Friday's open (−$1,155); the Monday-open fill landed on the splice bar. The −0.6% return compounds on the phantom from Dec-2004 and is NOT a number; ex-ALL-phantom (CHS +$514k, ICT −$161k, AGR −$220k in this run; ICT −$169k in the unfixed run — `results/phantom-trades.txt` — 10 splice-affected trades across all cells, issue #2646) realised is **+$85.6k fixed vs +$83.6k unfixed: the fixes are realised-NEUTRAL at 26y on salt 0** — the eject leg gains +$0.9M and the stop leg loses it back (day-0 artifacts become later, larger real stops).** +28.6pp raw vs the unfixed arc is inside the 132.5pp null anyway. The trade level is: zero Saturday-dated exits (ejects now fill Monday 1,753 / Tuesday-after-holiday 170), same-day stops 617→480 with 233→**1** on day 0, realised P&L −$85,545 → +$217,320 raw / **+$83.6k → +$85.6k ex-all-phantom (neutral)**, ejects +$763k → +$2,176k raw / **+$1,662k ex-phantom** (the first-order repricing said +$1,223k — direction confirmed, magnitude on the high side), stops −$2,544k → −$3,681k (day-0 artifacts become later, larger real stops), laggards +$1,504k → +$1,477k. MaxDD 57.4 → 61.2% (worse: positions that used to be killed on day 0 now ride drawdowns). 12 of 27 years positive on exit-year realised (was 10). Fill-week confirmation still 10% (212/2,212); 1,924 ejects of 2,518 trades — D3 remains the binding constraint. Wall 2h21m. Salt-0 only. |
| `arc26y-novol` | not run | | | | | dropped 2026-09-02 evening: user demoted 26y to confirmation-only ("try to make money in 1y/3y/5y before doing more 26ys"); the eject-off lever is measured on the 3-window fast grid instead (README §"Fast grid"). |

### 5b. The 3-window fast grid (fixed simulator, build `94a8c6857`, salt 0)

All arms carry `sim_exit_fill_next_open` + `stops_config.stop_skip_entry_bar`. Base = `fix`.
Warehouse-vintage caveat applies (README §"Fast grid"): g19 runs on ~980 names.

| cell | return | trades | win | Sharpe | MaxDD | read |
|---|---:|---:|---:|---:|---:|---|
| `g19-fix` (= `b5-arc-fix`) | −10.38% | 670 | 47.5% | −0.159 | 26.4% | base |
| `g19-novol` | −10.22% | 207 | 21.3% | −0.053 | 43.3% | eject OFF on the fixed sim: **≈ base** (+0.2pp). On the defective sim the same flip was −24.4 → +23.6. The +48pp was a D1/D2 artifact: stale Friday-open fills made ejects lose money, so holding looked better; with Monday-open fills the ejects earn what the held positions would have. Realised −$238k vs −$119k for the base (stops 141 at −$857k vs 129 at −$756k; laggards 64 at +$614k). MaxDD worse (43%) — held positions ride drawdowns. Salt-0 only. |
| `g19-s6` | **+30.18%** | 638 | 46.2% | +0.374 | 35.4% | fallback stop 4% → 5.9% (`initial_stop_buffer 0.98`, the book band's upper half) on the fixed sim: **+40.6pp vs base**, ≈2.7× the cell null; win rate unchanged, MaxDD +9pp. Realised +$274k — but **one `extension_stop` trade — MSTR 2020-09-15 → 2021-03-01, 152.56 → 798.40, 167 days — is +$542k**; ex that trade the cell is −$268k, below base. Exit mix 545 eject (+$344k) / 81 stop (−$723k) / 11 laggard (+$111k). The wider stop let one monster survive its first week: a tail-lottery shape (`project_edge_is_the_fat_tail`), not yet a lever verdict — needs the other two windows and salts. Salt-0 only. |
| `g19-novol-s6` | +6.79% | 163 | 31.9% | +0.162 | 39.5% | both levers: +17pp vs base, below `s6` alone. Exit mix 70 laggard (+$991k) / 93 stop (−$1,023k); realised −$32k raw, **+$176k ex-phantom** (a −$208k STMP 2021-10-05 splice, `phantom-trades.txt`); no MSTR-class trade. Salt-0 only. |
| `g00-fix` | **+75.21%** | 278 | 48.9% | +0.611 | **10.8%** | base, 2000–04 × top-3000-2000 (94% warehouse coverage — the one properly-PIT window). **⚠ 70% of the realised P&L (+$513,550 of +$736,024) is the CHS ticker-splice phantom (issue #2646); ex-phantom realised +$222k (203 ejects +$368k / 64 stops −$357k / 8 laggards +$161k) — still positive, but the +75% return compounds on the phantom and is not a number.** Every g00 arm carries the same trade; compare g00 arms on ex-phantom realised only. 278 trades in 5y (vs 670 on 2019–23). Salt-0 only. |
| `g00-novol` | +92.28% | 103 | 30.1% | +0.669 | 19.3% | eject OFF, 2000–04: no phantom trade (CHS never entered). Realised +$238k (25 laggards +$290k / 78 stops −$52k) vs base ex-phantom +$222k — **≈ equal realised**, same read as g19 (eject on/off is not a P&L lever on the fixed sim); MaxDD 19% vs 11% (held book rides drawdowns). The +92% vs +75% return gap is uninterpretable (base return compounds on the phantom). Salt-0 only. |
| `g00-s6` | +64.33% ⚠ | 264 | 48.9% | +0.546 | 12.8% | fallback stop 5.9%, 2000–04: CHS phantom +$481k again; **ex-phantom realised +$144k vs base +$222k — the wider stop LOSES −$78k here**, the opposite sign of g19 (+40pp, one MSTR trade). 207 ejects +$739k (incl. phantom) / 43 stops −$291k / 12 laggards +$162k. Salt-0 only. |
| `g00-novol-s6` | +32.08% | 102 | 25.5% | +0.332 | 30.3% | both levers, 2000–04: no phantom; **realised −$155k** (31 laggards +$252k / 70 stops −$430k) — the +32% return is open-position MTM; MaxDD 30%, the worst of the g00 arms. 2000–04 read on ex-phantom realised: base +$222k ≈ novol +$238k > s6 +$144k > novol-s6 −$155k. Salt-0 only. |
| `g05-fix` | +4.17% | 365 | 45.5% | +0.129 | 17.8% | base, 2005–09 × top-3000-2005 (54% coverage), through the GFC: no phantom; realised +$82k (270 ejects +$198k / 76 stops −$505k / 17 laggards +$336k); yearly −$66k / +$98k / +$58k / −$70k (2008) / +$62k. Salt-0 only. |
| `g05-novol` | +11.38% | 141 | 31.2% | +0.215 | 29.2% | eject OFF, 2005–09: no phantom; realised +$70k (38 laggards +$576k / 97 stops −$615k) vs base +$82k — **≈ equal, third window in a row**; MaxDD 29% vs 18%. Salt-0 only. |
| `g05-s6` | +33.28% | 315 | 46.7% | +0.566 | 22.3% | fallback stop 5.9%, 2005–09: no phantom; realised +$147k vs base +$82k (**+$65k**, the one window where the wider stop wins on realised without a single-trade driver: top trades CGIP +$93k, SHOO +$65k); 259 ejects −$11k / 33 stops −$325k / 22 laggards +$463k; MaxDD 22% vs 18%. Salt-0 only. |
| `g05-novol-s6` | +9.85% | 120 | 30.8% | +0.199 | 33.5% | both levers, 2005–09: no phantom; realised −$92k (37 laggards +$405k / 78 stops −$588k) vs base +$82k; MaxDD 34% — worst of the g05 arms. Salt-0 only. |

#### Decision table (pre-registered rule, README §"Fast grid"): ex-phantom realised P&L and MaxDD vs the window's `fix` base

| lever | 2019–23 (g19, ~980 names) | 2000–04 (g00, 94% coverage) | 2005–09 (g05, 54%) | verdict |
|---|---|---|---|---|
| base `fix` | −$119k / MaxDD 26.4% | +$222k / 10.8% | +$82k / 17.8% | — |
| eject OFF (`novol`) | −$238k / 43.3% (worse) | +$238k / 19.3% (≈, MaxDD worse) | +$70k / 29.2% (≈, MaxDD worse) | **REJECT as a lever**: realised-neutral in 3/3 windows, MaxDD worse in 3/3. The +48pp read on the defective simulator was the D1 tax on the eject leg. |
| stop 5.9% (`s6`) | +$274k / 35.4% — but −$268k ex one MSTR trade (worse) | +$144k / 12.8% (worse, −$78k) | +$147k / 22.3% (better, +$65k, diversified) | **NOT PROMOTABLE**: wins 1 of 3 windows on non-lottery realised; MaxDD worse in 3/3. Keep as an axis (the book band is 4–6%; 5.9% is inside it). |
| both (`novol-s6`) | +$176k ex-phantom (raw −$32k carries a −$208k STMP splice) / 39.5% — the best non-lottery realised in this window | −$155k / 30.3% (worst) | −$92k / 33.5% (worst) | **REJECT**: worst realised in 2/3 windows and **MaxDD worst in 3/3** (39.5/30.3/33.5 vs 26.4/10.8/17.8); the g19 realised win does not survive the MaxDD prong of the rule. |

No lever clears the rule → no 26y confirmation run, no salts. What the grid
DID settle: with honest fills the arc's 5y realised is roughly flat to
mildly positive in all three windows (2000–04 makes money through the
dot-com bust with an 11% drawdown), and neither the eject gate nor the
fallback-stop width is the lever — the deficit vs the record is structural
(D3/D5: what the ticket buys and when), consistent with
`project_edge_is_the_fat_tail`. Every number here is salt-0 and, for g19,
on a 32%-covered universe (README §"Fast grid" caveat).

## 6. Guards built (integration tests) and the fix-armed rerun

Three PRs, all default-off / behaviour-preserving, goldens untouched
(agent wave 2026-09-02 14:07–16:10 PDT):

| PR | what | tests |
|---|---|---|
| #2644 `feat/sim-exit-fill-next-open` — **MERGED 94a8c68 (17:18 PDT)**; rework 1 added the gate-level sibling-routing test (mutation-verified by both reviewers) | `sim_exit_fill_next_open` — `Next_open_fill_gate.make ~defer_entries ~defer_exits`; a Market order closing an `Exiting` position is held until a fresh bar. No engine change. | `test_sim_exit_next_open.ml`: OFF pins the Friday-open/Saturday fill (R1); ON fills Monday open; entries unaffected; two round trips across two weekends + a mid-week hole assert no trade date without a bar. Paired run of both docstring-flagged goldens bit-identical (table in PR). |
| #2645 `exp/arc-rerun-2026-09-01` — **MERGED 6444eba (17:08 PDT)**: this record (README, specs, chain, per-arm artifacts), one text-only rework | — | — |
| #2642 `feat/stop-skip-entry-bar` — **MERGED 60d5086 (16:44 PDT)** | `stops_config.stop_skip_entry_bar` — the stop-hit exit is masked on the bar whose date = the position's entry_date (structural, weekly trigger-only, catastrophic; short mirror); state machine still advances. | `test_stops_runner.ml` +9 (each ON case paired with an OFF R1 pin); `test_stop_skip_entry_bar_sim.ml` drives `Simulator.run` over four days: fills per step `[0;1;1;0]` OFF vs `[0;1;0;1]` ON. |
| #2641 `feat/validator-v13-v14` — **MERGED 7da7f24 (17:40 PDT)** after two rework rounds (12 + 3 tests; 47 total; every V13/V14 Skip branch mutation-caught by exactly one test). Residuals recorded by the final reviewer, not blocking: the status file's "(32 tests)" line (fixed in the follow-up commit) and a dedicated test for V14's "no bar on the entry date" input shape, which today shares the `\| _ -> Skip` arm | V13 (INV): every trade's entry/exit date has a bar for that symbol and the fill price lies inside that bar's [low, high]; V14 (EXP): a ≤1-day stop-out whose entry-day close is at/above the installed stop. `bars.daily` became a raw-OHLC record; V14 reads `stop_fill_distance_pct` (fill-basis) first. | `test_post_run_validator.ml` +7 (32 total), injected lookups. |

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
