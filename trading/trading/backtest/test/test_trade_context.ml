(** Unit tests for [Backtest.Trade_context] (M5.2e per-trade context join).

    Pins the join behaviour and the 6 derived fields against synthetic
    trade_metrics + audit + stop_log inputs. Covers:
    - Stage label rendering (Stage1/Stage2/Stage2_late/Stage3/Stage4)
    - stop_trigger_kind label rendering (gap_down/intraday/end_of_period)
    - Successful join: all 6 fields populate from matching audit + stop_log
    - Missing audit: audit-derived fields are [None], symbol still propagates
    - Missing stop_log: stop_trigger_kind / days_to_first_stop_trigger are
      [None]
    - Join preference: position_id first (matching however long after the
      decision the ticket filled), date proximity only as the fallback
    - days_to_first_stop_trigger is [None] when exit was not a stop trigger
    - csv_header_fields shape pin
    - csv_row_fields formatting (None → empty cell, %.4f for floats) *)

open OUnit2
open Core
open Matchers
module TC = Backtest.Trade_context
module TA = Backtest.Trade_audit
module SL = Backtest.Stop_log

let _date d = Date.of_string d

(* Builders ----------------------------------------------------------- *)

let make_trade ?(symbol = "AAPL") ?(side = Trading_base.Types.Buy)
    ?(entry_date = _date "2024-01-15") ?(exit_date = _date "2024-04-20")
    ?(days_held = 96) ?(entry_price = 150.0) ?(exit_price = 138.0)
    ?(quantity = 100.0) ?(pnl_dollars = -1200.0) ?(pnl_percent = -8.0)
    ?position_id () : Trading_simulation.Metrics.trade_metrics =
  {
    symbol;
    side;
    entry_date;
    exit_date;
    days_held;
    entry_price;
    exit_price;
    quantity;
    pnl_dollars;
    pnl_percent;
    position_id;
  }

let make_entry ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-wein-1") ?(side = Trading_base.Types.Long)
    ?(stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false })
    ?(volume_ratio = Some 2.4) ?(suggested_entry = 150.0)
    ?(installed_stop = 138.0) ?(cascade_score = 75) () : TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.72;
    macro_indicators = [];
    stage;
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.018;
    rs_trend = Some Weinstein_types.Positive_rising;
    rs_value = Some 1.05;
    volume_quality = Some (Weinstein_types.Strong 2.4);
    volume_ratio;
    resistance_quality = Some Weinstein_types.Clean;
    support_quality = Some Weinstein_types.Clean;
    sector_name = "Tech";
    sector_rating = Screener.Strong;
    cascade_score;
    cascade_grade = Weinstein_types.A;
    cascade_score_components = [];
    cascade_rationale = [];
    side;
    suggested_entry;
    close_at_decision = None;
    ma_value = None;
    local_range_top = None;
    suggested_stop = installed_stop;
    installed_stop;
    stop_floor_kind = TA.Buffer_fallback;
    split_safe_basis = TA.Flag_off;
    risk_pct = 0.08;
    initial_position_value = 15000.0;
    initial_risk_dollars = 1200.0;
    ticket_lifecycle = None;
    alternatives_considered = [];
  }

let make_record ?exit_ entry : TA.audit_record =
  { entry; exit_; external_exit = None; execution = None }

let make_stop_info ~position_id ~symbol
    ?(entry_date = Some (_date "2024-01-15")) ?(entry_stop = Some 138.0)
    ?(exit_stop = Some 138.0) ?exit_trigger () : SL.stop_info =
  { position_id; symbol; entry_date; entry_stop; exit_stop; exit_trigger }

(* stage_label --------------------------------------------------------- *)

let test_stage_label_distinguishes_late_stage2 _ =
  assert_that
    ( TC.stage_label (Weinstein_types.Stage1 { weeks_in_base = 0 }),
      TC.stage_label
        (Weinstein_types.Stage2 { weeks_advancing = 4; late = false }),
      TC.stage_label
        (Weinstein_types.Stage2 { weeks_advancing = 12; late = true }),
      TC.stage_label (Weinstein_types.Stage3 { weeks_topping = 2 }),
      TC.stage_label (Weinstein_types.Stage4 { weeks_declining = 3 }) )
    (equal_to ("Stage1", "Stage2", "Stage2_late", "Stage3", "Stage4"))

