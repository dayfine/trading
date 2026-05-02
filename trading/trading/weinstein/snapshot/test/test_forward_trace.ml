(** Tests for {!Forward_trace}.

    Pinned via fixtures so future drift in the rendering function shows up as a
    test failure rather than as a silent regression in CI metrics. *)

open Core
open OUnit2
open Matchers
open Weinstein_snapshot
open Types

let _date d = Date.of_string d

(** Build a [Daily_price.t] with no split adjustment (close = adjusted_close).
    Used everywhere except the explicit split fixture. *)
let _bar ?(volume = 1_000_000) ~date ~o ~h ~l ~c () : Daily_price.t =
  {
    date;
    open_price = o;
    high_price = h;
    low_price = l;
    close_price = c;
    volume;
    adjusted_close = c;
  }

let _candidate ?(score = 0.9) ?(grade = "A+") ?(sector = "XLK")
    ?(rationale = "test") ?(rs_vs_spy = None) ?(resistance_grade = None) ~symbol
    ~entry ~stop () : Weekly_snapshot.candidate =
  {
    symbol;
    score;
    grade;
    entry;
    stop;
    sector;
    rationale;
    rs_vs_spy;
    resistance_grade;
  }

let _snapshot ~date ~candidates : Weekly_snapshot.t =
  {
    schema_version = Weekly_snapshot.current_schema_version;
    system_version = "test";
    date;
    macro = { regime = "Bullish"; score = 0.5 };
    sectors_strong = [];
    sectors_weak = [];
    long_candidates = candidates;
    short_candidates = [];
    held_positions = [];
  }

(* ---------- Fixture 1: known historical pick (entry fills, +1% horizon) ---- *)

(** A 5-bar series where the pick (entry $100) fills on day 1 at $100, and the
    final bar closes at $101 — a +1% horizon return. Pinned values. *)
let _aapl_like_bars : Daily_price.t list =
  [
    _bar ~date:(_date "2020-08-31") ~o:99.5 ~h:100.5 ~l:98.5 ~c:100.0 ();
    _bar ~date:(_date "2020-09-01") ~o:100.2 ~h:101.0 ~l:99.0 ~c:100.5 ();
    _bar ~date:(_date "2020-09-02") ~o:100.5 ~h:102.0 ~l:99.5 ~c:101.5 ();
    _bar ~date:(_date "2020-09-03") ~o:101.0 ~h:101.5 ~l:99.0 ~c:99.5 ();
    _bar ~date:(_date "2020-09-04") ~o:99.5 ~h:101.5 ~l:99.0 ~c:101.0 ();
  ]

let test_filled_pick_basic_outcome _ =
  let pick =
    _candidate ~symbol:"AAPL" ~entry:100.0 ~stop:95.0 ~rs_vs_spy:(Some 1.34) ()
  in
  let picks = _snapshot ~date:(_date "2020-08-28") ~candidates:[ pick ] in
  let bars = String.Map.singleton "AAPL" _aapl_like_bars in
  let outcomes, _agg =
    Forward_trace.trace_picks ~picks ~bars ~horizon_days:20
  in
  assert_that outcomes
    (elements_are
       [
         all_of
           [
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.symbol)
               (equal_to "AAPL");
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.entry_filled_at)
               (float_equal 100.0);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.entry_filled_date)
               (equal_to (_date "2020-08-31"));
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.final_price)
               (float_equal 101.0);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.final_date)
               (equal_to (_date "2020-09-04"));
             field
               (fun (o : Forward_trace.per_pick_outcome) ->
                 o.pct_return_horizon)
               (float_equal ~epsilon:1e-6 0.01);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.stop_triggered)
               (equal_to false);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.winner)
               (equal_to true);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.max_favorable)
               (float_equal 102.0);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.max_adverse)
               (float_equal 98.5);
           ];
       ])

(* ---------- Fixture 2: stop-trigger detection ---- *)

let _stop_trigger_bars : Daily_price.t list =
  [
    (* Entry fills at 410 on day 1 *)
    _bar ~date:(_date "2021-01-04") ~o:405.0 ~h:415.0 ~l:402.0 ~c:412.0 ();
    (* Day 2 plummets — low pierces $400 stop at $399 *)
    _bar ~date:(_date "2021-01-05") ~o:411.0 ~h:412.0 ~l:399.0 ~c:401.0 ();
    _bar ~date:(_date "2021-01-06") ~o:401.0 ~h:404.0 ~l:400.0 ~c:402.0 ();
  ]

let test_stop_trigger_detected _ =
  let pick = _candidate ~symbol:"FOO" ~entry:410.0 ~stop:400.0 () in
  let picks = _snapshot ~date:(_date "2021-01-01") ~candidates:[ pick ] in
  let bars = String.Map.singleton "FOO" _stop_trigger_bars in
  let outcomes, _agg =
    Forward_trace.trace_picks ~picks ~bars ~horizon_days:10
  in
  assert_that outcomes
    (elements_are
       [
         all_of
           [
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.entry_filled_at)
               (float_equal 410.0);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.stop_triggered)
               (equal_to true);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.max_adverse)
               (float_equal 399.0);
           ];
       ])

