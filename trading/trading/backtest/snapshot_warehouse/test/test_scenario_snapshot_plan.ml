open Core
open OUnit2
open Matchers
module Scenario = Scenario_lib.Scenario
module Plan = Scenario_snapshot_plan

(* A minimal Weinstein scenario built from sexp so we don't hand-construct the
   large [expected] record. start_date 2020-01-02, end_date 2024-12-31, a small
   pinned universe of two symbols. *)
let weinstein_scenario_sexp =
  {|
  ((name "test")
   (description "fixture")
   (period ((start_date 2020-01-02) (end_date 2024-12-31)))
   (universe_path "universes/small.sexp")
   (config_overrides ())
   (strategy Weinstein)
   (expected
    ((total_return_pct ((min -90.0) (max 5000.0)))
     (total_trades     ((min   0.0) (max  500.0)))
     (win_rate         ((min   0.0) (max  100.0)))
     (sharpe_ratio     ((min  -2.0) (max    5.0)))
     (max_drawdown_pct ((min   0.0) (max   95.0)))
     (avg_holding_days ((min   0.0) (max 5000.0))))))
  |}

let scenario () = Scenario.t_of_sexp (Sexp.of_string weinstein_scenario_sexp)

(* The auxiliary symbols every Weinstein run also stages bars for: the primary
   index, the 11 SPDR sector ETFs, and the 3 global macro indices. Hardcoded
   here so the test pins the contract independently of the runner internals. *)
let primary_index = "GSPC.INDX"

let sector_etfs =
  [
    "XLK"; "XLF"; "XLE"; "XLV"; "XLI"; "XLP"; "XLY"; "XLU"; "XLB"; "XLRE"; "XLC";
  ]

let global_indices = [ "GDAXI.INDX"; "N225.INDX"; "ISF.LSE" ]
let universe = [ "AAPL"; "MSFT" ]
let required = (universe @ (primary_index :: sector_etfs)) @ global_indices

(* Count how many of [required] appear in [all_symbols]. Using List.count keeps a
   single assert_that over the count (per .claude/rules/test-patterns.md). *)
let _count_present all_symbols =
  List.count required ~f:(fun s -> List.mem all_symbols s ~equal:String.equal)

let test_derive _ =
  let plan = Plan.derive ~scenario:(scenario ()) ~universe in
  assert_that plan
    (all_of
       [
         (* warmup_start = 2020-01-02 - 364 days = 2019-01-03 *)
         field
           (fun (p : Plan.t) -> p.warmup_start)
           (equal_to (Date.of_string "2019-01-03"));
         field
           (fun (p : Plan.t) -> p.end_date)
           (equal_to (Date.of_string "2024-12-31"));
         field (fun (p : Plan.t) -> p.benchmark_symbol) (equal_to primary_index);
         (* every required symbol (universe ∪ index ∪ ETFs ∪ global indices) is
            present *)
         field
           (fun (p : Plan.t) -> _count_present p.all_symbols)
           (equal_to (List.length required));
         (* no duplicates: raw length equals deduped length *)
         field
           (fun (p : Plan.t) -> List.length p.all_symbols)
           (equal_to
              (List.length
                 (List.dedup_and_sort required ~compare:String.compare)));
       ])

let suite =
  "scenario_snapshot_plan"
  >::: [ "derive computes warmup window + complete symbol set" >:: test_derive ]

let () = run_test_tt_main suite
