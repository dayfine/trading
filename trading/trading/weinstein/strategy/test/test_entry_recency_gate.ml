(** Unit tests for the [entry_max_bar_age_days] entry-recency gate (issue #2672,
    guard 1 of 3).

    Pins the no-op-default contract and the gating behaviour of
    {!Weinstein_strategy.Entry_recency_gate}:

    - [max_bar_age_days = 0] (the default) → identity: every candidate is
      retained, so the entry candidate list is bit-identical to prior behaviour
      and every existing golden/baseline replays unchanged (R1).
    - Armed, a candidate whose latest bar is older than the allowance is dropped
      — the DTV shape from #2672 (last bar 2019-09-30, decision 2020-03-28, a
      180-day gap, entered at the stale $58.09 close).
    - A weekend-stale bar (3 days) survives a 10-day allowance: the gate must
      not confuse "the market was shut" with "the symbol is dead".
    - The boundary is inclusive ([gap = allowance] is kept), a missing reading
      never drops a candidate, and both sides are gated symmetrically.

    Plus the strategy-side adapter {!Entry_recency_gate.apply} over a real
    {!Bar_reader}, which pins that the gate reads the {b same} last bar the
    entry path prices off ({!Entry_audit_helpers.latest_close}). *)

open OUnit2
open Core
open Matchers
open Weinstein_types
module Bar_reader = Weinstein_strategy.Bar_reader
module Entry_recency_gate = Weinstein_strategy.Entry_recency_gate

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

