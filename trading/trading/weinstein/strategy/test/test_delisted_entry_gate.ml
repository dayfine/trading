(** Unit + wiring tests for the unconditional post-[active_through] entry
    exclusion (issue #2693).

    Pins {!Weinstein_strategy.Delisted_entry_gate}:

    - The boundary matches the simulator's [delisted] exit exactly —
      [Date.(as_of <= active_through)] is still tradeable, so the marker day
      itself admits and only a marker strictly in the past drops.
    - [None] (no marker) always keeps, which is the R1 no-op contract: every
      warehouse built before #2691 leaves [active_through] unset on every
      symbol, so the gate cannot move a golden there.
    - Both sides are gated — a delisted security cannot be shorted either.
    - The measured shapes from the 2026-09-06 acceptance run
      ([dev/experiments/warehouse-rebuild-2026-09-06/] §"Acceptance cell
      result"): FII entered 2020-03-28 and 2020-04-04 on a series that ended
      2020-01-31, and CY entered 2020-04-25 on a series that ended 2020-04-15.

    Plus the wiring end-to-end: {!Weinstein_strategy.Entry_assembly.assemble} at
    the {b default} config over a real {!Bar_reader.of_in_memory_bars}, so the
    marker travels the production path (snapshot writer → manifest →
    [Snapshot_callbacks.active_through_for]) and the CY-shaped candidate is not
    handed to the entry walk. *)

open OUnit2
open Core
open Matchers
open Weinstein_types
module Bar_reader = Weinstein_strategy.Bar_reader
module Config = Weinstein_strategy.Weinstein_strategy_config
module Delisted_entry_gate = Weinstein_strategy.Delisted_entry_gate
module Entry_assembly = Weinstein_strategy.Entry_assembly

(* Minimal [scored_candidate] builder — only [ticker] / [side] are load-bearing
   for the gate; the rest carry inert placeholders. *)
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
    suggested_entry = 10.0;
    suggested_stop = 10.8;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

let _long ticker = _make_candidate ~ticker ~side:Trading_base.Types.Long
let _short ticker = _make_candidate ~ticker ~side:Trading_base.Types.Short

(* CY's second stale entry in the acceptance run: screened 2020-04-25 on a
   series whose last bar (and marker) was 2020-04-15. *)
let _decision_date = Date.of_string "2020-04-25"
let _cy_marker = Date.of_string "2020-04-15"

(* FII's marker: its series ended 2020-01-31 yet it was entered twice, 57 and
   64 days later. *)
let _fii_marker = Date.of_string "2020-01-31"

(* Per-ticker marker lookup driven by an assoc list. A missing key and an
   explicit [None] both yield [None] ("no marker"). *)
let _active_through_for table ticker =
  Option.join (List.Assoc.find table ticker ~equal:String.equal)

let _survivors ~table candidates =
  Delisted_entry_gate.filter ~as_of:_decision_date
    ~active_through_for:(_active_through_for table)
    candidates
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

let _offset n = Some (Date.add_days _decision_date n)

(** No marker keeps the candidate — the R1 contract. Every warehouse built
    before #2691 answers [None] for every symbol, so merging this gate moves no
    golden. *)
let test_no_marker_is_kept _ =
  assert_that
    (_survivors ~table:[ ("NOMARK", None) ] [ _long "NOMARK" ])
    (elements_are [ equal_to "NOMARK" ])

(** A ticker absent from the lookup entirely is kept for the same reason. *)
let test_unknown_ticker_is_kept _ =
  assert_that
    (_survivors ~table:[] [ _long "ABSENT" ])
    (elements_are [ equal_to "ABSENT" ])

(** The marker day itself is still tradeable — [as_of = active_through] admits,
    matching the simulator's [Delisted_exit_runner], which exits only once
    [date > active_through]. *)
let test_marker_day_is_kept _ =
  assert_that
    (_survivors ~table:[ ("TODAY", _offset 0) ] [ _long "TODAY" ])
    (elements_are [ equal_to "TODAY" ])

(** A marker in the future is kept: the symbol delists later in the fold. *)
let test_future_marker_is_kept _ =
  assert_that
    (_survivors ~table:[ ("LATER", _offset 1) ] [ _long "LATER" ])
    (elements_are [ equal_to "LATER" ])

(** One day past the marker is already dropped — the boundary is exclusive on
    the far side. *)
let test_marker_yesterday_is_dropped _ =
  assert_that
    (_survivors
       ~table:[ ("GONE", _offset (-1)); ("LIVE", None) ]
       [ _long "GONE"; _long "LIVE" ])
    (elements_are [ equal_to "LIVE" ])

(** The two measured shapes: CY (10 days past its marker) and FII (85 days past
    its marker as of this decision date) are both dropped, a live name is kept,
    and the surviving order is preserved. *)
let test_measured_stale_entries_are_dropped _ =
  assert_that
    (_survivors
       ~table:
         [ ("CY", Some _cy_marker); ("FII", Some _fii_marker); ("LIVE", None) ]
       [ _long "CY"; _long "FII"; _long "LIVE" ])
    (elements_are [ equal_to "LIVE" ])

(** Longs and shorts are gated symmetrically — a security that no longer exists
    cannot be sold short either. *)
let test_both_sides_are_gated _ =
  assert_that
    (_survivors
       ~table:[ ("SGONE", Some _cy_marker); ("SLIVE", None) ]
       [ _short "SGONE"; _short "SLIVE" ])
    (elements_are [ equal_to "SLIVE" ])

(* --- Wiring: Entry_assembly over a real Bar_reader ------------------- *)

let _is_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat | Day_of_week.Sun -> false
  | _ -> true

let _weekdays_ending ~last ~n =
  let rec loop acc d remaining =
    if remaining = 0 then acc
    else if _is_weekday d then
      loop (d :: acc) (Date.add_days d (-1)) (remaining - 1)
    else loop acc (Date.add_days d (-1)) remaining
  in
  loop [] last n

let _bar ?(active_through = None) ~date () : Types.Daily_price.t =
  {
    date;
    open_price = 23.8;
    high_price = 23.9;
    low_price = 23.7;
    close_price = 23.82;
    adjusted_close = 23.82;
    volume = 1_000_000;
    active_through;
  }

(* A 30-bar series ending on [last]. When [active_through] is supplied the CSV
   convention is honoured: every row of the symbol's history carries it, which
   is what {!Bar_reader.of_in_memory_bars} reads off the tail to stamp the
   manifest. *)
let _series ?active_through ~last () =
  _weekdays_ending ~last ~n:30
  |> List.map ~f:(fun date -> _bar ?active_through ~date ())

(* Inert counts — [assemble] never reads them; the record is required only to
   build a well-formed {!Screener.result}. *)
let _diagnostics : Screener.cascade_diagnostics =
  {
    total_stocks = 2;
    candidates_after_held = 2;
    macro_trend = Bullish;
    long_macro_admitted = 2;
    long_breakout_admitted = 2;
    long_failed_breakout_dropped = 0;
    long_sector_admitted = 2;
    long_grade_admitted = 2;
    long_top_n_admitted = 2;
    short_macro_admitted = 0;
    short_breakdown_admitted = 0;
    short_sector_admitted = 0;
    short_rs_hard_gate_admitted = 0;
    short_grade_admitted = 0;
    short_top_n_admitted = 0;
  }

(* CY's shape: the series (and its marker) end 2020-04-15, the screen runs
   2020-04-25. LIVE keeps printing through the decision date with no marker. *)
let _assembled () =
  let bar_reader =
    Bar_reader.of_in_memory_bars
      [
        ("CY", _series ~active_through:(Some _cy_marker) ~last:_cy_marker ());
        ("LIVE", _series ~last:_decision_date ());
      ]
  in
  let config =
    Config.default_config ~universe:[ "CY"; "LIVE" ] ~index_symbol:"SPY"
  in
  Entry_assembly.assemble ~config ~bar_reader ~current_date:_decision_date
    {
      Screener.buy_candidates = [ _long "CY"; _long "LIVE" ];
      short_candidates = [];
      watchlist = [];
      macro_trend = Bullish;
      cascade_diagnostics = _diagnostics;
    }
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(** End-to-end at the {b default} config: the marker travels [of_in_memory_bars]
    → snapshot writer → manifest → [Snapshot_callbacks.active_through_for], and
    [Entry_assembly.assemble] hands the entry walk only the live name. Every
    other assembly gate is at its no-op default, so this drop is attributable to
    the new gate alone. *)
let test_assemble_drops_the_delisted_candidate _ =
  assert_that (_assembled ()) (elements_are [ equal_to "LIVE" ])

let () =
  run_test_tt_main
    ("delisted_entry_gate"
    >::: [
           "no marker is kept" >:: test_no_marker_is_kept;
           "unknown ticker is kept" >:: test_unknown_ticker_is_kept;
           "marker day is kept" >:: test_marker_day_is_kept;
           "future marker is kept" >:: test_future_marker_is_kept;
           "marker one day past is dropped" >:: test_marker_yesterday_is_dropped;
           "measured CY / FII stale entries are dropped"
           >:: test_measured_stale_entries_are_dropped;
           "both sides are gated" >:: test_both_sides_are_gated;
           "assemble drops the delisted candidate"
           >:: test_assemble_drops_the_delisted_candidate;
         ])
