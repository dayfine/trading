# Status: support-floor-stops

## Last updated: 2026-08-08

## Status
IN_PROGRESS

## Interface stable
YES

## Open PR
- `fix/split-safe-empty-population-pin` — the 2026-08-08 fix-forward on F6's
  qc-behavioral finding: the empty-population `Not_exercised` state was the one
  of three that pinned neither `"NOT EXERCISED"` nor `%`-absence. Test-only.
  See the "Correction 2026-08-08" block under the F6 addendum below.

## Recently merged
- `feat/split-safe-inert-report-row` — F6, the trade-audit report row for the
  split-safe basis tally + inert fraction (2026-08-07 addendum below). **PR
  #2234 was closed, not merged**: its entire content reached `main` via an
  unrelated auto-merged `ops(budget)` PR (#2235) built from a shared working
  tree, verified by identical file hashes on all four files. The code is live
  on `main`; the qc-behavioral rework it never received is the fix-forward
  above.
- `feat/split-safe-empty-window-panel` — **MERGED #2232 `b54f8880`** (2026-08-07),
  B5 + B6, the last two telemetry gaps (2026-08-07 addendum below).
- `feat/split-safe-fallback-telemetry` — **MERGED #2220 `480a59b7`** (2026-08-06),
  F5 whole-window fallback telemetry
  (2026-08-06 addendum below). Branch pushed; PR opened by the orchestrator.
- Previously merged on this track:
  - split-safe floors on the panel/callback path — #2213 (2026-08-05)
  - PR A (primitive, long + short) — #382 (2026-04-17)
  - PR B (wrapper + strategy wiring, long side) — #390 (2026-04-17)
  - anchor-mode dial — `feat/floor-anchor-close` (2026-07-29)
  - split-safe floors, bar-list path + `floor_is_structural` — #2181 (2026-08-02)

## Completed

- `dev/plans/support-floor-stops-2026-04-16.md` — plan committed (first-deliverable plan-first trigger)
- `Support_floor.find_recent_level` primitive (long + short) — implemented in `trading/trading/weinstein/stops/lib/support_floor.{ml,mli}` with 23 unit tests covering long/short happy paths, depth thresholds, tie-breaking, lookback truncation, and degenerate inputs (empty, single bar, flat prices, zero lookback). Short-side symmetrically returns the prior counter-rally high (resistance ceiling) — lands with no caller yet; future short-side strategy will consume it.
- `Weinstein_stops.compute_initial_stop_with_floor` wrapper — implemented in `weinstein_stops.{ml,mli}`; threads `~side` through to the primitive. 6 wrapper tests covering None-path parity with the fixed-buffer proxy (long + short) and Some-path using the identified level (long + short).
- `stop_types.config` extended with `support_floor_lookback_bars : int` (default 90)
- Wired `compute_initial_stop_with_floor` into `Weinstein_strategy._make_entry_transition` (one call-site swap) via `Bar_history.daily_bars_for` helper — long side only. Short-side wiring deferred (see `dev/status/short-side-strategy.md`).
- Backtest regression pins updated on 2018-2023 cached data: 6YR round-trips 1W/6L → 4W/3L; COVID 0W/4L → 1W/3L; POS adds one sell — confirms the support-floor path fires on real entries (smoke check)
- `dune build && dune runtest` green, `dune build @fmt` clean

## 2026-07-29 addendum — anchor-mode dial (task #13, PR `feat/floor-anchor-close`)

- Added `Support_floor.anchor_mode = Wick | Close` and threaded it as
  `?anchor_mode` on `find_recent_level_with_callbacks` (default `Wick` =
  bit-identical historical behaviour). `Close` measures the correction low /
  rally high (and the anchoring peak / trough) on the bar **close** instead of
  the intraday `low_price` / `high_price`, so a lone capitulation wick no longer
  anchors the structural floor to the wick extreme. Long/short mirrored (short:
  highest close vs highest high).
- Wired as a real `Weinstein_stops.config` field `support_floor_anchor_mode`
  (`[@sexp.default Wick]`) → embedded in `Weinstein_strategy.config.stops_config`
  → resolves through `Overlay_validator` as the `Variant_matrix` axis
  `((stops_config ((support_floor_anchor_mode Close))))`. R1 (default-off, exact
  no-op) + R2 (searchable axis) satisfied; R3 promotion needs a ledger ACCEPT.
- Motivation: CLMB 2026-04-30 wick $14.64 (~4% below neighbouring closes) forced
  a 42.5% stop distance → tiny position (`dev/notes/weekly-picks-2026-07-26.md`,
  priorities-2026-07-29 P1). Faithful-core: numeric-threshold-class initial-stop
  dial; spine item 5 (stop below the base) intact under either reading.
- Tests: default=Wick bit-identity, Close-mode long (wick) + short (spike)
  fixtures, config sexp round-trip + omitted-field-defaults-to-Wick,
  variant-matrix axis expansion. Bar-list `find_recent_level` intentionally left
  Wick-only (all-labelled signature; the dial lives on the callbacks path that
  the production stop + panel callers use) — avoids an unerasable-optional
  warning and churning ~20 existing call sites.

### Decision item — split-safe floors (A2 boundary; NOT executed here)

The priorities doc also wants `support_floor` split-safe (anchor on raw,
split-unadjusted lows) via `Adjusted_basis`. `Adjusted_basis` lives in
`trading/analysis/weinstein/snapshot_pipeline/`, but `support_floor` is in
`trading/trading/weinstein/stops/`. A direct import violates architecture rule
A2 (analysis → `trading/trading/` only allowed under `backtest/**`). Proposed
resolutions for human/review decision (per CLAUDE.md "propose as a decision
item"):
  1. Feed basis-corrected lows from the **caller** layer (the snapshot / entry
     pipeline already crosses into `analysis/`), keeping `support_floor` a pure
     price-list consumer — least architectural churn.
  2. Move the split-basis helper to a **canonical shared lib** both subtrees may
     depend on (e.g. `trading/base/` or a new shared module).
Not executed in this PR; needs a scope/architecture call.

## Ownership
`feat-weinstein` agent — see `.claude/agents/feat-weinstein.md`. Dispatched per the 2026-04-16 direction change in `dev/decisions.md` to unblock feat-backtest's support-floor stops experiment (see `dev/status/backtest-infra.md` §Blocked on).

## Goal

Replace the fixed-buffer proxy (`entry_price *. (1.0 /. buffer)`) with a real support-floor value derived from price history. Weinstein Ch. 6 §5.1: "Place below the significant support floor (prior correction low) BEFORE the breakout." Short-side mirror: place ABOVE the prior counter-rally high (resistance ceiling).

## Scope

Split into two stacked PRs:

**PR A — primitive (long + short)** in `trading/trading/weinstein/stops/lib/`:
- `Support_floor.find_recent_level` — pure function with a `~side` parameter. For long it returns the prior correction low; for short the prior counter-rally high. Depth threshold shared with `min_correction_pct`; lookback configurable. Returns `None` when no qualifying counter-move exists — caller falls back to fixed buffer.

**PR B — wrapper + strategy wiring** (stacked on A):
- `Weinstein_stops.compute_initial_stop_with_floor` — threads `~side` through; behaviour under `None` identical to pre-primitive direct call.
- `Bar_history.daily_bars_for` helper.
- `Weinstein_strategy._make_entry_transition` wiring — long side only (short-side strategy is a separate track).
- Backtest parity regression tests updated.

State machine itself (Initial → Trailing → Tightened) unchanged.

## Not in scope

- The fixed-buffer vs support-floor experiment — feat-backtest follow-on.
- Short-side strategy wiring — short-side strategy is a separate track (`dev/status/short-side-strategy.md`). The primitive lands here with both sides so the wrapper doesn't need a second API churn when the short-side strategy begins.
- Round-number shading of the stop value — §Follow-ups below.
- Regime-aware buffers — separate exploration in `dev/status/backtest-infra.md`.

## References

- `docs/design/weinstein-book-reference.md` §5.1 Initial Stop Placement, §5.2 Trailing Stop
- `docs/design/eng-design-3-portfolio-stops.md` §Stop state machine
- `dev/status/backtest-infra.md` §Blocked on — downstream experiment
- `dev/status/portfolio-stops.md` — prior base-strategy stops work (merged, interface stable)
- `dev/status/short-side-strategy.md` — consumes the short-side primitive

## 2026-08-02 addendum — split-safe floors + stop_recompute anchor-mode fix (PR `feat/split-safe-floors`)

Closes BOTH open follow-up items below (the #2167 QC finding + the A2
split-safe decision item).

- **Split-safe floors** (`split_safe_floors : bool [@sexp.default false]` on
  `Weinstein_stops.config`). When on, the bar-list floor path rescales each
  raw-OHLC bar onto its split/dividend-adjusted basis (per-bar factor
  `adjusted_close /. close_price`, one-sided corrupt-close guard → factor 1.0)
  **before** the correction low / rally high is measured, so a split inside the
  lookback window no longer mis-scales the floor against the current entry price
  (the live FBRX `split_in_window` warning, weekly-picks record 2026-07-31).
  Default-off = raw bars, exact bit-identity → zero golden changes (R1). Real
  `stops_config` bool field → resolves through `Overlay_validator` as the axis
  `((stops_config ((split_safe_floors true))))` (R2). Promotion needs a ledger
  ACCEPT (R3).
  - **User A2 decision (2026-08-02):** callers feed basis-corrected lows;
    `Support_floor` stays a pure price-list consumer — NO cross-boundary
    `Adjusted_basis` import, NO helper relocation. Implemented as a single
    chokepoint inside `Weinstein_stops.compute_initial_stop_with_floor` (the
    A2-forbidden `stops/` layer), which all bar-list callers (`stop_recompute`,
    `stop_thread`, `spy_only_weinstein_strategy`, `sector_rotation_stops`)
    funnel through. The per-bar rescale is inlined (few lines, mirrors
    `Adjusted_basis.to_adjusted_basis` + its guard) because A2 forbids importing
    analysis/ here; the factor is derivable from `Daily_price.adjusted_close`,
    already on every bar.
  - **Caller NOT converted:** the panel/callback path
    (`compute_initial_stop_with_floor_with_callbacks`, the main multi-symbol
    strategy hot path via `entry_audit_helpers`). Its `daily_view` exposes raw
    highs/lows + adjusted closes but **no raw close**, so the per-bar factor
    cannot be recovered without extending the view type — out of scope. The flag
    is documented as governing only the bar-list path. The live weekly-picks
    path (the FBRX motivator) IS the bar-list path, so it is covered.
- **stop_recompute anchor-mode fix (#2167 QC follow-up).** New single-source
  `Weinstein_stops.floor_is_structural` builds the callbacks through the SAME
  internal `_floor_callbacks` that `compute_initial_stop_with_floor` uses
  (honouring both `support_floor_anchor_mode` and `split_safe_floors`), so the
  `stop_is_structural` display flag and the installed level can never disagree.
  `stop_recompute.ml` now calls it instead of the Wick-only bar-list
  `find_recent_level`. Pinned by a test that returns `false` under `Close` mode
  where the old Wick-only classifier returned `true`.
- Tests (`test_support_floor.ml`): split fixture (4:1 mid-window split) long
  (raw 104 phantom vs adjusted 98) + short (raw non-structural vs adjusted 102)
  mirrored; default-off raw bit-identity; corrupt-close guard; `floor_is_structural`
  Close-mode-agrees-with-level + split-safe threading; config default-false /
  sexp round-trip / omitted-defaults-false. `test_variant_matrix.ml`: axis
  expansion for `stops_config.split_safe_floors`.

## 2026-08-05 addendum — split-safe floors on the panel/callback path (PR branch `feat/split-safe-panel-path`)

Closes the last open follow-up. `split_safe_floors` now governs **both** floor
paths; before this the flag was exposed as the searchable axis
`((stops_config ((split_safe_floors true))))` but silently did nothing on the
main multi-symbol strategy hot path, so a walk-forward surface over that axis was
measuring a partial mechanism (an `experiment-flag-discipline.md` R2 defect).

- **`Panel_views.daily_view` now carries both price bases.** Added
  `adjusted_closes` (from the `Snapshot_schema.Adjusted_close` cell) and renamed
  `closes` → `raw_closes`.
  - **Correction to the prior note.** The 2026-08-02 addendum recorded the
    blocker as "`daily_view` exposes raw highs/lows and adjusted closes but no
    raw close." That was **inverted**: `daily_view.closes` was populated from
    `Snapshot_schema.Close` (raw) all along, while the field's docstring claimed
    "Daily adjusted closes". The missing half was the *adjusted* close. Renaming
    the field rather than adding a same-named sibling keeps the change
    compiler-checked — every construction site had to be updated, and no
    existing `.closes` read could silently change meaning.
  - Two pre-existing readers in `trade_audit_report_bin.ml` were on the raw
    basis while their comments said "adjusted". Left on the raw basis (no
    behaviour change) with the discrepancy documented in place; whether the R6
    ratings *should* read adjusted closes is a separate question, deliberately
    not answered here.
- **One rescale implementation, at the callbacks-bundle level.** The rescale
  moved out of `_to_adjusted_basis_bar` (bar-level) into `_to_adjusted_basis`
  (bundle-level) inside `Floor_stop`, driven by a new
  `Support_floor.callbacks.get_adjusted_close` accessor. `compute_initial_stop_
  with_floor` now builds a raw bundle and calls straight through to
  `..._with_callbacks`, so both paths share one code path — the corrupt-close
  guard, the anchor mode and the flag cannot diverge between them by
  construction. A `daily_view` has no `Daily_price.t` to rewrite, only
  accessors, which is why the bundle level is the only level both paths share.
  The A2 decision from 2026-08-02 stands: the rescale is still inlined in
  `stops/`, with no `Adjusted_basis` import and no helper relocation.
- **`floor_is_structural_with_callbacks`** — callback-shaped sibling of
  `floor_is_structural`, running the same internal scan. `entry_audit_helpers`'
  `stop_floor_kind` tag now routes through it instead of calling the primitive
  directly, closing the #2167 class of bug on the panel path too (#2181 did the
  same for `stop_recompute` on the bar-list path).
- **R1 evidence (default-off bit-identical).** The panel test asserts structural
  equality of the whole `stop_state` against an in-test transcription of the
  pre-change code path (scan the bundle exactly as supplied, then place the
  stop) over the split-straddling window, plus the literal 104.0 phantom
  reference the raw basis yields. Mechanically, `_scan_callbacks` is the
  identity when the flag is off. Full `dune runtest` is green with zero golden
  changes.
- **R2 evidence (flag-on controls the panel path).** Same window, flag on: the
  long reference moves 104.0 → 98.0 (off the phantom that sat right at the
  ~104 entry, onto the adjusted-basis correction low) and matches the bar-list
  path exactly. Short mirror via `floor_is_structural_with_callbacks`:
  `false` → `true`.
- **Non-vacuity checked, not assumed.** Temporarily populating
  `adjusted_closes` from the raw close (the "looks wired, factor is silently
  1.0" failure mode) fails all three new adjusted-basis tests while the
  default-off R1 test correctly stays green.
- **Code health.** All three files the change touched were within 5 lines of
  their length cap on main, so the additions tripped the linter. Fixed by
  extraction, not by bumping limits or adding markers: daily-view walker →
  `snapshot_bar_views_helpers`; `empty_weekly_view` / `empty_daily_view`
  exported from `Snapshot_bar_views` and reused by `bar_reader` in place of a
  hand-copied literal; support-floor constructors → new `Panel_support_floor`
  (it has no back-edge to the Stage constructor, unlike the Sector / Macro /
  Stock_analysis ones the `@large-module` note cites).

Verify: `dev/lib/run-in-env.sh dune build && dev/lib/run-in-env.sh dune runtest`
(exit 0 each), then
`dune exec ./trading/weinstein/strategy/test/test_panel_callbacks.exe` — the
three `split_safe_floors` cases — and
`dune exec ./analysis/weinstein/snapshot_runtime/test/test_snapshot_bar_views.exe`
— `daily_view raw_closes / adjusted_closes are distinct fields`.

### 2026-08-05 QC rework iteration 1 (PR #2213)

qc-structural APPROVED 5/5. qc-behavioral NEEDS_REWORK on two unpinned
contracts — both were documented in the `.mli`s but had no test; neither was a
design defect. The reviewer independently rebuilt merge base `04e2c75b` in a
second worktree and confirmed R1 bit-identical on all four default-off cases
(including under `Close` anchor), and confirmed the flag was provably inert on
the panel path before this PR.

- **B1 — close-replacement pinned.** The rescale replaces the close with the
  adjusted close rather than leaving it raw. That is only observable under
  `Close` anchor mode, and `(Close × split_safe_floors=true)` is an expressible
  `Variant_matrix` cell — without the replacement that cell scans adjusted
  highs/lows against raw closes, i.e. the mixed-basis pathology this flag
  exists to remove. Worth 4% on the installed reference (100.0 correct vs
  104.0 phantom). Pinned on **both** paths; mutation M6 (drop the override) was
  caught by 0 tests repo-wide before, now 1 + 1.

- **B2 — unusable adjusted close now degrades the WHOLE window, not the bar.**
  Chose the coordinator's option (b) — degrade toward the flag-off default —
  but at **window** granularity, having measured that per-bar degradation as
  literally specified is unsafe. Three semantics measured on the 4:1 split
  fixture with the adjusted close blanked on the correction-low bar:

  | semantics | reference | `stop_is_structural` |
  |---|---|---|
  | NaN-propagation (as merged) | 99.0 | true — silently wrong |
  | per-bar fallback to 1.0 | **104.0 (phantom)** | true — the lone un-rescaled raw high 412 out-tops every adjusted high (110) and becomes the anchor |
  | whole-window fallback (chosen) | 104.0 = flag-off | matches flag-off |

  Per-bar degradation *creates* a mixed-basis window — the exact thing B1 is
  about. Whole-window keeps the invariant that makes the mechanism sound: **the
  scanned window is always on exactly one price basis**, so the flag returns
  either the correct adjusted answer or the flag-off answer, never a third one.
  Legacy-warehouse case (schema predating `Adjusted_close` ⇒ field read fails
  ⇒ all-NaN column): the flag is now **inert** (on == off in every row, which
  is diagnosable — it is the same signature that exposed this PR's original
  defect) instead of collapsing every scan to the buffer fallback, which would
  have read as a genuine negative result in a walk-forward surface. Note the
  real data source fails per-symbol, not per-date, so all-or-nothing also
  matches the granularity at which adjusted closes actually go missing.

  The guard is now symmetric across both operands of the division, and
  `_usable_price` is a single `> 0.0` test — NaN-safe without a separate
  `is_nan` branch, since IEEE `nan > 0.0` is `false`. A NaN-raw-close bar added
  to `corrupt_close_bars` pins that.

- **Mutation results** (unmutated baseline: both suites OK):

  | mutation | stops/test_support_floor | strategy/test_panel_callbacks |
  |---|---|---|
  | M6 — close override removed | 1 | 1 |
  | MN1 — adjusted-close guard removed (NaN propagates) | 4 | 1 |
  | MN2 — per-bar instead of whole-window | 1 | 0 |
  | M11 — always rescale (breaks R1) | 2 | 2 |
  | M12 — never rescale (breaks R2) | 4 | 3 |

  MN2 is caught only on the bar-list suite. That is adequate rather than ideal:
  there is one shared implementation now, so either suite exercises the same
  code. It needed a second fixture — the first NaN fixture could not catch it,
  because per-bar and whole-window happen to coincide at 104.0 there.
  `nan_adj_at_last_bar_bars` blanks the *post-split* bar (true factor 1.0),
  where per-bar reconstructs the adjusted window by luck (98.0) and
  whole-window returns the flag-off answer (104.0).

- **R1 unaffected.** Option (b) changes flag-**on** behaviour only; the
  default-off path never consults `get_adjusted_close`. M11 confirms the no-op
  is still pinned on both paths.

- **Code health.** Flattening required: `_to_adjusted_basis` tripped the nesting
  linter (avg 3.06 > 3.0). Split into `_adjusted_close_at` / `_rescaled` /
  `_to_adjusted_basis` — no marker, no limit bump.

### 2026-08-05 QC rework iteration 2 (PR #2213) — B3

qc-structural APPROVED 5/5 at `fbc11600`; qc-behavioral reproduced all five
mutation counts exactly with no overclaiming, and **retracted its own B2
prescription** ("my fix for B2 would have re-created B1"). One coverage gap
remained on correct code.

- **B3 — the "any offset" quantifier is now pinned.** `_window_is_adjustable`
  universally quantifies over the window, and both `weinstein_stops.mli` and
  `stop_types.mli` state that as a contract, but nothing tested it: mutation
  **MB5** (weaken the check to `day_offset:0` only) left the full repo
  `dune runtest` at exit 0. Every existing NaN fixture put its unusable cell at
  offset 0, and the one that didn't (`nan_adj_at_low_bars`, offset 1) returns
  104.0 under both whole-window and per-bar, so its assertion could not separate
  them.

  New fixture `nan_adj_at_first_bar_bars` blanks the adjusted close on
  2024-01-01 — `daily_view` is oldest-first and the callbacks flip the index, so
  the bad cell sits at **day_offset 4**. All three arms measured independently
  rather than taken from the review table; all three matched it:

  | implementation | far-offset `reference_level` |
  |---|---|
  | flag off | 104.0 |
  | **whole-window (shipped)** | **104.0** |
  | per-bar (MN2) | 98.0 |
  | offset-0-only (MB5) | 98.0 |

  Pinned on **both** paths. The panel sibling also closes the `MN2 panel 0`
  asymmetry flagged in the previous round — leaving the panel side without a
  non-zero-offset fixture would have repeated the exact shape of the defect this
  PR exists to fix.

- **Mutation results** (baseline: both suites OK; every mutation compile-checked
  before its result was read, per the stale-exe hazard hit earlier in this PR):

  | mutation | stops/test_support_floor | strategy/test_panel_callbacks |
  |---|---|---|
  | MB5 — window check weakened to offset 0 | 1 (was 0) | 1 (was 0) |
  | MN2 — per-bar instead of whole-window | 2 | **1 (was 0)** |

- **F4 closed** — the `None`-everywhere sentinel case is resolved by the
  all-or-nothing rework: a bundle whose `get_adjusted_close` is `None` at any
  offset makes the window un-rescalable, so the flag is inert rather than
  partially applied. No separate fix needed.

## 2026-08-06 addendum — F5 whole-window fallback telemetry (PR branch `feat/split-safe-fallback-telemetry`)

Closes **F5**. Plan: `dev/plans/split-safe-fallback-telemetry-2026-08-06.md`
(committed first on the branch, per plan-first).

The whole-window fallback returns exactly the flag-off level, so the level alone
cannot say whether the mechanism ran. A walk-forward arm over
`((stops_config ((split_safe_floors true))))` could therefore be substantially
inert with no per-decision signal, and an ACCEPT measured over a partly-inert
surface would be uninterpretable. This makes the condition measurable.

- **`Weinstein_stops.split_safe_basis = Flag_off | Adjusted | Raw_fallback`**
  (pure; `show`/`eq`/`sexp`), with `split_safe_basis_of_callbacks` and
  `split_safe_basis_of_bars`. Three states, not two — conflating "flag off" with
  "flag on but degraded" reproduces the exact ambiguity F5 is about.
- **Single-sourced, not re-derived.** `_to_adjusted_basis` was folded into a new
  private `_scan_basis` that returns **both** the bundle the scan reads and the
  basis it is on; `_scan_callbacks` is its `fst` and the public query its `snd`.
  A second, independent evaluation of `_window_is_adjustable` would let the
  reported basis drift from the basis actually scanned — the #2167 class of bug
  this track has already been bitten by twice (mutation MT2 below pins this).
- **Reaches a run artifact.** The tag threads
  `Entry_audit_helpers.initial_stop_and_kind` → `Entry_audit_capture.entry_meta`
  → `Audit_recorder.entry_event` → `Trade_audit.entry_decision` →
  `<scenario>/trade_audit.sexp`, so the inert fraction of a surface cell is a
  one-liner over artifacts that already exist:
  `Raw_fallback / (Raw_fallback + Adjusted)` counted over the run's
  `trade_audit.sexp`. A non-zero `Flag_off` count in a flag-on arm is itself a
  wiring alarm. **Denominator caveat, documented in the `.mli`s:** only *entered*
  candidates produce an `entry_decision`, so the fraction is over entries, not
  over all floor scans (`alternative_candidate` carries no stop fields).
- **R1 unaffected.** No stop level changes; `split_safe_floors = false` stays
  bit-identical. Full `dune runtest` green with zero golden changes.
- **Backward compatibility.** `Trade_audit.entry_decision.split_safe_basis`
  carries `[@sexp.default Flag_off]` so `trade_audit.sexp` files written before
  the field exist still parse — they are read back by `Optimal_run_artefacts`,
  `Validator_report` and `Trade_audit_report`. Pinned by a test that strips the
  field from a serialized row and asserts the parse defaults to `Flag_off`.
- **Design alternatives rejected** (full reasoning in the plan): a module-level
  mutable counter (cheapest, but destroys the purity the reproducible-backtest
  invariant rests on and makes the stops suite order-sensitive); an
  `~on_fallback` callback (pushes impurity to every call site and cannot express
  the `Adjusted` denominator, so it can produce a count but never a fraction); a
  richer return type on `compute_initial_stop_with_floor_with_callbacks` (forces
  every one of its many callers to change for telemetry most do not want);
  stopping at `Audit_recorder` (the recorder would drop the field — telemetry
  nobody reads, which reads as coverage without being it).

- **Mutation results** (baseline: all four suites OK; each mutation
  compile-checked before its result was read):

  | mutation | stops/test_support_floor | strategy/test_panel_callbacks | strategy/test_entry_audit_capture |
  |---|---|---|---|
  | MT1 — fallback branch reports `Adjusted` (behaviour unchanged, tag lies) | **3** | **2** | **1** |
  | MT2 — basis re-derived independently of `_window_is_adjustable` (the drift the single-source design prevents) | **3** | **2** | **1** |
  | MT3 — helper hardcodes `Flag_off` (telemetry computed but not wired) | 0 | 0 | **2** |

  MT1 failing assertions, verbatim:
  `support_floor:47:split_safe_basis_fallback_distinguishable_from_flag_off`,
  `support_floor:50:split_safe_basis_far_offset_reports_fallback`,
  `support_floor:51:split_safe_basis_corrupt_close_reports_fallback`, each
  "Values should be equal / not equal". MT3:
  `entry_audit_capture:12:F5: entry_meta basis is Adjusted when the window rescales`
  and `...:13:F5: entry_meta basis is Raw_fallback when the window degrades`.
  MT1/MT2 leaving `test_entry_audit_capture` at only 1 failure is expected — its
  `Flag_off` case does not touch the mutated branch. All three mutations were
  reverted and the library confirmed byte-identical (`git diff` empty on
  `floor_stop.ml` / `entry_audit_helpers.ml`).

  **MT2 retracted in rework iteration 1 — see below. Do not cite it.**

### 2026-08-06 QC rework iteration 1 (PR #2220)

qc-structural APPROVED 5/5 at `7e3b2586` (independently reproduced MT1 at
3/2/1). qc-behavioral NEEDS_REWORK on two blocking findings; both were real.

- **B1 — the telemetry could be silently zeroed at either sink, full repo
  green.** Hardcoding `Flag_off` at **both** `entry_audit_capture.ml`'s
  `build_entry_event` and `trade_audit_recorder.ml`'s `_entry_decision_of_event`
  left `dune runtest` at exit **0**. Every audit row in a `split_safe_floors
  true` arm would have read `Flag_off` and the inert fraction would evaluate
  `0/0`. Root cause: `Trade_audit_recorder` had **no test anywhere in the repo**,
  and every `build_entry_event` test drove a meta whose basis was the `Flag_off`
  default — a fixture that only exercises the default cannot distinguish
  "propagated" from "constant". MT3 pinned only the first of three hops.

  This one lands squarely against this PR's own stated standard: the plan
  rejected "stop at `Audit_recorder`" precisely because "`Trade_audit_recorder`
  would drop the field; telemetry nobody reads reads as coverage without being
  it." The reviewer demonstrated the field being dropped at exactly that hop.

  Fix: new `trading/trading/backtest/test/test_trade_audit_recorder.ml` (first
  test for that module) driving **every** constructor through the real
  `of_collector` bundle, plus `_stub_trans_and_meta` gaining
  `?split_safe_basis` so `build_entry_event` is pinned off non-default values.
  `stop_floor_kind` got the same treatment on the recorder hop — it had the same
  gap.

- **B2 — MT2 did not reproduce; the headline structural claim was
  unevidenced.** The reviewer ran a faithful re-derivation and got exit 0. They
  are right, and the argument generalises: **any behaviour-preserving
  re-derivation is green by construction**, so no test can separate
  "single-sourced" from "faithfully re-derived". Only a *divergent* re-derivation
  reddens, and that is MT1.

  **Resolution: option (b) — the claim is restated, not rescued.** Single-sourcing
  is a **structural / compile-time** property: there is no second decision site
  that *could* drift, so the #2167 class is *unrepresentable* here rather than
  merely absent. That is a code-shape guarantee verified by reading the code.
  What the tests pin is the weaker, testable claim that the tag tracks the branch
  (MT1). No test was manufactured to save the stronger wording. Corrected in
  `weinstein_stops.mli`, the plan file's §Approach and acceptance criterion 3;
  the PR body needs the same correction (wording handed to the coordinator).

- **B3 — an empty lookback window mis-reported as `Raw_fallback`.** A real
  metric-correctness bug in the number F5 exists to produce:
  `_window_is_adjustable` answers `false` for `n_days = 0`, which under
  `_scan_basis` read as "the fallback fired" for a window that had nothing to
  scan, inflating the inert-fraction numerator with non-events. Fixed with a
  deliberate fourth state **`Empty_window`**, branched before the adjustability
  check and threaded through `Audit_recorder` / `Trade_audit` /
  `Trade_audit_recorder`. Behaviour-preserving (the empty branch returns the
  bundle untouched, exactly as the `Raw_fallback` branch did) and pinned by a
  test that the empty-window stop still equals the flag-off stop. The metric is
  now defined as `Raw_fallback / (Raw_fallback + Adjusted)` with `Empty_window`
  excluded from **both** terms — documented on the type.

- **B4 — re-anchor independence pinned.** The §5.1 re-anchor replaces the
  installed level but does not re-run the scan, so `split_safe_basis` must
  describe the scan while `stop_floor_kind` flips to `Buffer_fallback`. The new
  test asserts both fields on the same `entry_meta` and requires them to
  disagree, which is what "independent" means operationally.

- Non-blocking, folded in: the denominator caveat moved onto
  `split_safe_basis_of_callbacks` (the entrypoint the strategy actually calls)
  and now names **both** narrowings — entries-not-candidates, and
  entry-time-not-stop-maintenance (`Stop_recompute` / `Stop_thread` scan under
  the flag untagged). `trade_audit.mli`'s justification for re-declaring the
  variant was imprecise ("so backtest needs no dependency on the stops
  library") — the type was already reachable via `weinstein_trading.strategy`,
  and the avoided edge would have been `trading/trading` → `trading/trading`,
  which A2 does not govern. Restated as what it actually is: a deliberate
  on-disk-schema boundary.

- **Rework mutation results** (baseline: all suites OK; each mutation
  compile-checked before its result was read):

  | mutation | stops/support_floor | strategy/entry_audit_capture | backtest/trade_audit_recorder |
  |---|---|---|---|
  | reviewer's B1 sink mutation — `Flag_off` hardcoded at **both** sinks (was **0/0/0**, full repo exit 0) | 0 | **1** | **1** |
  | MT4 — `Empty_window` branch removed (folds non-events into the inert numerator) | **1** | 0 | 0 |

  B1 failing assertions, verbatim:
  `Trade_audit_recorder:0:split_safe_basis projects all three states` and
  `entry_audit_capture:15:B1 hop 1: build_entry_event propagates the basis`,
  each "Values should be equal / not equal". MT4:
  `support_floor:52:split_safe_basis_empty_window_is_not_fallback`. Both
  mutations reverted; `git diff` empty on `entry_audit_capture.ml` /
  `trade_audit_recorder.ml`, and `floor_stop.ml` restored to the shipped form.

- **Suite counts:** `test_support_floor` 55 → 63, `test_panel_callbacks` 21 → 24,
  `test_entry_audit_capture` 40 → 45, `test_trade_audit` 26 → 28,
  `test_trade_audit_recorder` 0 → 3 (new module test).

## 2026-08-07 addendum — B5 + B6, the last two telemetry gaps (PR branch `feat/split-safe-empty-window-panel`)

Closes **B5** and **B6**. Both were raised by qc-behavioral during #2220's rework
round and recorded in `dev/daily/2026-08-06.md` §Follow-up Queue, but the
corresponding edit to this file was **lost to shared-tree churn** — they never
appeared in §Follow-ups below. They are filed there now (struck through, since
this PR closes them) so the audit trail is not a dangling reference to a daily
summary.

Telemetry + test work only. No behaviour change, no stop level moves,
`split_safe_floors` stays default-off; no default is flipped
(`.claude/rules/experiment-flag-discipline.md` R3 — there is still no ledger
ACCEPT).

- **B5 — `Empty_window` pinned on the bar-list path only.** When the fourth
  basis state landed (#2220 rework, B3) it was pinned in
  `stops/test/test_support_floor.ml` but not in
  `strategy/test/test_panel_callbacks.ml`, which carried siblings for the other
  three (`Flag_off`, `Raw_fallback`, `Adjusted`). "Covered on one path, silently
  unexercised on the other" is this track's documented recurring defect class —
  it was #2213's B3 and the shape #2220's B1 landed in.

  Fixed by one panel test asserting both configs on one view: flag-off reports
  `Flag_off`, flag-on reports `Empty_window`. The empty view is reached the way
  production reaches it — `Snapshot_bar_views.daily_view_for` asked for a symbol
  the snapshot has no rows for, on a calendar that *does* contain the `as_of`,
  so the emptiness comes from `_read_daily_tables` finding no raw-close rows (the
  newly-listed / snapshot-missing-symbol route) rather than from an unresolvable
  `as_of` or a non-positive lookback.

  Deliberately **not** added: a panel sibling of the bar-list
  `split_safe_empty_window_stop_matches_flag_off`. With `n_days = 0` every
  accessor returns `None`, so `_rescaled` and the untouched bundle are
  observationally identical and no plausible mutation of the empty branch can
  redden such a test. It would have been coverage-shaped but green by
  construction — the exact defect #2220's B2 was about.

- **B6 — an all-`Empty_window` arm reports an undefined `0/0`.** The metric
  documented on `Weinstein_stops.split_safe_basis` is
  `Raw_fallback / (Raw_fallback + Adjusted)` with `Empty_window` excluded from
  both terms (correct — folding non-events in inflates apparent inertness). But
  that denominator can be zero, and a blank cell then reads as "this column was
  never wired up". Those two states demand opposite responses: disqualify the arm
  for lack of exposure, versus stop and fix the harness.

  Fixed by making the undefined case a **named value rather than a rendered
  blank**, in a new pure module `trading/trading/backtest/lib/split_safe_metric.{ml,mli}`:

  ```
  type inertness = Inert_fraction of float | Not_exercised of tally
  ```

  `Not_exercised` carries the tally so the *cause* survives to the site that
  would otherwise print nothing: `flag_off > 0` is a wiring alarm; `empty_window
  > 0` with `flag_off = 0` is a coverage problem; all-zero is an empty
  population. A consumer must pattern-match, so `0/0` cannot silently reach a
  report as `0.0`, `nan`, or a blank.

  **Home: the audit layer, not the stops library.** The three re-declarations of
  the variant (`Weinstein_stops`, `Audit_recorder`, `Trade_audit`) are distinct
  OCaml types, and only the audit layer ever sees a *population* — the stops
  entrypoint returns one tag per decision. A reduction in the stops library would
  need a conversion at every call site and could not be used by the report that
  will consume it.

  **Deliberately not done:** no renderer. F6 below is exactly the report-row
  follow-up, and inventing a renderer here would have pre-empted it. The
  `.mli` prose that previously defined the metric in two places
  (`weinstein_stops.mli`, `trade_audit.mli`) now points at the one reduction
  instead of inviting each reader to re-derive the arithmetic.

- **Mutation results** (baseline: `dune runtest` exit 0 with the new tests; each
  mutation applied to the library, compile-checked, result read, then reverted
  and confirmed byte-identical against a pre-mutation copy):

  | mutation | strategy/test_panel_callbacks | backtest/test_split_safe_metric |
  |---|---|---|
  | MT5 — `Empty_window` branch removed from `_scan_basis` (empty windows fall through to `Raw_fallback`) | **1** | n/a |
  | MB1 — undefined case returns `Inert_fraction 0.0` instead of `Not_exercised` | n/a | **3** |
  | MB2 — `empty_window` folded into the denominator | n/a | **3** |
  | MB3 — `Not_exercised` carries `empty_tally` instead of the real tally (cause dropped) | n/a | **2** |
  | MB4 — `Empty_window` counted into `raw_fallback` (non-events inflate the numerator) | n/a | **4** |

  MT5 is the B5 measurement and was run **twice** to establish the before/after
  the finding claims. With the new panel test present it reddens
  `Panel_callbacks parity:24:split_safe basis is Empty_window, not a fallback,
  for an empty panel window` (25 cases, 1 failure, exit 1). With the same
  mutation applied and `test_panel_callbacks.ml` reverted to `25d07cfc`, the
  whole `trading/weinstein/strategy/test/` suite is **exit 0** (24 cases, 0
  failures) — i.e. the panel path really was blind to the branch, which is the
  finding.

  MB1 failing assertions, verbatim: `Split_safe_metric:1:all Empty_window is
  Not_exercised, not a number`, `Split_safe_metric:2:all Flag_off stays
  distinguishable from all Empty_window`, `Split_safe_metric:3:empty population
  is Not_exercised`. MB1 leaves `Split_safe_metric:7:all Adjusted is zero inert`
  green, which is the point: `0.0` is a legitimate reachable reading, so it can
  never be a safe rendering for the undefined case.

- **Suite counts:** `test_panel_callbacks` 24 → 25, `test_split_safe_metric`
  0 → 8 (new module test).

## 2026-08-07 addendum — F6, the split-safe report row (PR branch `feat/split-safe-inert-report-row`)

**What shipped.** `Trade_audit_report` now carries the split-safe basis tally on
its document model and renders it as a section of the markdown report. It is a
pure consumer: `Backtest.Split_safe_metric` is untouched.

- `trade_audit_report.mli` / `.ml` — new field `split_safe_tally :
  Backtest.Split_safe_metric.tally` on `t`, populated by `render` from the
  `split_safe_basis` of every `Trade_audit.entry_decision` in the `trade_audit`
  argument.
- `to_markdown` emits a `## Split-safe floor basis` section between the
  per-trade table and the analysis layer (both existing pinned markdown blocks
  end at `## Per-trade table` / the table header, so neither moved).

**Two decisions worth recording.**

1. **The tally is over the audit population, not over `rows`.** The basis tag
   lives on the entry decision. An entry still open at end-of-run, or one whose
   round-trip failed the `(symbol, entry_date)` join, exercised
   `split_safe_floors` exactly as much as a closed one; tallying over `rows`
   would drop it and understate the denominator. Pinned by
   `split-safe tally counts audit population not rows`.
2. **The inert fraction is not stored, only the tally.** It is a total function
   of the tally (`Split_safe_metric.inertness_of_tally`); a second stored copy
   could disagree with the counts printed beside it. `to_markdown` derives it at
   format time, which is also why the report and a `Split_safe_metric` caller
   cannot report different numbers. (`inertness` derives only `show, eq`, not
   `sexp`, so storing it on the `sexp`-deriving `t` would also have forced a
   change to a module this PR is a consumer of.)

**The `Not_exercised` rendering — the point of the item.** The section always
prints the four counts, then one of two lines:

- exercised: `- Inert fraction (raw_fallback / (raw_fallback + adjusted)): 25.0%`
- not exercised: `- Inert fraction: NOT EXERCISED — the denominator is zero, so
  there is no measurement here; this is not zero inertness. <cause>`

The not-exercised line contains **no percent sign at all** — a test asserts the
section is `%`-free in that state, so it cannot be skimmed as a wired-but-zero
column. `<cause>` names which of the three sub-cases on
`Split_safe_metric.inertness` applies, and the flag-off cause takes priority
when both it and empty windows are present (it is the louder signal — the flag
never reached the scan):

| tally state | rendered cause |
|---|---|
| `flag_off > 0` | `N decision(s) carry flag_off, so none reached the basis choice. In a run configured split_safe_floors=true that is a wiring alarm, not a data point.` |
| `empty_window > 0`, `flag_off = 0` | `the flag reached the scan, but all N lookback window(s) were empty — the mechanism ran with nothing to act on, so this run has no exposure to it.` |
| all zero | `no entry decisions were captured, so this run says nothing either way.` |

**The section is emitted unconditionally**, including for pre-PR-2 reports with
no audit records at all. An omitted section is indistinguishable from an inert
arm, which is the same confusion the variant exists to prevent — so "nothing to
report" is itself reported, as the all-zero cause.

**Tests.** 31 → 36 in `test_trade_audit_report.ml`. Every claim was
mutation-checked in both directions (mutation applied → the new test reddens;
mutation applied with the new tests reverted to `origin/main` → 31 tests, exit
0, i.e. the path was genuinely blind, not merely under-asserted):

| claim | mutation | with new tests | tests reverted |
|---|---|---|---|
| counts line reports the right column per state | swap `adjusted` / `raw_fallback` in the `sprintf` args | 1 failure | 31 tests, exit 0 |
| the fraction renders as a percentage | drop `*. 100.0` (25.0% → 0.3%) | 1 failure | 31 tests, exit 0 |
| the flag-off cause is reported, and wins over empty-window | make the `flag_off` branch unreachable | 1 failure | 31 tests, exit 0 |
| the empty-window cause is distinct from the empty-population one | make the `empty_window` branch unreachable | 1 failure | 31 tests, exit 0 |
| `Not_exercised` never renders as a percentage — **flag-off and empty-window states only** (see correction below) | replace the whole shared `Not_exercised` `sprintf` with a `0.0%` line | 3 failures | 31 tests, exit 0 |
| the section is never silently omitted | `_format_split_safe` returns `[]` | 4 failures | 31 tests, exit 0 |
| the tally is join-independent | drop audit records that joined a round-trip | 1 failure (only the tally test) | 31 tests, exit 0 |
| the tally is over entries, not round-trips | keep only audit records that joined a round-trip | 4 failures | 31 tests, exit 0 |

**Deliberately not done.** The HTML report — a separate surface, filed as F10.
No change to `Split_safe_metric`, `trade_audit_report_bin.ml`'s raw-vs-adjusted
reads (F3), or any core module.

#### Correction 2026-08-08 — the "never a percentage" row over-claimed, and the gap is now closed

qc-behavioral (on PR #2234, since closed — its content reached `main` via an
unrelated shared-tree auto-merge, so the defect was live on `main` rather than
on a branch) measured that the 3-failure row above **generalised from a
mutation of the shared `sprintf` branch to all three `Not_exercised` states**,
which does not follow. That mutation replaced the entire message, so it also
dropped the cause prose (`no entry decisions were captured`) that
`test_split_safe_not_exercised_empty_population` *does* assert — which is where
its third failure came from. The empty-population state asserted neither
`"NOT EXERCISED"` present nor the section `%`-free, so **"never a percentage"
was pinned on two of three states, not three.**

The all-zero tally is what every pre-PR-2 report and every zero-entry run
produces, so this was the state most likely to render as a bare `0.0%` — the
exact "wired-but-zero" reading the section exists to make impossible.

Closed 2026-08-08 by adding the two assertions its siblings already carry
(`"NOT EXERCISED"` present, `"%"` absent) to
`test_split_safe_not_exercised_empty_population`. Test-only change — no
implementation change was needed, confirming the renderer was already correct
and only the pin was missing. Re-measured in both directions with mutation
**M-G** (special-case the all-zero branch to
`sprintf "- Inert fraction: 0.0%% — %s" (_not_exercised_cause t)`, which keeps
the cause prose and so escapes every pre-existing assertion):

| state of `test_trade_audit_report.ml` | implementation | result |
|---|---|---|
| with the two new assertions | M-G applied | **1 failure** (`split-safe not exercised: empty population`), exit 1 |
| at `origin/main` (pre-fix) | M-G applied | 36 tests, **exit 0** — genuinely blind, not merely under-asserted |
| with the two new assertions | unmutated | 36 tests, exit 0 |

Suite count is unchanged at 36 — the assertions were added to the existing
test rather than as a new case.

## Follow-ups

- ~~**B5 (qc-behavioral, PR #2220 rework) — `Empty_window` pinned on only one of
  two paths.** Filed late: raised in #2220's rework and recorded in
  `dev/daily/2026-08-06.md` §Follow-up Queue, but the status-file edit was lost
  to shared-tree churn, so it never reached this section. Original text: "the
  panel path has telemetry siblings for the other three states but not the
  fourth. Not blocking, but 'covered on one path, unexercised on the other' is
  this track's documented recurring defect class (it was #2213's B3)."~~ —
  **done 2026-08-07**, see the addendum above.
- ~~**B6 (qc-behavioral, PR #2220 rework) — an all-`Empty_window` arm reports an
  undefined `0/0` that reads as "column unwired".** Filed late for the same
  reason as B5.~~ — **done 2026-08-07** via
  `Backtest.Split_safe_metric.inertness`; see the addendum above.
- ~~Round-number shading (§5.1)~~ — **already implemented; this line was stale.**
  `Stop_nudge.nudge_round_number` exists and `stop_types.ml` carries
  `round_number_nudge = 0.125`, applied by `Floor_stop.compute_initial_stop` and
  by the trailing / tightened candidates in `weinstein_stops.ml`. Nothing to build.
- ~~Split-safe on the panel/callback path~~ — **done 2026-08-05**, see the
  addendum above.
- ~~**F5 (qc-behavioral, PR #2213) — no telemetry when the whole-window fallback
  fires.**~~ — **done 2026-08-06** via `split_safe_basis`; see the addendum
  above. Original text retained for context:
- ~~**F5 (qc-behavioral, PR #2213) — no telemetry when the whole-window fallback
  fires.** Ranked by the reviewer as the most consequential of this PR's
  follow-ups. The all-or-nothing design is right, but silent at the single-decision
  level: a caller cannot distinguish "flag on, window adjusted, answer 104.0" from
  "flag on, window unadjustable, answer 104.0". Diagnosability exists only in
  aggregate (`on == off` across many rows). Because whole-window is by design
  sensitive to a *single* unusable cell anywhere in `support_floor_lookback_bars`,
  a run could be substantially inert with nobody knowing what fraction was
  affected. A counter or an `Audit_recorder` tag ("split-safe fallback fired")
  turns a silent condition into a measurable one and lets a walk-forward run
  report *how much* of the surface was inert. **Do this before the mechanism is
  ever promoted** — an ACCEPT computed over a partly-inert surface would be
  uninterpretable, precisely the failure class
  `.claude/rules/mechanism-validation-rigor.md` exists to prevent.~~
- **F3 (qc-behavioral, PR #2213) — `trade_audit_report_bin.ml` reads the raw
  basis where the domain wants adjusted.** Exposed (not introduced) by #2213's
  `closes` → `raw_closes` rename, which is why both readers were deliberately
  left on raw with no behaviour change. The domain judgement, from qc-behavioral:
  reading `raw_closes` in `_closes_lookup_of_reader` (R6 ratings) and
  `_bar_close_of_reader` (HTML benchmark / utilization marks) **is** a real
  correctness defect — a split inside the R6 lookback injects a ~4x discontinuity
  into the pre-entry close series, and a raw mark taken across a split produces a
  fake jump in the benchmark curve. This is the G14 pathology relocated to the
  reporting layer. Needs its own PR **including** a re-pin of affected report
  goldens.
- **F1 (qc-behavioral, PR #2213) — panel R2 fixture is one-sided on the high
  leg.** At `c7b1bcf6`, mutation M5 (`get_high` left unscaled) left
  `test_panel_callbacks.exe` fully green; only the bar-list
  `split_safe_short_uses_adjusted_ceiling` caught it. Lower priority after the
  rework: the panel path has since acquired discriminating coverage at three
  separate points (Close anchor, all-NaN, far-offset). Suggested fix — assert the
  panel short case's `reference_level` (102.0) rather than only the structural
  boolean.
- **F2 (qc-behavioral, PR #2213) — R1 comparand is an in-test transcription.**
  `test_panel_split_safe_off_matches_pre_flag_path` compares against
  `_pre_flag_panel_stop`, a re-statement of the old code path rather than an
  independent value, so a drifted transcription would pass while the invariant
  broke. No live risk — qc-behavioral verified R1 against merge base `04e2c75b`
  directly at both `c7b1bcf6` and `fbc11600`, all four default-off cases
  bit-identical — but pinning to literal floats (`104.0` / `99.84`) would make it
  self-sufficient. Lowest priority of the four.
- `split_safe_floors` still needs a ledger ACCEPT before its default can flip
  (R3). Now that the axis actually controls both paths, a walk-forward surface
  over `((stops_config ((split_safe_floors true))))` measures the whole
  mechanism rather than the bar-list half — any earlier reading of that axis
  under-states the effect and should be re-run. **When that surface is run,
  report the inert fraction from `trade_audit.sexp`'s `split_safe_basis` column
  alongside the metrics** — a cell whose entries are mostly `Raw_fallback` is
  measuring baseline, not the mechanism. Compute it with
  `Backtest.Split_safe_metric.inertness_of_tally` rather than by hand: a cell
  that comes back `Not_exercised` has **no** reading and must be disqualified,
  not recorded as 0% inert.
- **F9 (new, rework iteration 1) — `Stop_recompute` / `Stop_thread` scan under
  the flag untagged.** `split_safe_basis_of_bars` exists for them but no caller
  is wired, so the inert fraction is entry-time-only. Disclosed on
  `split_safe_basis_of_callbacks`. Same shape as F7 (entries-vs-candidates):
  both narrowings *understate* how much of a run the flag touched, so neither
  can make an inert arm look active — but both must be named when the number is
  read.
- ~~**F6 (new, from the F5 work) — no report surface for the inert fraction.**
  The per-decision tag is in `trade_audit.sexp`, but `Trade_audit_report` / the
  HTML report do not render it, so today the number comes from a shell count.
  Cheap follow-up: one summary row (`Adjusted / Raw_fallback / Flag_off` counts)
  in the trade-audit report.~~ — **done 2026-08-07** for the **markdown**
  report; see the 2026-08-07 F6 addendum below. The HTML renderer is a separate
  surface and is **not** covered (residual, recorded as F10).
  **R4 correction (the original text said "the shell count is sufficient to
  qualify a surface"): it is not.** A shell count over `trade_audit.sexp` is
  exactly the ad-hoc path that produces the bare `0/0` blank
  `Split_safe_metric.inertness` exists to forbid — it cannot tell a
  never-exercised arm from an unwired column. Read the rendered section, or
  call `Split_safe_metric.inertness_of_tally`; do not hand-count.
- **F10 (new, residual from F6) — the HTML report still has no split-safe
  surface.** F6 shipped the section on the **markdown** `Trade_audit_report`
  only; the HTML renderer is a separate surface with its own layout and was
  kept out to keep the F6 diff reviewable. Low priority — anyone reading the
  inert fraction today reads the markdown report — but until it lands, an HTML
  reader sees no split-safe row at all, which is the same "absence reads as
  zero" ambiguity F6 exists to close, just on a different surface.
- **F7 (new, from the F5 work) — telemetry covers entries only.** Screened but
  skipped candidates run a floor scan too and produce no `entry_decision`, so
  the inert fraction has an entries-denominator. Widening it would mean adding
  stop fields to `Trade_audit.alternative_candidate`. Low priority: the entries
  are the decisions the mechanism actually changes.
- **F8 (new, observed while wiring F5) —
  `Entry_audit_capture.classify_stop_floor_kind` bypasses the scan chokepoint.**
  It calls `Support_floor.find_recent_level_with_callbacks` directly instead of
  `Weinstein_stops.floor_is_structural_with_callbacks`, so it honours
  `support_floor_anchor_mode` but **not** `split_safe_floors` — the #2167 shape
  that #2181/#2213 closed everywhere else. The production path
  (`Entry_audit_helpers.initial_stop_and_kind`) does not use it, so there is no
  live defect today, but it is an exported `.mli` val and a trap for the next
  caller. Should either be re-pointed at `floor_is_structural_with_callbacks` or
  deleted.

- **F11 (new, from the 2026-08-08 F6 rework) — anchor the not-exercised
  assertion to its label.** All three `Not_exercised` tests assert
  `String.is_substring s ~substring:"NOT EXERCISED"`, which is satisfied by any
  line containing those two words anywhere. The reviewer's mutation **M-A**
  (emit the percentage *and* the words on the same line, e.g.
  `- Inert fraction: 0.0% — NOT EXERCISED …`) passes all 36 on the flag-off and
  empty-window states, because the `%`-absence assertion is the only thing
  standing between the reader and a number. Closed at zero cost by tightening
  the three substrings to `"- Inert fraction: NOT EXERCISED"`, which forbids
  interposing anything numeric between the label and the words.
  **Non-blocking** — the `%`-absence assertion (now on all three states) already
  catches the concrete rendering, so this is defence in depth on the label
  itself, not a live hole.
- **F12 (new, from the 2026-08-08 F6 rework) — extend the existing `core_lines`
  byte pin to cover the split-safe section.** Mutation **M-E** (swap the order
  of the two bullets — counts line and inertness line) escapes every current
  assertion, since all of them are substring containment over the section as a
  whole; so would duplicate emission of either bullet, or a change to the blank
  lines around the heading. Presentation-only, which is why the original author's
  withholding was judged correct — but `to_markdown`'s `core_lines` already
  byte-pins the header / aggregate / per-trade-table block, so extending that pin
  over the fourth block is consistent with what the file already does rather than
  new machinery. **Non-blocking.**

### Follow-ups filed 2026-08-07 (qc-behavioral residuals on PR #2232, all non-blocking)

- **R1 -- `tally_of_bases` order-independence documented but unpinned.** The `split_safe_metric.mli` docstring says "Order-independent and total"; totality is pinned by `tally counts every basis state`, order-independence is not (no test permutes the input). True by inspection -- a fold over independent counters -- and a test would be **green by construction** in exactly the way the author correctly withheld the panel stop-level test for. Filed only so the claim/test map is complete, not as work to do.
- **R2 -- `empty_tally`'s field values pinned only transitively.** `empty population is Not_exercised` uses `M.empty_tally` on both sides of the equality, so it does not independently pin "all four counts zero". The literal zeros *are* pinned elsewhere (`all Empty_window is Not_exercised` asserts `flag_off = 0; adjusted = 0; raw_fallback = 0` literally), so there is no real hole -- a naming nit at most.
- ~~**R3 -- one skimmer-facing line in Follow-ups.**~~ — **moot 2026-08-08.** F6
  has shipped on the markdown surface, so the struck B6 line no longer implies
  closure that does not exist; the only remaining residual is the HTML surface,
  which is separately named as F10. Original text: The strikethrough reads "~~B6...~~ -- **done 2026-08-07** via `Backtest.Split_safe_metric.inertness`". The "renderer still pending" qualifier lives in the addendum and in F6, not on that line. Everything is accurate and traceable, but a skimmer reading only the struck line could infer more closure than exists. Suggest appending "(reduction only; rendering remains F6)".
- ~~**R4 -- F6's "shell count is sufficient" is now stale advice.**~~ —
  **resolved 2026-08-07**, in the F6 entry itself: the "R4 correction" paragraph
  on F6 above now states that a shell count is *not* sufficient and directs the
  reader to the rendered section or `Split_safe_metric.inertness_of_tally`.
  Original text: F6 still says "the shell count over `trade_audit.sexp` is sufficient to qualify a surface", which is precisely the ad-hoc path that produces the `0/0` blank B6 exists to prevent. It predates this PR and is not one of the three `.mli` sites, so it does not affect the Q4 consistency finding -- but a reader following it would reintroduce the defect the new type forbids.

**Standing sequencing note.** With B5, B6 and now F6 closed, the `split_safe_floors` axis can report its own inert fraction on both paths, an all-`Empty_window` arm is distinguishable from an unwired column, and the number is rendered rather than hand-counted. What remains before a promotion decision per `.claude/rules/promotion-confirmation.md` is a walk-forward surface that actually reports it. F9 (`Stop_recompute` / `Stop_thread` scans untagged) and F7 (skipped candidates) both **understate** how much of a run the flag touched, so neither can make an inert arm look active -- but both must be named when the number is read.

## QC

overall_qc: PENDING
structural_qc: PENDING
behavioral_qc: PENDING

Reviewers when work lands:
- qc-structural — module boundaries, pure-function discipline, test coverage for degenerate inputs (empty bars, single bar, all-flat prices); symmetry of long/short branches in the primitive.
- qc-behavioral — spot-check against Weinstein Ch. 6 examples (Merck, Anthony Industries, National Semiconductor) — does the identified correction low match what the book calls out? For the short side, spot-check against Ch. 11 short-sell examples (resistance ceiling identification).
