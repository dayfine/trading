(** Tests for {!Spike_bar_gate} — the spike-bar "data-suspect" report-hygiene
    flag (issue #2083 fix 3).

    Fixtures are built directly as [(symbol, Daily_price.t list)] pairs fed to
    {!Bar_reader.of_in_memory_bars}, so the exact close of every bar (and hence
    the exact percentage move of the last one) is fully controlled per test. *)

open Core
open OUnit2
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Gate = Weinstein_snapshot_gen.Spike_bar_gate

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

let _bar ~close date : Types.Daily_price.t =
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

let _start = Date.of_string "2026-06-26"

(* A flat 100.0 series of [n] bars whose LAST bar closes [last_close]. Returns
   (bars, as_of) where [as_of] is the last bar's date. *)
let _series ~n ~last_close : Types.Daily_price.t list * Date.t =
  let dates = _weekdays ~start:_start ~n in
  let last_i = n - 1 in
  let bars =
    List.mapi dates ~f:(fun i d ->
        if i = last_i then _bar ~close:last_close d else _bar ~close:100.0 d)
  in
  (bars, List.last_exn dates)

let _reader_of bars = Bar_reader.of_in_memory_bars [ (_symbol, bars) ]

let _check ~bars ~as_of ~threshold_pct =
  Gate.check (_reader_of bars) ~symbol:_symbol ~as_of ~threshold_pct

(* A [Data_suspect] verdict projected to [(move_pct, threshold_pct, bar_date)],
   [None] for [Clean]. Needed because the verdict's DERIVED equality compares
   [move_pct] exactly, while the computed move carries the usual binary-float
   residue ([(158 - 100) / 100 * 100 = 58.000000000000014]); asserting through
   this projection routes the floats through [float_equal]'s epsilon. *)
let _suspect_parts = function
  | Gate.Data_suspect { move_pct; threshold_pct; bar_date } ->
      Some (move_pct, threshold_pct, bar_date)
  | Gate.Clean -> None

let _is_suspect ~move_pct ~threshold_pct ~bar_date =
  is_some_and
    (all_of
       [
         field (fun (m, _, _) -> m) (float_equal move_pct);
         field (fun (_, t, _) -> t) (float_equal threshold_pct);
         field (fun (_, _, d) -> d) (equal_to bar_date);
       ])

(* ------- Tests ------- *)

(* Default/disabled: [threshold_pct <= 0.0] is always Clean, even on the exact
   +58% SNSE-shaped spike — the no-op contract (experiment-flag-discipline R1). *)
let test_disabled_flag_always_clean _ =
  let bars, as_of = _series ~n:6 ~last_close:158.0 in
  assert_that (_check ~bars ~as_of ~threshold_pct:0.0) (equal_to Gate.Clean)

(* A negative threshold is also treated as disabled (defensive; same [<= 0.0]
   contract). *)
let test_negative_threshold_is_disabled _ =
  let bars, as_of = _series ~n:6 ~last_close:158.0 in
  assert_that (_check ~bars ~as_of ~threshold_pct:(-5.0)) (equal_to Gate.Clean)

(* Armed + the 2026-07-17 incident's shape: the last bar closes +58% vs the
   prior bar's close, above a 25% threshold -> Data_suspect carrying the exact
   move, threshold and offending bar date. *)
let test_armed_spike_is_data_suspect _ =
  let bars, as_of = _series ~n:6 ~last_close:158.0 in
  assert_that
    (_suspect_parts (_check ~bars ~as_of ~threshold_pct:25.0))
    (_is_suspect ~move_pct:58.0 ~threshold_pct:25.0 ~bar_date:as_of)

(* Armed + a quiet last bar (+1%): under the threshold -> Clean. Proves the flag
   is not marking everything once armed. *)
let test_armed_quiet_bar_is_clean _ =
  let bars, as_of = _series ~n:6 ~last_close:101.0 in
  assert_that (_check ~bars ~as_of ~threshold_pct:25.0) (equal_to Gate.Clean)

(* The move is ABSOLUTE: a -58% crash bar is just as suspect as a +58% spike,
   and reports the magnitude (58.0), not the signed move. *)
let test_downward_spike_reports_absolute_move _ =
  let bars, as_of = _series ~n:6 ~last_close:42.0 in
  assert_that
    (_suspect_parts (_check ~bars ~as_of ~threshold_pct:25.0))
    (_is_suspect ~move_pct:58.0 ~threshold_pct:25.0 ~bar_date:as_of)

(* The threshold is inclusive: a move exactly equal to it is Data_suspect. *)
let test_move_exactly_at_threshold_is_suspect _ =
  let bars, as_of = _series ~n:6 ~last_close:125.0 in
  assert_that
    (_suspect_parts (_check ~bars ~as_of ~threshold_pct:25.0))
    (_is_suspect ~move_pct:25.0 ~threshold_pct:25.0 ~bar_date:as_of)

(* The comparison is against the prior bar PRESENT IN THE SERIES, not the prior
   calendar trading day: a feed that skips ~2 weeks and then prints one outsized
   bar (the zombie-feed shape) is flagged. Here only two bars exist, 10 trading
   days apart. *)
let test_gap_in_series_compares_prior_resident_bar _ =
  let dates = _weekdays ~start:_start ~n:11 in
  let first = List.hd_exn dates in
  let last = List.last_exn dates in
  let bars = [ _bar ~close:100.0 first; _bar ~close:158.0 last ] in
  assert_that
    (_suspect_parts (_check ~bars ~as_of:last ~threshold_pct:25.0))
    (_is_suspect ~move_pct:58.0 ~threshold_pct:25.0 ~bar_date:last)

(* Fewer than two resident bars: nothing to compare against -> Clean (the
   sparse-tail gate owns the "not enough data" surface, not this flag). *)
let test_single_bar_is_clean _ =
  let bars, as_of = _series ~n:1 ~last_close:158.0 in
  assert_that (_check ~bars ~as_of ~threshold_pct:25.0) (equal_to Gate.Clean)

let test_no_bars_at_all_is_clean _ =
  let verdict =
    Gate.check (Bar_reader.empty ()) ~symbol:_symbol
      ~as_of:(Date.of_string "2026-07-17")
      ~threshold_pct:25.0
  in
  assert_that verdict (equal_to Gate.Clean)

(* A [0.0] prior close makes the percentage move undefined -> Clean rather than
   a division-by-zero infinity. *)
let test_zero_prior_close_is_clean _ =
  let dates = _weekdays ~start:_start ~n:2 in
  let bars =
    [
      _bar ~close:0.0 (List.hd_exn dates);
      _bar ~close:10.0 (List.last_exn dates);
    ]
  in
  assert_that
    (_check ~bars ~as_of:(List.last_exn dates) ~threshold_pct:25.0)
    (equal_to Gate.Clean)

(* [warning] is [None] for [Clean] and [Some msg] for [Data_suspect], naming the
   symbol, the observed move, the threshold, the bar date, and — crucially —
   stating that the candidate was KEPT (flagged, not dropped). *)
let test_warning_none_for_clean _ =
  assert_that (Gate.warning ~symbol:_symbol Gate.Clean) is_none

let test_warning_some_for_data_suspect _ =
  let verdict =
    Gate.Data_suspect
      {
        move_pct = 58.0;
        threshold_pct = 25.0;
        bar_date = Date.of_string "2026-07-17";
      }
  in
  assert_that
    (Gate.warning ~symbol:_symbol verdict)
    (is_some_and
       (matching
          ~msg:"warning names the symbol, move, threshold, date, and 'kept'"
          (fun msg ->
            if
              String.is_substring msg ~substring:_symbol
              && String.is_substring msg ~substring:"58.0"
              && String.is_substring msg ~substring:"25.0"
              && String.is_substring msg ~substring:"2026-07-17"
              && String.is_substring msg ~substring:"kept"
            then Some ()
            else None)
          (equal_to ())))

let suite =
  "spike_bar_gate"
  >::: [
         "disabled flag is always clean" >:: test_disabled_flag_always_clean;
         "negative threshold is disabled"
         >:: test_negative_threshold_is_disabled;
         "armed spike is data-suspect" >:: test_armed_spike_is_data_suspect;
         "armed quiet bar is clean" >:: test_armed_quiet_bar_is_clean;
         "downward spike reports the absolute move"
         >:: test_downward_spike_reports_absolute_move;
         "move exactly at the threshold is suspect"
         >:: test_move_exactly_at_threshold_is_suspect;
         "gap in the series compares the prior resident bar"
         >:: test_gap_in_series_compares_prior_resident_bar;
         "single bar is clean" >:: test_single_bar_is_clean;
         "no bars at all is clean" >:: test_no_bars_at_all_is_clean;
         "zero prior close is clean" >:: test_zero_prior_close_is_clean;
         "warning is none for clean" >:: test_warning_none_for_clean;
         "warning is some for data-suspect"
         >:: test_warning_some_for_data_suspect;
       ]

let () = run_test_tt_main suite