(* The #2672 decision date: DTV was entered here off a 2019-09-30 bar. *)
let _decision_date = Date.of_string "2020-03-28"

(* Per-ticker last-bar-date lookup driven by an assoc list. A missing key and an
   explicit [None] both yield [None] (the gate treats both as "no reading"). *)
let _last_bar_date_for table ticker =
  Option.join (List.Assoc.find table ticker ~equal:String.equal)

let _days_before n = Some (Date.add_days _decision_date (-n))

(* DTV's real gap in the #2672 sighting: 2019-09-30 -> 2020-03-28. *)
let _dtv_last_bar = Some (Date.of_string "2019-09-30")

let _survivors ~max_bar_age_days ~table candidates =
  Entry_recency_gate.filter ~max_bar_age_days ~current_date:_decision_date
    ~last_bar_date_for:(_last_bar_date_for table) candidates
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(** Default [0] is a no-op: the stale DTV candidate is retained, in order. This
    is the R1 contract — merging the gate moves no golden. *)
let test_zero_allowance_is_noop _ =
  assert_that
    (_survivors ~max_bar_age_days:0
       ~table:[ ("DTV", _dtv_last_bar); ("FRESH", _days_before 1) ]
       [ _long "DTV"; _long "FRESH" ])
    (elements_are [ equal_to "DTV"; equal_to "FRESH" ])

(** Armed at 10 days, the 180-day-stale DTV candidate is dropped. *)
let test_stale_candidate_is_dropped _ =
  assert_that
    (_survivors ~max_bar_age_days:10
       ~table:[ ("DTV", _dtv_last_bar); ("FRESH", _days_before 1) ]
       [ _long "DTV"; _long "FRESH" ])
    (elements_are [ equal_to "FRESH" ])

(** A 3-day-old bar (Friday close read on a Monday decision) survives a 10-day
    allowance — a market holiday is not a delisting. *)
let test_weekend_stale_bar_is_kept _ =
  assert_that
    (_survivors ~max_bar_age_days:10
       ~table:[ ("WKND", _days_before 3) ]
       [ _long "WKND" ])
    (elements_are [ equal_to "WKND" ])

(** The boundary is inclusive: [gap = allowance] is kept, [gap = allowance + 1]
    is dropped. *)
let test_boundary_is_inclusive _ =
  assert_that
    (_survivors ~max_bar_age_days:10
       ~table:[ ("AT", _days_before 10); ("OVER", _days_before 11) ]
       [ _long "AT"; _long "OVER" ])
    (elements_are [ equal_to "AT" ])

(** A bar dated {b after} the decision date yields a negative gap and is kept —
    the gate is a staleness floor, not a two-sided window, so a warehouse row
    that runs ahead of the simulated clock must never drop a candidate. *)
let test_future_dated_bar_is_kept _ =
  assert_that
    (_survivors ~max_bar_age_days:10
       ~table:[ ("AHEAD", _days_before (-5)) ]
       [ _long "AHEAD" ])
    (elements_are [ equal_to "AHEAD" ])

(** No reading never drops a candidate (matches {!Short_borrow_gate.filter}). *)
let test_missing_reading_is_retained _ =
  assert_that
    (_survivors ~max_bar_age_days:10
       ~table:[ ("UNKNOWN", None) ]
       [ _long "UNKNOWN" ])
    (elements_are [ equal_to "UNKNOWN" ])

(** Longs and shorts are gated symmetrically — a stale price is equally unusable
    on either side. *)
let test_both_sides_are_gated _ =
  assert_that
    (_survivors ~max_bar_age_days:10
       ~table:[ ("SL", _dtv_last_bar); ("SF", _days_before 2) ]
       [ _short "SL"; _short "SF" ])
    (elements_are [ equal_to "SF" ])

(* --- Adapter over a real Bar_reader ---------------------------------- *)

let _bar ~date ~close : Types.Daily_price.t =
  {
    date;
    open_price = close;
    high_price = close;
    low_price = close;
    close_price = close;
    adjusted_close = close;
    volume = 100_000;
    active_through = None;
  }

(* STALE's series ends 180 days before the decision date; LIVE's ends the day
   before. Both are 30 bars long so neither is empty. *)
let _series ~last_bar_offset =
  let last = Date.add_days _decision_date (-last_bar_offset) in
  List.init 30 ~f:(fun i ->
      _bar ~date:(Date.add_days last (i - 29)) ~close:58.09)

let _adapter_survivors ~max_bar_age_days =
  let bar_reader =
    Bar_reader.of_in_memory_bars
      [
        ("STALE", _series ~last_bar_offset:180);
        ("LIVE", _series ~last_bar_offset:1);
      ]
  in
  Entry_recency_gate.apply ~max_bar_age_days ~bar_reader
    ~current_date:_decision_date
    [ _long "STALE"; _long "LIVE" ]
  |> List.map ~f:(fun (c : Screener.scored_candidate) -> c.ticker)

(** [apply] at the default keeps both — the DTV entry the gate exists to prevent
    is exactly what happens today. *)
let test_apply_default_keeps_stale _ =
  assert_that
    (_adapter_survivors ~max_bar_age_days:0)
    (elements_are [ equal_to "STALE"; equal_to "LIVE" ])

(** [apply] armed at 10 reads the real last bar off the reader and drops the
    stale symbol — the same bar {!Entry_audit_helpers.latest_close} would have
    priced the entry off. *)
let test_apply_armed_drops_stale _ =
  assert_that
    (_adapter_survivors ~max_bar_age_days:10)
    (elements_are [ equal_to "LIVE" ])

let () =
  run_test_tt_main
    ("entry_recency_gate"
    >::: [
           "zero allowance is a no-op" >:: test_zero_allowance_is_noop;
           "stale candidate is dropped" >:: test_stale_candidate_is_dropped;
           "weekend-stale bar is kept" >:: test_weekend_stale_bar_is_kept;
           "boundary is inclusive" >:: test_boundary_is_inclusive;
           "future-dated bar is kept" >:: test_future_dated_bar_is_kept;
           "missing reading is retained" >:: test_missing_reading_is_retained;
           "both sides are gated" >:: test_both_sides_are_gated;
           "apply: default keeps the stale symbol"
           >:: test_apply_default_keeps_stale;
           "apply: armed drops the stale symbol"
           >:: test_apply_armed_drops_stale;
         ])
