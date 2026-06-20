# Next-session priorities — 2026-06-20

**Supersedes** `next-session-priorities-2026-06-19.md`. Check main CI green first
(`.claude/rules/session-rampup.md`). The 2026-06-19 session built + landed both P0
levers the 06-19 doc surfaced.

## What shipped 2026-06-19 (both default-off, per experiment-flag-discipline)

1. **P0a — RESERVED SHORT SLEEVE: MERGED #1659.** Default-off
   `Weinstein_strategy_config.short_sleeve_fraction : float [@sexp.default 0.0]`.
   When `> 0.0`, `entries_from_candidates` partitions the per-Friday cash budget
   into a reserved short-only budget (`fraction * portfolio_value`) walked
   independently of longs, fixing the diagnosed crowd-out
   (`project_short_funnel_crowded_out`: 1,662 short slots offered / 37 entered /
   0 rejected over 28y — shorts were never *reached*, not rejected). `<= 0.0` is
   bit-identical. Searchable `Variant_matrix` nested axis. **Not wired into any
   preset.**

2. **P0b — VOL-SCALED STOP DISTANCE: MERGED #1662.** Default-off
   `Weinstein_stops.config.vol_scaled_stop_atr_mult : float [@sexp.default 0.0]`
   (+ `vol_scaled_stop_atr_period [@sexp.default 14]`). When `> 0.0`, the minimum
   installed-stop distance becomes
   `Float.max(installed_stop_min_pct, mult * ATR/entry)` — volatile names get a
   structurally wider stop floor (whipsaw reduction *at source*, the lever
   weekly-close #1655 couldn't reach without holding breakdowns deeper). `<= 0.0`
   bit-identical. New pure primitive `Weinstein_stops.Vol_scaled_stop`; ATR from
   `analysis/technical/indicators/atr`; the `max_stop_distance_pct` 15% reject cap
   still applies after the widened floor (pinned by test). Searchable nested axis.
   **Not wired into any preset.**

Both lands are SAFE (default = pre-existing no-op, every golden bit-identical);
neither changes live/backtest behaviour until a spec flips the flag.

## P0 NEXT — screen the two flags (the actual alpha question)

Both levers are BUILT and searchable but UNPROVEN. The whole point of landing
them default-off is to now *test* whether they help. Per
`experiment-flag-discipline.md` R3 + `promotion-confirmation.md`, neither flips
a default without a ledger ACCEPT + a confirmation grid.

### P0a-screen — reserved short sleeve
Lens-screen the sleeve via the `decision_grading` instrument: with the sleeve
funded (`short_sleeve_fraction` ∈ {0.1, 0.2, 0.3}), do the now-numerous shorts
add a **real offsetting / DD-reducing** leg, or just churn at ~breakeven (the (c)
symptom)? The build only proved shorts now *enter* — it did NOT prove they help.
If the lens shows a genuine offset → WF-CV surface → confirmation grid. If it's
still ~breakeven/coin-flip → record the no-build *with the why* (capital reserved
for a leg that doesn't pay = drag) and keep default-off as an axis.

### P0b-screen — vol-scaled stop
Lens-screen `vol_scaled_stop_atr_mult` ∈ {1.0, 1.5, 2.0}: does stop
**upside-foregone shrink while disaster-dodged holds** (the asymmetry
weekly-close failed)? The decision-grading stop lens already measures
forgone-upside vs disaster-dodged per stop decision — re-run it with the flag on.
Promising → WF-CV surface → grid. Secondary stop lever still open: post-stop
re-entry.

**Watch the estimand (`mechanism-validation-rigor`):** a lens screen rejects
*prioritization*, not the mechanism; only WF-CV rejects the mechanism. Calibrate
verdicts accordingly.

## P1 — barbell promotion (unchanged, still valid)
`project_barbell_on_stocks`: SPY-timing floor + Cell-E engine NAV blend beat both
legs on Calmar (deep + bull); never taken to a promotion grid. WF-CV +
`promotion-confirmation.md`. Lower priority than screening the two just-built
flags (those are hot — built this session, untested).

## Guardrail (carried)
Do NOT start another *selection* screen (entry/cascade/swap/short-pick) — dead
end five times over (`project_edge_is_the_fat_tail`,
`project_accuracy_is_unreachable_diversify_instead`). The live class is
structural diversification + stop/holding quality. Both P0 levers are in that
class; keep search there.

## P1 — lens as standing instrument
The `decision_grading` + `laggard_cf` bins are the repeatable instrument; grade
any candidate at the decision level before/after. Harness gap (non-blocking,
carried): the bins' I/O glue (`_mfe_index`/`_find_mfe`, csv/forward extraction)
is untested over the pinned libs — factor into a tested shared helper if the lens
becomes more load-bearing.

## State
- Both P0 PRs merged (#1659, #1662), main green, 0 open PRs (verify at session start).
- v2 warehouses at `/tmp/snap_top3000_{2000,2011,1998_2026}_v2`; backtests run
  clean at `SNAPSHOT_CACHE_MB=1024`. Scenario-runner gotcha: `universe_path` is
  resolved relative to `--fixtures-root`; use the leading-slash-stripped path +
  `--fixtures-root /`.
- Lens lives at `trading/trading/backtest/decision_grading/`.
- New surfaces to screen: `short_sleeve_fraction` (nested under
  `Weinstein_strategy.config`) and `stops_config.vol_scaled_stop_atr_mult`.

## Process note (this session)
The P0b feat-agent died mid-run on a 401 (auth expiry); its work was complete on
disk and recovered + finished dispatcher-side. Three dispatcher fixes followed:
file-length extraction (real QC finding), magic-number on `[@sexp.default 14]`
(CI-only catch the QC agent's build-only run missed — confirms CI is the only
full-lint gate), and a behavioral CP4 test gap (the cap-after-vol-floor reject
was undocumented-by-test). All resolved; both gates + CI green.
