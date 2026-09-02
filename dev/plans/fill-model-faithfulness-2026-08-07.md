# Plan — fill-model faithfulness: fixes + validation + evaluation

Companion to `dev/notes/fill-model-fix-findings-2026-08-07.md`. Executes the
two fill-model fixes AND the two standing asks (2026-08-07 user directive):
(1) validation invariants that ensure captured orders/trades/screening signals
are faithful, extending the existing framework; (2) a robust
faithfulness/sensibility evaluation for backtests, not just performance.

Governing rules: `experiment-flag-discipline` (default-off → axis → ACCEPT),
`weinstein-faithful-core` (spine vs dials), `promotion-confirmation` (grid),
`mechanism-validation-rigor`. All strategy changes land **default-off** and
change no backtest result until a spec flips them.

## Existing framework (reuse, don't reinvent)

Post-run validator: `trading/backtest/validation/lib/` (`Post_run_validator`).
- 11 checks V1–V11, each `Invariant` (hard bug) or `Expectation` (soft), driven
  from `trades.csv` + `trade_audit.sexp` + the per-symbol bar store.
- Thresholds all route through `Validator_types.config` (no magic numbers).
- CLI: `trading/backtest/validation/bin/post_run_validator_cli.ml`
  (`-run-dir -data-dir -config -out`, report-only, writes `.sexp` + `.md`).
- Current invariants already cover the Weinstein spine: V1 Stage2-only,
  V2 no-Bearish-macro, V3 ADV floor, V8 no-Declining-MA, etc.

The gap: **no check pins the fill/stop-order geometry** — exactly the surface
the fill-model inversion lives in. We add V12–V14.

## Workstream A — Validation invariants (ask #1)

Extend `Post_run_validator` with three checks. Each: a `check_vN` in
`validator_row_checks.ml` (or `validator_bar_checks.ml` if it needs bars), a
threshold field in `Validator_types.config`, an id in `all_check_ids`, a
docstring, and tests in `validation/test`.

- **V12 (INV) — stop-distance faithfulness.** For every entry,
  `|suggested_entry − installed_stop| / suggested_entry ≤
  config.max_stop_distance_pct`. Rationale: `entry_audit_capture.ml:136`
  rejects wider stops as `Stop_too_wide`, so a surviving trade wider than the
  cap is an invariant break. **This is the check that auto-resolves the gate
  confound** (findings §4 OPEN): run it on the record arm — if V12 fails, the
  gate is not firing (or the audit's `installed_stop` disagrees with the gated
  stop), and we have a mechanical, reproducible signal instead of a hand
  puzzle. Threshold reads the run's own `max_stop_distance_pct`.

- **V13 (EXP) — entry-chase / extension faithfulness.** For every LONG entry,
  the effective fill is not materially above the breakout it claims to trade:
  `effective_entry ≤ breakout_price × (1 + config.entry_extension_tol_pct)`.
  Detects the book arm's E-chase (findings §4 Q3): a March fill at 79.81 on a
  January breakout trips it. `breakout_price` is available on the audit's
  entry-decision context; if not currently persisted, add it to
  `Trade_audit.entry_decision` (small, additive). EXP not INV because a modest
  buffered extension is legitimate; the tolerance separates "buffer" from
  "chase."

- **V14 (EXP) — fill-timing basis telemetry.** Flag entries whose fill price
  equals the signal-bar (Friday) close to within an epsilon — i.e. same-bar
  fills (findings §4 Q1). Not a bug per se, but it quantifies how much of a
  run's fills use the optimistic same-bar basis vs next-bar open. Becomes a
  PASS once Fix #1 (next-open) is the basis.

Deliverable: `post_run_validator_cli` reports V1–V14; V12 run on the committed
record arm gives the gate-confound verdict in the findings doc.

## Workstream B — Faithfulness evaluation harness (ask #2)

The validator checks one run against invariants. Tonight's analysis was a
different thing: a **two-arm divergence / sensibility profile** — the report
that made the inversion legible. Systematize it as a repeatable tool so every
backtest is evaluated for *how it trades*, not just *what it returns*.

New tool `trading/backtest/faithfulness_report/` (bin + lib + test), inputs two
run dirs (or one run for the single-arm profile), emits `.md` + `.sexp`:

1. **Per-year trade-by-trade divergence** — matched by symbol, tagged
   BOTH / A-only / B-only, ranked by |Δpnl|. (Tonight's `yeardiff` awk, made a
   typed OCaml tool.)
2. **Whipsaw-rate profile** — per-year % of entries stopped in ≤N days
   (config N). The 40-60% vs 0-16% signature.
3. **Hold-time distribution** — mean / p50 / p90 / count held ≥ M days
   (the runner tail).
4. **Stop-width distribution** — % of entries with stop distance > 15%,
   mean, max. (The deep-floor signature.)
