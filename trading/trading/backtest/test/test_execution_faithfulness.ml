(** Unit tests for [Backtest.Execution_faithfulness] (#2158 follow-on).

    Pins:
    - [entry_order_kind_of_config]: Market unless the StopLimit fill model is
      armed ([enable_sim_entry_stoplimit && entry_extension_max_pct > 0]).
    - [enrich]: the designed-order + fill join produces the right
      [execution_faithfulness] verdict per case — Market is faithful by
      definition; a StopLimit is faithful iff the fill sat at/beyond the trigger
      in the breakout direction and within the do-not-chase cap.
    - The designed trigger is recovered exactly as the effective entry from the
      audit's dollar fields.
    - Unmatched (still-open) entries keep [execution = None].
    - sexp back-compat: an old [audit_record] sexp with no [execution] field
      parses ([execution = None]); a record carrying an [execution] round-trips.
*)

open OUnit2
open Core
open Matchers
module EF = Backtest.Execution_faithfulness
module TA = Backtest.Trade_audit
module TL = Backtest.Ticket_lifecycle

let _date d = Date.of_string d

(* Builders ----------------------------------------------------------- *)

let make_trade ?(symbol = "AAPL") ?(side = Trading_base.Types.Buy)
    ?(entry_date = _date "2024-01-15") ?(entry_price = 150.0) ?position_id () :
    Trading_simulation.Metrics.trade_metrics =
  {
    symbol;
    side;
    entry_date;
    exit_date = _date "2024-04-20";
    days_held = 96;
    entry_price;
    exit_price = 138.0;
    quantity = 100.0;
    pnl_dollars = -1200.0;
    pnl_percent = -8.0;
    position_id;
  }

(* [initial_position_value = 100 * suggested_entry],
   [initial_risk_dollars = 100 * |suggested_entry - installed_stop|] so the
   trigger recovery returns [suggested_entry] exactly. *)
let make_entry ?(symbol = "AAPL") ?(entry_date = _date "2024-01-15")
    ?(position_id = "AAPL-wein-1") ?(side = Trading_base.Types.Long)
    ?(suggested_entry = 150.0) ?(installed_stop = 138.0)
    ?(ticket_lifecycle = None) () : TA.entry_decision =
  {
    symbol;
    entry_date;
    position_id;
    macro_trend = Weinstein_types.Bullish;
    macro_confidence = 0.72;
    macro_indicators = [];
    stage = Weinstein_types.Stage2 { weeks_advancing = 4; late = false };
    ma_direction = Weinstein_types.Rising;
    ma_slope_pct = 0.018;
    rs_trend = Some Weinstein_types.Positive_rising;
    rs_value = Some 1.05;
    volume_quality = Some (Weinstein_types.Strong 2.4);
    volume_ratio = Some 2.4;
    resistance_quality = Some Weinstein_types.Clean;
    support_quality = Some Weinstein_types.Clean;
    sector_name = "Tech";
    sector_rating = Screener.Strong;
    cascade_score = 75;
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
    initial_position_value = 100.0 *. suggested_entry;
    initial_risk_dollars = 100.0 *. Float.abs (suggested_entry -. installed_stop);
    ticket_lifecycle;
    alternatives_considered = [];
  }

let make_record entry : TA.audit_record =
  { entry; exit_ = None; external_exit = None; execution = None }

(* The [config] plumbing only reads two fields; build via [default_config] and
   override so we don't depend on unrelated defaults. *)
let config_with ~stoplimit ~extension_pct : Weinstein_strategy.config =
  {
    (Weinstein_strategy.default_config ~universe:[ "AAPL" ]
       ~index_symbol:"GSPC.INDX")
    with
    enable_sim_entry_stoplimit = stoplimit;
    entry_extension_max_pct = extension_pct;
  }

let execution_of_first records =
  match records with [ (r : TA.audit_record) ] -> r.execution | _ -> None

(* entry_order_kind_of_config ----------------------------------------- *)

let test_kind_market_when_flag_off _ =
  assert_that
    (EF.entry_order_kind_of_config
       (config_with ~stoplimit:false ~extension_pct:15.0))
    (equal_to (EF.Market : EF.entry_order_kind))

let test_kind_market_when_extension_zero _ =
  assert_that
    (EF.entry_order_kind_of_config
       (config_with ~stoplimit:true ~extension_pct:0.0))
    (equal_to (EF.Market : EF.entry_order_kind))

let test_kind_stoplimit_when_armed _ =
  assert_that
    (EF.entry_order_kind_of_config
       (config_with ~stoplimit:true ~extension_pct:15.0))
    (equal_to (EF.Stop_limit_band 0.15 : EF.entry_order_kind))

(* enrich: Market ----------------------------------------------------- *)

let test_market_fill_is_faithful _ =
  let audit = [ make_record (make_entry ()) ] in
  let round_trips = [ make_trade ~entry_price:151.0 () ] in
  assert_that
    (execution_of_first
       (EF.enrich ~audit ~round_trips ~entry_order_kind:Market))
    (is_some_and
       (all_of
          [
            field
              (fun e -> e.TA.designed_order_type)
              (equal_to (TA.Market : TA.designed_order_type));
            field (fun e -> e.TA.designed_trigger) (float_equal 150.0);
            field (fun e -> e.TA.fill_price) (float_equal 151.0);
            field (fun e -> e.TA.fill_within_band) (equal_to true);
            field (fun e -> e.TA.faithful) (equal_to true);
          ]))

(* enrich: StopLimit long --------------------------------------------- *)

let test_stoplimit_fill_at_trigger_is_faithful _ =
  let audit = [ make_record (make_entry ()) ] in
  (* Fill exactly at the breakout trigger (150) — a genuinely resting stop. *)
  let round_trips = [ make_trade ~entry_price:150.0 () ] in
  assert_that
    (execution_of_first
       (EF.enrich ~audit ~round_trips ~entry_order_kind:(Stop_limit_band 0.15)))
    (is_some_and
       (all_of
          [
            field
              (fun e -> e.TA.designed_order_type)
              (matching ~msg:"Expected Stop_limit"
                 (function
                   | TA.Stop_limit { trigger; limit } -> Some (trigger, limit)
                   | TA.Market -> None)
                 (all_of
                    [
                      field fst (float_equal 150.0);
                      field snd (float_equal 172.5);
                    ]));
            field (fun e -> e.TA.fill_vs_trigger_pct) (float_equal 0.0);
            field (fun e -> e.TA.fill_within_band) (equal_to true);
            field (fun e -> e.TA.faithful) (equal_to true);
          ]))

let test_stoplimit_fill_below_trigger_is_unfaithful _ =
  let audit = [ make_record (make_entry ()) ] in
  (* Fill BELOW the breakout (the G14 close-trigger pathology): the order did
     not rest at the breakout — unfaithful. *)
  let round_trips = [ make_trade ~entry_price:140.0 () ] in
  assert_that
    (execution_of_first
       (EF.enrich ~audit ~round_trips ~entry_order_kind:(Stop_limit_band 0.15)))
    (is_some_and
       (all_of
          [
            field
              (fun e -> e.TA.fill_vs_trigger_pct)
              (float_equal ((140.0 -. 150.0) /. 150.0));
            field (fun e -> e.TA.fill_within_band) (equal_to false);
            field (fun e -> e.TA.faithful) (equal_to false);
          ]))

let test_stoplimit_fill_above_cap_is_unfaithful _ =
  let audit = [ make_record (make_entry ()) ] in
  (* Fill above the do-not-chase cap (172.5) — chased too far, unfaithful. *)
  let round_trips = [ make_trade ~entry_price:180.0 () ] in
  assert_that
    (execution_of_first
       (EF.enrich ~audit ~round_trips ~entry_order_kind:(Stop_limit_band 0.15)))
    (is_some_and (field (fun e -> e.TA.faithful) (equal_to false)))

(* enrich: StopLimit short -------------------------------------------- *)

let test_stoplimit_short_fill_at_trigger_is_faithful _ =
  (* Short: E=100 recovered from value 10000 / risk 1200 vs stop 112. Fill at
     the breakdown trigger (100) is within [85, 100] — faithful. *)
  let entry =
    make_entry ~side:Trading_base.Types.Short ~suggested_entry:100.0
      ~installed_stop:112.0 ()
  in
  let round_trips =
    [ make_trade ~side:Trading_base.Types.Sell ~entry_price:100.0 () ]
  in
  assert_that
    (execution_of_first
       (EF.enrich
          ~audit:[ make_record entry ]
          ~round_trips ~entry_order_kind:(Stop_limit_band 0.15)))
    (is_some_and
       (all_of
          [
            field (fun e -> e.TA.designed_trigger) (float_equal 100.0);
            field
              (fun e -> e.TA.designed_order_type)
              (matching ~msg:"Expected Stop_limit"
                 (function
                   | TA.Stop_limit { trigger; limit } -> Some (trigger, limit)
                   | TA.Market -> None)
                 (all_of
                    [
                      field fst (float_equal 100.0);
                      field snd (float_equal 85.0);
                    ]));
            field (fun e -> e.TA.faithful) (equal_to true);
          ]))

(* enrich: unmatched entry -------------------------------------------- *)

let test_unmatched_entry_keeps_none _ =
  let audit = [ make_record (make_entry ~position_id:"AAPL-wein-1" ()) ] in
  (* Round-trip for a different symbol/date — no position match. *)
  let round_trips =
    [ make_trade ~symbol:"MSFT" ~entry_date:(_date "2020-06-01") () ]
  in
  assert_that
    (execution_of_first
       (EF.enrich ~audit ~round_trips ~entry_order_kind:(Stop_limit_band 0.15)))
    is_none

(* sexp back-compat --------------------------------------------------- *)

let test_old_sexp_without_execution_parses_as_none _ =
  (* [@sexp.option] omits [execution] when [None], so a record serialized
     without it (= every pre-#2158 [trade_audit.sexp]) still parses. *)
  let old_record = make_record (make_entry ()) in
  let sexp = TA.sexp_of_audit_records [ old_record ] in
  assert_that
    (Sexp.to_string sexp |> String.is_substring ~substring:"execution")
    (equal_to false)

let test_execution_record_round_trips _ =
  let enriched =
    EF.enrich
      ~audit:[ make_record (make_entry ()) ]
      ~round_trips:[ make_trade ~entry_price:150.0 () ]
      ~entry_order_kind:(Stop_limit_band 0.15)
  in
  let round_tripped =
    TA.sexp_of_audit_records enriched |> TA.audit_records_of_sexp
  in
  (* Whole-record pin: all six execution fields survive the sexp round-trip. *)
  assert_that
    (execution_of_first round_tripped)
    (is_some_and
       (all_of
          [
            field
              (fun e -> e.TA.designed_order_type)
              (matching ~msg:"Expected Stop_limit"
                 (function
                   | TA.Stop_limit { trigger; limit } -> Some (trigger, limit)
                   | TA.Market -> None)
                 (all_of
                    [
                      field fst (float_equal 150.0);
                      field snd (float_equal 172.5);
                    ]));
            field (fun e -> e.TA.designed_trigger) (float_equal 150.0);
            field (fun e -> e.TA.fill_price) (float_equal 150.0);
            field (fun e -> e.TA.fill_vs_trigger_pct) (float_equal 0.0);
            field (fun e -> e.TA.fill_within_band) (equal_to true);
            field (fun e -> e.TA.faithful) (equal_to true);
          ]))

let test_degenerate_trigger_falls_back_to_suggested_entry _ =
  (* When the dollar fields cannot recover [E] ([initial_position_value <= 0]),
     the trigger falls back to the screener's [suggested_entry] — the recovery
     formula is undefined (nan ratio), so the guard rejects it. *)
  let entry =
    {
      (make_entry ~suggested_entry:200.0 ~installed_stop:180.0 ()) with
      initial_position_value = 0.0;
    }
  in
  assert_that
    (execution_of_first
       (EF.enrich
          ~audit:[ make_record entry ]
          ~round_trips:[ make_trade ~entry_price:200.0 () ]
          ~entry_order_kind:Market))
    (is_some_and (field (fun e -> e.TA.designed_trigger) (float_equal 200.0)))

(* PR-5 ticket age at fill --------------------------------------------- *)

let _lifecycle ?(ticket_age_weeks_at_cancel = None) ~placement_date () : TL.t =
  {
    placement_date;
    ticket_age_weeks_at_cancel;
    ticket_age_weeks_at_fill = None;
    fill_volume = None;
    freshness_basis = TL.Ma_cross;
    sized_down_wide_stop = false;
    triple_confirmation =
      {
        breakout_volume_multiple = None;
        rs_zero_cross = false;
        in_base_advance_pct = None;
      };
  }

let _lifecycle_of_first records =
  match records with
  | [ (r : TA.audit_record) ] -> r.entry.ticket_lifecycle
  | _ -> None

let _age_of_first records =
  Option.bind (_lifecycle_of_first records) ~f:(fun (l : TL.t) ->
      l.ticket_age_weeks_at_fill)

let _enrich_one ?ticket_age_weeks_at_cancel ?position_id ~placement ~fill () =
  let audit =
    [
      make_record
        (make_entry ~entry_date:(_date placement)
           ~ticket_lifecycle:
             (Some
                (_lifecycle ?ticket_age_weeks_at_cancel
                   ~placement_date:(_date placement) ()))
           ());
    ]
  in
  EF.enrich ~audit
    ~round_trips:[ make_trade ~entry_date:(_date fill) ?position_id () ]
    ~entry_order_kind:Market

(** A ticket placed on the Friday and filled the following Monday resolves at
    age 0; one filled a week later resolves at 1. Both sit inside
    {!Trade_context}'s date-proximity fallback window, so they resolve even for
    a round-trip carrying no position id. *)
let test_enrich_stamps_ticket_age_at_fill _ =
  let enriched ~placement ~fill =
    _age_of_first (_enrich_one ~placement ~fill ())
  in
  assert_that
    [
      enriched ~placement:"2024-01-12" ~fill:"2024-01-15";
      enriched ~placement:"2024-01-08" ~fill:"2024-01-15";
    ]
    (elements_are [ is_some_and (equal_to 0); is_some_and (equal_to 1) ])

(** A ticket that rested 12 weeks before filling. The date-proximity fallback
    cannot reach that far — which is why this column used to read only 0 or 1 —
    but the position-id join does, so the real resting age is stamped. *)
let test_enrich_stamps_multi_week_age_via_position_id _ =
  assert_that
    (_age_of_first
       (_enrich_one ~position_id:"AAPL-wein-1" ~placement:"2024-01-12"
          ~fill:"2024-04-05" ()))
    (is_some_and (equal_to 12))

(** The fill stamp writes ONLY its own column. Given a row that already carries
    a cancel-side age, enrichment leaves that value intact — the split keeps the
    two resolution modes' statistics from being averaged together. *)
let test_enrich_writes_only_the_fill_age_column _ =
  assert_that
    (_lifecycle_of_first
       (_enrich_one ~ticket_age_weeks_at_cancel:(Some 9) ~placement:"2024-01-12"
          ~fill:"2024-01-15" ()))
    (is_some_and
       (all_of
          [
            field
              (fun (l : TL.t) -> l.ticket_age_weeks_at_fill)
              (is_some_and (equal_to 0));
            field
              (fun (l : TL.t) -> l.ticket_age_weeks_at_cancel)
              (is_some_and (equal_to 9));
          ]))

(** A [trade_audit.sexp] written before PR-5 has no [ticket_lifecycle]; the
    enrichment must not fabricate one, only the [execution] record it owns. *)
let test_enrich_leaves_a_pre_pr5_row_without_a_lifecycle _ =
  let audit = [ make_record (make_entry ()) ] in
  let enriched =
    EF.enrich ~audit ~round_trips:[ make_trade () ] ~entry_order_kind:Market
  in
  assert_that enriched
    (elements_are
       [
         all_of
           [
             field
               (fun (r : TA.audit_record) -> r.entry.ticket_lifecycle)
               is_none;
             field
               (fun (r : TA.audit_record) -> r.execution)
               (is_some_and (field (fun e -> e.TA.faithful) (equal_to true)));
           ];
       ])

let suite =
  "execution_faithfulness"
  >::: [
         "enrich stamps the ticket age at fill"
         >:: test_enrich_stamps_ticket_age_at_fill;
         "enrich stamps a multi-week age via position_id"
         >:: test_enrich_stamps_multi_week_age_via_position_id;
         "enrich writes only the fill age column"
         >:: test_enrich_writes_only_the_fill_age_column;
         "enrich leaves a pre-PR-5 row without a lifecycle"
         >:: test_enrich_leaves_a_pre_pr5_row_without_a_lifecycle;
         "kind: Market when flag off" >:: test_kind_market_when_flag_off;
         "kind: Market when extension 0"
         >:: test_kind_market_when_extension_zero;
         "kind: StopLimit when armed" >:: test_kind_stoplimit_when_armed;
         "Market fill is faithful" >:: test_market_fill_is_faithful;
         "StopLimit fill at trigger is faithful"
         >:: test_stoplimit_fill_at_trigger_is_faithful;
         "StopLimit fill below trigger is unfaithful"
         >:: test_stoplimit_fill_below_trigger_is_unfaithful;
         "StopLimit fill above cap is unfaithful"
         >:: test_stoplimit_fill_above_cap_is_unfaithful;
         "StopLimit short fill at trigger is faithful"
         >:: test_stoplimit_short_fill_at_trigger_is_faithful;
         "unmatched entry keeps None" >:: test_unmatched_entry_keeps_none;
         "old sexp without execution parses as None"
         >:: test_old_sexp_without_execution_parses_as_none;
         "execution record round-trips" >:: test_execution_record_round_trips;
         "degenerate trigger falls back to suggested_entry"
         >:: test_degenerate_trigger_falls_back_to_suggested_entry;
       ]

let () = run_test_tt_main suite