(* stop_trigger_kind_label -------------------------------------------- *)

let test_stop_trigger_kind_label_distinguishes_all _ =
  assert_that
    ( TC.stop_trigger_kind_label SL.Gap_down,
      TC.stop_trigger_kind_label SL.Intraday,
      TC.stop_trigger_kind_label SL.End_of_period,
      TC.stop_trigger_kind_label SL.Non_stop_exit )
    (equal_to ("gap_down", "intraday", "end_of_period", "non_stop_exit"))

(* csv_header_fields --------------------------------------------------- *)

let test_csv_header_fields_pinned _ =
  assert_that TC.csv_header_fields
    (elements_are
       [
         equal_to "entry_stage";
         equal_to "entry_volume_ratio";
         equal_to "stop_initial_distance_pct";
         equal_to "stop_trigger_kind";
         equal_to "days_to_first_stop_trigger";
         equal_to "screener_score_at_entry";
         equal_to "position_id";
         equal_to "stop_fill_distance_pct";
       ])

(* of_audit_and_stop_log: full join ----------------------------------- *)

let test_of_audit_and_stop_log_populates_all_fields _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let audit = [ make_record entry ] in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 137.99 })
      ()
  in
  let stop_infos = [ stop_info ] in
  let ctx = TC.of_audit_and_stop_log ~audit ~stop_infos ~trade in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.entry_stage)
           (is_some_and (equal_to "Stage2"));
         field
           (fun (c : TC.t) -> c.entry_volume_ratio)
           (is_some_and (float_equal 2.4));
         field
           (fun (c : TC.t) -> c.stop_initial_distance_pct)
           (is_some_and (float_equal ~epsilon:1e-6 0.08));
         field
           (fun (c : TC.t) -> c.stop_trigger_kind)
           (is_some_and (equal_to "intraday"));
         field
           (fun (c : TC.t) -> c.days_to_first_stop_trigger)
           (is_some_and (equal_to 96));
         field
           (fun (c : TC.t) -> c.screener_score_at_entry)
           (is_some_and (equal_to 75));
         field
           (fun (c : TC.t) -> c.position_id)
           (is_some_and (equal_to "AAPL-wein-1"));
         field
           (fun (c : TC.t) -> c.stop_fill_distance_pct)
           (is_some_and (float_equal ~epsilon:1e-6 0.08));
       ])

(* Fill-basis vs E-basis: when the realized fill (120) diverges from the
   screener's suggested E (150), the two stop-distance columns disagree —
   E-basis |150-138|/150 = 0.08 but fill-basis |138-120|/120 = 0.15. This is
   the WDC confound in miniature (findings 2026-08-07 §4 RESOLVED): only the
   fill-basis column reflects stop depth vs cost. *)
let test_fill_basis_diverges_from_e_basis _ =
  let trade = make_trade ~entry_price:120.0 () in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record (make_entry ()) ]
      ~stop_infos:[] ~trade
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.stop_initial_distance_pct)
           (is_some_and (float_equal ~epsilon:1e-6 0.08));
         field
           (fun (c : TC.t) -> c.stop_fill_distance_pct)
           (is_some_and (float_equal ~epsilon:1e-6 0.15));
       ])

(* Late Stage2 propagates to entry_stage label. *)
let test_late_stage2_label _ =
  let trade = make_trade () in
  let entry =
    make_entry
      ~stage:(Weinstein_types.Stage2 { weeks_advancing = 12; late = true })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log ~audit:[ make_record entry ] ~stop_infos:[] ~trade
  in
  assert_that ctx.entry_stage (is_some_and (equal_to "Stage2_late"))

