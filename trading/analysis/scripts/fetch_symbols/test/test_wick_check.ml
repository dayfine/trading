open Core
open OUnit2
open Matchers
module W = Fetch_symbols_lib.Wick_check

let _bar ~date ~o ~h ~l ~c : Types.Daily_price.t =
  {
    date = Date.of_string date;
    open_price = o;
    high_price = h;
    low_price = l;
    close_price = c;
    volume = 1_000_000;
    adjusted_close = c;
    active_through = None;
  }

(* The three SPY lows from #3018's behavioral QC, against their stored copies:
   2009-06-02 87.53 vs 94.23, 2009-12-14 105.476 vs 111.13, 2002-08-08 80.54
   vs 87.80. Closes agree, so these are wicks, not a re-basing. *)
let _issue_pairs =
  [
    ("2002-08-08", 87.80, 80.54, 89.10);
    ("2009-06-02", 94.23, 87.53, 94.62);
    ("2009-12-14", 111.13, 105.476, 111.52);
  ]

let test_flags_the_reported_spy_lows _ =
  let stored =
    List.map _issue_pairs ~f:(fun (d, low, _, c) ->
        _bar ~date:d ~o:c ~h:(c +. 1.0) ~l:low ~c)
  in
  let fetched =
    List.map _issue_pairs ~f:(fun (d, _, bad, c) ->
        _bar ~date:d ~o:c ~h:(c +. 1.0) ~l:bad ~c)
  in
  let expect (d, low, bad, _) =
    equal_to
      ({
         date = Date.of_string d;
         field = Low;
         observed = bad;
         reference_value = low;
         reference = Stored;
         deviation_pct = (low -. bad) /. low;
       }
        : W.wick)
  in
  assert_that (W.check ~stored fetched)
    (all_of
       [
         field
           (fun (r : W.report) -> r.wicks)
           (elements_are (List.map _issue_pairs ~f:expect));
         field (fun (r : W.report) -> r.basis_changes) is_empty;
       ])

let test_ordinary_bars_are_accepted _ =
  let bars =
    [
      _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.5;
      _bar ~date:"2024-01-03" ~o:100.5 ~h:102.0 ~l:99.5 ~c:101.0;
    ]
  in
  assert_that
    (W.check ~stored:bars bars, W.check ~stored:[] bars)
    (equal_to
       ( ({ wicks = []; basis_changes = [] } : W.report),
         ({ wicks = []; basis_changes = [] } : W.report) ))

(* Strict threshold: exactly 5 % below the stored low is not flagged, 5.01 %
   is. *)
let test_threshold_boundary _ =
  let stored =
    [ _bar ~date:"2024-01-02" ~o:101.0 ~h:102.0 ~l:100.0 ~c:101.0 ]
  in
  let fetched low =
    [ _bar ~date:"2024-01-02" ~o:101.0 ~h:102.0 ~l:low ~c:101.0 ]
  in
  let count low = List.length (W.check ~stored (fetched low)).wicks in
  assert_that (count 95.0, count 94.99) (equal_to (0, 1))

let _w_date (w : W.wick) = w.date
let _w_field (w : W.wick) = w.field
let _w_reference (w : W.wick) = w.reference
let _w_reference_value (w : W.wick) = w.reference_value
let _w_deviation (w : W.wick) = w.deviation_pct

