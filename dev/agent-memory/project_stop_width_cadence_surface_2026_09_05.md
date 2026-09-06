---
name: project_stop_width_cadence_surface_2026_09_05
description: "Stop-width {4,8,10,12,14}% x cadence {daily, weekly-update} surface, record convention, fixed basis, 2019-vintage warehouse (dev/experiments/stop-width-cadence-surface-2026-09-05/). SALT 0: widening NEVER cuts loss dollars (best −6%; the yearly-review counterfactual was wrong — survivors of a 4% stop mostly lose 8–14%); it cuts loser count and ≤5-day exits, lifts win rate 30→37–46%, moves exits from stops to rotations. 2000–04: every width ≥8% = maxDD −8..−11pp, equity ≥ null ex-monster (14% daily +$682k incl. ADSK +$382k held). 2019–23: only 14% daily (+$150k, maxDD −0.7pp) and 12% weekly (+$389k, three names) pass. Cadence flips sign across widths = path noise. Salts 1–2 DONE: all 7 survivors pass equity+maxDD at ≥2/3 salts; 14% daily (3/3 both windows) and 12% weekly (3/3 + 2/3) clear BOTH windows; 26y confirmation arms running."
metadata:
  type: project
  modified: 2026-09-05
---

**Design:** record spec + `((initial_stop_buffer b)) ((stop_update_cadence c))`,
width = 1 − 0.96·b; 14% is the ceiling (`max_stop_distance_pct` 0.15 rejects wider);
build `e4984c5fe` (pinned `sweep-stop0905`); 2019–23 on `/tmp/snap_top3000_2019`
(first level-valid record-convention 2019 null: **16.8% / 179 / maxDD 22.0**, vs 3.0%
on the 2000-vintage warehouse), 2000–04 on the 2000-vintage warehouse.

**Salt-0 table** in the README. Headlines: loss dollars never fall ≥ 6%; ≤ 5-day exits
52 → 6–18 (2019) and 19 → 7–11 (2000); exit mix 139/40 stops/rotations → ~95/85–100 at
12–14% on 2019 — **a wide enough stop hands the exit to the laggard rotation**, which
is the A-grade channel ([[project_yearly_trade_review_2026_09_04]]). Regime split as in
[[project_stop_width_regime_dependent]]: bust/recovery survivors are the recovery
(2000–04 wants 8–10%, maxDD 17–18% vs 28%); melt-up survivors are laggards until the
width is wide enough (14%) for the position to reach a rotation exit. Weekly-close
cadence (book L3) is equity-neutral-to-negative at 4–10%, +$358k/+$239k at 12%, negative
again at 14% on 2019 — sign flips = path noise, not a mechanism.

**Artifacts seen:** DTV held at final 0.00 in the 2019 14%-daily arm (−$66k phantom,
#2672); wide arms are more exposed because they hold delisted names longer.

**Pre-registered test (1) (loss $ ≥ 40% lower) was miscalibrated** — recorded as a
deviation; salts run for the (2)+(3) passers (2019 w14-D, w12-W; 2000 w8-D, w10-D,
w10-W, w12-W, w14-D). Promotion bar unchanged: ≥ 2/3 salts on BOTH windows + 26y maxDD.

**Salts 1–2 (done 06:50 09-05):** 7/7 survivors pass (2)+(3) at ≥ 2/3 salts. 2019–23
14% daily: equity +150/+69/+31k, shared drift +115/+166/+124k, maxDD −0.7/−3.5/−0.8pp —
3/3. 2019–23 12% weekly: +389/+315/+204k, maxDD +2.9/+1.5/+5.4pp — 3/3 + 2/3, with a
salt-stable APPS/NVDA/HVT cohort. 2000–04: every width 8–14% holds maxDD 17.5–20% vs
19.6–28.4% at 3/3 salts; 8–10% win ex-IPIXQ, 12–14% win through 55–67 extra entries.
**Both-window passers: 14% daily, 12% weekly** → 26y confirmation arms `sw26y-w14-D`,
`sw26y-w12-W` (running from 06:50; ~3h each). Promotion bar unchanged; #2672 must be
fixed before any promotion PR (wide arms hold delisted names longer).

**26y confirmation (09-05 15:40):** `sw26y-w14-D` = 513% / 1,009 / win 42% / Sharpe
0.51 / **maxDD 40.4** vs record 303 / 723 / 34% / 0.40 / 36.3 → FAILS the 26y bar
(+4.1pp; Feb–Mar 2020 entries lose 14% each, 2020 realised −$670k vs −$145k).
`sw26y-w12-W` = **761% / 862 / win 44% / Sharpe 0.58 / maxDD 29.7** → CLEARS the bar
(−6.5pp; shared drift +$1.67M over 380 trades; largest arm-only trade BFX +$1.05M = 24%
of the delta; open book KLAC +$1.08M; STMP stub in both arms; drawdown trough 2020-03-25
and 2020 realised +$359k because the trail is raised only weekly so the stop rests lower mid-week (trigger intraday in both arms)). **Promotion
candidate: `initial_stop_buffer 0.9167` + `stop_update_cadence Weekly`** (two knobs;
neither alone clears both windows at 26y), gated on #2672 fix + re-run, ledger entry,
paired goldens, user decision.

**Breadth-state analysis (27y, PIT universes, /tmp/yr-run/breadth_all_daily.csv):**
level-only "crash" states are NET POSITIVE (they include the recovery buys); the losing
state is breadth DETERIORATING (<45% above 150d MA and falling ≥5pt/20d, or NL>8% and
rising): record 80 entries −$604k (1 A), 14% arm 94 entries −$668k (2 A); RECOVERING
entries +$627k / +$1.81M. Deteriorating losses cluster 2020, 2023, 2018, 2025, 2007;
false positives 2022, 2014. Design: macro gate emits breadth DIRECTION as a state; width
map + admission read the state (paired surface).

**CORRECTION (qc-behavioral, 09-05 16:10):** `stop_update_cadence Weekly` does NOT
evaluate the stop on the weekly close — `stops_runner.mli`: trigger continuous
(intraday) in both cadences; Weekly only raises the trail on Friday. Weekday
histograms of stop exits are identical across cadences. The "W" arms win via a
LEVEL effect (the trail rests lower mid-week → fewer shakeout stop-outs), which is
why cadence matters only at wide widths. The qc-behavioral-authority L3 row ("stop
triggers on weekly close") is unsupported by the reference §5.1 — docs write-back PR.

**Open before promotion (qc-behavioral notes, #2678):** (a) the 26y w12-W maxDD gain is
NOT fewer crash stop-outs (19 vs 19 stops in 2020-02-24…03-25, −$887k vs −$425k) — the
gain is elsewhere in the path; dissect the drawdown window before citing a mechanism.
(b) No `sw26y-w12-D` arm exists: at 26y cadence is confounded with width — run it.
(c) Tripwire for the level-effect mechanism: mean `n_stop_raises` 0.15 (Weekly) vs
0.42 (Daily) on 2019–23 at 12%. Merged as #2678 (d5e8715f7); L3 checklist fixed in #2681.
