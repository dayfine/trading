(** Tests for {!Rename_gate} — the {!Weinstein_strategy.Bar_reader} adapter in
    front of the pure {!Rename_detector} (issue #2083 fix 2).

    Fixtures are built as explicit [(symbol, Daily_price.t list)] pairs fed to
    {!Bar_reader.of_in_memory_bars}, so exactly which trading days each symbol
    has a bar for is under test control. This is the seam where "a bar store"
    becomes "a rename mapping", so both halves of the verdict are asserted here:
    the superseded ticker is dropped AND the successor is kept. *)

open Core
open OUnit2
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Gate = Weinstein_snapshot_gen.Rename_gate

let _bars_total = 120

(* Successor's first bar: 22 trading days of overlap, the incident's shape. *)
let _changeover_idx = 98

(* Predecessor's zombie tail — 6 scattered prints after the changeover, 4 of
   which fall in the detector's default 15-day trailing window. *)
let _zombie_indices = [ 99; 103; 107; 111; 115; 119 ]

let _next_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Fri -> Date.add_days d 3
  | Day_of_week.Sat -> Date.add_days d 2
  | _ -> Date.add_days d 1

let _calendar =
  let rec loop d acc n =
    if n <= 0 then Array.of_list (List.rev acc)
    else loop (_next_weekday d) (d :: acc) (n - 1)
  in
  loop (Date.create_exn ~y:2026 ~m:Month.Jan ~d:5) [] _bars_total

let _as_of = _calendar.(_bars_total - 1)

(* Deterministic compounding path — no randomness, so every score below is
   reproducible. *)
let _path =
  let closes = Array.create ~len:_bars_total 100.0 in
  for i = 1 to _bars_total - 1 do
    closes.(i) <-
      closes.(i - 1) *. (1.0 +. (0.02 *. Float.sin (Float.of_int (i * 7))))
  done;
  closes

let _bar ~date ~close ~adjusted : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = adjusted;
    volume = 1_000_000;
    active_through = None;
  }

(* [scale] models a different split/dividend adjustment basis: the adjusted
   LEVELS move, the adjusted RETURNS do not.

   The RAW close carries an extra per-day wobble, so it is not a constant
   multiple of the adjusted close. That is deliberate: rename detection must
   read [adjusted_close] (the only field on which two adjustment bases of one
   company agree), and reading [close_price] instead has to break these
   tests rather than pass by coincidence. *)
let _series ~scale indices =
  List.map indices ~f:(fun i ->
      let adjusted = _path.(i) *. scale in
      let wobble =
        1.0 +. (0.03 *. Float.sin (Float.of_int (i * 11) *. scale))
      in
      _bar ~date:_calendar.(i) ~close:(adjusted *. wobble) ~adjusted)

let _range lo hi = List.range lo (hi + 1)

(* ZOMB: dense history, then a zombie tail. ZOMBN: takes over at the changeover
   on a 1.37x adjustment basis. MARKET: dense throughout — an unrelated control
   that must survive, and the symbol that establishes the trading calendar. *)
let _bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      ("MARKET", _series ~scale:1.0 (_range 0 (_bars_total - 1)));
      ( "ZOMB",
        _series ~scale:1.0 (_range 0 (_changeover_idx - 1) @ _zombie_indices) );
      ("ZOMBN", _series ~scale:1.37 (_range _changeover_idx (_bars_total - 1)));
    ]

let _tickers = [ "MARKET"; "ZOMB"; "ZOMBN" ]

let _partition ?(min_overlap_days = 5) ?(match_fraction = 0.95) () =
  Gate.partition (_bar_reader ()) ~as_of:_as_of ~min_overlap_days
    ~match_fraction _tickers

(* Both halves of the verdict at the seam: the superseded ZOMB is dropped, and
   the successor ZOMBN is KEPT (as is the unrelated MARKET), in input order.
   Asserting the exact list pins both directions — dropping the successor, or
   dropping nothing, both fail. *)
let test_armed_drops_predecessor_and_keeps_successor _ =
  let survivors, _ = _partition () in
  assert_that survivors (elements_are [ equal_to "MARKET"; equal_to "ZOMBN" ])

