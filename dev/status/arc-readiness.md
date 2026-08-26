# Status: arc-readiness

## Last updated: 2026-08-26

## Status
IN_PROGRESS

## Interface stable
NO

G2a/G2b add two new config fields. (A3-3, the config `.mli` docstring
compression, has since shipped — #2477.)

---

## What this track is

The user's framing, 2026-08-20:

> *"we are not yet trying to get this arc to beat record. We are trying to get
> the necessary features in place together first"*

and the three axes to be ready on:

1. **All arc features built and working properly** — trading performance may not
   be impressive yet; we keep iterating within the arc.
2. **All necessary validation and testing tools** — not only trade performance
   but **execution correctness** (it does what we thought) and **book
   faithfulness**.
3. **Simplified / compressed codebase + docs** to minimise confusion and
   distraction.

**This reframes every measurement.** At a 132.5pp (26y) / 278pp (ladder-v4)
noise floor most single mechanisms cannot clear anything — the broad-5y cell
showed one arm's own salt-to-salt spread (9.24pp) exceeding the arm-to-arm gap
(−6.22pp). So "does X clear its null" is the wrong question right now. "Is X
built, correct, composable, faithful" is the right one.

Design rationale: `dev/plans/arc-readiness-2026-08-20.md` (#2447).

---

## Axis 1 — arc features built and working — COMPLETE

### 2026-08-20 — the book-faithful entry bundle is assembled (PR #2452)

`staging-arc-2026-08/top3000-2000-2026-arc-faithful.sexp`. Most of it already
existed: `staging-record-convention/...-fullbook-graded.sexp` carried the whole
**entry-ticket** half (`sim_entry_trigger_at_suggested` so the trigger RESTS at
E rather than the current close, `enable_sim_entry_stoplimit` +
`entry_extension_max_pct 2.0`, `stop_anchor_at_entry_base`). The bundle adds the
**screening** half: `entry_anchor_local_range_weeks 4`,
`entry_freshness_basis Range_top_breakout`, `volume_confirm_at_fill true`.

The **2pp band is the book's number**, not a tuned one — §"Buying Within
Limits" specifies a buy-stop at the breakout with a limit ¼ point above it,
= 2.06% on Weinstein's own 12⅛ example. He rejects both neighbours: no limit
gives *"the proud owner of XYZ at 15"*; limit == trigger gives *"one out of
four, the stock will break out without your ever buying it"* — the fat-tail-miss
objection, anticipated and priced by the author at 1-in-4.

**Live picks regenerated at as-of 2026-08-14** (control reproduces the committed
`f88c277d5` report **bit-identical**, validating universe / bars / as-of /
invocation together): **17 of 20 unchanged**; out PAY, TPC, INVX; in DRI, BLK,
NDAQ. Tickets now carry the 2pp band (`trigger $86.68 limit $88.41`) vs the old
15pp. Extended/watch-only rows 4 → 1.

**26y runs complete** (pre-correction −40.1%, corrected four-override bundle −62.4%; #2459). The anatomy — §4.2 fill-week gate ejecting 72% of entries — is the record; see `dev/notes/arc26y-corrected-writeup-2026-08-21.md`.

⚠ **Defect found during assembly:** `Range_top_breakout` was armed **without
`entry_anchor_local_range_weeks`**, the knob defining the `local_range_top` its
freshness test measures against. Live picks went to **zero candidates**; adding
`4` restored 20. `staging-record-convention/*` and the live picks config set
that knob **zero times**, so any bundle built on that base inherits the `0`
default. **A backtest smoke did not catch it** — armed without the anchor a
1-year cell gave 93 trades vs 35 for the control, a large plausible-looking
delta. That proved the field was *read*, not *correctly configured*.
**Liveness is not correctness.** (`project_rt_needs_its_anchor_knob`.)

---

Seven mechanisms, all built and tested (1–4 test files each). **Six of seven
verified running together** — `ladder-v4-async-ticket-2026-08-10` cell `v4-16`
arms `Range_top_breakout` + rescreen + rest-4wk + `Drop_over_max` + volconf
simultaneously (checked as armed *values*, not field mentions).

The hole is the **funding leg**, whose plan
(`dev/plans/ticket-funding-2026-08-16.md`) has four steps:

| step | state |
|---|---|
| G1 — land `ticket_age_weeks_at_cancel` + `cancel_reason` (#2348) | ✅ done (3 impl, 5 test files) |
| step 2 — measure the cohort from artifacts | ✅ done — 3,530 rejections, median shortfall 52%, 63% in bursts |
| step 3 — build each axis behind its own flag | ✅ **3 of 3** (G3, G2a, G2b) |
| step 4 — one grid over all three + null | ✅ done — #2473 `aa70c876`, program CLOSED |

### Sub-tasks

- [x] **A1-1 — Build G2a `entry_fill_reject_retries`** (retry). **MERGED
      #2463 `d7c3d295` 2026-08-21**, branch `feat/arc-g2a-fill-retries`. Default-off `int`, default `0`
      (`experiment-flag-discipline.md` R1/R2/R3 — no ledger verdict exists, so
      it ships off). New `Trading_simulation.Entry_fill_retry` holds the run's
      budget + per-ticket ledger; on a refused entry fill it leaves the
      `Entering` position alone and re-submits a copy of the refused order so
      the engine re-offers it next tick, up to N times, instead of the ticket
      being destroyed. Threaded through `Simulator.create_deps` from
      `panel_runner`. At `0` `handle_rejected_entries` returns its input list
      itself — no ledger write, no order-manager call — so the cancel path is
      bit-identical and no golden moved. Axis reachability through the real
      `Overlay_validator.apply_overrides` is pinned for `(0 1 2)` in
      `test_runner_hypothesis_overrides.ml`. Also pays back the file-length
      budget it consumed: `Simulator._compute_benchmark_return` moved to the
      existing `Simulator_metrics` (simulator.ml 500 → 493, its declared-large
      cap is 500).
- [x] **A1-2 — Build G2b `entry_fill_size_to_available`** (resize). **MERGED
      #2468 `094b91b0` 2026-08-21**, branch `feat/funding-g2b`. Two default-off fields: `entry_fill_size_to_available`
      (`bool`, `false`) and its guard `entry_fill_min_size_fraction` (`float`,
      `0.5`, inert while the flag is off) — `experiment-flag-discipline.md`
      R1/R2/R3, no ledger verdict exists so it ships off. New
      `Trading_simulation.Entry_fill_resize` clamps a portfolio-refused entry
      fill to the largest whole-share quantity the cash floor accepts (paper-loss
      drag included) and books it **at the price the ticket triggered at**, so
      unlike G2a it pays no timing tax. Clamps below `min_size_fraction` of the
      designed quantity fall through to the unchanged destroy path. Threaded
      through `Simulator.create_deps` from `panel_runner` as one
      `?entry_fill_resize` value rather than two more optional scalars.
      **Precedence:** the resize runs *before* `Entry_fill_retry`, so retry
      budget is only spent on refusals the resize declined — pinned by a test
      that runs the real chain both ways (`(0, 1)` retries used). Also carries
      the #2466 guard: the `Entering` match requires the *entry* side, so a
      rejected exit is never claimed, and a claimed entry is removed from the
      list `Cancel_handler.revert_rejected_exits` scans (that scan matches on
      symbol alone, so an `Exiting` sibling on the same symbol would otherwise be
      reverted). Axis reachability for both fields pinned through the real
      `Overlay_validator.apply_overrides`. Pays back its own file-length budget:
      `Simulator._apply_transitions` moved to the existing `Cancel_handler`
      (simulator.ml 493 → 487, declared-large cap 500).
- [x] **A1-3 — Arm G3 `reserve_cash_for_resting_tickets`** (#2469). First
      arming anywhere: `inspect-6mo-g3`. Liveness confirmed (0 cash
      rejections); isolated cost vs the `bookstop` control: trades 39 → 11,
      max concurrency 5 → 2 (the control sits at the nominal 0.70/0.14 = 5
      ceiling and G3 more than halves it).
- [x] **A1-4 — The funding grid ran and the program is CLOSED** (#2473;
      `dev/notes/funding-grid-writeup-2026-08-22.md`;
      `project_funding_grid_monster_lottery`). Five arms × 26y on the
      record-convention base. Verdicts: **saved tickets are net-profitable in
      every arm** (+$47k…+$490k on the pure 522-key cohort — the AXTI-class
      premise holds) but **top-line gaps are monster-lottery reshuffling**
      inside the 132.5pp floor (CLS-2023 +$658k null-only vs SKYW-2023 +$428k
      arm-only; one monster ≈ 66pp ≈ the whole spread). **G3 = REJECT as a
      global default, terminal** (53 trades in 26y — reservation exhausts the
      pool; flag stays as the R1 no-op). **G2a/G2b = keep default-off as
      axes**, no promotion case at this power. Transferable why: funding
      handling is tail-preserving in intent, tail-reshuffling in effect —
      future funding levers must protect *monster* entries specifically, not
      ticket counts.

- [x] **A1-3 — Fill-model default flip: sim entries now match live.**
      Branch `feat/fill-model-default`. `enable_sim_entry_stoplimit`
      `false -> true` and `entry_extension_max_pct` `0.0 -> 2.0`, flipped as a
      **pair** because the runner arms the StopLimit path iff
      `enable_sim_entry_stoplimit && entry_extension_max_pct > 0.0`
      (`trading/trading/backtest/lib/panel_runner.ml` `_entry_cap_for_sim`;
      mirrored in `execution_faithfulness.ml`
      `entry_order_kind_of_config`) — a lone flag flip would be a
      half-mechanism. `2.0` is the #2404-unified live value (user decision
      2026-08-25, PR #2554), so the code default and
      `dev/weekly-picks/live-config-overrides.sexp` now agree.
      **R3 basis: user-directed FIDELITY decision recorded on #2405
      (2026-08-26)**, same class as the #2530 stops-basis flip. The
      `2026-08-04` entry ledger REJECTED this flip *on returns*; that verdict
      is overridden openly, not quietly — its surface compared sim-vs-sim,
      which is the wrong estimand for "does the simulator model the orders we
      actually place". **No return-improvement claim is made anywhere.**
      Golden bands move because the basis moved. Verify:
      `dune runtest trading/backtest/test/` (`test_execution_faithfulness.ml`
      "kind: default config arms the StopLimit path" runs the DEFAULT config
      through the arming predicate and asserts a `Stop_limit_band 0.02` comes
      out — per the #2567 silent-null lesson, reading the two fields is not
      enough) and `dune runtest trading/backtest/golden_drift/` (stale
      `deviates_from_live` declarations removed from 12 goldens).

**Why G3 matters beyond bookkeeping:** an unfundable triggered ticket is
silently **destroyed** — not retried, not resized. `Entry_walk`'s per-tick
`remaining_cash` is re-seeded from `portfolio.cash` every tick, so a ticket
resting from week N is invisible in week N+1 and its money is committed twice.

---

## Axis 2 — validation and testing tools

Three capabilities. Two are strong; one had no tooling at all.

### (a) Trade performance — strong tooling, low power

`variant_matrix`, `variant_ranking` (Pareto), `deflated_sharpe`, `fold_health`,
`rolling_start` + convexity/dispersion stats; 15 artifacts per scenario run.

- [x] **A2-1 — Automate effect-vs-null reporting.** Shipped
      `Walk_forward.Effect_null_report`
      (`trading/trading/backtest/walk_forward/lib/effect_null_report.{ml,mli}`)
      + the `effect_null_report.exe` CLI
      (`trading/trading/backtest/walk_forward/bin/effect_null_report.ml`), 18
      tests in `test/test_effect_null_report.ml`. Reads the standard per-arm
      `actual.sexp` artifacts, pairs arm against null **by position** (salt
      *i* with salt *i*), and emits the Rule-4 table — per metric: the mean
      paired gap, every per-pair gap (so a sign flip is visible), that
      metric's own null band (the null set's salt-to-salt `max−min`), the
      ratio, and a verdict. PASS requires same sign on every salt **and**
      every |gap| above the band; anything else is INSIDE-NOISE. Metrics
      passed to `--no-direction` are reported but never judged. A single pair,
      or a null whose salts are identical, yields NO-BAND rather than a
      verdict — an unmeasured noise floor is not a floor of zero. **Guardrail:
      run contexts (`params.sexp` beside each result, or a scenario spec via
      `--arm-params`/`--null-params`) are compared on `universe_size` and the
      date window; any difference is a non-zero exit citing
      `universe-discipline.md`, and no context at all is a loud WARNING, not a
      silent pass.** Verify:
      `dune exec trading/backtest/walk_forward/bin/effect_null_report.exe -- --arm <a.sexp,...> --null <n.sexp,...>`;
      re-run against `dev/experiments/rt-freshness-broad5y-2026-08-20/results/`
      (3 salts, rangetop vs core) and it reproduces the recorded finding —
      `max_drawdown_pct` PASS at ratio 11.8, every other metric INSIDE-NOISE.

### (b) Execution correctness — ✅ covered, no action

`decision_audit` (counterfactual / screen_record / weekly_adapter),
`trade_audit` + recorder + basis + report + ratings + `trade_score`,
`entry_audit_capture` / `exit_audit_capture` / `audit_recorder`,
`screener_cascade_diagnostics`, HTML report.

### (c) Book faithfulness — was absent; partly addressed

No automated check exists anywhere in `trading/devtools/` or `.github/`;
"faithful" appears only in `.mli` prose. Enforcement is qc-behavioral's manual
S1–S6 / L1–L4 / C1–C3 checklist. **This cannot be linted** — faithfulness is a
judgment, not a predicate over source.

- [x] **A2-2 — Make the book a first-class resource** (#2447). Shipped
      `.claude/rules/book-as-authority.md`: the local path, the OCR caveat
      (extraction has spacing artifacts, so exact long-phrase greps fail and a
      failed grep is *not* evidence of absence), and a three-tier protocol —
      reference → book when the reference is silent/ambiguous/contested →
      **write the answer back**, so the reference becomes a cache of resolved
      questions. Cited from `weinstein-faithful-core.md` W2 and
      `qc-behavioral-authority.md`.
- [x] **A2-3 — Fill-model A/B: DECIDED 2026-08-20 as option B.**
      `project_fill_model_inversion` posed it as an explicit either/or — **(A)**
      align live to the record rule (market entry + deep floor: +8,367%, MaxDD
      37%, **one trade = 76% of it**) or **(B)** re-base records to the book
      ticket (~+280%, MaxDD 23%). The user's directive *"we will get faithful
      right first and then later chase down the performance gap"* **is** option
      B. Executed as the arc bundle below.

      **The deferred gap, stated plainly:** book ticket **+287%** vs record
      **+8,367%** vs **SPY-TR +687%** over the same 26y. The faithful arm
      currently runs *below buy-and-hold*. That is what "chase the gap later"
      means concretely.

- [ ] **A2-4 — Make the picks chart answer "how was entry picked?"**
      (`dev/plans/picks-chart-informative-2026-08-20.md`, PR #2453). The chart
      draws the **ticket** level (`entry`) while the level that governs
      **admission** (`breakout_price`) is invisible, and there is no date axis.
      Phase A (dates) needs no schema change; Phase B needs `schema_version`
      1 → 2 to emit `breakout_price` / `local_range_top` / Stage-2 start.
      Execution-correctness work, not a return lever.

---

## Axis 3 — compression

Measured surfaces: `dev/notes/` 368 files / **53,200 lines**; `dev/plans/` 139
files / 28,718 lines; `weinstein_strategy_config.mli` **1,787 lines for 81
fields** (1,554 of them docstring, ~19/field, +337 lines in 11 days).

**Rule 4 is net-zero:** 0 promotions, 0 net retirements, +7 inert mechanisms in
11 days.

### Why it never happens — the load-bearing finding

**Every prune list built by hand on 2026-08-20 shrank by half or more once each
row was verified:**

| list | headline | after verification |
|---|---:|---:|
| Rule-4 retirement "confirm" flags | 5 | **0** (5→2→0 across two passes) |
| orphaned experiment dirs | 145 files | **53** |
| superseded priorities docs | 106 | **84** |

The headline always overstates; **the per-row verification is the work**, and
nobody budgets it. That is why the flag inventory sat unworked from 08-09.

### Sub-tasks

- [x] **A3-0 — Correct the flag inventory** (#2450). `enable_late_stage2_stop_tighten`
      reclassified RETIRE → **KEEP-AXIS**; the eligible count is **zero**. Its
      memory says *"Dial stays default-off / available as an axis; no further
      investment"* — REJECT-as-legitimate-axis, which Rule 4 says does not
      retire. **Caught by the tool below reading the record and reporting it as
      the one `ELIGIBLE` row** — making the claim operational is what exposed
      an assertion that had sat unchallenged for 11 days.
- [x] **A3-1 — Land `prune_candidates.sh` + weekly GHA** — **MERGED #2449
      `48c6315e` 2026-08-21** (marker corrected 2026-08-23; the entry still
      read "in flight").
      Automates the *verification*, not the deletion: proposes, never deletes.
      Three checkers, each encoding a trap that cost a real error —
      `[[:space:]]` not `\s`; sanity probes that hard-abort rather than report
      an empty list as clean; a 30-day quarantine (a "cited by nothing" test
      also catches *this week's* work, so it measures citation **age**, not
      deadness); and a path name is not its content.
- [x] **A3-2 — Delete the uncited priorities docs** — **MERGED #2476
      `cd116d80` 2026-08-22**. Was blocked on A3-1 so the list would be
      tool-verified; A3-1 landed 08-21 and this followed the next day.
      `session-rampup.md` already says only the newest is load-bearing;
      git history keeps the rest.
- [x] **A3-3 — Compress `weinstein_strategy_config.mli` docstrings** —
      **MERGED #2477 `3871a143` 2026-08-23**, 1,911 → 1,362 lines. Mechanism
      *histories* moved out (they live in the ledger and experiment records),
      contract left in place. **Not** a Rule-4 retirement — the flags stayed,
      only the prose moved.

---

## Next task

*Reconciled 2026-08-23. The previous version of this section named A3-2, A3-3
and the #2433 framing decision as open; all three had landed, two of them the
same day the section was written (#2474 merged ahead of #2476/#2477/#2433).
A same-day ordering artifact, not neglect — but the file misdescribed its own
track, so the claims are re-stated against verified merge state below.*

**Axis 1 is feature-complete** — all seven arc mechanisms plus the funding
trio built, exercised, and verdicted; the funding program is closed (#2473).
The `entry_fill_min_size_fraction` sweep the plan named is folded into the
grid's outcome: with the whole G2b axis kept default-off on a no-promotion
verdict, sweeping its guard has no decision to feed and is not queued.

**Axis 3 is complete as scoped.** A3-0 (#2450), A3-1 (#2449 `48c6315e`),
A3-2 (#2476 `cd116d80`) and A3-3 (#2477 `3871a143`) have all merged.

Remaining open work:

1. **A2-4 — make the picks chart answer "how was entry picked?"** The *plan*
   merged (#2453, 2026-08-21); the implementation has not. Phase A (date axis)
   needs no schema change; Phase B needs `schema_version` 1 → 2. This is the
   only unchecked sub-task left on the whole track.
2. USER DECISIONS carried: `Volume.config` overlay plumbing for the
   `strong_threshold` era axis. (**The #2433 framing decision is no longer
   carried** — see `## Follow-ups`. The global `initial_stop_buffer` flip
   shipped in #2530; the fill-model default flip shipped as A1-3 above.)
3. **Post-A1-3 golden re-pin (dispatcher-owned, sequenced AFTER the PR is up).**
   The fill-model flip moves every golden not already arming the pair. Only the
   pins PR CI itself runs are re-pinned in the A1-3 PR (tier-1 smoke +
   `dune runtest`-pinned cells); the postsubmit sp500 / historical /
   custom-universe goldens are re-pinned from the dispatcher's paired sweep,
   after which `paired-run-done` is applied. `goldens-affected` SHOULD flag the
   A1-3 PR — that is the rule working, not a defect.
4. A2-1 follow-up (not blocking): the funding-grid results dir commits no
   `params.sexp` beside its `actual.sexp` files, so `effect_null_report.exe`
   can only WARN there rather than verify. Committing a per-arm `params.sexp`
   alongside future results would make the guardrail bite by default.

## Follow-ups

- **`goldens_affected_check.sh` is blind to a default *flip*.** On the A1-3 PR
  it named exactly one golden — `sp500-2019-2023-armed-stoplimit.sexp`, the one
  cell that already arms both knobs at the new default values and therefore
  does **not** move. The ~15 cells that do move are precisely the ones that
  never named the knobs and silently inherited the old defaults, which the
  check's exact-name match on `config_overrides` cannot see. Not a defect in
  the #2384 case it was built for (there the affected golden armed a *related*
  knob, and the docstring cross-reference caught it), but a default-flip
  inverts the population: "arms the knob" and "is affected by the knob" become
  disjoint. Worth teaching the check that a changed `[@sexp.default]` affects
  every Weinstein golden that does NOT arm the knob.
- **Does a non-Weinstein benchmark sleeve belong under the Weinstein entry
  cap?** Surfaced by the A1-3 fill-model flip: `Panel_runner._entry_cap_for_sim`
  reads the run's *Weinstein* config and threads the cap into
  `Simulator.create_deps` regardless of `strategy_choice` — as it already does
  for `margin_config`, `stale_hold_policy` and `sim_entry_fill_next_open`. So
  the BAH-SPY / BAH-BRK-B benchmark cells moved (−0.42% / −0.79%) on a flip
  that is conceptually about Weinstein entry tickets, and their `dune runtest`
  pins were re-anchored in that PR. Consistent with existing wiring, so **not**
  fixed there; but a benchmark used as a comparison baseline moving on a
  strategy-side default is worth a deliberate decision (gate
  `_entry_cap_for_sim` on `Strategy_choice.Weinstein`, or keep the current
  strategy-agnostic threading and say so). Note the golden-drift linter already
  treats these cells as having no Weinstein config to compare (it skips
  non-Weinstein scenarios), which is mild evidence for gating.
- **#2433 framing — RESOLVED. MERGED `d7087e0a` 2026-08-22, reframed.** This
  entry previously read "⚠ USER DECISION — held under `do-not-merge`"; the hold
  was lifted and the PR landed with its framing corrected. As merged: the
  sp500 "reversal" is **retracted as a universe artifact** (#2448 `35aa1397`),
  and **only MaxDD survives both cells**. The win-rate leg fails Rule 4 on
  broad-5y and must not be quoted as a Rule-4 survivor. `Range_top_breakout`
  is **not promotable** on this evidence.
  See also `.claude/rules/universe-discipline.md`, which the episode produced.
- Two non-blocking observations on #2449 recorded rather than fixed: checker 3's
  two sanity probes mutually mask, and the `newest`-by-git-log-vs-filename bound
  is not discriminated because the fixture's filename order coincides with its
  commit order.
