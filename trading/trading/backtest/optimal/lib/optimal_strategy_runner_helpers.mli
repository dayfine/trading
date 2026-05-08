(** Pure computation helpers extracted from [Optimal_strategy_runner].

    Provides the Friday-calendar, per-symbol analysis, sector-context, and
    candidate-scan functions that the runner composes into its pipeline. All
    functions here are pure or only read from [snapshot_callbacks]. *)

open Core

val index_symbol : string
(** The benchmark index ticker used for weekly benchmark bars and snapshot
    construction (["GSPC.INDX"]). *)

val bar_lookback_weeks : int
(** Weekly-bar lookback used for per-Friday analysis and forward-outlook
    memoisation. Large enough to cover the 30-week MA plus breakout-base
    lookback in [Stock_analysis.default_config]. *)

val friday_on_or_before : Date.t -> Date.t
(** [friday_on_or_before d] returns the most recent Friday on or before [d]. *)

val fridays_in_range : start:Date.t -> end_:Date.t -> Date.t list
(** [fridays_in_range ~start ~end_] returns all Fridays in [[start, end_]],
    inclusive. The list is ascending and drives the per-week scan loop. *)

val analyze_symbol_on_friday :
  snapshot_callbacks:Snapshot_runtime.Snapshot_callbacks.t ->
  friday:Date.t ->
  stock_config:Stock_analysis.config ->
  bar_lookback:int ->
  string ->
  Stock_analysis.t option
(** [analyze_symbol_on_friday ~snapshot_callbacks ~friday ~stock_config
     ~bar_lookback symbol] runs [Stock_analysis.analyze] for [symbol] on
    [friday]. Returns [None] when there are not enough weekly bars (e.g. early
    in the run or a newly-listed symbol). *)

val build_sector_context_map :
  (string, string) Hashtbl.t -> (string, Screener.sector_context) Hashtbl.t
(** [build_sector_context_map sectors] converts a flat symbol-to-sector-name
    table into a [Screener.sector_context] map using [Neutral] rating and a
    [Stage2] pass-through. Sector caps are enforced separately by the filler's
    [max_sector_concentration] config. *)

val build_forward_table :
  snapshot_callbacks:Snapshot_runtime.Snapshot_callbacks.t ->
  fridays:Date.t list ->
  stage_config:Stage.config ->
  bar_lookback:int ->
  universe:string list ->
  (string, Outcome_scorer.weekly_outlook list) Hashtbl.t
(** [build_forward_table ~snapshot_callbacks ~fridays ~stage_config
     ~bar_lookback ~universe] builds the per-symbol memoised outlook table
    (PR-1: optimal-strategy improvements 2026-05-01). Iterates [fridays] once
    per symbol; subsequent per-candidate scoring is an O(N_fridays) list slice.
*)

val scan_all_fridays :
  snapshot_callbacks:Snapshot_runtime.Snapshot_callbacks.t ->
  fridays:Date.t list ->
  universe:string list ->
  sector_map:(string, Screener.sector_context) Hashtbl.t ->
  stock_config:Stock_analysis.config ->
  scanner_config:Stage_transition_scanner.config ->
  bar_lookback:int ->
  macro_trend_table:(Date.t, Weinstein_types.market_trend) Hashtbl.t ->
  Optimal_types.candidate_entry list
(** [scan_all_fridays ...] runs [Stage_transition_scanner.scan_week] over every
    Friday in [fridays], emitting all [candidate_entry] records. The per-Friday
    [macro_trend] is looked up from [macro_trend_table]; Fridays absent from the
    table fall back to [Weinstein_types.Neutral]. *)