(* Gap-down stop flows through to stop_trigger_kind label. *)
let test_gap_down_stop_classified _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 125.0 })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record entry ]
      ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx.stop_trigger_kind (is_some_and (equal_to "gap_down"))

(* Take-profit exit yields non_stop_exit + None days_to_first_stop_trigger. *)
let test_take_profit_exit_is_non_stop _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:
        (SL.Take_profit { target_price = 165.0; actual_price = 165.0 })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record entry ]
      ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.stop_trigger_kind)
           (is_some_and (equal_to "non_stop_exit"));
         field (fun (c : TC.t) -> c.days_to_first_stop_trigger) is_none;
       ])

(* End-of-period exit. *)
let test_end_of_period_exit_classified _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:SL.End_of_period ()
  in
  let ctx =
    TC.of_audit_and_stop_log
      ~audit:[ make_record entry ]
      ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx.stop_trigger_kind (is_some_and (equal_to "end_of_period"))

(* Missing audit record yields None for all audit-derived fields, but
   stop_trigger_kind still populates from stop_log via symbol fallback. *)
let test_missing_audit_yields_none_for_audit_fields _ =
  let trade = make_trade () in
  let stop_info =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 137.99 })
      ()
  in
  let ctx =
    TC.of_audit_and_stop_log ~audit:[] ~stop_infos:[ stop_info ] ~trade
  in
  assert_that ctx
    (all_of
       [
         field (fun (c : TC.t) -> c.entry_stage) is_none;
         field (fun (c : TC.t) -> c.entry_volume_ratio) is_none;
         field (fun (c : TC.t) -> c.stop_initial_distance_pct) is_none;
         field (fun (c : TC.t) -> c.stop_fill_distance_pct) is_none;
         field (fun (c : TC.t) -> c.screener_score_at_entry) is_none;
         field (fun (c : TC.t) -> c.position_id) is_none;
         field
           (fun (c : TC.t) -> c.stop_trigger_kind)
           (is_some_and (equal_to "intraday"));
       ])

(* Missing stop_log yields None for stop-derived fields; audit fields
   still populate. *)
let test_missing_stop_log_yields_none_for_stop_fields _ =
  let trade = make_trade () in
  let entry = make_entry () in
  let ctx =
    TC.of_audit_and_stop_log ~audit:[ make_record entry ] ~stop_infos:[] ~trade
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.entry_stage)
           (is_some_and (equal_to "Stage2"));
         field
           (fun (c : TC.t) -> c.screener_score_at_entry)
           (is_some_and (equal_to 75));
         field (fun (c : TC.t) -> c.stop_trigger_kind) is_none;
         field (fun (c : TC.t) -> c.days_to_first_stop_trigger) is_none;
       ])

(* stop_info_for_trade: re-traded symbol keys by position_id ---------- *)

(* A symbol traded twice must resolve each round-trip to its OWN stop_info via
   the audit-recovered position_id, independent of the order the stop_infos are
   supplied in. This is the join the result writer relies on so exit_trigger
   stays consistent with stop_trigger_kind on re-traded symbols. *)
let test_stop_info_for_trade_keys_by_position_id _ =
  let trade1 =
    make_trade ~entry_date:(_date "2024-01-15") ~exit_date:(_date "2024-02-20")
      ()
  in
  let trade2 =
    make_trade ~entry_date:(_date "2024-05-01") ~exit_date:(_date "2024-06-10")
      ()
  in
  let entry1 =
    make_entry ~entry_date:(_date "2024-01-15") ~position_id:"AAPL-wein-1" ()
  in
  let entry2 =
    make_entry ~entry_date:(_date "2024-05-01") ~position_id:"AAPL-wein-2" ()
  in
  let stop1 =
    make_stop_info ~position_id:"AAPL-wein-1" ~symbol:"AAPL"
      ~exit_trigger:(SL.Stop_loss { stop_price = 138.0; actual_price = 137.99 })
      ()
  in
  let stop2 =
    make_stop_info ~position_id:"AAPL-wein-2" ~symbol:"AAPL"
      ~exit_trigger:SL.End_of_period ()
  in
  (* stop_infos deliberately reversed relative to trade order so an
     order-dependent (FIFO) join would mis-assign. *)
  let pre =
    TC.precompute
      ~audit:[ make_record entry1; make_record entry2 ]
      ~stop_infos:[ stop2; stop1 ]
  in
  assert_that
    (TC.stop_info_for_trade pre ~trade:trade1)
    (is_some_and
       (field
          (fun (i : SL.stop_info) -> i.position_id)
          (equal_to "AAPL-wein-1")));
  assert_that
    (TC.stop_info_for_trade pre ~trade:trade2)
    (is_some_and
       (field
          (fun (i : SL.stop_info) -> i.position_id)
          (equal_to "AAPL-wein-2")))