(* ---------- Fixture 3: split-day round-trip (no phantom 4× return) ---- *)

(** Bars spanning a 4:1 split. Pre-split: close ~$500, post-split: close ~$125
    raw — but [adjusted_close] for the pre-split bar is rebased to ~$125 too, so
    a forward trace using adjusted prices throughout sees ≈0% return, not 4×.

    Day 0 (pick): close 500, adjusted_close 125 Day 1: high 510, low 490, close
    502, adj_close 125.5 Day 2 (split day): raw close 130, adjusted_close 130 —
    same scale Day 3: close 132, adj_close 132 — small gain in adjusted terms
    only *)
let _split_day_bars : Daily_price.t list =
  [
    {
      date = _date "2020-08-31";
      open_price = 498.0;
      high_price = 503.0;
      low_price = 497.0;
      close_price = 500.0;
      volume = 1_000_000;
      adjusted_close = 125.0;
    };
    {
      date = _date "2020-09-01";
      open_price = 500.0;
      high_price = 510.0;
      low_price = 498.0;
      close_price = 502.0;
      volume = 1_000_000;
      adjusted_close = 125.5;
    };
    (* Split day: raw price collapses 4×, adjusted is unchanged scale *)
    {
      date = _date "2020-09-02";
      open_price = 126.0;
      high_price = 132.0;
      low_price = 125.0;
      close_price = 130.0;
      volume = 4_000_000;
      adjusted_close = 130.0;
    };
    {
      date = _date "2020-09-03";
      open_price = 130.5;
      high_price = 134.0;
      low_price = 130.0;
      close_price = 132.0;
      volume = 4_000_000;
      adjusted_close = 132.0;
    };
  ]

let test_split_day_no_phantom_return _ =
  (* Suggested entry 125 (in adjusted terms). Stop 115. Day 0 high adj 503 *
     (125/500) = 125.75 ≥ 125 → fills at 125 (entry). Final adj_close 132 →
     return = (132 - 125)/125 = 5.6%, not the phantom 4× a naive close-based
     impl would produce. *)
  let pick = _candidate ~symbol:"AAPL" ~entry:125.0 ~stop:115.0 () in
  let picks = _snapshot ~date:(_date "2020-08-28") ~candidates:[ pick ] in
  let bars = String.Map.singleton "AAPL" _split_day_bars in
  let outcomes, _agg =
    Forward_trace.trace_picks ~picks ~bars ~horizon_days:20
  in
  assert_that outcomes
    (elements_are
       [
         all_of
           [
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.entry_filled_at)
               (float_equal 125.0);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.final_price)
               (float_equal 132.0);
             field
               (fun (o : Forward_trace.per_pick_outcome) ->
                 o.pct_return_horizon)
               (float_equal ~epsilon:1e-6 0.056);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.stop_triggered)
               (equal_to false);
             (* No phantom 4× return — adjusted prices keep scale uniform *)
             field
               (fun (o : Forward_trace.per_pick_outcome) ->
                 o.pct_return_horizon)
               (lt (module Float_ord) 1.0);
           ];
       ])

(* ---------- Fixture 4: empty bars / never-filled pick ---- *)

let test_empty_bars_unfilled _ =
  let pick = _candidate ~symbol:"NOPE" ~entry:100.0 ~stop:90.0 () in
  let picks = _snapshot ~date:(_date "2021-06-04") ~candidates:[ pick ] in
  let outcomes, agg =
    Forward_trace.trace_picks ~picks ~bars:String.Map.empty ~horizon_days:20
  in
  assert_that outcomes
    (elements_are
       [
         all_of
           [
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.symbol)
               (equal_to "NOPE");
             field
               (fun (o : Forward_trace.per_pick_outcome) ->
                 Float.is_nan o.entry_filled_at)
               (equal_to true);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.winner)
               (equal_to false);
             field
               (fun (o : Forward_trace.per_pick_outcome) -> o.stop_triggered)
               (equal_to false);
           ];
       ]);
  assert_that agg
    (all_of
       [
         field (fun (a : Forward_trace.aggregate) -> a.total_picks) (equal_to 1);
         field (fun (a : Forward_trace.aggregate) -> a.winners) (equal_to 0);
         field (fun (a : Forward_trace.aggregate) -> a.losers) (equal_to 0);
         field (fun (a : Forward_trace.aggregate) -> a.stopped_out) (equal_to 0);
         field (fun (a : Forward_trace.aggregate) -> a.best_pick) (equal_to "");
         field (fun (a : Forward_trace.aggregate) -> a.worst_pick) (equal_to "");
         field
           (fun (a : Forward_trace.aggregate) -> Float.is_nan a.avg_return_pct)
           (equal_to true);
       ])

(* ---------- Fixture 5: never-filled pick (entry never reached) ---- *)