5. **Fill-vs-breakout divergence** — effective fill vs `breakout_price`
   distribution (the chase signature).

These are the five "sensibility" lenses; each is a distribution, not a point
estimate (per `mechanism-validation-rigor` check 2). The tool is read-only over
committed artifacts — no re-run needed to profile an existing arm.

## Workstream C — Fix #1: next-bar-open fill (default-off)

**Corrected seam (2026-08-07 trace).** This is *not* a `bar_reader` grab in
`effective_entry_price` — that runs at Friday decision time and cannot see
Monday's open without lookahead. The record entry is a **Market** order
(`order_generator.ml:49-52,77`; `None` = "historical Market fill model"); its
fill price is set by the **engine's order-matching layer** when it matches the
Market order against a bar to produce the `trade` whose `price` `fill_router`
applies (`fill_router.ml:69`). Record's `entry_price` = the Friday close is
carried on the position for sizing/stop, but the *fill* resolves in the engine.

So Fix #1 = a **default-off** `config.sim_entry_fill_next_open : bool` that,
when on, makes a Market **entry** order fill at the **next bar's open** instead
of the signal-bar close. The change spans: config field → thread through
`order_generator` / the engine order-matching path → the bar the Market entry
matches against. The exit path and all other orders are untouched. This is the
"#2158 Phase 2" fill-model contract the `order_generator` docstring already
anticipates. **Cross-cutting engine change — dispatch feat-weinstein with QC;
do not rush inline.**

- R1: default-off ⇒ bit-identical (same `List.last` close path). Verify with a
  golden diff.
- R2: real config field ⇒ `Variant_matrix` axis `((flag sim_entry_fill_next_open)
  (values (true false)))`.
- Faithful (`weinstein-faithful-core`): the spine (Stage-2 breakout entry) is
  untouched; only the *fill assumption* changes — a realism dial, not a
  mechanism. W1 pass.
- Tests: a synthetic case where next-open ≠ signal-close proves the branch;
  off-path bit-identity test.

### Fix #1b — exits (default-off `sim_exit_fill_next_open`)

Fix #1 as shipped covers Market **entries** only and deliberately exempts exits.
Measurement on the 26y arc run (`dev/experiments/arc-rerun-2026-09-01/README.md`
§D1) showed the exit side carries the same defect, and at far higher volume:
**2192/2192 `volume_eject`, 154/154 `laggard_rotation` and 148/668 `stop_loss`
exits were Saturday-dated at Friday's open**; the record convention shows the
same shape (269/269 laggard exits). The mechanism is identical — the simulator
steps one *calendar* day (`simulator.ml`), `Market_state.update` retains the
previous session's bars when a step supplies none (`market_state.ml`), so a
Market exit submitted at the Friday tick matches the stale Friday bar on the
Saturday step and is re-stamped Saturday by `Fill_date_stamp.restamp`. A
Friday-close decision executing at a price from *before* the decision is a
look-back fill, and the trade lands on a day the market was not open.

**The seam is the gate, not the engine.** `Next_open_fill_gate.make` already
receives `~positions` and `~today_bars` and returns the `?can_fill` predicate
`Engine.process_orders` consults, so Fix #1b needed no engine change: the gate
now takes `~defer_entries` / `~defer_exits` and matches an exit the way it
matches an entry — a **Market** order whose (symbol, side) routes to an
`Exiting` position, using `Fill_router.exit_trade_side` so a scale-in add
`Entering` on the same symbol is not confused with the original `Exiting` one.
Full exits and partial trims are treated alike (both rest one Market order while
`Exiting`). Non-Market orders stay exempt by construction and by intent:
`Order_generator._exit_order_for_position` emits exits only as Market today, and
a `StopLimit` carries its own trigger price, so a retained stale bar cannot fill
it at a look-back price the way an unconditional Market order can.

- R1: **both** flags off ⇒ no `?can_fill` is supplied at all ⇒ bit-identical;
  `defer_entries:true, defer_exits:false` reproduces shipped Fix #1 exactly.
- R2: real config field ⇒ axis `((flag sim_exit_fill_next_open) (values (true
  false)))`, threaded config → `panel_runner` → `Simulator.deps` alongside
  `sim_entry_fill_next_open`.
- Faithful: spine untouched; only the fill assumption moves. W1 pass.
- Tests: `trading/trading/simulation/test/test_sim_exit_next_open.ml` — OFF pins
  the stale-Friday-open fill, ON pins the Monday-open fill, the exit flag alone
  leaves entries bit-identical, and a two-round-trip multi-week scenario (two
  weekends + a mid-week hole) asserts that with both flags on **no trade is
  dated on a day the symbol had no bar**.

## Workstream D — Fix #2: no-chase entry E (default-off)

