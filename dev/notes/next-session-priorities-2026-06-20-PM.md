# Next-session priorities — 2026-06-20 PM

**Supersedes** `next-session-priorities-2026-06-20.md`. Check main CI green first
(`.claude/rules/session-rampup.md`). The 2026-06-20 AM session lens-screened the
two P0 levers landed 06-19; **both are NO-BUILD** (kept default-off as axes).

## What happened 2026-06-20 — both P0 screens → NO-BUILD

Deep 1998-2026 top-3000 Cell-E, decision-grading lens @26w. Full record:
`dev/experiments/p0-screens-2026-06-20/FINDINGS.md` (+ PLAN.md, per-variant
grade md, batch output `dev/backtest/scenarios-2026-06-20-062510/`).

### P0a — reserved short sleeve (`short_sleeve_fraction`) → NO-BUILD
Sweep {0.10, 0.20, 0.30} vs sleeve-OFF long-short baseline (return1663/Sharpe0.57/
MaxDD36.9/Calmar0.29). Results **wildly non-monotonic**: return 1663→1478→2019→
**375**; shorts **lose at every fraction** (−$424k…−$676k, 21–31% win) and are
**never unlocked** (36/37/37/44 ≈ 37 baseline). Three transferable findings:
1. **Crowd-out-by-cash diagnosis WRONG** — shorts are *supply*-gated (Stage-4
   signal count + `short_min_price 17`), not cash-gated. Funding a reserved
   budget doesn't reach more shorts.
2. **No offsetting leg to fund** — shorts lose in every cell; reserved capital is
   pure drag.
3. **Reserved cash taxes the fat-tail long engine** (0.30 craters return to 375%)
   — `project_edge_is_the_fat_tail` again. The 0.20 "win" is a lucky path.

### P0b — vol-scaled stop (`vol_scaled_stop_atr_mult`) → NO-BUILD
Sweep {1.0, 1.5, 2.0} vs volstop-OFF long-only baseline (return1934/Sharpe0.61/
MaxDD48.7/Calmar0.23/Ulcer15.8). Every mult **reduces return** (1934→820/1206/242)
and **lowers Sharpe** (0.61→0.47/0.56/0.34); non-monotonic = path-dependent. The
floor fires fewer stops monotonically (746→643→527→465) — mechanic works — but:
1. **Per-decision stop quality got WORSE** — stop net-VA −6.2%→−7.6%; the lens's
   core question (does upside-foregone shrink while disaster-dodged holds?) = NO.
2. **mult=1.5's DD "win"** (Calmar0.29/Ulcer13.6/MaxDD32.3) is **just less
   risk-taking** — bought with −38% return + lower Sharpe; obtainable cleaner via
   exposure/sizing.
3. The stop cost is **structural, not a tuning miss** — both weekly-close (#1655)
   and vol-scaled stop fail the per-decision asymmetry; the foregone upside *is*
   the fat-tail recovery.

## P0 NEXT — P1 barbell promotion grid (now the live lever)
With both stop/short levers ruled out, the next lever is the diversification
LAYER that does NOT touch the long tail: **barbell** (SPY-timing floor + Cell-E
engine NAV blend, `project_barbell_on_stocks` — beat both legs on Calmar in deep
+ bull, never taken to a grid). Take to WF-CV + `promotion-confirmation.md` grid
(≥3 period×universe cells incl. a bear-dominated macro regime). This is the
correct class per the guardrail below.

## Queued (secondary) — short-supply screen [~76min deep run]

The 06-20 short re-decomposition (`dev/experiments/p0-screens-2026-06-20/`,
longshort baseline 37 shorts) **corrected the earlier overclaim**: with stops the
per-trade short payoff is fine (avg win +$109k vs avg loss −$34k, loss tail capped
at −14.7%) — short P&L is ~breakeven at baseline, NOT −EV by construction. The real
limits are **supply** (only 37 shorts / 28y, confirmed gated) and **unreliable
bear timing** (shorts *lost* in 2000/2002/2008 — the grinding crashes — won only in
single-shot 2001/2020). n=37 = selection-noise-dominated, low confidence.

**The cheap test of the supply lever:** one deep run with `short_min_price`
loosened (admit more, cheaper Stage-4 shorts), then the SAME read-only by-year +
distribution decomposition. Does a bigger short book (a) actually grow the count,
(b) stay per-trade-favorable, and crucially (c) finally fire in 2008?

Recipe — clone `dev/backtest/decision-grading-longshort-2026-06-18/cell-e-top3000-1998-longshort.sexp`,
change one override `((short_min_price 17.0))` → e.g. `((short_min_price 5.0))`
(and optionally a 2nd variant at 1.0 to sweep). Run:
`scenario_runner --dir <new-dir> --snapshot-dir /tmp/snap_top3000_1998_2026_v2
--fixtures-root / --parallel 1`. Then decompose shorts with the awk used 06-20
(by exit-year P&L + win/loss distribution on `trades.csv` side=SHORT), OR extend
`stop_ma_split`-style.

**Yellow flag going in:** the 2008 whipsaw loss suggests *more* name-level
Stage-4 shorts may just lose more in grinding bears — individual-name short timing
is the suspected failure, which loosening supply does NOT fix. If the loosened run
*still* loses in 2008, the verdict is "name-level shorts aren't a dependable
bear-hedge; use the regime/index overlay (barbell) instead" and this line closes.
Lower priority than the P1 barbell grid above.

## Guardrail (HARDENED by today's two no-builds)
Do NOT screen **winner/loser-touching** levers — the `edge_is_the_fat_tail`
class now has ~8 rejections (laggard, force-exit, stage2-ma-hold, late-flag,
macro-trim, harvest-rotate, **short-sleeve**, **vol-scaled-stop**). Capital-
reservation and stop-widening both tax the tail. The live class is **structural
diversification layers** (barbell, regime-gating overlays, offsetting legs that
actually pay) — NOT entry/cascade/swap/short-pick selection (dead 5×) and NOT
stop/sizing knobs that just trade return for smoothness.

## Standing-belief corrections to propagate
- `project_short_funnel_crowded_out`: supply-gated, not cash-gated (see above).
- `project_weekly_close_stop_lever` / stop whipsaw: structural cost, not tunable.

## State
- Both P0 flags remain default-off axes (no code change this session; screens
  only). 0 open PRs at session start; findings committed docs-only.
- v2 warehouses at `/tmp/snap_top3000_{2000,2011,1998_2026}_v2`; lens at
  `trading/trading/backtest/decision_grading/`; backtests run at
  `SNAPSHOT_CACHE_MB=1024`, parallel=1 for N=3000, ~76min/run deep.