(* position_id join: decision→fill gap far beyond the date window ------ *)

(* A resting entry ticket placed on the 2024-01-15 decision tick but not filled
   until 2024-09-30 — 259 days later, two orders of magnitude outside the 7-day
   date-proximity window. The position_id join must still attach the audit
   record. This is the case that was silently empty for 51% of rows on a real
   run before the round-trip carried its position id. *)
let _stale_fill_trade ?position_id () =
  make_trade ~entry_date:(_date "2024-09-30") ~exit_date:(_date "2024-11-15")
    ?position_id ()

let test_position_id_join_survives_stale_fill _ =
  let audit = [ make_record (make_entry ~position_id:"AAPL-wein-7" ()) ] in
  let ctx =
    TC.of_audit_and_stop_log ~audit ~stop_infos:[]
      ~trade:(_stale_fill_trade ~position_id:"AAPL-wein-7" ())
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.entry_stage)
           (is_some_and (equal_to "Stage2"));
         field
           (fun (c : TC.t) -> c.screener_score_at_entry)
           (is_some_and (equal_to 75));
         (* |150 - 138| / 150 on both the E basis and the fill basis, since the
            round-trip's entry_price defaults to the suggested entry. *)
         field
           (fun (c : TC.t) -> c.stop_initial_distance_pct)
           (is_some_and (float_equal 0.08));
         field
           (fun (c : TC.t) -> c.stop_fill_distance_pct)
           (is_some_and (float_equal 0.08));
         field
           (fun (c : TC.t) -> c.position_id)
           (is_some_and (equal_to "AAPL-wein-7"));
       ])

(* Same stale fill with NO position id on the round-trip: the date fallback is
   all that remains, and it correctly declines to guess across a 259-day gap.
   Pins that the fix threads a key through rather than widening the window —
   an empty column here is the intended outcome, not a wrong one. *)
let test_stale_fill_without_position_id_stays_unjoined _ =
  let audit = [ make_record (make_entry ~position_id:"AAPL-wein-7" ()) ] in
  let ctx =
    TC.of_audit_and_stop_log ~audit ~stop_infos:[] ~trade:(_stale_fill_trade ())
  in
  assert_that ctx
    (all_of
       [
         field (fun (c : TC.t) -> c.entry_stage) is_none;
         field (fun (c : TC.t) -> c.position_id) is_none;
       ])

(* No position id, fill 3 days after the decision: the legacy date-proximity
   path still joins, so nothing that worked before regresses. *)
let test_date_fallback_still_joins_within_window _ =
  let audit =
    [
      make_record
        (make_entry ~entry_date:(_date "2024-01-12") ~position_id:"AAPL-wein-3"
           ());
    ]
  in
  let ctx =
    TC.of_audit_and_stop_log ~audit ~stop_infos:[]
      ~trade:(make_trade ~entry_date:(_date "2024-01-15") ())
  in
  assert_that ctx
    (all_of
       [
         field
           (fun (c : TC.t) -> c.entry_stage)
           (is_some_and (equal_to "Stage2"));
         field
           (fun (c : TC.t) -> c.position_id)
           (is_some_and (equal_to "AAPL-wein-3"));
       ])

(* A position id no audit record claims falls back to the date path rather than
   returning nothing — the pre-fix behaviour for such a row, preserved. *)