The chase is `suggested_entry = breakout_price × (1+buffer)` recomputed weekly
(`screener.ml:126-138`, `breakout_price` from `stock_analysis`). Add
`config.freeze_entry_at_first_breakout : bool [@sexp.default false]` (name TBD).
When `true`, once a symbol first qualifies, its entry E is pinned to that
first-qualifying breakout level until the order fills or the setup expires — the
book's actual rule ("buy *the* breakout," not "buy every successive higher
high"). Rather than re-plumb screener state, the cleanest seam is likely the
entry layer (`entry_walk` / `entry_audit_capture`): carry a per-symbol
first-seen-E in `stop_states`-adjacent state, or reuse `entry_anchor_local_range_weeks`
semantics with a "freeze on first qualify" variant.

- R1: default-off ⇒ bit-identical.
- R2: config field ⇒ axis.
- Faithful: **this INCREASES faithfulness** — it stops the unfaithful chase.
  W2 cites book "buy the breakout, don't chase extended stock."
- **Higher risk than Fix #1** (touches entry selection/state). If a clean
  seam isn't reachable without cross-module state, land the *detection* (V13)
  first and ship Fix #2 as a scoped follow-up rather than force it. Detection
  before mechanism is the disciplined order anyway.
- Tests: a trending-symbol scenario where the frozen-E order fills at the
  original breakout, not the later extension.

## Status (2026-08-07 overnight) + reframed sequencing

**Shipped this session:**
- A — **V12 invariant** (installed stop ≤ gate) — PR #2229. (V13 chase-detection
  moved to the harness; V14 fill-timing deferred.)
- B — **faithfulness harness** — PR #2230, validated end-to-end reproducing the
  manual numbers.
- Docs — findings + plan — PR #2227.

**Reframe (the confound gates the fixes).** The trace showed the deep
support-floor stop is a *separate axis* entangled in the record-vs-book
comparison: three arms (control/cap15/trigonly) carry 94%-wide stops with an
unlifted 15% gate; only `stop_anchor_at_entry_base` caps them. So the +8,367 vs
+287 gap is **not fill-timing alone** — the stop treatment differs too. Two
candidates (findings §4 CONFOUND): (a) committed configs don't reproduce the
runs, or (b) support-floor bypasses the gate. **Distinguished only by the
`trade_audit.sexp` regen.**

**Next-session sequence (critical path = the confound, not more flags):**
1. **Regen** `trade_audit.sexp` for the record arm (pinned worktree, warehouse
   present, output to `/tmp/sweeps`, per the inventory recipe); run V12 on it →
   decide (a) vs (b). Deferred tonight for disk safety (~30GB; sweep-hygiene
   bars unattended multi-hour runs).
2. If (a): fix the committed `record-convention` scenarios + the re-run recipe
   so they reproduce the record. If (b): fix the support-floor gate path.
3. C (next-open fill) + D (no-chase E) — `feat-weinstein`, QC, **serially**
   (disk; no concurrent agents per sweep-hygiene / worktree-isolation).
4. Honest re-run of the ladder **with the stop gate held fixed across both
   arms** (so it isolates the fill-model effect) under WF-CV + the confirmation
   grid, then the A/B decision. Promotion gated regardless.

## Status update (2026-08-07 PM) — step 1 DONE, confound RESOLVED

Regen executed (pinned worktree `28b187d7a`, v5thin_adj warehouse):
**bit-identical reproduction** (+8,366.8%, 1122 trades) → (a) dead. V12:
29/1122 modest (15–20%) violations, gate firing in-arm → (b) dead. True cause
= **metric artifact**: `trades.csv.stop_initial_distance_pct` is E-basis
(`trade_context.ml:171`), not fill-basis; record stops are ~97.4%
gate-compliant vs cost. Full evidence: findings doc §4 "RESOLVED". Artifacts:
`dev/…/.sweep-output/confound-regen-artifacts/` (local),
`confound-regen-v12.{md,sexp}`.

**Consequences for the sequence:** step 2 is void (nothing to fix — recipe
sound, gate sound). Step 4's "hold the stop gate fixed" is automatic (same
gate both arms); the A/B isolates to **fill basis** (market-at-close vs
resting-at-chased-E). Remaining:
- Fix #1 (next-open fill) — also cleans up the 29 drift cases V12 caught.
- Fix #2 (no-chase E) — now MORE central: it directly narrows the arms' gap.
- Follow-up (small): fill-basis stop-distance column in trades.csv (or fix
  col-16 docstring); V11 thresholds re-read on fill basis.
- Then the honest ladder re-run + A/B under WF-CV + grid, unchanged.

## Out of scope / do NOT

- Do **not** touch the deep structural stops (findings §4 Q2) — the edge.
- Do **not** flip any default or re-base the record numbers tonight — every
  change is default-off; re-basing needs the honest re-run + grid.
- Do **not** run the multi-hour ladder or any >1h sweep tonight (disk).
- Do **not** modify `dev/status/_index.md` from feature PRs (per
  `feat-agent-dispatch` §4).
