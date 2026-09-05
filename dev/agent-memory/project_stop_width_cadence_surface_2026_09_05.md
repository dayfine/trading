---
name: project_stop_width_cadence_surface_2026_09_05
description: "Stop-width {4,8,10,12,14}% x cadence {daily, weekly-close} surface, record convention, fixed basis, 2019-vintage warehouse (dev/experiments/stop-width-cadence-surface-2026-09-05/). SALT 0: widening NEVER cuts loss dollars (best −6%; the yearly-review counterfactual was wrong — survivors of a 4% stop mostly lose 8–14%); it cuts loser count and ≤5-day exits, lifts win rate 30→37–46%, moves exits from stops to rotations. 2000–04: every width ≥8% = maxDD −8..−11pp, equity ≥ null ex-monster (14% daily +$682k incl. ADSK +$382k held). 2019–23: only 14% daily (+$150k, maxDD −0.7pp) and 12% weekly (+$389k, three names) pass. Cadence flips sign across widths = path noise. Salts 1–2 DONE: all 7 survivors pass equity+maxDD at ≥2/3 salts; 14% daily (3/3 both windows) and 12% weekly (3/3 + 2/3) clear BOTH windows; 26y confirmation arms running."
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
