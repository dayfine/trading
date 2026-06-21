(** Configuration for the deployable barbell overlay (gate #2).

    The barbell runs two independent strategy legs on split capital — a FLOOR
    leg (typically [Spy_only_weinstein], SPY 30wk long/flat) and an ENGINE leg
    (the full Weinstein Cell-E strategy) — and periodically rebalances cash
    between them so their NAV split returns to a constant
    [floor_weight : (1 - floor_weight)] target. See
    [dev/plans/barbell-deployable-overlay-2026-06-21.md] (Option A — sleeve
    orchestration) and [dev/backtest/barbell-grid-2026-06-20/blend.awk] (the
    validated daily-return blend this overlay reproduces).

    Every field is a no-op at its default per
    [.claude/rules/experiment-flag-discipline.md]: with [enable] [false] and
    [floor_weight] [0.0] a barbell run is byte-identical to a pure-engine run.
    The record is [sexp]-derivable so each field is expressible as a
    {!Backtest.Variant_matrix}-style axis (R2) — nothing here is a hardcoded
    constant. No default is flipped on: the documented promotion target is a
    light floor [~0.30-0.40] ([dev/backtest/engine-edge-1998-2026/FINDINGS.md]),
    but that flip is a separate, ledger-gated decision. *)

open Core

type t = {
  enable : bool; [@sexp.default false]
      (** Master switch. [false] (default) means the overlay is inert — callers
          run a single (engine) leg exactly as before. [true] activates the
          two-sleeve orchestration + rebalance. Default-off per R1. *)
  floor_weight : float; [@sexp.default 0.0]
      (** Target fraction of total capital allocated to the FLOOR leg, in
          [[0.0, 1.0]]. The ENGINE leg gets [1.0 -. floor_weight]. At each
          rebalance point cash is transferred so the two sleeves' NAVs return to
          this split (positions are never touched). [0.0] (default) = pure
          engine (no floor) = the pre-overlay no-op; [1.0] = pure floor. The
          validated light-floor target is [~0.30-0.40] but is NOT the default —
          promoting it is a separate ledger-gated decision per R3. *)
  rebalance_weeks : int; [@sexp.default 1]
      (** Rebalance cadence in weeks. [1] (default) rebalances every week;
          internally the overlay rebalances every [rebalance_weeks * 7] calendar
          days of the blended series. A daily cadence (expressed by the runner
          via {!rebalance_stride_days} = 1) reproduces [blend.awk]'s
          constant-daily-weight blend exactly; weekly / monthly cadences track
          it within a small drift while transferring cash less often. Must be
          [>= 1]. *)
}
[@@deriving sexp, eq, show]

val default : t
(** The fully inert configuration: [enable = false], [floor_weight = 0.0],
    [rebalance_weeks = 1]. A barbell run under this config produces the
    pure-engine result. *)

val rebalance_stride_days : t -> int
(** [rebalance_stride_days t] is the rebalance cadence converted to calendar
    days: [t.rebalance_weeks * 7], clamped to a minimum of [1]. The blend core
    rebalances the two sleeves to the target split every this-many days of the
    blended series. A stride of [1] is the daily-rebalance limit that reproduces
    [blend.awk] exactly. *)

val validate : t -> (unit, string) Result.t
(** [validate t] checks the invariants the blend core relies on: [floor_weight]
    in [[0.0, 1.0]] and [rebalance_weeks >= 1]. Returns [Error msg] describing
    the first violated invariant, [Ok ()] otherwise. The inert {!default}
    validates. *)