let test_unknown_position_id_falls_back_to_date _ =
  let audit =
    [
      make_record
        (make_entry ~entry_date:(_date "2024-01-12") ~position_id:"AAPL-wein-3"
           ());
    ]
  in
  let ctx =
    TC.of_audit_and_stop_log ~audit ~stop_infos:[]
      ~trade:
        (make_trade ~entry_date:(_date "2024-01-15")
           ~position_id:"AAPL-wein-999" ())
  in
  assert_that ctx
    (field (fun (c : TC.t) -> c.entry_stage) (is_some_and (equal_to "Stage2")))

(* csv_row_fields formatting ----------------------------------------- *)

let test_csv_row_fields_formats_correctly _ =
  let ctx : TC.t =
    {
      symbol = "AAPL";
      entry_date = _date "2024-01-15";
      entry_stage = Some "Stage2";
      entry_volume_ratio = Some 2.4;
      stop_initial_distance_pct = Some 0.08;
      stop_trigger_kind = Some "intraday";
      days_to_first_stop_trigger = Some 96;
      screener_score_at_entry = Some 75;
      position_id = Some "AAPL-wein-1";
      stop_fill_distance_pct = Some 0.065;
    }
  in
  assert_that (TC.csv_row_fields ctx)
    (elements_are
       [
         equal_to "Stage2";
         equal_to "2.4000";
         equal_to "0.0800";
         equal_to "intraday";
         equal_to "96";
         equal_to "75";
         equal_to "AAPL-wein-1";
         equal_to "0.0650";
       ])

let test_csv_row_fields_renders_none_as_empty _ =
  let ctx : TC.t =
    {
      symbol = "AAPL";
      entry_date = _date "2024-01-15";
      entry_stage = None;
      entry_volume_ratio = None;
      stop_initial_distance_pct = None;
      stop_trigger_kind = None;
      days_to_first_stop_trigger = None;
      screener_score_at_entry = None;
      position_id = None;
      stop_fill_distance_pct = None;
    }
  in
  assert_that (TC.csv_row_fields ctx)
    (elements_are
       [
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
         equal_to "";
       ])

(* --- Reader-side schema (header-addressed position_id) ----------------- *)

(** The full post-#2317 header a current [Result_writer] emits: the 13 base
    columns plus {!TC.csv_header_fields}. [position_id] sits at index 19 today,
    but no reader may hardcode that — the tests below pin that the lookup is by
    name. *)
let _canonical_header =
  String.concat ~sep:","
    ([
       "symbol";
       "side";
       "entry_date";
       "exit_date";
       "days_held";
       "entry_price";
       "exit_price";
       "quantity";
       "pnl_dollars";
       "pnl_percent";
       "entry_stop";
       "exit_stop";
       "exit_trigger";
     ]
    @ TC.csv_header_fields)

(* 21 cells matching [_canonical_header], with [position_id] parameterised. *)
let _canonical_row ~position_id =
  String.split ~on:','
    ("AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal,Stage2,2.4000,0.0800,intraday,36,75,"
   ^ position_id ^ ",0.0650")

let test_position_id_read_from_populated_cell _ =
  let schema = TC.csv_schema_of_header_line _canonical_header in
  assert_that
    (TC.position_id_of_cells schema (_canonical_row ~position_id:"AAPL-wein-7"))
    (is_some_and (equal_to "AAPL-wein-7"))

let test_position_id_empty_cell_reads_none _ =
  (* The canonical missing-data sentinel [csv_row_fields] writes for [None].
     Must not surface as [Some ""] — an empty id joins nothing yet would still
     suppress the date fallback in a caller that only checks [is_some]. *)
  let schema = TC.csv_schema_of_header_line _canonical_header in
  assert_that
    (TC.position_id_of_cells schema (_canonical_row ~position_id:""))
    is_none

let test_position_id_absent_from_header_reads_none _ =
  (* Legacy 12-column layout: the column does not exist at all. *)
  let schema =
    TC.csv_schema_of_header_line
      "symbol,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,entry_stop,exit_stop,exit_trigger"
  in
  assert_that
    (TC.position_id_of_cells schema
       (String.split ~on:','
          "AAPL,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal"))
    is_none

