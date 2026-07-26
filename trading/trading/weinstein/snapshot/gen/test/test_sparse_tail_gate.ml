(** Tests for {!Sparse_tail_gate} — the sparse-tail eligibility gate (issue
    #2083 fix 1).

    Fixtures are built directly as [(symbol, Daily_price.t list)] pairs fed to
    {!Bar_reader.of_in_memory_bars}, independent of the synthetic-strategy data
    generator, so the exact date pattern (which trading days have a bar, which
    don't) is fully controlled per test. *)

open Core
open OUnit2
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Gate = Weinstein_snapshot_gen.Sparse_tail_gate

let _symbol = "SNSE"

(* Next weekday on/after [d] (mirrors [Synthetic_source]'s weekend skip). *)
let _first_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat -> Date.add_days d 2
  | Day_of_week.Sun -> Date.add_days d 1
  | _ -> d

let _next_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat -> Date.add_days d 2
  | Day_of_week.Sun -> Date.add_days d 1
  | _ -> Date.add_days d 1

(* [n] consecutive trading-day (weekday) dates starting at [start], ascending. *)
let _weekdays ~start ~n : Date.t list =
  let rec loop d acc n =
    if n <= 0 then List.rev acc else loop (_next_weekday d) (d :: acc) (n - 1)
  in
  loop (_first_weekday start) [] n

let _bar ?(close = 100.0) date : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* A dense window: one bar per trading day, [n] consecutive weekdays ending at
   the last date (which the caller treats as [as_of]). *)
let _dense_window ~start ~n : Types.Daily_price.t list =
  List.map (_weekdays ~start ~n) ~f:(fun d -> _bar d)

(* SNSE-shaped sparse tail: [n] trading days, keep only every [stride]-th bar
   plus the very last one (always kept, and spiked — mirrors the 2026-07-17
   zombie-feed incident's anomalous last bar). Returns (bars, as_of) where
   [as_of] is the date of the last (kept, spiked) trading day. *)
let _sparse_tail ~start ~n ~stride ~spike_mult :
    Types.Daily_price.t list * Date.t =
  let dates = Array.of_list (_weekdays ~start ~n) in
  let last_idx = Array.length dates - 1 in
  let as_of = dates.(last_idx) in
  let kept =
    List.filter
      (List.range 0 (last_idx + 1))
      ~f:(fun i -> i % stride = 0 || i = last_idx)
  in
  let bars =
    List.map kept ~f:(fun i ->
        if i = last_idx then _bar ~close:(100.0 *. spike_mult) dates.(i)
        else _bar dates.(i))
  in
  (bars, as_of)

let _reader_of bars = Bar_reader.of_in_memory_bars [ (_symbol, bars) ]

(* ------- Tests ------- *)

(* Default/disabled: [window_trading_days <= 0] is always Eligible, regardless
   of how sparse the tail actually is — the exact no-op contract
   (experiment-flag-discipline R1). *)
let test_disabled_gate_always_eligible _ =
  let bars, as_of =
    _sparse_tail
      ~start:(Date.of_string "2026-06-01")
      ~n:15 ~stride:3 ~spike_mult:1.3
  in
  let verdict =
    Gate.check (_reader_of bars) ~symbol:_symbol ~as_of ~min_bars:10
      ~window_trading_days:0
  in
  assert_that verdict (equal_to Gate.Eligible)

(* A negative window is also treated as disabled (defensive; same contract as
   [<= 0]). *)
let test_negative_window_is_disabled _ =
  let bars, as_of =
    _sparse_tail
      ~start:(Date.of_string "2026-06-01")
      ~n:15 ~stride:3 ~spike_mult:1.3
  in
  let verdict =
    Gate.check (_reader_of bars) ~symbol:_symbol ~as_of ~min_bars:10
      ~window_trading_days:(-5)
  in
  assert_that verdict (equal_to Gate.Eligible)

(* Armed + dense tail: every trading day in the window has a bar, well above
   [min_bars] -> Eligible. Proves the gate is not just dropping everything. *)
let test_armed_dense_tail_eligible _ =
  let start = Date.of_string "2026-06-01" in
  let bars = _dense_window ~start ~n:15 in
  let as_of = (List.last_exn bars).date in
  let verdict =
    Gate.check (_reader_of bars) ~symbol:_symbol ~as_of ~min_bars:10
      ~window_trading_days:15
  in
  assert_that verdict (equal_to Gate.Eligible)

(* Armed + sparse tail: [stride = 3] over 15 trading days keeps indices
   {0,3,6,9,12,14} = 6 bars (matches the real SNSE incident's "6 bars in ~15
   trading days"). 6 < min_bars(10) -> Sparse_tail with the exact count. *)
let test_armed_sparse_tail_flagged _ =
  let bars, as_of =
    _sparse_tail
      ~start:(Date.of_string "2026-06-01")
      ~n:15 ~stride:3 ~spike_mult:1.3
  in
  let verdict =
    Gate.check (_reader_of bars) ~symbol:_symbol ~as_of ~min_bars:10
      ~window_trading_days:15
  in
  assert_that verdict
    (equal_to
       (Gate.Sparse_tail
          { bars_present = 6; min_bars = 10; window_trading_days = 15 }))

(* The SNSE-shaped regression fixture named explicitly in issue #2083: ~6 bars
   across ~15 trading days, a spike bar near the right edge, [data_end] (the
   last resident bar) equal to [as_of]. This is the exact case that passed the
   OLD "too few bars" check (the series was non-empty and current at the
   right-hand edge) — pinning it here is the single most direct regression
   test for the bug. *)
let test_snse_shaped_regression_fixture_is_sparse _ =
  let bars, as_of =
    _sparse_tail
      ~start:(Date.of_string "2026-06-26")
      ~n:15 ~stride:3 ~spike_mult:1.4
  in
  (* [_sparse_tail] always keeps the last (spiked) trading day, so [as_of]
     equals the last resident bar's date by construction — the "data_end =
     as_of" shape the old check saw as healthy. *)
  let verdict =
    Gate.check (_reader_of bars) ~symbol:_symbol ~as_of ~min_bars:10
      ~window_trading_days:15
  in
  assert_that verdict
    (matching ~msg:"Sparse_tail with bars_present < min_bars"
       (function
         | Gate.Sparse_tail { bars_present; min_bars; _ } ->
             if bars_present < min_bars then Some bars_present else None
         | Gate.Eligible -> None)
       (equal_to 6))

(* A symbol entirely absent from the bar reader (0 bars in the window) is the
   sparsest possible tail: Sparse_tail with [bars_present = 0] whenever the
   gate is armed. *)
let test_no_bars_at_all_is_sparse_when_armed _ =
  let as_of = Date.of_string "2026-07-17" in
  let verdict =
    Gate.check (Bar_reader.empty ()) ~symbol:_symbol ~as_of ~min_bars:10
      ~window_trading_days:15
  in
  assert_that verdict
    (equal_to
       (Gate.Sparse_tail
          { bars_present = 0; min_bars = 10; window_trading_days = 15 }))

(* [warning] is [None] for [Eligible] and [Some msg] naming the symbol + the
   counts for [Sparse_tail]. *)
let test_warning_none_for_eligible _ =
  assert_that (Gate.warning ~symbol:_symbol Gate.Eligible) is_none

let test_warning_some_for_sparse_tail _ =
  let verdict =
    Gate.Sparse_tail
      { bars_present = 6; min_bars = 10; window_trading_days = 15 }
  in
  assert_that
    (Gate.warning ~symbol:_symbol verdict)
    (is_some_and
       (matching ~msg:"warning names the symbol and the bar counts"
          (fun msg ->
            if
              String.is_substring msg ~substring:_symbol
              && String.is_substring msg ~substring:"6"
              && String.is_substring msg ~substring:"10"
              && String.is_substring msg ~substring:"15"
            then Some ()
            else None)
          (equal_to ())))

let suite =
  "sparse_tail_gate"
  >::: [
         "disabled gate is always eligible"
         >:: test_disabled_gate_always_eligible;
         "negative window is treated as disabled"
         >:: test_negative_window_is_disabled;
         "armed + dense tail is eligible" >:: test_armed_dense_tail_eligible;
         "armed + sparse tail is flagged" >:: test_armed_sparse_tail_flagged;
         "SNSE-shaped regression fixture is flagged sparse"
         >:: test_snse_shaped_regression_fixture_is_sparse;
         "no bars at all is sparse when armed"
         >:: test_no_bars_at_all_is_sparse_when_armed;
         "warning is None for Eligible" >:: test_warning_none_for_eligible;
         "warning names symbol and counts for Sparse_tail"
         >:: test_warning_some_for_sparse_tail;
       ]

let () = run_test_tt_main suite
