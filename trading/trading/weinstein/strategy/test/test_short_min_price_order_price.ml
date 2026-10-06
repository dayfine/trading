(** #3131 — [short_min_price_on_order_price]: the sub-$17 short floor gates the
    price the short ticket is actually placed at, not the screener's level.

    Pinned through {!Weinstein_strategy.Entry_assembly.assemble} over a real
    in-memory {!Bar_reader}, so the price read is the same
    [Entry_audit_helpers.effective_entry_price] the entry walk installs:

    - UMPQ 2009-01-12 shape: the screener level sits above $17 but the stock
      closed at 10.33, and the default close-priced ticket filled there. Flag
      off admits it (R1, today's behaviour); flag on rejects it.
    - With the E-anchored ticket armed the order price is [suggested_entry] —
      since #3133 the breakdown level. A base top above $17 with a breakdown
      below it is rejected; the same name, close-priced at 18.00, is admitted.
    - Long candidates are never touched by the gate. *)

open OUnit2
open Core
open Matchers
open Weinstein_types
module Bar_reader = Weinstein_strategy.Bar_reader
module Config = Weinstein_strategy.Weinstein_strategy_config
module Entry_assembly = Weinstein_strategy.Entry_assembly

let _decision_date = Date.of_string "2009-01-12"
let _floor = 17.0

let _analysis ~ticker ~base_top ~breakdown =
  let a =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
      ~bars:[] ~benchmark_bars:[] ~prior_stage:None ~as_of_date:_decision_date
  in
  { a with breakout_price = Some base_top; breakdown_price = Some breakdown }

let _candidate ~ticker ~side ~base_top ~breakdown ~suggested_entry :
    Screener.scored_candidate =
  {
    ticker;
    analysis = _analysis ~ticker ~base_top ~breakdown;
    side;
    sector =
      {
        sector_name = "Test";
        rating = Screener.Weak;
        stage = Stage4 { weeks_declining = 5 };
      };
    grade = B;
    score = 0;
    suggested_entry;
    suggested_stop = suggested_entry *. 1.08;
    risk_pct = 0.08;
    swing_target = None;
    rationale = [];
  }

(* UMPQ: level above the floor (breakdown 20.00 less the 0.5 % buffer), close
   10.33 at the decision. *)
let _umpq =
  _candidate ~ticker:"UMPQ" ~side:Trading_base.Types.Short ~base_top:24.0
    ~breakdown:20.0 ~suggested_entry:19.90

(* Base top above the floor, breakdown below it: the #3133 ticket rests at
   16.50 * 0.995 = 16.42. The decision close is 18.00. *)
let _split_level =
  _candidate ~ticker:"SPLT" ~side:Trading_base.Types.Short ~base_top:20.0
    ~breakdown:16.5 ~suggested_entry:16.42

(* A cheap long the short-side floor must never drop. *)
let _cheap_long =
  _candidate ~ticker:"CHEAP" ~side:Trading_base.Types.Long ~base_top:5.0
    ~breakdown:4.0 ~suggested_entry:5.05

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

let _series ~close =
  List.init 10 ~f:(fun i ->
      _bar ~date:(Date.add_days _decision_date (-i)) ~close)
  |> List.rev

let _bar_reader () =
  Bar_reader.of_in_memory_bars
    [
      ("UMPQ", _series ~close:10.33);
      ("SPLT", _series ~close:18.0);
      ("CHEAP", _series ~close:5.0);
    ]

(* Inert counts — [assemble] never reads them. *)
let _diagnostics : Screener.cascade_diagnostics =
  {
    total_stocks = 3;
    candidates_after_held = 3;
    macro_trend = Bearish;
    long_macro_admitted = 1;
    long_breakout_admitted = 1;
    long_failed_breakout_dropped = 0;
    long_sector_admitted = 1;
    long_grade_admitted = 1;
    long_top_n_admitted = 1;
    short_macro_admitted = 2;
    short_breakdown_admitted = 2;
    short_sector_admitted = 2;
    short_rs_hard_gate_admitted = 2;
    short_grade_admitted = 2;
    short_top_n_admitted = 2;
  }

let _assembled ~on_order_price ~armed =
  let base =
    Config.default_config
      ~universe:[ "UMPQ"; "SPLT"; "CHEAP" ]
      ~index_symbol:"SPY"
  in
  let config =
    {
      base with
      short_min_price = _floor;
      short_min_price_on_order_price = on_order_price;
      sim_entry_trigger_at_suggested = armed;
      enable_sim_entry_stoplimit = armed;
    }
  in
  Entry_assembly.assemble ~config ~bar_reader:(_bar_reader ())
    ~current_date:_decision_date
    {
      Screener.buy_candidates = [ _cheap_long ];
      short_candidates = [ _umpq; _split_level ];
      watchlist = [];
      macro_trend = Bearish;
      cascade_diagnostics = _diagnostics;
    }
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(** Flag off (default): the gate reads [suggested_entry], so UMPQ passes on its
    19.90 level although its ticket is priced at the 10.33 close. Bit-identical
    to the pre-#3131 gate (R1). *)
let test_flag_off_gates_suggested_entry _ =
  assert_that
    (_assembled ~on_order_price:false ~armed:false)
    (elements_are [ equal_to "CHEAP"; equal_to "UMPQ" ])

(** Flag on, close-priced ticket: UMPQ's order price is the 10.33 close, below
    the floor, so it is rejected; SPLT's close of 18.00 clears it. *)
let test_close_priced_ticket_gates_the_close _ =
  assert_that
    (_assembled ~on_order_price:true ~armed:false)
    (elements_are [ equal_to "CHEAP"; equal_to "SPLT" ])

(** Flag on, E-anchored ticket armed: the order price is the breakdown ticket.
    SPLT's base top is above $17 but its breakdown ticket (16.42) is not, so it
    is rejected; UMPQ's 19.90 ticket is admitted. *)
let test_armed_ticket_gates_the_breakdown_level _ =
  assert_that
    (_assembled ~on_order_price:true ~armed:true)
    (elements_are [ equal_to "CHEAP"; equal_to "UMPQ" ])

(** [Short_min_price_gate.filter ~price_of] gates on whatever price it is
    handed: the same UMPQ candidate passes at its level and fails at its close.
*)
let test_filter_reads_price_of _ =
  let gate price =
    Short_min_price_gate.filter
      ~price_of:(fun _ -> price)
      ~short_min_price:_floor [ _umpq ]
    |> List.length
  in
  assert_that (gate 19.90, gate 10.33) (equal_to (1, 0))

let () =
  run_test_tt_main
    ("short_min_price_order_price"
    >::: [
           "#3131: flag off gates suggested_entry"
           >:: test_flag_off_gates_suggested_entry;
           "#3131: close-priced ticket gates the close"
           >:: test_close_priced_ticket_gates_the_close;
           "#3131: armed ticket gates the breakdown level"
           >:: test_armed_ticket_gates_the_breakdown_level;
           "#3131: filter reads price_of" >:: test_filter_reads_price_of;
         ])