let test_position_id_short_row_reads_none _ =
  (* Header advertises the column but the row predates the trailing context
     block (13 cells only). Reading past the end is a missing value, not an
     error. *)
  let schema = TC.csv_schema_of_header_line _canonical_header in
  assert_that
    (TC.position_id_of_cells schema
       (String.split ~on:','
          "AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal"))
    is_none

let test_position_id_follows_header_position_not_fixed_index _ =
  (* A hypothetical layout that inserts a column ahead of [position_id]: the
     by-name lookup tracks it. A reader pinned to today's index 19 would return
     the neighbouring [screener_score_at_entry] cell ("75") instead. *)
  let schema =
    TC.csv_schema_of_header_line
      (String.substr_replace_first _canonical_header
         ~pattern:"screener_score_at_entry"
         ~with_:"inserted_column,screener_score_at_entry")
  in
  assert_that
    (TC.position_id_of_cells schema
       (String.split ~on:','
          "AAPL,LONG,2024-01-15,2024-02-20,36,150.00,165.00,10,150.00,10.00,140.00,160.00,signal_reversal,Stage2,2.4000,0.0800,intraday,36,inserted,75,AAPL-wein-9,0.0650"))
    (is_some_and (equal_to "AAPL-wein-9"))

let test_legacy_csv_schema_never_yields_position_id _ =
  assert_that
    (TC.position_id_of_cells TC.legacy_csv_schema
       (_canonical_row ~position_id:"AAPL-wein-7"))
    is_none

let suite =
  "Trade_context"
  >::: [
         "position_id read from populated cell"
         >:: test_position_id_read_from_populated_cell;
         "position_id empty cell reads none"
         >:: test_position_id_empty_cell_reads_none;
         "position_id absent from header reads none"
         >:: test_position_id_absent_from_header_reads_none;
         "position_id short row reads none"
         >:: test_position_id_short_row_reads_none;
         "position_id follows header position not fixed index"
         >:: test_position_id_follows_header_position_not_fixed_index;
         "legacy_csv_schema never yields position_id"
         >:: test_legacy_csv_schema_never_yields_position_id;
         "stage_label distinguishes Stage2_late"
         >:: test_stage_label_distinguishes_late_stage2;
         "stop_trigger_kind_label all variants"
         >:: test_stop_trigger_kind_label_distinguishes_all;
         "csv_header_fields pinned" >:: test_csv_header_fields_pinned;
         "fill basis diverges from E basis"
         >:: test_fill_basis_diverges_from_e_basis;
         "of_audit_and_stop_log full join"
         >:: test_of_audit_and_stop_log_populates_all_fields;
         "late stage2 label" >:: test_late_stage2_label;
         "gap_down stop classified" >:: test_gap_down_stop_classified;
         "take_profit exit is non_stop" >:: test_take_profit_exit_is_non_stop;
         "End_of_period exit classified" >:: test_end_of_period_exit_classified;
         "missing audit -> audit fields None"
         >:: test_missing_audit_yields_none_for_audit_fields;
         "missing stop_log -> stop fields None"
         >:: test_missing_stop_log_yields_none_for_stop_fields;
         "stop_info_for_trade keys by position_id"
         >:: test_stop_info_for_trade_keys_by_position_id;
         "position_id join survives stale fill"
         >:: test_position_id_join_survives_stale_fill;
         "stale fill without position_id stays unjoined"
         >:: test_stale_fill_without_position_id_stays_unjoined;
         "date fallback still joins within window"
         >:: test_date_fallback_still_joins_within_window;
         "unknown position_id falls back to date"
         >:: test_unknown_position_id_falls_back_to_date;
         "csv_row_fields formats correctly"
         >:: test_csv_row_fields_formats_correctly;
         "csv_row_fields renders None as empty"
         >:: test_csv_row_fields_renders_none_as_empty;
       ]

let () = run_test_tt_main suite
