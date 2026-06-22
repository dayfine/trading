(** Floor-weight axis for the deployable barbell overlay (gate #2, R2
    completion).

    Makes {!Barbell_config.t}'s [floor_weight] a {b searchable surface}: declare
    a list of weights to compare (e.g. [0.20; 0.30; 0.40]) and expand it into
    one cell per weight, each carrying a resolved {!Barbell_config.t} and a
    deterministic label — then evaluate every cell into a
    [(label, weight, metrics)] row, the comparison table a tuning session reads.

    {b Why a barbell-local axis rather than a {!Backtest.Variant_matrix} cell.}
    {!Backtest.Variant_matrix} validates every axis override against the
    canonical {!Weinstein_strategy.config} via
    [Overlay_validator.apply_overrides] at expansion time. But [floor_weight]
    lives in a {e separate} {!Barbell_config.t} and the overlay runs through
    {!Barbell_runner.run}, not the walk-forward / variant-matrix path — so a
    [(barbell floor_weight)] override would fail that validation (it is not a
    [Weinstein_strategy.config] field). This module is the faithful in-scope
    equivalent of an axis scoped to {!Barbell_config}: same "declare axis →
    expand to cells → evaluate to a searchable surface" ergonomics, validated
    against {!Barbell_config.validate} rather than [Overlay_validator]. See
    [dev/plans/barbell-floor-weight-axis-2026-06-22.md].

    Pure and self-contained: the expansion and the table builder take a
    blend-thunk (so the table is unit-testable without forking a backtest, the
    same pure/executable split {!Barbell_runner} and
    {!Backtest.Rolling_start_runner} use). The executable
    [barbell_floor_sweep_runner] wires the thunk to a real
    {!Barbell_blend.blend} over two legs run once.

    Default-off per [.claude/rules/experiment-flag-discipline.md]: enumerating
    weights flips no default; the axis is only realised when a session opts into
    running the sweep, and [floor_weight = 0.0] remains a valid (no-op = pure
    engine) cell. Promoting any weight to the default is a separate,
    ledger-gated decision (R3 / [.claude/rules/promotion-confirmation.md]). *)

type axis = {
  floor_weights : float list;
      (** The [floor_weight] values to search, each in [[0.0, 1.0]]. Order is
          irrelevant — {!cells} sorts ascending. Must be non-empty and contain
          no duplicates. *)
  rebalance_weeks : int;
      (** The rebalance cadence shared by every cell (only [floor_weight] varies
          across the surface). Must be [>= 1]; see
          {!Barbell_config.rebalance_weeks}. *)
}
[@@deriving sexp, eq, show]
(** A floor-weight axis declaration: a list of weights to compare at a fixed
    rebalance cadence. Mirrors a single-axis {!Backtest.Variant_matrix.t} scoped
    to {!Barbell_config}. *)

type cell = {
  label : string;
      (** Deterministic compact label for the cell, [Printf]-formatted as
          ["floor_weight=0.30"] (two decimals) — the row key in the surface. *)
  config : Barbell_config.t;
      (** The resolved overlay config for this cell: [enable = true], this
          cell's [floor_weight], and the axis's shared [rebalance_weeks]. Passes
          {!Barbell_config.validate}. *)
}
[@@deriving sexp, eq, show]
(** One point on the searchable surface: a labelled {!Barbell_config.t}
    differing from its neighbours only in [floor_weight]. *)

val cells : axis -> cell list
(** [cells axis] expands [axis] into one {!cell} per weight, in
    {b ascending weight} order (so the surface reads low→high floor). Each
    cell's [config] is
    [{ enable = true; floor_weight; rebalance_weeks = axis.rebalance_weeks }].

    @raise Invalid_argument
      if [axis.floor_weights] is empty or contains duplicates, if
      [axis.rebalance_weeks < 1], or if any resulting {!Barbell_config.t} fails
      {!Barbell_config.validate} (a weight outside [[0,1]]) — loudly, mirroring
      {!Backtest.Variant_matrix.expand} raising on an invalid axis rather than
      silently producing a degenerate cell. *)

type row = {
  label : string;  (** The cell's {!cell.label}. *)
  floor_weight : float;  (** The cell's [floor_weight]. *)
  metrics : Barbell_blend.metrics;
      (** The blend metrics for this cell, from the supplied blend thunk. *)
}
[@@deriving sexp, eq, show]
(** One row of the comparison surface: a cell's label + weight paired with its
    evaluated blend metrics. *)

val metrics_table :
  axis -> blend:(Barbell_config.t -> Barbell_blend.metrics) -> row list
(** [metrics_table axis ~blend] expands [axis] via {!cells} and evaluates each
    cell's [config] through [blend], returning one {!row} per cell in
    ascending-weight order — the searchable surface.

    [blend] is the per-cell evaluator: the executable supplies
    [fun config -> (Barbell_blend.blend ~config ~floor_curve
     ~engine_curve).metrics] over two legs run once (only the blend weight
    varies, so the legs need not re-run per cell). A test supplies a
    deterministic stub.

    @raise Invalid_argument from {!cells} on an invalid axis. *)