(* The warning must name BOTH tickers, so a trader whose pick vanished learns
   what to look at instead. *)
let test_armed_warning_names_both_tickers _ =
  let _, warnings = _partition () in
  assert_that warnings
    (elements_are
       [
         matching ~msg:"warning naming ZOMB and ZOMBN"
           (fun w ->
             if
               String.is_substring w ~substring:"ZOMB"
               && String.is_substring w ~substring:"ZOMBN"
             then Some ()
             else None)
           (equal_to ());
       ])

(* R1: either knob at its config default disables the gate — passthrough, no
   warning, and (by construction of [Rename_gate.partition]) no series read. *)
let test_disabled_by_zero_overlap_is_passthrough _ =
  let survivors, warnings = _partition ~min_overlap_days:0 () in
  assert_that (survivors, warnings)
    (all_of
       [
         field fst
           (elements_are
              [ equal_to "MARKET"; equal_to "ZOMB"; equal_to "ZOMBN" ]);
         field snd is_empty;
       ])

let test_disabled_by_zero_match_fraction_is_passthrough _ =
  let survivors, warnings = _partition ~match_fraction:0.0 () in
  assert_that (survivors, warnings)
    (all_of
       [
         field fst
           (elements_are
              [ equal_to "MARKET"; equal_to "ZOMB"; equal_to "ZOMBN" ]);
         field snd is_empty;
       ])

(* Armed but with nothing renamed: a universe of dense, unrelated series is
   returned untouched — the gate is not simply dropping whatever it is pointed
   at once enabled. *)
let test_armed_on_a_clean_universe_changes_nothing _ =
  let reader =
    Bar_reader.of_in_memory_bars
      [
        ("MARKET", _series ~scale:1.0 (_range 0 (_bars_total - 1)));
        ("OTHER", _series ~scale:2.5 (_range 0 (_bars_total - 1)));
      ]
  in
  let survivors, warnings =
    Gate.partition reader ~as_of:_as_of ~min_overlap_days:5 ~match_fraction:0.95
      [ "MARKET"; "OTHER" ]
  in
  assert_that (survivors, warnings)
    (all_of
       [
         field fst (elements_are [ equal_to "MARKET"; equal_to "OTHER" ]);
         field snd is_empty;
       ])

(* [series_for] reads the symbol's whole history up to [as_of], preserving the
   sparse shape (6 zombie prints after the changeover, not 22 filled ones). *)
let test_series_for_reads_the_resident_bars _ =
  let s = Gate.series_for (_bar_reader ()) ~as_of:_as_of ~symbol:"ZOMB" in
  assert_that
    (s.symbol, Array.length s.closes, fst s.closes.(Array.length s.closes - 1))
    (all_of
       [
         field (fun (sym, _, _) -> sym) (equal_to "ZOMB");
         (* 98 dense bars + 6 zombie prints — the gaps are NOT filled in. *)
         field (fun (_, n, _) -> n) (equal_to (_changeover_idx + 6));
         field (fun (_, _, last) -> last) (equal_to _as_of);
       ])

let test_series_for_unknown_symbol_is_empty _ =
  let s = Gate.series_for (_bar_reader ()) ~as_of:_as_of ~symbol:"NOSUCH" in
  assert_that (Array.length s.closes) (equal_to 0)

let suite =
  "rename_gate"
  >::: [
         "armed drops predecessor and keeps successor"
         >:: test_armed_drops_predecessor_and_keeps_successor;
         "armed warning names both tickers"
         >:: test_armed_warning_names_both_tickers;
         "zero overlap disables the gate"
         >:: test_disabled_by_zero_overlap_is_passthrough;
         "zero match fraction disables the gate"
         >:: test_disabled_by_zero_match_fraction_is_passthrough;
         "armed on a clean universe changes nothing"
         >:: test_armed_on_a_clean_universe_changes_nothing;
         "series_for reads the resident bars"
         >:: test_series_for_reads_the_resident_bars;
         "series_for on an unknown symbol is empty"
         >:: test_series_for_unknown_symbol_is_empty;
       ]

let () = run_test_tt_main suite