(* A matcher on one wick's field / reference / reference value / deviation. *)
let _wick_is ~field:f ~reference ~reference_value ~deviation =
  all_of
    [
      field _w_field (equal_to f);
      field _w_reference (equal_to reference);
      field _w_reference_value (float_equal reference_value);
      field _w_deviation (float_equal deviation);
    ]

let test_flags_a_high_anomaly _ =
  let stored = [ _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.5 ] in
  let fetched =
    [ _bar ~date:"2024-01-02" ~o:100.0 ~h:110.0 ~l:99.0 ~c:100.5 ]
  in
  let matcher =
    _wick_is ~field:W.High ~reference:W.Stored ~reference_value:101.0
      ~deviation:(9.0 /. 101.0)
  in
  assert_that (W.check ~stored fetched).wicks (elements_are [ matcher ])

(* No stored copy: the neighbour check flags a low far below both the body and
   the prior close, and leaves the first bar and an ordinary bar alone. *)
let test_missing_reference_uses_neighbours _ =
  let fetched =
    [
      _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:50.0 ~c:100.0;
      _bar ~date:"2024-01-03" ~o:100.0 ~h:102.0 ~l:90.0 ~c:101.0;
      _bar ~date:"2024-01-04" ~o:101.0 ~h:102.0 ~l:99.0 ~c:101.5;
    ]
  in
  let matcher =
    all_of
      [
        field _w_date (equal_to (Date.of_string "2024-01-03"));
        _wick_is ~field:W.Low ~reference:W.Neighbour ~reference_value:100.0
          ~deviation:0.10;
      ]
  in
  assert_that (W.check ~stored:[] fetched).wicks (elements_are [ matcher ])

(* A legitimate gap: the open is 15 % under the prior close, so the low that
   follows it is not a wick. *)
let test_gap_day_is_exempt _ =
  let fetched =
    [
      _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.0;
      _bar ~date:"2024-01-03" ~o:85.0 ~h:87.0 ~l:80.0 ~c:86.0;
    ]
  in
  assert_that (W.check ~stored:[] fetched).wicks is_empty

(* A 2:1 split re-based since the stored copy: the close halved too, so the
   date is a basis change and the halved low is not called a wick. *)
let test_split_is_a_basis_change_not_a_wick _ =
  let stored =
    [ _bar ~date:"2024-01-02" ~o:200.0 ~h:202.0 ~l:198.0 ~c:200.0 ]
  in
  let fetched =
    [ _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.0 ]
  in
  let change : W.basis_change =
    {
      date = Date.of_string "2024-01-02";
      stored_close = 200.0;
      fetched_close = 100.0;
    }
  in
  assert_that (W.check ~stored fetched)
    (equal_to ({ wicks = []; basis_changes = [ change ] } : W.report))

(* The rendered lines carry exactly the finding's fields — symbol, date, field,
   values, deviation — and nothing else (no URL, no token). *)
let test_render_lines _ =
  let stored =
    [ _bar ~date:"2009-06-02" ~o:94.62 ~h:95.62 ~l:94.23 ~c:94.62 ]
  in
  let fetched =
    [ _bar ~date:"2009-06-02" ~o:94.62 ~h:95.62 ~l:87.53 ~c:94.62 ]
  in
  let basis =
    W.check
      ~stored:[ _bar ~date:"2024-01-02" ~o:200.0 ~h:202.0 ~l:198.0 ~c:200.0 ]
      [ _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.0 ]
  in
  assert_that
    (W.render ~symbol:"SPY" (W.check ~stored fetched)
    @ W.render ~symbol:"X" basis)
    (equal_to
       [
         "WICK SPY 2009-06-02 low observed=87.5300 reference=94.2300 (stored) \
          deviation=7.11%";
         "BASIS X 2024-01-02 stored_close=200.0000 fetched_close=100.0000";
       ])

(* Two fetched bars, no stored copy: [prev_close] then the bar under test. *)
let _neighbour_wicks ~prev_close ~o ~h ~l ~c =
  (W.check ~stored:[]
     [
       _bar ~date:"2024-01-02" ~o:prev_close ~h:prev_close ~l:prev_close
         ~c:prev_close;
       _bar ~date:"2024-01-03" ~o ~h ~l ~c;
     ])
    .wicks

(* "Below BOTH the body and the prior close": each low below one reference by
   7.5 % but within 5 % of the other is not flagged. Either reference alone
   would flag it. *)
let test_neighbour_low_must_clear_both _ =
  assert_that
    ( _neighbour_wicks ~prev_close:97.0 ~o:100.0 ~h:102.0 ~l:92.5 ~c:101.0,
      _neighbour_wicks ~prev_close:100.0 ~o:97.0 ~h:100.0 ~l:92.5 ~c:99.0 )
    (equal_to (([], []) : W.wick list * W.wick list))

(* The neighbour high mirrors the low: flagged above max(body top, prior
   close) by more than the threshold, and not when it clears only one. *)
let test_neighbour_high_check _ =
  let flagged =
    _neighbour_wicks ~prev_close:100.0 ~o:100.0 ~h:110.0 ~l:99.0 ~c:101.0
  in
  let above_prev_only =
    _neighbour_wicks ~prev_close:100.0 ~o:100.0 ~h:108.0 ~l:99.0 ~c:105.0
  in
  let above_body_only =
    _neighbour_wicks ~prev_close:105.0 ~o:100.0 ~h:108.0 ~l:99.0 ~c:101.0
  in
  let matcher =
    _wick_is ~field:W.High ~reference:W.Neighbour ~reference_value:101.0
      ~deviation:(9.0 /. 101.0)
  in
  assert_that
    (flagged, above_prev_only @ above_body_only)
    (all_of [ field fst (elements_are [ matcher ]); field snd is_empty ])

(* Strict at every boundary: a neighbour low exactly 5 % under is not flagged;
   an open exactly 5 % from the prior close is not a gap (so its 15.8 % flush is
   flagged); a close exactly 5 % from the stored close is not a re-basing (so
   its 9.1 % low is flagged as a wick). *)
let test_strict_at_neighbour_gap_and_basis_boundaries _ =
  let neighbour =
    _neighbour_wicks ~prev_close:100.0 ~o:100.0 ~h:100.0 ~l:95.0 ~c:100.0
  in
  let gap =
    _neighbour_wicks ~prev_close:100.0 ~o:95.0 ~h:96.0 ~l:80.0 ~c:95.5
  in
  let basis =
    W.check
      ~stored:[ _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:99.0 ~c:100.0 ]
      [ _bar ~date:"2024-01-02" ~o:95.0 ~h:96.0 ~l:90.0 ~c:95.0 ]
  in
  assert_that
    ( List.length neighbour,
      List.length gap,
      List.length basis.wicks,
      List.length basis.basis_changes )
    (equal_to (0, 1, 1, 0))

(* Fetched bars arrive in any order: the prior close is the prior DATE's. *)
let test_unsorted_input_is_sorted _ =
  let bars =
    [
      _bar ~date:"2024-01-02" ~o:100.0 ~h:101.0 ~l:50.0 ~c:100.0;
      _bar ~date:"2024-01-03" ~o:100.0 ~h:102.0 ~l:90.0 ~c:101.0;
      _bar ~date:"2024-01-04" ~o:101.0 ~h:102.0 ~l:99.0 ~c:101.5;
    ]
  in
  assert_that
    (W.check ~stored:[] (List.rev bars))
    (equal_to (W.check ~stored:[] bars))

let test_render_high_and_neighbour_labels _ =
  let report : W.report =
    {
      wicks =
        _neighbour_wicks ~prev_close:100.0 ~o:100.0 ~h:110.0 ~l:99.0 ~c:101.0;
      basis_changes = [];
    }
  in
  assert_that
    (W.render ~symbol:"X" report)
    (equal_to
       [
         "WICK X 2024-01-03 high observed=110.0000 reference=101.0000 \
          (neighbour) deviation=8.91%";
       ])

(* A non-positive reference (a zero row in the stored copy) is skipped: no
   wick and no basis change, rather than a division by zero. *)
let test_non_positive_reference_is_skipped _ =
  assert_that
    (W.check
       ~stored:[ _bar ~date:"2024-01-02" ~o:0.0 ~h:0.0 ~l:0.0 ~c:0.0 ]
       [ _bar ~date:"2024-01-02" ~o:10.0 ~h:10.5 ~l:9.5 ~c:10.0 ])
    (equal_to ({ wicks = []; basis_changes = [] } : W.report))

let suite =
  "wick_check (#3028)"
  >::: [
         "flags the reported SPY lows" >:: test_flags_the_reported_spy_lows;
         "ordinary bars are accepted" >:: test_ordinary_bars_are_accepted;
         "threshold boundary is strict" >:: test_threshold_boundary;
         "flags a high anomaly" >:: test_flags_a_high_anomaly;
         "missing reference uses neighbours"
         >:: test_missing_reference_uses_neighbours;
         "gap day is exempt" >:: test_gap_day_is_exempt;
         "split is a basis change, not a wick"
         >:: test_split_is_a_basis_change_not_a_wick;
         "render lines carry only the finding" >:: test_render_lines;
         "neighbour low must clear both references"
         >:: test_neighbour_low_must_clear_both;
         "neighbour high check" >:: test_neighbour_high_check;
         "strict at neighbour, gap and basis boundaries"
         >:: test_strict_at_neighbour_gap_and_basis_boundaries;
         "unsorted input is sorted" >:: test_unsorted_input_is_sorted;
         "render high and neighbour labels"
         >:: test_render_high_and_neighbour_labels;
         "non-positive reference is skipped"
         >:: test_non_positive_reference_is_skipped;
       ]

let () = run_test_tt_main suite
