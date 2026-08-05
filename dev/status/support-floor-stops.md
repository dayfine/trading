# Status: support-floor-stops

## Last updated: 2026-08-05

## Status
READY_FOR_REVIEW

## Interface stable
YES

## Open PR
- `feat/split-safe-panel-path` — split-safe floors on the panel/callback path
  (2026-08-05 addendum below). Branch pushed; PR opened by the orchestrator.
- Previously merged on this track:
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

## Follow-ups

- ~~Round-number shading (§5.1)~~ — **already implemented; this line was stale.**
  `Stop_nudge.nudge_round_number` exists and `stop_types.ml` carries
  `round_number_nudge = 0.125`, applied by `Floor_stop.compute_initial_stop` and
  by the trailing / tightened candidates in `weinstein_stops.ml`. Nothing to build.
- ~~Split-safe on the panel/callback path~~ — **done 2026-08-05**, see the
  addendum above.
- `split_safe_floors` still needs a ledger ACCEPT before its default can flip
  (R3). Now that the axis actually controls both paths, a walk-forward surface
  over `((stops_config ((split_safe_floors true))))` measures the whole
  mechanism rather than the bar-list half — any earlier reading of that axis
  under-states the effect and should be re-run.

## QC

overall_qc: PENDING
structural_qc: PENDING
behavioral_qc: PENDING

Reviewers when work lands:
- qc-structural — module boundaries, pure-function discipline, test coverage for degenerate inputs (empty bars, single bar, all-flat prices); symmetry of long/short branches in the primitive.
- qc-behavioral — spot-check against Weinstein Ch. 6 examples (Merck, Anthony Industries, National Semiconductor) — does the identified correction low match what the book calls out? For the short side, spot-check against Ch. 11 short-sell examples (resistance ceiling identification).
