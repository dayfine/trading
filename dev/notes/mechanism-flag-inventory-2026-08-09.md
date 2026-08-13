# Mechanism-flag inventory — 2026-08-09

The retirement worklist for `experiment-flag-discipline.md` Rule 4
(mechanism retirement). Enumerates every mechanism flag/knob in
`Weinstein_strategy_config` (`trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli`),
the stops config (`trading/trading/weinstein/stops/lib/stop_types.mli`),
the screener config (`trading/analysis/weinstein/screener/lib/screener.mli`),
and the stage config (`trading/analysis/weinstein/stage/lib/stage.mli`),
against its ledger verdict and a keep/retire call.

Scope notes:

- **Plumbing fields are excluded** (universe, indices, sub-config wiring,
  lookbacks, `skip_*` test shims) — they are not mechanisms.
- **Calls are proposals.** RETIRE rows seeded by the 08-09 priorities doc
  (`dev/notes/next-session-priorities-2026-08-09.md` §P1) are
  ready-for-removal; RETIRE rows *not* in that seed list carry a
  "confirm" note and need a human nod (or a do-not-revive
  classification recorded) before a removal PR — per Rule 4, a REJECT
  without the classification is not retirement-eligible.
- Removal PRs route through **full gates**, one mechanism per commit,
  goldens bit-identical = proof. This file is docs; the removals are
  step 3 (separate dispatches).
- Ledger pointers are files under `dev/experiments/_ledger/`; memory
  pointers are files under `dev/agent-memory/`.

Call legend: **RETIRE** (terminal REJECT, remove flag+code+tests) /
**KEEP-AXIS** (legitimate default-off experiment axis) /
**KEEP-PROMOTED** (earned its default via ledger ACCEPT) /
**DEFER** (decision blocked on an in-flight program) /
**UNKNOWN** (no verdict found — needs human/ledger check).

## Correction log

**2026-08-12 — `trigger_on_weekly_close` reclassified RETIRE -> KEEP.** Caught
while attempting the removal: the flag is armed by live production code
(`Stop_thread`, the weekly picks report), which the ledger REJECT did not
cover because that verdict was about the *simulator lever*, not the field.

The general lesson for the rest of this worklist: a ledger REJECT retires a
**mechanism**, not necessarily a **field**. Before removing any row, grep for
code that *assigns* the flag — not just scenario specs that override it:

```sh
git grep -n '<flag> *=' -- 'trading/**/*.ml' | grep -v /test/ | grep -v 'sexp.default'
```

Anything beyond the `default_config` assignment is a live consumer. Goldens
will not catch this class: they exercise the backtest path only, so a flag armed
by the snapshot generator or any other non-backtest surface stays bit-identical
in every golden while being load-bearing in production.

Audited on 2026-08-12 against the three already-removed rows
(`enable_harvest_rotate` / `harvest_fraction`, `early_admission_ma_period`,
`cash_reserve_pct`): each had only its `default_config` assignment, so those
removals are clean.

**2026-08-13 — `enable_continuation_buys` + `continuation_config` reclassified
RETIRE -> KEEP-AXIS.** Caught during the Rule-4 eligibility screen for the
removal. Full evidence:
`dev/plans/continuation-retirement-2026-08-13.md`. Four findings:

1. **The row was never seeded.** The 08-09 priorities doc §P1 graveyard list
   names *"scale-in v2 continuation-add"* — the **scale-in** mechanism, retired
   by #2299. This inventory turned that one seed item into two RETIRE rows. By
   this file's own scope note, an unseeded RETIRE row is a "confirm first" row.
