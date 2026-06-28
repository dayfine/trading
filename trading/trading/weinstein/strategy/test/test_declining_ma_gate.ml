(** Unit tests for the declining-MA long-entry gate
    ({!Declining_ma_gate.filter}).

    - [reject = false] (default) → identity: every candidate retained, so the
      entry candidate list is bit-identical to prior behaviour.
    - [reject = true] → drop Long candidates whose stage MA direction is
      [Declining] (misclassified Stage-2 / counter-trend bounce); keep
      rising/flat-MA Longs and all Shorts (a declining MA is correct for a
      Stage-4 short). *)

open OUnit2
open Core
open Matchers
open Weinstein_types

let reject_declining_ma_longs = Declining_ma_gate.filter

(* Minimal [scored_candidate] with a chosen side + MA direction. Only [side] and
   [analysis.stage.ma_direction] are load-bearing for the gate; the rest are
   inert placeholders. *)
let _make ~ticker ~side ~ma_direction : Screener.scored_candidate =
  let base =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
      ~bars:[] ~benchmark_bars:[] ~prior_stage:None
      ~as_of_date:(Date.of_string "2024-01-01")
  in
  {
    ticker;
    analysis = { base with stage = { base.stage with ma_direction } };
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Neutral;
        stage = Stage2 { weeks_advancing = 5; late = false };
      };
    grade = C;
    score = 0;
    suggested_entry = 50.0;
    suggested_stop = 46.0;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let candidates () =
  [
    _make ~ticker:"LONG_RISING" ~side:Trading_base.Types.Long
      ~ma_direction:Rising;
    _make ~ticker:"LONG_DECLINING" ~side:Trading_base.Types.Long
      ~ma_direction:Declining;
    _make ~ticker:"SHORT_DECLINING" ~side:Trading_base.Types.Short
      ~ma_direction:Declining;
  ]

let tickers cs =
  List.map cs ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(* reject = false → no-op: all three retained, in order. *)
let test_default_is_noop _ =
  assert_that
    (tickers (reject_declining_ma_longs ~reject:false (candidates ())))
    (elements_are
       [
         equal_to "LONG_RISING";
         equal_to "LONG_DECLINING";
         equal_to "SHORT_DECLINING";
       ])

(* reject = true → drop only the declining-MA Long; keep rising-MA Long + short. *)
let test_drops_declining_longs_only _ =
  assert_that
    (tickers (reject_declining_ma_longs ~reject:true (candidates ())))
    (elements_are [ equal_to "LONG_RISING"; equal_to "SHORT_DECLINING" ])

let suite =
  "declining_ma_gate"
  >::: [
         "default is a no-op" >:: test_default_is_noop;
         "drops declining-MA longs only" >:: test_drops_declining_longs_only;
       ]

let () = run_test_tt_main suite
