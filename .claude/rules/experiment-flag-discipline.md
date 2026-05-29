# Experiment flag discipline

Every new strategy mechanism lands behind a **default-off** config flag
(or a value defaulting to the no-op), becomes an **experiment axis** the
day it lands, and is **not wired into the default config** until it has
an **ACCEPT verdict in the experiment ledger**.

This codifies de-facto practice (E2 segmentation, the stage3 exit-margin
knob in #1362) so it is checkable. It is Gap E of the systematic
experiment-platform program (`dev/plans/experiment-platform-2026-05-29.md`).

## The three rules

1. **Default-off on merge.** A new mechanism's flag (e.g.
   `enable_laggard_rotation : bool [@sexp.default false]`) or its no-op
   value (e.g. `stage3_exit_margin_pct : float [@sexp.default 0.0]`)
   must default to the behaviour the system had *before* the mechanism
   existed. Merging the mechanism changes no backtest result until a
   spec explicitly flips the flag. Backward-compat is preserved on
   merge, always.

2. **An axis the day it lands.** The mechanism is only useful if it is
   searchable. The same PR (or its immediate follow-up) that adds the
   flag should make it expressible as a `Variant_matrix` axis — i.e.
   the flag is a real `Weinstein_strategy.config` field that
   `Overlay_validator.apply_overrides` resolves, so
   `((flag <name>) (values (true false)))` expands and validates.
   (`Variant_matrix` lives at
   `trading/trading/backtest/walk_forward/lib/variant_matrix.mli`.)

3. **No default-on without an ACCEPT.** A mechanism is wired into the
   default config (flipped on by default, or its no-op value changed)
   **only after** it earns an ACCEPT verdict in the experiment ledger —
   i.e. it survived walk-forward CV with proper best-of-N correction
   (Deflated Sharpe), not a single-window win. Until then it stays
   default-off and lives as an axis.

## Why

The 2026-05-29 hysteresis episode and the 2026-05-13 continuation
combined-axis rejection both came from promoting a mechanism on a
single-window win that did not generalise. The discipline forces every
mechanism through the same gate: land safe (default-off), search the
surface (axis), promote only on a ledger-backed ACCEPT.

It also keeps `main` always shippable — no half-wired mechanism ever
changes live/backtest behaviour silently, because the default is the
pre-existing no-op.

## What QC can check

For a PR that adds a strategy mechanism:

- **R1 — default-off.** The new `config` field carries a
  `[@sexp.default <no-op>]` and the no-op equals the prior behaviour.
  FAIL if a new mechanism is on by default with no ledger ACCEPT cited.
- **R2 — searchable.** The flag/knob is a real `Weinstein_strategy.config`
  field (not a hardcoded constant), so it routes through
  `Overlay_validator` and can be an axis. FAIL if the mechanism is
  gated by anything other than a config field.
- **R3 — promotion needs a verdict.** A PR that flips a default
  (default-off → default-on, or changes a no-op default value) must
  cite the ledger ACCEPT entry that justifies it. FAIL otherwise.

These are mechanical: grep the `config` record diff for the new field +
its `[@sexp.default ...]`; check the PR body for a ledger citation when
a default changes.
