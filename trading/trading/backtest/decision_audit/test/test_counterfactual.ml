(** Unit tests for [Decision_audit.Counterfactual].

    Builds synthetic {!Screen_record.t} values plus an in-memory
    {!Weinstein_strategy.Bar_reader.t} with hand-built weekly [Daily_price]
    series so forward returns are known exactly. Covers: correct forward-return
    computation for a long and a short, [None] when the symbol has no bars / no
    bar at-or-after the screen date, and correct funded / near-miss partitioning
    \+ funded-wins dedup. *)

open OUnit2
open Core
open Matchers
module CF = Decision_audit.Counterfactual
module SR = Decision_audit.Screen_record
module TA = Backtest.Trade_audit
module Bar_reader = Weinstein_strategy.Bar_reader

let _date d = Date.of_string d
let screen_date = _date "2020-01-06" (* a Monday anchor *)
let _horizon = 4

(* A weekly bar [week_offset] weeks after the screen anchor. Volume / adjusted
   close are irrelevant to the forward return and fixed to dummies. *)
let _bar ~week_offset ~high ~low ~close =
  Types.Daily_price.make
    ~date:(Date.add_days screen_date (week_offset * 7))
    ~open_price:close ~high_price:high ~low_price:low ~close_price:close
    ~volume:1000 ~adjusted_close:close ()

(* Monotonically rising: base (first bar at/after screen) close = 100; over 4
   weeks the close climbs 100 -> 110 -> 120 -> 130. For h=4 a LONG forward
   return (continuation) = (130 - 100) / 100 = 0.30; a SHORT is sign-mirrored
   to -0.30. *)
let _rising_bars =
  [
    _bar ~week_offset:0 ~high:101.0 ~low:99.0 ~close:100.0;
    _bar ~week_offset:1 ~high:111.0 ~low:100.0 ~close:110.0;
    _bar ~week_offset:2 ~high:121.0 ~low:110.0 ~close:120.0;
    _bar ~week_offset:3 ~high:131.0 ~low:120.0 ~close:130.0;
  ]

let _funded ?(symbol = "AAPL") ?(score = 80) () : SR.funded_entry =
  {
    symbol;
    score;
    grade = Weinstein_types.A;
    stage = Weinstein_types.Stage2 { weeks_advancing = 2; late = false };
    weeks_advancing = Some 2;
    rs_value = Some 1.1;
    volume_ratio = Some 2.0;
    sector_name = "Tech";
  }

let _near ?(symbol = "AMD") ?(score = 70) ?(side = Trading_base.Types.Long)
    ?(reason = TA.Insufficient_cash) () : SR.near_miss =
  {
    symbol;
    side;
    score;
    grade = Weinstein_types.B;
    reason_skipped = reason;
    stage = Weinstein_types.Stage2 { weeks_advancing = 3; late = false };
    weeks_advancing = Some 3;
    rs_value = Some 1.0;
    volume_ratio = Some 1.5;
    sector_name = "Tech";
  }

let _screen ?(funded = []) ?(near_misses = []) () : SR.t =
  {
    screen_date;
    funded;
    near_misses;
    summary =
      {
        n_funded = List.length funded;
        n_near_miss = List.length near_misses;
        min_funded_score = None;
        max_nearmiss_score = None;
        inversion = false;
      };
  }

(* A reader that has the rising series for [symbol]s in [symbols] and nothing
   else. *)
let _reader symbols =
  Bar_reader.of_in_memory_bars
    (List.map symbols ~f:(fun s -> (s, _rising_bars)))

(* Long funded entry on the rising series: forward return = 0.30. *)
let test_long_forward_return _ =
  let bar_reader = _reader [ "AAPL" ] in
  assert_that
    (CF.compute
       [ _screen ~funded:[ _funded ~symbol:"AAPL" () ] () ]
       ~bar_reader ~horizon_weeks:_horizon)
    (elements_are
       [
         all_of
           [
             field
               (fun (c : CF.candidate_forward) -> c.symbol)
               (equal_to "AAPL");
             field
               (fun (c : CF.candidate_forward) -> c.is_funded)
               (equal_to true);
             field
               (fun (c : CF.candidate_forward) -> c.forward_return_pct)
               (is_some_and (float_equal 0.30));
           ];
       ])