2. **One cited verdict belongs to a different mechanism.**
   `2026-07-05-continuation-add-v2-surface` armed `enable_scale_in` +
   `Scale_in_detector.Consolidation_breakout` (#1855) — code #2299 deleted. It
   never armed `enable_continuation_buys`. #2299 already spent that verdict.
3. **No do-not-revive anywhere; an uncancelled revival path instead.**
   `project_continuation_combined_rejected` says *"if the mechanism is to come
   back, it needs a different design (eg gated by macro regime …)"*, and
   `dev/experiments/continuation-combined-2026-05-14/report.md` makes
   retirement the **fallback if the regime-gated test fails** — that test was
   never run. This is the deciding asymmetry vs #2299, whose one named revival
   path *was* recorded as cancelled (`project_envelope_knobs_dead`, #1861).
4. **It is a Weinstein-documented dial with an open plan.** Entry mode
   (base vs continuation) is a dial per `.claude/rules/weinstein-faithful-core.md`,
   which states the #1366 rejection tested a one-at-a-time graft rather than
   the mechanism; `dev/plans/weinstein-trader-investor-presets-2026-05-31.md`
   names this flag as the Trader preset's entry-mode config home.

The single on-point REJECT (`2026-05-14-continuation-combined-axis`) is two
single-run windows on one universe — no folds, no DSR, no deep macro-regime
cell — and its own comment concedes the config hash is approximate.

**General lesson (extends the 08-12 one):** a ledger REJECT retires the
mechanism *it actually armed*. Before removing a row, confirm each cited entry
armed **this** field — and check whether the entry has already been spent on a
different row.

## RETIRE — graveyard (seeded by the 08-09 priorities doc)

| field | config module | default | ledger verdict (pointer) | call | notes |
|---|---|---|---|---|---|
| `early_admission_ma_period` | `Stage.config` | `None` | REJECT — `2026-05-31-early-admission-deep-27y` (27y grid reversed all post-2009 cells); `project_early_admission_mechanism` "do not revive" | RETIRE | The canonical do-not-revive case. Supersedes the earlier surface-v2 Accept. |
| `stage3_exit_margin_pct` | `Weinstein_strategy_config` | `0.0` | REJECT — `2026-05-29-stage3-hysteresis-wf-cv`, `2026-05-31-exit-timing-hysteresis-revalidated` (9 Rejects); `project_stage3_hysteresis_rejected_wfcv` | RETIRE | The stage3 hysteresis knob (#1362). |
| `enable_harvest_rotate` | `Weinstein_strategy_config` | `false` | REJECT — `2026-06-11-harvest-rotate-top3000`; `project_harvest_rotate_rejected` (coin-flip per decision) | RETIRE | Winner-trimming taxes the fat tail (`project_edge_is_the_fat_tail`). |
| `harvest_fraction` | `Weinstein_strategy_config` | `0.5` | same as `enable_harvest_rotate` | RETIRE | Remove in the same commit as its enable flag. |
| `enable_scale_in` + `scale_in_config` | `Weinstein_strategy_config` | `false` / `Scale_in_detector.default_config` | REJECT — `2026-07-03-scale-in-v1-surface` + `2026-07-05-continuation-add-v2-surface`; `project_capital_mgmt_scale_in_design` (v1+v2 CLOSED) | RETIRE | "Breadth IS the edge" — sizing mechanics closed. |
| `enable_macro_bearish_exposure_trim` | `Weinstein_strategy_config` | `false` | REJECT-leaning — `project_macro_bearish_trim_lever` (regime-dependent); seeded graveyard 08-09 | RETIRE | Memory had earlier kept it as a default-off axis; the 08-09 priorities doc reclassifies it graveyard. Cite that supersession in the removal PR. |
| `macro_bearish_max_long_exposure_pct` | `Weinstein_strategy_config` | `0.70` | same as `enable_macro_bearish_exposure_trim` | RETIRE | Companion knob; same commit. |
| `trigger_on_weekly_close` | `Weinstein_stops.config` (`stop_types.mli`) | `false` | REJECT as a backtest lever — `2026-05-31-exit-timing-deep-2000-2026` (9 Rejects); `project_weekly_close_stop_lever` | **KEEP — NOT RETIRABLE** | **Corrected 2026-08-12.** The flag has a LIVE production consumer the ledger verdict does not cover: `Stop_thread._weekly_close_config` (`trading/trading/weinstein/snapshot/gen/lib/stop_thread.ml:34`) sets it to `true` on purpose, because that path replays **weekly** bars where the default intra-bar trigger would fire on an intra-week wick — and the book's rule is a weekly CLOSE. Reached from the weekly picks report via `held_position_row.ml`. The REJECT was about *arming it in the simulator*, not about deleting the field. Removing it would silently break the weekly report, and **no golden would catch it** — the goldens do not exercise the snapshot generator. |
| `vol_scaled_stop_atr_mult` | `Weinstein_stops.config` | `0.0` | NO-BUILD/REJECT — `project_p0_levers_no_build_2026_06_20` (vol-stop fails); seeded graveyard 08-09 | RETIRE | Vol-scaled stop. |
| `vol_scaled_stop_atr_period` | `Weinstein_stops.config` | `14` | same as `vol_scaled_stop_atr_mult` | RETIRE | Companion knob; same commit (also delete `vol_scaled_stop.ml/.mli`). |
| `cash_reserve_pct` | `Weinstein_strategy_config` | `0.0` | REJECT — `2026-07-06-cash-reserve-surface`; `project_cash_reserve_rejected` (envelope closed) | RETIRE | Protection lever superseded by barbell. |

## RETIRE — candidates NOT in the 08-09 seed list (confirm before removal)

| field | config module | default | ledger verdict (pointer) | call | notes |
|---|---|---|---|---|---|
| `enable_late_stage2_stop_tighten` + `late_stage2_stop_buffer_pct` | `Weinstein_strategy_config` | `false` / `0.0` | REJECT — `2026-06-06-late-stage2-stop-tighten-grid`; `project_stage_late_flag_discarded` (tighten dial #1446 REJECTED, flag discarded) | RETIRE (confirm) | Memory reads as do-not-revive but the 08-09 seed list omits it — confirm. |
| `enable_stage2_ma_hold` | `Stage.config` | `false` | REJECT — `2026-06-09-stage2-ma-hold-top3000` | RETIRE (confirm) | No do-not-revive marking found; classify per Rule 4 before removing. |
| `dawn_leverage_enabled` + `dawn_initial_long_margin_req` + `dawn_max_ma_flip_age_weeks` | `Weinstein_strategy_config` | `false` / `1.0` / `default_dawn_max_flip_age_weeks` | REJECT — `2026-07-26-leverage-dawn-surface` + `2026-07-27-leverage-dawn-clean-rerun`; `project_leverage_dawn_reject` (fat tail unscalable even conditionally) | RETIRE (confirm) | Terminal-reading rejects, recent (07-27). |
| `initial_long_margin_req` + `long_margin_rate_annual_pct` + `maintenance_long_pct` | `Weinstein_strategy_config` | `1.0` / `0.0` / `0.0` | REJECT — `2026-07-24-margin-m4-leverage-surface` + `2026-07-22-leverf-age-band-surface`; `project_margin_m4_leverage_reject` (leverage Sharpe monotone down) | RETIRE (confirm) | Long-side leverage family only. `margin_config` (short-side margin) is live plumbing and stays. Dawn fields depend on these — remove the whole long-leverage family together or not at all. |
| `catastrophic_stop_pct` | `Weinstein_stops.config` | `0.0` | REJECT — `2026-07-09-catstop-deep-wfcv` | RETIRE (confirm) | No do-not-revive marking found; classify first (also `catastrophic_stop.ml/.mli`). |

## KEEP-PROMOTED — earned defaults (ledger ACCEPT / promotion PR)

| field | config module | default | ledger verdict (pointer) | call | notes |
|---|---|---|---|---|---|
| `enable_short_side` | `Weinstein_strategy_config` | `true` | baseline behaviour; short-timing edge confirmed by `2026-06-23-ad-default-flip-confirmation-grid` (Accept) | KEEP-PROMOTED | Spine-adjacent (book's short side). |
| `neutral_blocks_shorts` | `Weinstein_strategy_config` | `true` | ACCEPT — `2026-06-22-neutral-blocks-shorts-wfcv` + `2026-06-23-ad-default-flip-confirmation-grid`; `project_ad_default_flip` (grid 3/3) | KEEP-PROMOTED | Screener mirror field defaults `false` (strategy field is authoritative at runtime). |
| `suppress_warmup_trading` | `Weinstein_strategy_config` | `true` | ACCEPT — `2026-07-08-warmup-364-basis-change`; `project_warmup_trading_running_start` | KEEP-PROMOTED | Measurement-basis field, not an alpha mechanism. |
| `stale_exit_after_days` | `Weinstein_strategy_config` | `Some 5` | ACCEPT — `2026-07-10-realism-defaults-flip` (#1926); `project_realism_defaults_flip_merged` | KEEP-PROMOTED | |
| `liquidity_config` | `Weinstein_strategy_config` | `Liquidity_config.default_config` | ACCEPT — `2026-07-10-liquidity-overlay-wfcv` REJECT was for the *overlay variant*; $1M gate default-on via `2026-07-10-realism-defaults-flip`; `project_liquidity_realism_overlay` | KEEP-PROMOTED | Realism, not alpha. |
| `extension_stop_config` | `Weinstein_strategy_config` | `Extension_stop.default_config` (armed 2.0x/25%) | ACCEPT — `2026-07-14-extension-stop-insurance-accept` (#1960); `project_extension_stop_acceptance` | KEEP-PROMOTED | |
| `support_floor_basis` (Wick) + `split_safe_floors` | `Weinstein_stops.config` | `Wick` / `false` | promotion #2167 + split-safe basis program; `project_split_safe_resistance_basis` (grid complete, default-Wick) | KEEP-PROMOTED | Split-safe migration is a measurement-basis correction; `split_safe_floors` default in the .mli is the deserialization fallback — record configs set it. |
| `resistance_min_history_bars` + `resistance_lookback_bars` + `overhead_supply` + `virgin_crossing_readmission` | `Weinstein_strategy_config` | `0` / `0` / `None` / `false` (deserialization fallbacks) | ACCEPT — resistance-v2 bundle #2047 (`2026-07-17-resistance-supply-confirmation-grid` Accept); `project_resistance_v2_progress` (w30+vc+floors-0+arming default-ON) | KEEP-PROMOTED | `2026-07-19-virgin-crossing-flag-surface` REJECT was the standalone-flag arm; the flag promoted as part of the bundle. .mli defaults are compat fallbacks, promoted values live in the default config literal / record spec. |
| `w_overhead_supply` + `w_virgin_support` | `Screener_scoring` (scoring weights) | `None` | part of the resistance-v2 bundle above | KEEP-PROMOTED | |

## KEEP-AXIS — legitimate default-off axes / active programs

| field | config module | default | ledger verdict (pointer) | call | notes |
|---|---|---|---|---|---|
| `early_stage2_max_weeks` | `Screener.config` | `4` | value ≤4 pinned — `2026-07-06-early-stage2-window-surface` (alternatives Reject); `project_early_stage2_window_validated` | KEEP-AXIS | Seeded keep. Basis (not value) revisited by async-v2 F1. |
| `enable_continuation_buys` + `continuation_config` | `Weinstein_strategy_config` | `false` / `Continuation.default_config` | REJECT as default — `2026-05-14-continuation-combined-axis` (two single-run windows, pre-WF-CV); `project_continuation_combined_rejected` names an **uncancelled** regime-gated revival | **KEEP-AXIS — reclassified 2026-08-13**, see Correction log | Was a RETIRE row; the seed was a transcription of the *scale-in* v2 continuation-add item (retired by #2299), and `2026-07-05-continuation-add-v2-surface` armed `enable_scale_in`, not this flag. Weinstein-documented entry-mode dial ("The Trader's Way", Ch. 3) and the Trader preset's config home in `weinstein-trader-investor-presets-2026-05-31.md`. Retirement-eligible once EITHER the trader-preset program is *recorded* as closed, OR the regime-gated surface runs and REJECTs. Evidence: `dev/plans/continuation-retirement-2026-08-13.md`. |
| `reject_declining_ma_long_entry` | `Weinstein_strategy_config` | `false` | REJECT as default — `2026-06-28-declining-ma-gate-grid`; but `project_declining_ma_gate_breadth_preset` (broad-only ARM-FOR-BROAD preset knob) | KEEP-AXIS | Seeded keep — the model case of REJECT-as-default-but-legitimate-axis. |
| `enable_slow_grind_short_gate` | `Weinstein_strategy_config` (+ screener mirror) | `false` | REJECT — `2026-06-22-slow-grind-adlive-wfcv`; but `project_decline_character_builds`: deep re-screens blocked on pre-2009 data, not rejected | KEEP-AXIS | Decline-character trio, seeded keep. |
| `fast_v_arm_on_rate_alone` | `Weinstein_strategy_config` | `false` | Mixed — `2026-06-22-arming-speed-wfcv` Accept, `2026-06-24-arming-speed-adlive-wfcv` Reject; `project_decline_character_builds` | KEEP-AXIS | Decline-character trio. |
| `fast_v_min_rate_pct` + `fast_v_ignores_ma_filter` | `Weinstein_strategy_config` / `Decline_character.config` | `0.08` / `false` | REJECT — `2026-06-22-fast-v-min-rate-surface`; `project_decline_character_builds` | KEEP-AXIS | Decline-character trio. |
| `enable_laggard_rotation` + `laggard_rotation_config` + `laggard_reentry_cooldown_weeks` | `Weinstein_strategy_config` | `false` / defaults / `0` | disable retracted — `2026-05-29-laggard-disable-retracted` (Reject of the disable); `2026-06-25-laggard-cadence-surface` Inconclusive; `project_laggard_broad_recheck` (keep ON, helps all breadths) | KEEP-AXIS | Active profit channel in the record config (`project_trade_forensics_2026_06_12`). Do NOT retire. |
| `enable_stage3_force_exit` + `stage3_force_exit_config` | `Weinstein_strategy_config` | `false` / defaults | turning it OFF rejected on the grid — `2026-06-09-stage3-force-exit-off-confirmation-grid` (Reject), top3000 cell Inconclusive | KEEP-AXIS | Live exit machinery; .mli default is the compat fallback. |
| `neutral_blocks_longs` | `Weinstein_strategy_config` (+ screener mirror) | `false` | tested alongside the A-D flip program | KEEP-AXIS | |
| `stop_update_cadence` | `Weinstein_strategy_config` | `Daily` | Weekly value rejected via exit-timing surfaces (`2026-05-31-exit-timing-deep-2000-2026`) | KEEP-AXIS | The cadence knob itself is infrastructure; only the Weekly *value* lost. |
| `candidate_ranking` | `Screener.config` | `Alphabetical` | ranked modes REJECT — `2026-06-29-candidate-ranking-tiebreak-grid`, `2026-06-30-tiebreak-noise-floor`; `project_screener_alphabetical_tiebreak` | KEEP-AXIS | Ranked mode stays a default-off axis per memory. |
| `w_early_stage2` | `Screener_scoring` | `None` | REJECT — `2026-06-10-cascade-w-early-stage2-reweight-top3000` (the cascade-reweight save) | KEEP-AXIS | Scoring-weight axis; cascade inversion context (`project_cascade_selection_inversion`). |
| `enable_sim_entry_stoplimit` + `sim_entry_trigger_at_suggested` + `sim_entry_fill_next_open` + `freeze_entry_at_first_breakout` + `entry_anchor_local_range_weeks` | `Weinstein_strategy_config` | all no-op | `2026-08-04-sim-entry-stoplimit-surface` Rejects stand (`project_sim_entry_stoplimit_reject`), but the flags ARE the active P0 entry-ticket program (`dev/plans/entry-ticket-async-v2-2026-08-10.md`, user decision `project_entry_trigger_decision`) | KEEP-AXIS | Do not touch — P0 in flight; sibling feat agents editing this config surface. |
| `entry_through_band_pct` + `entry_extension_max_pct` | `Weinstein_strategy_config` | `0.0` / `0.0` | active entry program; the 15% extension gate is the ladder-v3 structural-exclusion finding (`project_faithful_ticket_structural_exclusion`) | KEEP-AXIS | Under active study; not retirement candidates. |
| `enable_pi_filter` | `Weinstein_strategy_config` | `false` | no ledger entry; PIT universe-membership filter (universe plan P5, `project_tier4_goldens_pit_migration`, `project_pit_survivorship_inflation`) | KEEP-AXIS | Data-correctness infra, not an alpha mechanism. |
| `short_min_price` + `short_borrow_min_dollar_adv` + `min_price` | `Weinstein_strategy_config` / `Screener.config` | `0.0` | realism family (`project_short_realism_p0`, `2026-07-10-realism-defaults-flip`) | KEEP-AXIS | Realism knobs. |
| `sparse_tail_min_bars` + `sparse_tail_window_trading_days` + `spike_bar_threshold_pct` | `Weinstein_strategy_config` | `0` / `0` / `0.0` | data-hygiene family (corrupt/sparse-bar filtering) | KEEP-AXIS | Not alpha mechanisms. |
| `rename_detect_min_overlap_days` + `rename_detect_match_fraction` | `Weinstein_strategy_config` | `0` / `0.0` | twin-dedup v2 #1946 (`project_rename_twin_dedup_returns_basis`) | KEEP-AXIS | Data-hygiene; active in dedup warehouses. |
| `min_score_override` + `max_score_override` + `volume_ratio_exclude_range` | `Screener.config` | `None` | diagnostic/ablation axes (cascade studies) | KEEP-AXIS | Screener ablation knobs. |
| `short_sleeve_fraction` | `Weinstein_strategy_config` | `0.0` | screens only, no WF-CV ledger entry — `project_p0_levers_no_build_2026_06_20` (short sleeve fails), `project_p1a_deep_short_screens` (hedge-shaped) | DEFER | No terminal ledger REJECT exists; either run the surface or record a do-not-revive classification before retiring. |
| `stop_anchor_at_entry_base` | `Weinstein_strategy_config` | `false` | ladder-v3 history references it; retirement note in the async-v2 plan | DEFER | Seeded DEFER — joins the graveyard only after ladder v4. |

## RESOLVED 2026-08-10 (was UNKNOWN — classified by consumer-grep + user decision)

All four were listed UNKNOWN because no ledger verdict exists for any of them.
That turned out to be the wrong lens: **none is a retirement question** (Rule 4
needs a terminal REJECT, and there is none), they are mechanisms that were
built, wired, defaulted to no-op, and then **never evaluated** — zero scenario-
spec references between three of them. That is an `experiment-flag-discipline`
**R2 gap** ("an axis the day it lands"), not an R4 one.

Consumer counts that drove the calls (non-test `.ml` refs | tests | scenario specs):

| field | refs | tests | specs | call | reasoning |
|---|---|---|---|---|---|
| `max_long_exposure_pct_entry` | 10 | 6 | **7** | **KEEP — in active use** | Referenced by 7 live scenario specs, so not a graveyard candidate at all. `project_envelope_knobs_dead`'s "grep consumers first" warning was right and the answer came back yes. No longer open. |
| `stage3_reentry_cooldown_weeks` | 3 | **0** | 0 | **RETIRE** (with the stage3 family) | One consumer (`special_exits.ml:64`, `~cooldown_weeks`), **no `.mli` docstring at all** (the field at line 99 is undocumented; the neighbouring docstring belongs to `stage3_exit_margin_pct` below it), no tests, no specs. Its sibling `stage3_exit_margin_pct` is already on the RETIRE list as part of the rejected stage3-hysteresis family (`project_stage3_hysteresis_rejected_wfcv`). Reads as a leftover of that rejection. Retire alongside it. |
| `cascade_post_stop_cooldown_weeks` | 5 | 4 | 0 | **KEEP-AXIS — sweep once, expect it to lose** | Benches a symbol for N weeks after a stop-out; motivated by a real documented pathology (cascade re-firing within days of stop-out, `dev/notes/sp500-trade-quality-findings-2026-04-30.md`). Strong prior AGAINST from `project_edge_is_the_fat_tail`: it is a re-entry suppressor, and the AXTI-class monsters are exactly names that whipsaw before they run. Cheap as one axis; a **recorded** loss is worth more than a silent flag. |
| `failed_breakout_tolerance_pct` | 21 | 24 | 0 | **RESOLVE AGAINST F2 FIRST** | Drops a long candidate whose close fell back below `breakout_price *. (1. -. k)` and demotes it to the watchlist. This **overlaps F2 `entry_order_ttl_weeks`' primary re-screen cancel** (#2263, merged 2026-08-10): under the async ticket model, price falling back below the breakout while the ticket rests *is* the failed breakout. Either this is now largely redundant, or it is the sharper-specified version of F2's cancel condition. Sweeping both without resolving the overlap would test two spellings of one mechanism and read the interaction as signal. Decide the overlap before either is swept. |

**Common shape worth noting:** all three non-KEEP entries are re-entry /
whipsaw suppressors. They are close to one question, not three, and
`project_edge_is_the_fat_tail` already carries a strong prior on that family.

## Tallies

- RETIRE (seeded, ready for step-3 removal PRs): **11 rows** (~12 fields)
  — was 12/~14; `enable_continuation_buys`+`continuation_config` moved to
  KEEP-AXIS on 2026-08-13 (see Correction log).
- RETIRE (confirm-first): **5 rows** (~10 fields)
- KEEP-PROMOTED: **9 rows**
- KEEP-AXIS: **21 rows** (20 + `enable_continuation_buys`+`continuation_config`,
  reclassified 08-13)
- DEFER: **2 rows** (`short_sleeve_fraction`, `stop_anchor_at_entry_base`)
- UNKNOWN: **0 rows** — all four resolved 2026-08-10, see the RESOLVED section
  above. Net effect: +1 RETIRE (`stage3_reentry_cooldown_weeks`, folded into the
  stage3 family), +1 KEEP-AXIS, +1 KEEP (`max_long_exposure_pct_entry`, in
  active use), +1 pending-overlap-decision (`failed_breakout_tolerance_pct`).

## Step-3 sequencing suggestion

1. Start with the four cleanest seeded removals (no cross-field
   dependencies): `enable_harvest_rotate`+`harvest_fraction`,
   `cash_reserve_pct`, `stage3_exit_margin_pct`,
   `early_admission_ma_period`.
2. Then the stop levers (`trigger_on_weekly_close`, vol-scaled pair +
   module, then `catastrophic_stop_pct` if confirmed).
3. Then the entry-side pair `scale_in` (done, #2299) and the
   `macro_bearish` pair. **`continuation` is no longer in this sequence** —
   reclassified KEEP-AXIS 2026-08-13 (see Correction log); it re-enters only
   if the trader-preset program is recorded as closed or a regime-gated
   surface REJECTs.
4. Long-leverage family (`dawn_*` + long-margin fields) last, as one
   coordinated family removal — only after human confirmation.
5. Serialize all of these AFTER the in-flight async-v2 PR-1/PR-2
   config edits land (the config .mli is contended).