let test_entry_never_reached _ =
  (* Bars that stay below entry of 200 — never fill *)
  let bars : Daily_price.t list =
    [
      _bar ~date:(_date "2022-01-04") ~o:150.0 ~h:155.0 ~l:148.0 ~c:152.0 ();
      _bar ~date:(_date "2022-01-05") ~o:152.0 ~h:158.0 ~l:150.0 ~c:155.0 ();
    ]
  in
  let pick = _candidate ~symbol:"BAR" ~entry:200.0 ~stop:140.0 () in
  let picks = _snapshot ~date:(_date "2022-01-01") ~candidates:[ pick ] in
  let bars_map = String.Map.singleton "BAR" bars in
  let outcomes, _agg =
    Forward_trace.trace_picks ~picks ~bars:bars_map ~horizon_days:20
  in
  assert_that outcomes
    (elements_are
       [
         field
           (fun (o : Forward_trace.per_pick_outcome) ->
             Float.is_nan o.entry_filled_at)
           (equal_to true);
       ])

(* ---------- Fixture 6: aggregate over multiple picks ---- *)

let test_aggregate_winners_losers _ =
  (* Two filled picks: one winner (+5%), one loser (-3%). Both fill on day 1. *)
  let bars_w : Daily_price.t list =
    [
      _bar ~date:(_date "2020-09-01") ~o:99.5 ~h:101.0 ~l:99.0 ~c:100.0 ();
      _bar ~date:(_date "2020-09-02") ~o:100.0 ~h:106.0 ~l:99.5 ~c:105.0 ();
    ]
  in
  let bars_l : Daily_price.t list =
    [
      _bar ~date:(_date "2020-09-01") ~o:49.5 ~h:51.0 ~l:49.0 ~c:50.0 ();
      _bar ~date:(_date "2020-09-02") ~o:50.0 ~h:50.5 ~l:48.0 ~c:48.5 ();
    ]
  in
  let candidates =
    [
      _candidate ~symbol:"WIN" ~entry:100.0 ~stop:90.0 ();
      _candidate ~symbol:"LOSE" ~entry:50.0 ~stop:45.0 ();
    ]
  in
  let picks = _snapshot ~date:(_date "2020-08-31") ~candidates in
  let bars = String.Map.of_alist_exn [ ("WIN", bars_w); ("LOSE", bars_l) ] in
  let _outcomes, agg = Forward_trace.trace_picks ~picks ~bars ~horizon_days:5 in
  assert_that agg
    (all_of
       [
         field
           (fun (a : Forward_trace.aggregate) -> a.horizon_days)
           (equal_to 5);
         field (fun (a : Forward_trace.aggregate) -> a.total_picks) (equal_to 2);
         field (fun (a : Forward_trace.aggregate) -> a.winners) (equal_to 1);
         field (fun (a : Forward_trace.aggregate) -> a.losers) (equal_to 1);
         field (fun (a : Forward_trace.aggregate) -> a.stopped_out) (equal_to 0);
         field
           (fun (a : Forward_trace.aggregate) -> a.best_pick)
           (equal_to "WIN");
         field
           (fun (a : Forward_trace.aggregate) -> a.worst_pick)
           (equal_to "LOSE");
         field
           (fun (a : Forward_trace.aggregate) -> a.avg_winner_return_pct)
           (float_equal ~epsilon:1e-6 0.05);
         field
           (fun (a : Forward_trace.aggregate) -> a.avg_loser_return_pct)
           (float_equal ~epsilon:1e-6 (-0.03));
         field
           (fun (a : Forward_trace.aggregate) -> a.avg_return_pct)
           (float_equal ~epsilon:1e-6 0.01);
       ])

(* ---------- Fixture 7: gap-up entry fills at the open, not at the entry ---- *)

let test_gap_up_open_entry _ =
  (* Pick entry $100. Day 1 opens at $105 (gap above), high 108. Fill must be at
     105 (the open), not 100 — buy-stop becomes a market order on gap. *)
  let bars : Daily_price.t list =
    [
      _bar ~date:(_date "2023-03-02") ~o:105.0 ~h:108.0 ~l:104.0 ~c:107.0 ();
      _bar ~date:(_date "2023-03-03") ~o:107.0 ~h:109.0 ~l:106.0 ~c:108.0 ();
    ]
  in
  let pick = _candidate ~symbol:"GAP" ~entry:100.0 ~stop:90.0 () in
  let picks = _snapshot ~date:(_date "2023-03-01") ~candidates:[ pick ] in
  let bars_map = String.Map.singleton "GAP" bars in
  let outcomes, _agg =
    Forward_trace.trace_picks ~picks ~bars:bars_map ~horizon_days:5
  in
  assert_that outcomes
    (elements_are
       [
         field
           (fun (o : Forward_trace.per_pick_outcome) -> o.entry_filled_at)
           (float_equal 105.0);
       ])

let suite =
  "forward_trace"
  >::: [
         "filled_pick_basic_outcome" >:: test_filled_pick_basic_outcome;
         "stop_trigger_detected" >:: test_stop_trigger_detected;
         "split_day_no_phantom_return" >:: test_split_day_no_phantom_return;
         "empty_bars_unfilled" >:: test_empty_bars_unfilled;
         "entry_never_reached" >:: test_entry_never_reached;
         "aggregate_winners_losers" >:: test_aggregate_winners_losers;
         "gap_up_open_entry" >:: test_gap_up_open_entry;
       ]

let () = run_test_tt_main suite
