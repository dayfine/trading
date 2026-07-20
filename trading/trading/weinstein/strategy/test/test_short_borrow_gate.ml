(** Unit tests for the [short_borrow_availability] short-entry gate (margin M3a).

    Pins the no-op-default contract and the gating behaviour of
    {!Weinstein_strategy.Short_borrow_gate.filter}:

    - [min_dollar_adv = 0.0] (default) → identity: every candidate is retained,
      so the entry candidate list is bit-identical to prior behaviour and every
      existing golden/baseline replays unchanged.
    - A positive floor drops {b short} candidates whose dollar-ADV is below it
      ("no borrow available"); long candidates are never affected.
    - A [None] dollar-ADV reading never drops a candidate. *)

open OUnit2
open Core
open Matchers
open Weinstein_types
module Short_borrow_gate = Weinstein_strategy.Short_borrow_gate

let _make_candidate ~ticker ~side : Screener.scored_candidate =
  {
    ticker;
    analysis =
      Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
        ~bars:[] ~benchmark_bars:[] ~prior_stage:None
        ~as_of_date:(Date.of_string "2024-01-01");
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Neutral;
        stage = Stage2 { weeks_advancing = 5; late = false };
      };
    grade = C;
    score = 0;
    suggested_entry = 20.0;
    suggested_stop = 21.6;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _short ~ticker = _make_candidate ~ticker ~side:Trading_base.Types.Short
let _long ~ticker = _make_candidate ~ticker ~side:Trading_base.Types.Long

(* Fixed ADV lookup: THIN trades $100k/day, THICK $5M/day, and NOREAD has no
   reading. *)
let adv_for = function
  | "THIN" -> Some 100_000.0
  | "THICK" -> Some 5_000_000.0
  | _ -> None

let tickers result = List.map result ~f:(fun c -> c.Screener.ticker)

let test_zero_floor_is_noop _ =
  let candidates = [ _short ~ticker:"THIN"; _short ~ticker:"THICK" ] in
  assert_that
    (tickers
       (Short_borrow_gate.filter ~min_dollar_adv:0.0 ~dollar_adv_for:adv_for
          candidates))
    (elements_are [ equal_to "THIN"; equal_to "THICK" ])

let test_floor_drops_illiquid_short_keeps_liquid _ =
  let candidates = [ _short ~ticker:"THIN"; _short ~ticker:"THICK" ] in
  assert_that
    (tickers
       (Short_borrow_gate.filter ~min_dollar_adv:1_000_000.0
          ~dollar_adv_for:adv_for candidates))
    (elements_are [ equal_to "THICK" ])

let test_floor_never_drops_longs _ =
  (* A LONG named THIN (below the floor) is retained — borrow is short-only. *)
  let candidates = [ _long ~ticker:"THIN"; _short ~ticker:"THIN" ] in
  assert_that
    (tickers
       (Short_borrow_gate.filter ~min_dollar_adv:1_000_000.0
          ~dollar_adv_for:adv_for candidates))
    (elements_are [ equal_to "THIN" ])

let test_missing_reading_keeps_short _ =
  (* NOREAD has no dollar-ADV reading → kept (a missing reading never drops). *)
  let candidates = [ _short ~ticker:"NOREAD" ] in
  assert_that
    (List.length
       (Short_borrow_gate.filter ~min_dollar_adv:1_000_000.0
          ~dollar_adv_for:adv_for candidates))
    (equal_to 1)

let () =
  run_test_tt_main
    ("short_borrow_gate"
    >::: [
           "zero floor is a no-op" >:: test_zero_floor_is_noop;
           "floor drops illiquid short, keeps liquid"
           >:: test_floor_drops_illiquid_short_keeps_liquid;
           "floor never drops longs" >:: test_floor_never_drops_longs;
           "missing reading keeps short" >:: test_missing_reading_keeps_short;
         ])
