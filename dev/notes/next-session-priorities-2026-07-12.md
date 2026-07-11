# Next-session priorities — 2026-07-12

**Supersedes** `next-session-priorities-2026-07-11.md` (its S0 and S1 are DONE
and merged; queue re-numbered below). Main green.

## What the 07-11 (PM) session shipped

1. **S0 DONE — realism-defaults flip MERGED (#1926).** Entry gate $1M ADV +
   stale-exit 5d are now the DEFAULTS (`min_hold_dollar_adv` stays 0.0).
   Full re-measure campaign completed: sp500 near-inert (STOP-rule never
   triggered; only OPV re-pinned on the 2010-2026 pair); covid-recovery
   BIT-IDENTICAL; broad top-1000 goldens re-pinned with BIG path moves
   (bull-crash 41→77%, decade 90→37%, six-year 22→104% — stale-exit
   ghost-cash recycling + ADV gate on delisted-heavy PIT; overlapping
   windows moved OPPOSITE directions = funding-path chaos, 5th
   path-flattery confirmation). test_data deep sanity 5/5 near-inert.
   top3000-catstop verified: flip basis = **5729.2%** (vs un-armed 2063%)
   — the PR's "expect ≤2063%" guess was WRONG; **stale-exit recycling, not
   hold-exit, is most of the honest-tradeable arming lift** (MTM-top-heavy,
   OPV $54M/$44.9M unrealized). tier4-broad + 30y-capacity NA'd
   (structurally blocked: coverage 53%, no corpus, pre-1999 bars).
   Full runtest + linters green; 3 gates; post-merge main CI green.
   Memory: `project_realism_defaults_flip_merged`.

2. **S1 DONE — AXTI exit verification (#1931).** Warehouse rebuilt to
   2026-06-26 (kept at `/tmp/snap_top3000_1998_2026_e0626`; old 04-30 one
   still at `/tmp/snap_top3000_1998_2026`); honest-tradeable re-run with
   extended end. **Branch B: AXTI STILL HELD** — trailing stop never
   advanced past the mid-May pullback; rode $122→$70 (~$34M MTM give-back
   from peak). Topline flat +6885.1%; Sharpe 0.806→0.768 = measured
   branch-B cost to date; **realized ≈$17.7M (+1670%, ~11.5%/yr) still
   beats refreshed SPY TR +700.0% (8.17%/yr)**. Note:
   `dev/notes/axti-exit-verification-2026-07-11.md`; staged scenario
   committed under `staging-honest-tradeable-ext/`.

## Queue (re-numbered from 07-11's S2-S7)

**P0 — extension-episode event-level screen** (was S2). close/MA ≥2.5-3×
held episodes across deep runs; paired high-trail variants 10/15/20/25%;
distributions, not means (screen-rigor: all 7 checks). Now has TWO fresh
inputs: the AXTI branch-B specimen (give-back measured: Sharpe −0.038,
realized delta 0) and the flip-basis deep runs. Decides whether an
`extension_stop` axis is worth building. LAW applies: any WF-CV needs a
horizon sweep (2y vs 4y+). Remember the April-28 trap: AXTI dipped to $71
BEFORE the May leg to $122 — single-specimen thresholds are hindsight.

**P1 — trader-preset BUNDLE audit + WF-CV** (was S3; per
weinstein-faithful-core W3; plan
`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`; AXTI as the
qualitative specimen).

**P2 — P1b step 3: sleeve lens screen vs TR-SPY** (was S5; consumes
`Breaker_spy_sleeve` from #1913; floor-quality Next-Steps 1).

**P3 — grind-weeks exposure** (was S6, carried).

**P4 — faithful per-week universes (M6.6 design)** (was S7): largest
identified capture loss (static PIT can't see later IPOs — deep run
literally cannot trade GME). Design + cost first; likely its own plan doc.

## Standing constraints

NO reversal timing; entry-selection/scale-in/reallocation/envelope/
stop-tuning closed; Weinstein spine fixed. Comparators TOTAL-RETURN.
LAW: horizon-sweep or rolling-start before believing tail-dependent
verdicts. Container: long runs solo; WIP-push within 30 min of any
dispatch; process checks must match strings a watcher's own argv cannot
contain. Post-#1926 note: default-config backtests now HAVE the entry gate
+ stale-exit — un-armed comparisons against pre-flip numbers must arm/disarm
explicitly.
