(** Pure blend core for the deployable barbell overlay (gate #2).

    Reproduces the validated [blend.awk] math
    ([dev/backtest/barbell-grid-2026-06-20/blend.awk]) as a runnable
    sleeve-orchestration: maintain two capital sleeves — a FLOOR sleeve and an
    ENGINE sleeve — each compounding its own leg's daily return, and on a
    configurable cadence transfer {b cash only} between them so their NAV split
    returns to the [floor_weight : (1 - floor_weight)] target (positions are
    never touched — that is the rebalance's modelled effect on the combined NAV;
    each leg's own positions are owned by its own backtest run).

    At a daily cadence ({!Barbell_config.rebalance_stride_days} = 1) the blended
    NAV equals [blend.awk]'s constant-daily-weight blend exactly:
    [r(t) = w * floor_ret(t) + (1 - w) * engine_ret(t)], NAV compounded over the
    dates common to both legs. Coarser cadences let the weight drift between
    rebalances and track the daily curve within a small tolerance.

    Pure and self-contained — depends only on the two input equity curves and
    the config, so it is unit-testable without forking a backtest. Metric
    formulas (Sharpe, MaxDD, Calmar, Ulcer) match [blend.awk] line-for-line so
    the overlay is provably the same object the barbell grid validated. *)

open Core

type metrics = {
  total_return_pct : float;
      (** [(final_nav - 1) * 100] over the blended NAV path (starts at [1.0]).
      *)
  sharpe : float;
      (** [mean(r) / popstd(r) * sqrt(252)] over the per-step blended returns
          [r]; [0.0] when the population std is [0.0]. *)
  max_drawdown_pct : float;
      (** Worst peak-to-trough decline of the blended NAV, as a {b positive}
          percent ([0.0] = no decline, [25.0] = a 25% drop). *)
  calmar : float;
      (** Annualised return / [max_drawdown] (both as fractions); [0.0] when
          [max_drawdown] is [0.0]. Annualised return is
          [final_nav ^ (252 / n_returns) - 1]. *)
  ulcer_pct : float;
      (** [sqrt(mean(dd%^2))] over the per-step blended-NAV drawdown percents —
          penalises both depth and duration of drawdowns. *)
  n_points : int;
      (** Number of dates common to both legs (= the length of the blended NAV
          path). *)
}
[@@deriving sexp, eq, show]

type t = {
  nav_curve : (Date.t * float) list;
      (** The blended combined-NAV path, normalised to start at [1.0] on the
          first date common to both legs, in chronological order. One point per
          common date. *)
  metrics : metrics;
}

val blend_with_stride_days :
  floor_weight:float ->
  rebalance_stride_days:int ->
  floor_curve:(Date.t * float) list ->
  engine_curve:(Date.t * float) list ->
  t
(** Lower-level blend driven by an explicit calendar-day rebalance stride rather
    than the week-granular {!Barbell_config.t}. Used by {!blend} (passing
    [Barbell_config.rebalance_stride_days config]) and by callers that need the
    daily limit ([rebalance_stride_days = 1]) which exactly reproduces
    [blend.awk] but is not expressible in whole weeks. Semantics are otherwise
    identical to {!blend}. [rebalance_stride_days] is clamped to [>= 1]. *)

val blend :
  config:Barbell_config.t ->
  floor_curve:(Date.t * float) list ->
  engine_curve:(Date.t * float) list ->
  t
(** [blend ~config ~floor_curve ~engine_curve] runs the two-sleeve orchestration
    over the dates common to both legs and returns the blended NAV path +
    metrics. Thin wrapper over {!blend_with_stride_days} using
    [Barbell_config.rebalance_stride_days config] for the cadence.

    - [floor_curve] / [engine_curve] are each chronological [(date, value)]
      series (e.g. a run's [equity_curve.csv] as
      [(step.date, step.portfolio_value)]). They need not be the same length;
      the blend joins on the dates present in {b both} (matching [blend.awk]'s
      [if (d in f)]), preserving [engine_curve]'s order.
    - The FLOOR sleeve starts at [config.floor_weight] of total capital, the
      ENGINE sleeve at [1.0 -. config.floor_weight]. Each step, every sleeve
      grows by its leg's daily return [(v_i -. v_{i-1}) /. v_{i-1}].
    - Every {!Barbell_config.rebalance_stride_days} days (counted from the first
      common date) the sleeves are reset to the target split via a cash transfer
      that leaves total NAV unchanged. A stride of [1] reproduces [blend.awk]
      exactly.
    - Degenerate weights short-circuit to the corresponding single leg:
      [floor_weight = 1.0] returns the floor leg's own NAV curve (normalised),
      [floor_weight = 0.0] the engine leg's — so a no-op config yields the
      pure-engine result.
    - When fewer than two common dates exist the metrics are zeroed and
      [nav_curve] holds at most the single normalised point.

    Ignores [config.enable] — the caller (the runner) decides whether to invoke
    the overlay at all; [blend] always blends the curves it is given. *)