(* Short near-miss on the SAME rising series: sign-mirrored to -0.30. *)
let test_short_forward_return_sign_flip _ =
  let bar_reader = _reader [ "TSLA" ] in
  assert_that
    (CF.compute
       [
         _screen
           ~near_misses:
             [ _near ~symbol:"TSLA" ~side:Trading_base.Types.Short () ]
           ();
       ]
       ~bar_reader ~horizon_weeks:_horizon)
    (elements_are
       [
         all_of
           [
             field
               (fun (c : CF.candidate_forward) -> c.symbol)
               (equal_to "TSLA");
             field
               (fun (c : CF.candidate_forward) -> c.is_funded)
               (equal_to false);
             field
               (fun (c : CF.candidate_forward) -> c.side)
               (equal_to Trading_base.Types.Short);
             field
               (fun (c : CF.candidate_forward) -> c.forward_return_pct)
               (is_some_and (float_equal (-0.30)));
             field
               (fun (c : CF.candidate_forward) -> c.reason_skipped)
               (is_some_and (equal_to TA.Insufficient_cash));
           ];
       ])

(* Symbol absent from the warehouse -> no bars -> forward_return_pct = None, but
   the candidate is still emitted (counted). *)
let test_missing_symbol_yields_none _ =
  let bar_reader = _reader [ "AAPL" ] in
  assert_that
    (CF.compute
       [ _screen ~funded:[ _funded ~symbol:"ZZZZ" () ] () ]
       ~bar_reader ~horizon_weeks:_horizon)
    (elements_are
       [
         all_of
           [
             field
               (fun (c : CF.candidate_forward) -> c.symbol)
               (equal_to "ZZZZ");
             field
               (fun (c : CF.candidate_forward) -> c.forward_return_pct)
               is_none;
           ];
       ])

(* A symbol whose only bars all precede the screen date -> no bar at/after the
   screen -> None. *)
let test_no_bar_at_or_after_screen_yields_none _ =
  let before =
    [
      _bar ~week_offset:(-3) ~high:210.0 ~low:190.0 ~close:200.0;
      _bar ~week_offset:(-1) ~high:215.0 ~low:198.0 ~close:205.0;
    ]
  in
  let bar_reader = Bar_reader.of_in_memory_bars [ ("OLD", before) ] in
  assert_that
    (CF.compute
       [ _screen ~funded:[ _funded ~symbol:"OLD" () ] () ]
       ~bar_reader ~horizon_weeks:_horizon)
    (elements_are
       [
         field (fun (c : CF.candidate_forward) -> c.forward_return_pct) is_none;
       ])

(* Funded ∪ near-miss partition: one funded + one distinct near-miss -> two
   candidates, correctly flagged. *)
let test_funded_and_near_miss_partitioned _ =
  let bar_reader = _reader [ "AAPL"; "AMD" ] in
  assert_that
    (CF.compute
       [
         _screen
           ~funded:[ _funded ~symbol:"AAPL" () ]
           ~near_misses:[ _near ~symbol:"AMD" () ]
           ();
       ]
       ~bar_reader ~horizon_weeks:_horizon)
    (all_of
       [
         field
           (fun cs -> List.count cs ~f:(fun c -> c.CF.is_funded))
           (equal_to 1);
         field
           (fun cs -> List.count cs ~f:(fun c -> not c.CF.is_funded))
           (equal_to 1);
       ])

(* A symbol that is BOTH funded and a near-miss on the same screen dedups toward
   the funded entry: exactly one candidate, flagged funded. *)
let test_dup_symbol_dedups_toward_funded _ =
  let bar_reader = _reader [ "AAPL" ] in
  assert_that
    (CF.compute
       [
         _screen
           ~funded:[ _funded ~symbol:"AAPL" () ]
           ~near_misses:[ _near ~symbol:"AAPL" () ]
           ();
       ]
       ~bar_reader ~horizon_weeks:_horizon)
    (elements_are
       [
         all_of
           [
             field
               (fun (c : CF.candidate_forward) -> c.symbol)
               (equal_to "AAPL");
             field
               (fun (c : CF.candidate_forward) -> c.is_funded)
               (equal_to true);
           ];
       ])

let suite =
  "Decision_audit.Counterfactual"
  >::: [
         "long forward return" >:: test_long_forward_return;
         "short forward return sign flip"
         >:: test_short_forward_return_sign_flip;
         "missing symbol yields None" >:: test_missing_symbol_yields_none;
         "no bar at/after screen yields None"
         >:: test_no_bar_at_or_after_screen_yields_none;
         "funded and near-miss partitioned"
         >:: test_funded_and_near_miss_partitioned;
         "dup symbol dedups toward funded"
         >:: test_dup_symbol_dedups_toward_funded;
       ]

let () = run_test_tt_main suite
