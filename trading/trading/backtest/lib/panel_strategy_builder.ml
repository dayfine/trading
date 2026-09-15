(** Strategy dispatch for the panel runner — see [panel_strategy_builder.mli].
*)

open Core
module Spy_only = Weinstein_strategy.Spy_only_weinstein_strategy
module Sector_rotation = Weinstein_strategy.Sector_rotation_weinstein_strategy
module Breaker_spy = Weinstein_strategy.Breaker_spy_strategy

(* The tradable universe for the sector-rotation strategy when it opts into the
   scenario universe: every symbol with a snapshot (the keys of [ticker_sectors])
   except the benchmark, sorted for a deterministic order. Excluding the
   benchmark preserves the never-trade-the-benchmark invariant. *)
let _scenario_universe ~ticker_sectors ~benchmark_symbol : string list =
  Hashtbl.keys ticker_sectors
  |> List.filter ~f:(fun s -> not (String.equal s benchmark_symbol))
  |> List.sort ~compare:String.compare

(* Build the sector-rotation strategy instance. Extracted from [build]'s match
   arm so the arm stays a flat call and [build]'s nesting depth (and the file's
   average) stay within the linter limit. *)
let _build_sector_rotation ~ticker_sectors ~bar_reader ~k ~ma_period_weeks
    ~enable_macro_gate ~use_scenario_universe ~sector_cap =
  let benchmark_symbol = Sector_rotation.default_benchmark_symbol in
  (* Opt-in: trade the scenario's own universe instead of the SPDR default.
     [Option.some_if] yields [None] when off so [config_with] keeps the default
     — bit-identical to the pre-opt-in behaviour. *)
  let symbols =
    Option.some_if use_scenario_universe
      (_scenario_universe ~ticker_sectors ~benchmark_symbol)
  in
  (* The symbol→GICS-sector lookup the per-sector cap resolves through; wired
     unconditionally (cheap) but only consulted when [sector_cap] is set. *)
  let sector_of symbol = Hashtbl.find ticker_sectors symbol in
  let config =
    Sector_rotation.config_with ?symbols ~k ~ma_period_weeks ~enable_macro_gate
      ~sector_cap ~sector_of ()
  in
  Sector_rotation.make ~config ~bar_reader ()

(* A dated universe schedule is only honourable by a branch that screens the
   SCENARIO's universe. [Sector_rotation_weinstein] with
   [use_scenario_universe = true] trades every staged symbol — and on a
   scheduled run the staged set is the UNION of every list in the schedule
   ({!Scenario_lib.Universe_schedule.union_sector_map}) — so it would silently
   trade names the schedule has already dropped. Fail loudly instead.

   The remaining branches trade a symbol set the scenario's universe does not
   determine at all ([Bah_benchmark] / [Spy_only_weinstein] /
   [Breaker_spy_sleeve] are single-symbol; sector rotation with
   [use_scenario_universe = false] trades the SPDR sector-ETF default list), so
   for them a schedule is inapplicable rather than silently wrong — the same
   reason they already ignore [universe_path]. *)
let _reject_schedule_on_scenario_universe ~use_scenario_universe
    ~universe_membership_at =
  match (use_scenario_universe, universe_membership_at) with
  | true, Some _ ->
      failwith
        "Panel_strategy_builder: strategy_choice Sector_rotation_weinstein \
         with use_scenario_universe = true does not implement \
         universe_schedule (dated point-in-time membership) — it trades the \
         whole staged universe, which on a scheduled run is the UNION of every \
         list. Drop universe_schedule from the spec, or run this scenario \
         under the Weinstein strategy."
  | true, None | false, _ -> ()

let build ~ad_bars ~breadth_bars ~ticker_sectors ~config ~strategy_choice
    ~bar_reader ~audit_recorder ?fold_start_date ?universe_membership_at () =
  match (strategy_choice : Strategy_choice.t) with
  | Weinstein ->
      Weinstein_strategy.make ~ad_bars ~breadth_bars ~ticker_sectors ~bar_reader
        ~audit_recorder ?fold_start_date ?universe_membership_at config
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
      _reject_schedule_on_scenario_universe ~use_scenario_universe
        ~universe_membership_at;
      _build_sector_rotation ~ticker_sectors ~bar_reader ~k ~ma_period_weeks
        ~enable_macro_gate ~use_scenario_universe ~sector_cap
  | Breaker_spy_sleeve { symbol } ->
      let config = { Breaker_spy.default_config with symbol } in
      Breaker_spy.make ~config ~bar_reader ()
