(** Strategy dispatch for the panel runner — see [panel_strategy_builder.mli].
*)

open Core
module Spy_only = Weinstein_strategy.Spy_only_weinstein_strategy
module Sector_rotation = Weinstein_strategy.Sector_rotation_weinstein_strategy

(* The tradable universe for the sector-rotation strategy when it opts into the
   scenario universe: every symbol with a snapshot (the keys of [ticker_sectors])
   except the benchmark, sorted for a deterministic order. Excluding the
   benchmark preserves the never-trade-the-benchmark invariant. *)
let _scenario_universe ~ticker_sectors ~benchmark_symbol : string list =
  Hashtbl.keys ticker_sectors
  |> List.filter ~f:(fun s -> not (String.equal s benchmark_symbol))
  |> List.sort ~compare:String.compare

let build ~ad_bars ~ticker_sectors ~config ~strategy_choice ~bar_reader
    ~audit_recorder =
  match (strategy_choice : Strategy_choice.t) with
  | Weinstein ->
      Weinstein_strategy.make ~ad_bars ~ticker_sectors ~bar_reader
        ~audit_recorder config
  | Bah_benchmark { symbol } ->
      Trading_strategy.Bah_benchmark_strategy.make { symbol }
  | Spy_only_weinstein { symbol; ma_period_weeks; enable_stage4_short } ->
      let config =
        Spy_only.config_with ~symbol ~enable_stage4_short ~ma_period_weeks ()
      in
      Spy_only.make ~config ~bar_reader ()
  | Sector_rotation_weinstein
      {
        k;
        ma_period_weeks;
        enable_macro_gate;
        use_scenario_universe;
        sector_cap;
      } ->
      let benchmark_symbol = Sector_rotation.default_benchmark_symbol in
      (* Opt-in: trade the scenario's own universe instead of the SPDR default.
         Omit [?symbols] entirely when off so [config_with] keeps the default —
         bit-identical to the pre-opt-in behaviour. *)
      let symbols =
        if use_scenario_universe then
          Some (_scenario_universe ~ticker_sectors ~benchmark_symbol)
        else None
      in
      (* The symbol→GICS-sector lookup the per-sector cap resolves through; wired
         unconditionally (cheap) but only consulted when [sector_cap] is set. *)
      let sector_of symbol = Hashtbl.find ticker_sectors symbol in
      let config =
        Sector_rotation.config_with ?symbols ~k ~ma_period_weeks
          ~enable_macro_gate ~sector_cap ~sector_of ()
      in
      Sector_rotation.make ~config ~bar_reader ()
