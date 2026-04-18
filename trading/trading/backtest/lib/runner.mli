(** Load universe / AD bars / sector map, build a fresh Weinstein strategy, run
    the simulator, and return a [result] holding the summary plus the
    post-filter steps and trades. Pure orchestration — no output is written. *)

open Core

type result = {
  summary : Summary.t;
  round_trips : Trading_simulation.Metrics.trade_metrics list;
  steps : Trading_simulation_types.Simulator_types.step_result list;
      (** Steps filtered to [start_date..end_date] on real trading days only *)
  overrides : Sexp.t list;
      (** The override sexps used for this run, echoed into params.sexp *)
  stop_infos : Stop_log.stop_info list;
      (** Per-position stop info captured from strategy transitions. Each entry
          records the initial stop level, the stop level at exit, and the exit
          trigger (stop-loss, take-profit, etc.). Keyed by position_id; joinable
          with [round_trips] via symbol + entry_date. *)
}

val run_backtest :
  start_date:Date.t ->
  end_date:Date.t ->
  ?overrides:Sexp.t list ->
  ?sector_map_override:(string, string) Core.Hashtbl.t ->
  unit ->
  result
(** Run the simulator from [start_date - warmup] to [end_date], filter to the
    requested range and to trading days only, and return the [result].

    [overrides] are partial config sexps deep-merged into the default config in
    order. Each must be a record sexp with fields matching
    [Weinstein_strategy.config]. Example:
    {[
    [
      Sexp.of_string "((initial_stop_buffer 1.08))";
      Sexp.of_string "((stage_config ((ma_period 40))))";
    ]
    ]}

    [sector_map_override], when passed, replaces the sector-map normally loaded
    from [data/sectors.csv]. The backtest universe becomes exactly the keys of
    this hashtable. This is the wiring point for scenario-level universe
    selection (small / broad tiers). When [None] (the default), the runner falls
    back to [Sector_map.load] — pre-migration behaviour. *)
