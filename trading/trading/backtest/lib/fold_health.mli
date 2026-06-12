(** Degenerate-fold detector for a single backtest run.

    A backtest can complete "successfully" (no exception, a written
    [summary.sexp]) yet produce a result that is silently garbage. The
    motivating case (A2, 2026-06-12): a rolling-start fold whose 210-day warmup
    window spanned the GFC crash entered positions {b during warmup}, took a
    catastrophic loss before the measurement window opened, and then reported a
    flat in-window equity curve pinned at ~35% of initial capital with
    {b zero in-window round-trips} — because every entry/exit pair straddled the
    warmup→window boundary and so could not be paired by the in-window
    round-trip extractor. The run "passed" its scenario range checks while
    describing nothing real.

    This module is a {b pure, additive guard}: given a run's terminal facts it
    returns a list of {!finding}s naming each tripped invariant. It changes no
    strategy or simulator behaviour and computes no new backtest — it only reads
    facts already in the {!Summary.t} (plus the equity-curve series). Callers
    (the scenario runner) surface the findings loudly so the whole class of
    silent-garbage folds is caught at the reporting boundary rather than
    propagating into a dispersion matrix.

    Every threshold is a field of {!config} (no magic numbers);
    {!default_config} encodes the values calibrated against the A2 repro. *)

type config = {
  min_steps_for_check : int;
      (** Only evaluate the zero-round-trip / flat-equity invariants on runs
          with at least this many in-window steps. A genuinely short window (a
          handful of trading days) can legitimately have no round-trips, so the
          guard stays silent below this floor to avoid false positives on tiny
          folds. *)
  flat_equity_min_distinct_ratio : float;
      (** A run is "flat" when the count of {e distinct} equity-curve values,
          divided by the number of equity-curve points, is at or below this
          ratio. A healthy multi-month run moves its NAV on most days; an
          all-but-constant curve (the frozen-mark signature) sits near
          [1 / n_points]. In [[0.0, 1.0]]. *)
  depleted_abs_return_threshold : float;
      (** A run is "depleted/inflated" when [|final/initial - 1|] meets or
          exceeds this fraction (e.g. [0.5] = NAV ended at least 50% away from
          the starting stake). Combined with zero round-trips and a flat curve,
          a large terminal move that no in-window trade explains is the
          warmup-leak signature. A non-negative fraction. *)
  max_stuck_held_positions : int;
      (** Divergence guard (#1553): the largest tolerated gap between the count
          of {e open portfolio positions} and the count of
          {e strategy positions still under active stop evaluation}. A position
          the portfolio holds but the strategy no longer monitors (e.g. stuck in
          [Exiting] after a rejected exit fill, so the stop machinery — which
          only re-evaluates [Holding] — never re-fires) is a terminally-stuck
          zombie that rode an adverse move unbounded. A gap strictly greater
          than this count trips {!Stuck_held_positions}. Default [0]: every open
          position must be accounted for under stop evaluation. A non-negative
          count. *)
}
[@@deriving sexp, eq]

val default_config : config
(** Thresholds calibrated against the A2 repro (2009-06-26 start,
    top-3000-2000): [min_steps_for_check = 60] (≈ a quarter of trading days),
    [flat_equity_min_distinct_ratio = 0.05] (≤5% distinct NAV values = flat),
    [depleted_abs_return_threshold = 0.5] (≥50% terminal move),
    [max_stuck_held_positions = 0] (every open position must be under stop
    evaluation). These are the defaults the scenario runner uses; callers may
    override for stricter or looser gating. *)

type finding =
  | Zero_round_trips_over_long_window of { n_steps : int }
      (** [n_steps] in-window steps (≥ [min_steps_for_check]) produced zero
          round-trips: no entry/exit pair landed entirely inside the measurement
          window. Strongly suggests positions were opened during the warmup
          window and never cleanly round-tripped in-window. *)
  | Flat_equity_curve of { n_points : int; n_distinct : int }
      (** The equity curve has [n_distinct] distinct NAV values across
          [n_points] points — at/below [flat_equity_min_distinct_ratio]. The NAV
          is effectively frozen, the signature of held positions stuck on cached
          / avg-cost marks. *)
  | Unexplained_terminal_move of { total_return_pct : float }
      (** Terminal NAV moved [total_return_pct]% from the starting stake (≥
          [depleted_abs_return_threshold]) while the run also showed zero
          in-window round-trips — i.e. a large P&L swing that no in-window trade
          accounts for (warmup-window leak). *)
  | Stuck_held_positions of { n_open_positions : int; n_stop_eligible : int }
      (** Portfolio↔strategy divergence (#1553): the portfolio holds
          [n_open_positions] open positions but only [n_stop_eligible] of them
          are under active strategy stop evaluation (the gap exceeds
          [max_stuck_held_positions]). The unmonitored remainder are terminally
          stuck — e.g. positions left in [Exiting] after a rejected exit fill,
          which the stop machinery never re-evaluates — and ride their adverse
          move unbounded. *)
[@@deriving sexp, eq]

val finding_to_string : finding -> string
(** A one-line human-readable rendering of [finding] for console / log output.
*)

val check :
  config:config ->
  initial_cash:float ->
  final_portfolio_value:float ->
  n_round_trips:int ->
  n_steps:int ->
  equity_curve:float list ->
  finding list
(** [check ~config ~initial_cash ~final_portfolio_value ~n_round_trips ~n_steps
     ~equity_curve] returns every degenerate-fold invariant the run trips, in a
    stable order (round-trips, flat-equity, terminal-move). An empty list means
    the run looks healthy on these axes.

    The three invariants and their guards:
    - {e Zero round-trips}: emitted only when
      [n_steps >= config.min_steps_for_check] and [n_round_trips = 0].
    - {e Flat equity}: emitted when [equity_curve] is non-empty and its distinct
      / total ratio is [<= config.flat_equity_min_distinct_ratio].
    - {e Unexplained terminal move}: emitted only when [n_round_trips = 0]
      {b and} [|final/initial - 1| >= config.depleted_abs_return_threshold] (so
      a healthy run that legitimately moved NAV via in-window trades is never
      flagged); a non-positive [initial_cash] suppresses it (return is
      undefined). *)

val check_divergence :
  config:config -> n_open_positions:int -> n_stop_eligible:int -> finding list
(** [check_divergence ~config ~n_open_positions ~n_stop_eligible] returns a
    singleton [Stuck_held_positions] finding when
    [n_open_positions - n_stop_eligible > config.max_stuck_held_positions], else
    the empty list (#1553). [n_open_positions] is the count of open positions in
    the end-of-run portfolio; [n_stop_eligible] is the count of strategy
    positions still under active stop evaluation (in the simulator's terms,
    positions in the [Holding] state). The two diverge exactly when a position
    the portfolio holds is no longer monitored by the strategy — the
    stuck-[Exiting] zombie signature.

    Kept separate from {!check} because the divergence inputs (the two position
    counts) come from the end-of-run portfolio + strategy state rather than the
    summary/equity-curve facts {!check} reads. Callers union the two finding
    lists. A negative gap (more eligible than open — should not occur) never
    trips. *)

val has_findings :
  config:config ->
  initial_cash:float ->
  final_portfolio_value:float ->
  n_round_trips:int ->
  n_steps:int ->
  equity_curve:float list ->
  bool
(** [has_findings ...] is [not (List.is_empty (check ...))] — a convenience for
    callers that only need the boolean "is this fold suspect?". Covers only the
    {!check} invariants, not {!check_divergence}. *)
