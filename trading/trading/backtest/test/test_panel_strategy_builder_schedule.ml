(** {!Backtest.Panel_strategy_builder.build}'s handling of
    [?universe_membership_at] — the dated point-in-time membership predicate a
    scheduled run threads down from {!Scenario_lib.Universe_schedule}.

    Only the [Weinstein] branch screens the SCENARIO's universe, so only it can
    honour a schedule. The load-bearing case is
    [Sector_rotation_weinstein { use_scenario_universe = true; _ }]: it trades
    every staged symbol, and on a scheduled run the staged set is the UNION of
    every list in the schedule
    ({!Scenario_lib.Universe_schedule.union_sector_map}) — so silently ignoring
    the predicate there would trade names the schedule has already dropped.
    [build] must fail loudly instead.

    The remaining constructors trade a symbol set the scenario universe does not
    determine (single-symbol BAH / Spy-only / Breaker-spy; sector rotation on
    the SPDR default list), so a schedule is inapplicable rather than silently
    wrong and [build] must NOT raise on them — that is the half a blanket
    "reject everything non-Weinstein" guard would get wrong.

    Authority: [panel_strategy_builder.mli]'s [@param universe_membership_at];
    [dev/plans/pit-universe-migration-2026-09-14.md] §Step 3a. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Strategy_choice = Backtest.Strategy_choice
module Sector_rotation = Weinstein_strategy.Sector_rotation_weinstein_strategy

let _universe = [ "AAPL"; "MSFT" ]

(* Sector rotation's benchmark is excluded from the tradable set, so it is
   staged alongside the universe for the [use_scenario_universe] branch to have
   something to exclude. *)
let _ticker_sectors () =
  let tbl = Hashtbl.create (module String) in
  List.iter _universe ~f:(fun s ->
      Hashtbl.set tbl ~key:s ~data:"Information Technology");
  Hashtbl.set tbl ~key:Sector_rotation.default_benchmark_symbol ~data:"Index";
  tbl

let _sector_rotation ~use_scenario_universe : Strategy_choice.t =
  Sector_rotation_weinstein
    {
      k = 1;
      ma_period_weeks = 30;
      enable_macro_gate = false;
      use_scenario_universe;
      sector_cap = None;
    }

(* [build] returns a first-class module, so the rejection is an exception rather
   than a [Result]. Project it to the message (or a sentinel) for assertion. *)
let _build_outcome ?universe_membership_at ~strategy_choice () =
  Or_error.try_with (fun () ->
      Backtest.Panel_strategy_builder.build ~ad_bars:[] ~breadth_bars:[]
        ~ticker_sectors:(_ticker_sectors ())
        ~config:
          (Weinstein_strategy.default_config ~universe:_universe
             ~index_symbol:"SPY")
        ~strategy_choice ~bar_reader:(Bar_reader.empty ())
        ~audit_recorder:Weinstein_strategy.Audit_recorder.noop
        ?universe_membership_at ())
  |> Result.error
  |> Option.value_map ~default:"<no exception>" ~f:Error.to_string_hum

let _admits_everything (_ : string) (_ : Date.t) = true

(** The rejection: sector rotation on the scenario's own universe cannot honour
    a schedule, so [build] raises with a message naming both the strategy choice
    and [universe_schedule]. *)
let test_sector_rotation_on_scenario_universe_rejects_schedule _ =
  assert_that
    (_build_outcome
       ~strategy_choice:(_sector_rotation ~use_scenario_universe:true)
       ~universe_membership_at:_admits_everything ())
    (all_of
       [
         contains_substring "Sector_rotation_weinstein";
         contains_substring "universe_schedule";
       ])

(** Same branch, no predicate: the pre-schedule path is untouched. *)
let test_sector_rotation_on_scenario_universe_without_schedule_builds _ =
  assert_that
    (_build_outcome
       ~strategy_choice:(_sector_rotation ~use_scenario_universe:true)
       ())
    (equal_to "<no exception>")

(** [use_scenario_universe = false] trades the SPDR sector-ETF default list, not
    the scenario's universe, so a schedule is inapplicable there and must not
    raise. *)
let test_sector_rotation_on_default_list_ignores_schedule _ =
  assert_that
    (_build_outcome
       ~strategy_choice:(_sector_rotation ~use_scenario_universe:false)
       ~universe_membership_at:_admits_everything ())
    (equal_to "<no exception>")

(** A single-symbol branch: the scenario universe does not determine what it
    trades, so the predicate is ignored without raising. *)
let test_single_symbol_branch_ignores_schedule _ =
  assert_that
    (_build_outcome
       ~strategy_choice:(Bah_benchmark { symbol = "SPY" })
       ~universe_membership_at:_admits_everything ())
    (equal_to "<no exception>")

(** The branch that DOES honour the schedule builds normally with it. *)
let test_weinstein_branch_accepts_schedule _ =
  assert_that
    (_build_outcome ~strategy_choice:Weinstein
       ~universe_membership_at:_admits_everything ())
    (equal_to "<no exception>")

let suite =
  "panel_strategy_builder_schedule_tests"
  >::: [
         "sector rotation on the scenario universe rejects a schedule"
         >:: test_sector_rotation_on_scenario_universe_rejects_schedule;
         "sector rotation on the scenario universe still builds without one"
         >:: test_sector_rotation_on_scenario_universe_without_schedule_builds;
         "sector rotation on the SPDR default list ignores a schedule"
         >:: test_sector_rotation_on_default_list_ignores_schedule;
         "a single-symbol branch ignores a schedule"
         >:: test_single_symbol_branch_ignores_schedule;
         "the Weinstein branch accepts a schedule"
         >:: test_weinstein_branch_accepts_schedule;
       ]

let () = run_test_tt_main suite
