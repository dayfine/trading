# Plan: Bar_history rolling-window trim (2026-04-24)

## Why

Local A/B finding (PR #524 / `backtest-scale.md` § Follow-up): on a
292-symbol bull-crash run, Tiered uses ~95% more RSS than Legacy
(1.87 GB vs 3.65 GB). Diagnosis: `Bar_history` is `Daily_price.t list
Hashtbl.M(String).t` — append-only, never trimmed, no `trim_before`
function exists. Both strategies grow Bar_history forever within a
run. Tiered additionally carries `Full.t.bars` (bounded at
`Full_compute.tail_days` ≈ 250 bars per Full-tier symbol) on top of
the same unbounded Bar_history. Result: Tiered pays Legacy's cache
shape PLUS its own bounded one.

Strategy readers only need ≤365 days of history (52-week RS line is
the binding lookback). Bars older than 365 days are dead weight in
both Legacy and Tiered.

This trim is **not** required to flip the Tiered loader default —
both strategies have the bug, and the flip is gated separately on the
292-symbol PV divergence (also tracked in PR #524). But fixing
Bar_history's monotonic growth delivers the design's "29 MB" memory
target for the first time and benefits Legacy as much as Tiered.

## Goal

Cap per-symbol `Bar_history` at `max_lookback_days` daily bars
(default 365 days = 52 weeks). End-of-run RSS on the 292-symbol
bull-crash should drop by ~3× for Legacy (from ~1.87 GB) and by
~2.5× for Tiered (from ~3.65 GB). Trade lists and final PV must
remain bit-identical to the pre-trim baseline (no strategy reader
should ever request bars older than `max_lookback_days`).

## Risks

1. **Some reader needs more than 365 days.** Audit every
   `Bar_history.daily_bars_for` and `weekly_bars_for` caller before
   adding the trim. The `weinstein_stops` support-floor primitive is
   explicitly called out in the .mli as a window-slicing caller —
   confirm its window is ≤365 days.
2. **Idempotency on replay.** The simulator can re-invoke the
   strategy on a replayed day. `accumulate` already handles this via
   strict-greater-than-last-date check; `trim_before` must be
   equally idempotent (calling it twice on the same `as_of` is a
   no-op, never re-adds trimmed bars).
3. **Parity gates.** `test_tiered_loader_parity` (`smoke/tiered-loader-parity.sexp`,
   7 symbols × 6 months) and the GHA `tiered-loader-ab` workflow
   must remain $0.00 PV delta after the trim lands.
4. **Configurability.** Make `max_lookback_days` a config field on
   `Weinstein_strategy.config` (default 365), not a hardcoded
   constant. Future tunability via `--override`.

## Sequence (each PR is independently reviewable, ≤500 LOC)

### PR 1 — `Bar_history.trim_before` primitive + tests
- Add `val trim_before : t -> as_of:Date.t -> max_lookback_days:int -> unit`
  to `bar_history.mli` with full doc comment.
- Implement: for each symbol, drop bars whose `date < as_of -
  max_lookback_days`. Idempotent.
- Tests in `test_bar_history.ml`: trim-then-add, trim-empty,
  trim-twice-same-as_of, trim-with-future-as_of (no-op),
  trim-with-zero-lookback (drops everything except today).
- No callers wired yet. Pure dead code. Branch
  `feat/backtest-bar-history-trim-primitive`.
- Estimated size: ~80 LOC including tests.

### PR 2 — Audit Bar_history readers + document binding window
- Doc-only PR. Add a new section
  `dev/notes/bar-history-readers-2026-04-24.md` listing every caller
  of `Bar_history.daily_bars_for` / `weekly_bars_for` /
  `Hashtbl.find` (direct map access) and their effective lookback.
- Confirm 365 days (52 weeks) is the binding window. If a caller
  needs more, surface it as a decision item — either make the
  default bigger or refactor that caller.
- Update `bar_history.mli` `daily_bars_for` doc comment to record
  the bounded-by-`max_lookback_days` invariant once integration
  lands.
- Branch `docs/bar-history-readers-audit`. Estimated size: ~150
  LOC of docs.

### PR 3 — Wire `trim_before` into the strategy (feature-flagged off)
- Add `bar_history_max_lookback_days : int option` to
  `Weinstein_strategy.config`. `None` = current behavior (no trim);
  `Some n` = call `Bar_history.trim_before` once per
  `on_market_close` with `as_of = today`, `max_lookback_days = n`.
- Default config: `None` (no behavior change).
- Tests: integration test with `Some 365` confirming trade list +
  final PV match the `None` baseline on
  `smoke/tiered-loader-parity.sexp`.
- Branch `feat/backtest-bar-history-trim-wired`. Estimated size:
  ~120 LOC.

### PR 4 — Local A/B with flag on, measure RSS savings, verify parity
- No code change. Just a measurement run + doc update.
- Run the same 292-symbol scoped A/B (per
  `backtest-scale.md` § Follow-up repro recipe) with `--override
  '(bar_history_max_lookback_days 365)'` and capture RSS.
- Expected: Legacy RSS drops from ~1.87 GB to ~600 MB; Tiered RSS
  drops from ~3.65 GB to ~1.5 GB. Trade lists bit-identical to
  baseline (parity gate).
- If parity holds, write findings into
  `backtest-scale.md` § Follow-up. If parity breaks, the audit in
  PR 2 missed a reader; iterate.

### PR 5 — Flip default to 365 days
- One-line change: `bar_history_max_lookback_days = Some 365` in
  `Weinstein_strategy.default_config`.
- Updates the `smoke/tiered-loader-parity.sexp` golden if needed
  (it shouldn't change since the parity test uses identical
  strategies on both sides).
- Updates the goldens-small / goldens-broad expected metrics if any
  changed (they shouldn't — readers don't reach that far back).
- Branch `feat/backtest-bar-history-trim-default-on`. Estimated
  size: ~30 LOC.

### PR 6 (optional) — Drop the `option` wrapper
- After PR 5 has been on main for some time and no one needed to
  flip it back to `None`, simplify the config field from
  `int option` to `int`. Remove dead `None` branch.
- Branch `feat/backtest-bar-history-trim-cleanup`. Estimated size:
  ~30 LOC.

## Acceptance per PR

Standard `feat-backtest` checklist applies (see
`.claude/agents/feat-backtest.md` § Acceptance Checklist). Per-PR
overrides:
- PR 1: must include all 5 test cases listed.
- PR 3: parity test on `smoke/tiered-loader-parity.sexp` must pass
  with both `None` and `Some 365`.
- PR 5: small-universe (302) bull-crash A/B must show bit-identical
  trade lists vs the baseline measured in PR 4.

## Decision items (need human or QC sign-off)

1. **Default lookback value.** 365 days is the obvious starting
   point given 52-week RS. Could be smaller (`Stops_runner` and the
   30-week MA only need ~210 days). Bigger window = more memory but
   safer against unknown future readers. Suggested 365 as a
   compromise; revisit after PR 2's audit.

2. **Trim cadence.** Per-day trim (in `on_market_close`) vs per-week
   trim (Friday only) vs per-promote trim (Tiered only, on Full
   promote). Per-day is the simplest and gives the steady RSS curve
   we want; per-week amortizes the work but keeps a 7-day buffer of
   stale bars. Suggested per-day; the cost (one Hashtbl iteration
   per day) is trivial.

3. **Where the trim call lives.** Inside `Weinstein_strategy.on_market_close`
   itself (uniform across Legacy and Tiered) vs inside the wrapper
   for Tiered only. Suggested inside `Weinstein_strategy` so Legacy
   benefits too — that's the whole point.

## Why this is multi-PR, not one

- **Audit before integration.** PR 2 must complete before PR 3 lands
  to avoid silently changing strategy outputs.
- **Reversibility.** PR 3's flag-default-off lets us revert
  instantly if a reader was missed in PR 2.
- **Measurement isolation.** PR 4's RSS numbers must come from a
  clean code state with the flag on, not bundled with implementation
  changes.
- **Each PR ≤500 LOC** per `feat-backtest` PR-sizing rules.
