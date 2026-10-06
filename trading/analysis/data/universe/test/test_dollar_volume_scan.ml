open Core
open OUnit2
open Matchers
module Scan = Dollar_volume_measurement_lib.Dollar_volume_scan
module Report = Dollar_volume_measurement_lib.Dollar_volume_report
module DVB = Universe.Dollar_volume_basis
module BR = Universe.Composition_bar_reader
module CA = Corporate_actions

let _d = Date.of_string

let _params ?(liquidity_floor = 1e6) ?(liquidity_lookback_bars = 2) () :
    Scan.params =
  {
    years = [ 2018 ];
    trailing_window_days = 60;
    min_window_bars = 1;
    basis = DVB.true_dollars_config;
    liquidity_floor;
    liquidity_lookback_bars;
  }

let _bar date close volume : BR.bar =
  { date = _d date; close; adjusted_close = close; volume }

let test_governing_list_year _ =
  assert_that
    ( Scan.governing_list_year (_d "2019-05-31"),
      Scan.governing_list_year (_d "2019-06-03"),
      Scan.governing_list_year (_d "2020-01-15") )
    (equal_to ((2018, 2019, 2019) : int * int * int))

(* A 2:1 forward split on day 3. Volume restated: flat across the split. *)
let _split_bars ~after_volume =
  [
    _bar "2020-01-06" 100.0 1000.0;
    _bar "2020-01-07" 100.0 1000.0;
    _bar "2020-01-08" 50.0 after_volume;
    _bar "2020-01-09" 50.0 after_volume;
  ]

let _two_for_one : CA.split = { date = _d "2020-01-08"; factor = 2.0 }

(* Jump share 0 for flat (restated) volume, 1 for volume that doubles with the
   share count; [None] for a factor of 1 or a split dated on no bar. *)
let test_volume_jump_share _ =
  let p = { DVB.true_dollars_config with volume_check_bars = 2 } in
  assert_that
    ( DVB.volume_jump_share p (_split_bars ~after_volume:1000.0) _two_for_one,
      DVB.volume_jump_share p (_split_bars ~after_volume:2000.0) _two_for_one,
      DVB.volume_jump_share p
        (_split_bars ~after_volume:1000.0)
        { _two_for_one with factor = 1.0 },
      DVB.volume_jump_share p
        (_split_bars ~after_volume:1000.0)
        { _two_for_one with date = _d "2021-01-04" } )
    (equal_to
       ((Some 0.0, Some 1.0, None, None)
         : float option * float option * float option * float option))

(* Two weeks of one bar each. Stored dollar volume 2M/day passes a $1M floor;
   a later 4:1 split makes the true figure 0.5M/day, which fails it. The first
   week is outside a list the symbol belongs to, so only one week counts. *)
let test_liquidity_flips_counts_member_weeks _ =
  let bars =
    Array.of_list
      [
        _bar "2019-05-31" 20.0 100_000.0;
        _bar "2019-06-07" 20.0 100_000.0;
        _bar "2019-06-14" 20.0 100_000.0;
      ]
  in
  let splits : CA.split list = [ { date = _d "2025-01-02"; factor = 4.0 } ] in
  assert_that
    (Scan.liquidity_flips (_params ()) ~splits
       ~is_member:(fun y -> y = 2019)
       bars)
    (elements_are
       [
         equal_to
           ({ cal_year = 2019; weeks = 2; lost = 2; gained = 0 }
             : Scan.liquidity_year);
       ])

let _scan symbol scores : Scan.t =
  {
    symbol;
    has_splits_file = true;
    vendor_splits = [];
    applied = [];
    confirmed = [];
    volume_jump_shares = [];
    scores;
    rejected = [];
    liquidity = [];
  }

let _ys legacy truth : Scan.year_score list =
  [ { year = 2018; legacy = Some legacy; truth = Some truth } ]

