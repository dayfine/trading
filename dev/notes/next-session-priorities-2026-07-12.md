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

**~~P0 — extension-episode event-level screen~~ DONE 2026-07-11 PM →
NO-BUILD DECISION** (`dev/backtest/extension-screen-2026-07-11/FINDINGS.md`,
tool `analysis/scripts/extension_screen/`). Extension events are RARE
(~0.6-1% of episodes at 2.0× WMA30 — AXTI's true max is 2.41×, not the
eyeballed 2.5-3×), so a WF-CV would be structurally powerless; tight trails
(10-20%) tax the on-ramp of the same monsters they'd protect (9th
fat-tail-law confirmation, first at event level); the only positive cell
(trail 25%) is single-event-dominated (DDD closed + AXTI mark-timing).
Survives as a tail-insurance dial (catastrophic-stop class) — and the USER
DIRECTED THE INSURANCE BUILD (2026-07-11 PM): "no way we actually sit
through 140→70, even if that would take a manual intervention." Encoding
the intervention beats an untested panic exit. → new P0a below.
Capture-monster #4 closed as an ALPHA target only. Follow-up observation:
deep run held NLS/BFX rename-twins as two positions — universe dedupe
check worth a look.

**P0a (NEW, user-directed) — build `extension_stop` as default-off
tail-INSURANCE dial.** Shape: `extension_stop_config { trigger_ratio
(~2.0, WMA-30 basis); trail_pct (0.25) }` in `Weinstein_strategy.config`;
weekly-close semantics (L3); can only TIGHTEN the effective stop (L2 —
never lowers); default-off + axis per experiment-flag-discipline; W2
authority = Weinstein's trader exit-aggressiveness dial / swing-sell on
extended advances (cite book section in the .mli). Acceptance = the
sanctioned-insurance path (#1695 catastrophic-stop precedent): left-tail /
dispersion / event-level audit (re-run
`analysis/scripts/extension_screen`-style counterfactual + armed-vs-off
record runs), NEVER fold Sharpe (screen proved WF-CV powerless here —
~1% event rate). Screen evidence pins the values: 25% trail survives the
AXTI April shakeout AND January chop, fires 2026-05-29 @ $103 (banks ~$67M
vs $46M mark); 10-20% trails are on-ramp killers (do NOT build tight).

**P1 — trader-preset BUNDLE audit + WF-CV** (was S3; per
weinstein-faithful-core W3; plan
`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`; AXTI as the
qualitative specimen).

**P2 — P1b step 3: sleeve lens screen vs TR-SPY** (was S5; consumes
`Breaker_spy_sleeve` from #1913; floor-quality Next-Steps 1). PRIORITY
REINFORCED by the melt-up-lag anatomy
(`dev/notes/melt-up-lag-anatomy-2026-07-11.md`): the sleeve's carry years
are exactly the lag years (2019/2023/2024) and the lag is structural
(mega-cap non-participation + annual whipsaw premium), not fixable
screener-side.

**P2b (NEW) — decision_audit Phase-2: forward-return counterfactual of
cash-REJECTED vs funded** (was an open follow-up in
[[project_decision_audit_faithful]]): the melt-up anatomy found NVDA passed
the screen at score 70-75/A fresh and was cash-skipped SIX times
(2003/2010/2012/2021) + MSFT 2023 — the "selection FAITHFUL" verdict
measured captured-feature predictability among candidates, not the forward
returns of the cash-rejected pile. Screen-rigor applies; the question is
whether capacity-at-signal (capture-monster #2) has measurable expected
cost and whether funding order (score-tie + alphabetical) leaves EV on the
table.

**P3 — grind-weeks exposure** (was S6, carried).

**P4 — faithful per-week universes (M6.6 design)** (was S7): largest
identified capture loss (static PIT can't see later IPOs — deep run
literally cannot trade GME). Design + cost first; likely its own plan doc.

## Overnight 07-12 session additions (deployment-readiness program)

Shipped: #1934 extension-stop insurance (merged), #1937 post-run validation
harness v1 (in gates), fresh 2026-07-10 weekly picks + first sanity pass,
deployment-readiness doc, trade-audit artifact + agenda, visual audit + two
gate screens (both NO-BUILD — see
`dev/notes/visual-trade-audit-2026-07-12.md`; V-bounce losses ≡ monster
winners, same ticket).

**NEW QUEUE ITEMS (correctness fixes, ordered):**

**C1 — rename-twin dedup + record re-pin (W13).** ~11.9% of the record
run's realized PnL is clone legs (10 groups). Twin-dedup in the snapshot/
universe builders (>95%-identical adjusted_close over ≥100 overlapping
days), rebuild warehouse, re-run + re-pin the honest-tradeable record.
Until then: haircut headline ~12%.

**C2 — trades.csv export-join fix.** Key `exit_trigger` AND
`stop_trigger_kind` by position_id (41 blank-trigger rows, 27
contradictory). Validator V5 pins it.

**C3 — universe asset-type fix (W14).** CEF/trust/SPAC leak (~55 clear,
FTHY was a top-7 live pick); fundamentals `General::Type` enrichment or
blocklist at universe build. Validator-adjacent; live-relevant.

**C4 — resistance-mapper window/label fix (W12-surviving).** 520-bar spec
vs 52-110-bar panels → false Virgin_territory (COO backtest, CWST live).
Fix label or extend windows (incl. live weekly-review warehouse start).
NOT a gate. Validator V7 pins it.

**C5 — arm declining-MA gate for broad** (record convention + live config;
own WF-CV support; catches the AIR subclass).

**C6 — validator follow-ups**: run v1 over the record run (expect V5/V6/V7
hits, V1-V4 clean), scenario_runner --validate post-step, weekly-picks
validation reuse.

**CLOSED tonight (do not reopen):** overhead-resistance entry gate;
base-quality/recent-S4 entry gate (both screened net-negative at every
threshold — `project_entry_shape_gates_no_build`).

## Standing constraints

NO reversal timing; entry-selection/scale-in/reallocation/envelope/
stop-tuning closed; Weinstein spine fixed. Comparators TOTAL-RETURN.
LAW: horizon-sweep or rolling-start before believing tail-dependent
verdicts. Container: long runs solo; WIP-push within 30 min of any
dispatch; process checks must match strings a watcher's own argv cannot
contain. Post-#1926 note: default-config backtests now HAVE the entry gate
+ stale-exit — un-armed comparisons against pre-flip numbers must arm/disarm
explicitly.