(* A ranks first on the stored basis but third on true dollars. *)
let test_membership_row_diffs_bases _ =
  let scans =
    [
      _scan "A" (_ys 100.0 5.0);
      _scan "B" (_ys 50.0 50.0);
      _scan "C" (_ys 20.0 20.0);
    ]
  in
  let row =
    Report.membership_row
      ~committed:(Some (String.Set.of_list [ "A"; "B" ]))
      ~size:2 ~top_k:1 scans 2018
  in
  assert_that row
    (all_of
       [
         field
           (fun (r : Report.row) -> List.map r.entered ~f:(fun m -> m.symbol))
           (elements_are [ equal_to "C" ]);
         field
           (fun (r : Report.row) ->
             List.map r.left ~f:(fun m ->
                 (m.symbol, m.legacy_rank, m.true_rank)))
           (elements_are
              [
                equal_to
                  (("A", Some 1, Some 3) : string * int option * int option);
              ]);
         field
           (fun (r : Report.row) -> (r.committed, r.committed_out, r.drift_out))
           (equal_to ((2, 1, 0) : int * int * int));
         field
           (fun (r : Report.row) -> List.map r.true_top ~f:fst)
           (elements_are [ equal_to "B" ]);
       ])

let _contains substring = field (String.is_substring ~substring) (equal_to true)

(* The rendered report carries the specimen row, the jump-share histogram
   bin, the headline row and the gate-flip row built from the inputs. *)
let test_render_sections _ =
  let scan =
    {
      (_scan "A" (_ys 100.0 5.0)) with
      volume_jump_shares = [ 0.1 ];
      liquidity = [ { cal_year = 2018; weeks = 4; lost = 1; gained = 0 } ];
    }
  in
  let scans = [ scan; _scan "B" (_ys 50.0 50.0) ] in
  let row = Report.membership_row ~committed:None ~size:1 ~top_k:1 scans 2018 in
  assert_that
    (Report.render ~liquidity_floor:1e6 ~rows:[ row ] ~movers_size:1 ~movers_k:5
       ~scans
       ~specimens:[ ("AMZN", _d "2018-06-14", 20.0, 1.0) ])
    (all_of
       [
         _contains "| AMZN | 2018-06-14 | 20 | 1 | 20.000 |";
         _contains "| [0.00, 0.25) | 1 |";
         _contains "| 2018 | 1 | 1 | 1 | 100.0% | 0 | n/a | 0 |";
         _contains "| 2018 | 4 | 1 | 0 | 25.0% | 1 | 0 |";
       ])

(* Succeeds on the third attempt; gives up after three. *)
let test_retry_read _ =
  let calls = ref 0 in
  let flaky () =
    incr calls;
    if !calls >= 3 then Some !calls else None
  in
  let third = Scan.retry_read flaky in
  let never_calls = ref 0 in
  let never () =
    incr never_calls;
    None
  in
  let never_result : int option = Scan.retry_read never in
  assert_that
    (third, never_result, !never_calls)
    (equal_to ((Some 3, None, 3) : int option * int option * int))

let test_rejected_csv _ =
  let scan =
    { (_scan "X" []) with rejected = [ (_bar "1999-01-04" 2.0 3.0, 6.0) ] }
  in
  assert_that
    (Report.rejected_csv [ scan ])
    (equal_to
       "symbol,date,close,volume,true_dollar_volume\nX,1999-01-04,2,3,6\n")

let suite =
  "Dollar_volume_scan"
  >::: [
         "test_governing_list_year" >:: test_governing_list_year;
         "test_volume_jump_share" >:: test_volume_jump_share;
         "test_liquidity_flips_counts_member_weeks"
         >:: test_liquidity_flips_counts_member_weeks;
         "test_membership_row_diffs_bases" >:: test_membership_row_diffs_bases;
         "test_render_sections" >:: test_render_sections;
         "test_retry_read" >:: test_retry_read;
         "test_rejected_csv" >:: test_rejected_csv;
       ]

let () = run_test_tt_main suite
