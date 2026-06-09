(** Pin [Exit_audit_capture]'s MFE/MAE contract: the max favourable / adverse
    excursion fields on the recorded [exit_event] are computed from the hold
    window's weekly high/low vs the position's entry price (mirrored for
    shorts), not left at the placeholder [0.0] the bridge used before this
    change.

    The recorder is a callback bundle, so the test captures the emitted
    [exit_event] via a custom [record_exit] rather than wiring a backtest
    collector. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module AR = Audit_recorder

let _ticker = "ZZZZ"
let _entry_date = Date.of_string "2024-01-08"
let _exit_date = Date.of_string "2024-01-11"

(** Daily path over the hold: entry at $100, an intraday high of $120 (→ +20%
    favourable for a long) and an intraday low of $90 (→ -10% adverse). *)
let _bar ~date ~high ~low : Types.Daily_price.t =
  {
    date;
    open_price = 100.0;
    high_price = high;
    low_price = low;
    close_price = 100.0;
    adjusted_close = 100.0;
    volume = 1_000_000;
    active_through = None;
  }

let _bar_reader () : Bar_reader.t =
  Bar_reader.of_in_memory_bars
    [
      ( _ticker,
        [
          _bar ~date:_entry_date ~high:100.0 ~low:100.0;
          _bar ~date:(Date.of_string "2024-01-09") ~high:120.0 ~low:95.0;
          _bar ~date:(Date.of_string "2024-01-10") ~high:110.0 ~low:90.0;
          _bar ~date:_exit_date ~high:105.0 ~low:100.0;
        ] );
    ]

(** Build a Holding {!Position.t} at $100 entry on [_entry_date]. *)
let _holding_pos ~side : Position.t =
  let make_trans kind =
    { Position.position_id = _ticker; date = _entry_date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> assert_failure "position setup failed"
  in
  let open Position in
  create_entering
    (make_trans
       (CreateEntering
          {
            symbol = _ticker;
            side;
            target_quantity = 10.0;
            entry_price = 100.0;
            reasoning = ManualDecision { description = "test" };
          }))
  |> unwrap
  |> fun p ->
  apply_transition p
    (make_trans (EntryFill { filled_quantity = 10.0; fill_price = 100.0 }))
  |> unwrap
  |> fun p ->
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

let _exit_transition : Position.transition =
  {
    position_id = _ticker;
    date = _exit_date;
    kind =
      Position.TriggerExit
        {
          exit_reason = Position.SignalReversal { description = "test exit" };
          exit_price = 100.0;
        };
  }

(** Run [emit_exit_audit] against a capturing recorder and return the emitted
    [exit_event]. *)
let _emit_and_capture ~side =
  let captured = ref None in
  let recorder =
    { AR.noop with AR.record_exit = (fun e -> captured := Some e) }
  in
  let pos = _holding_pos ~side in
  let positions = Map.singleton (module String) _ticker pos in
  Exit_audit_capture.emit_exit_audit ~audit_recorder:recorder
    ~prior_macro_result:(ref None) ~stage_config:Stage.default_config
    ~lookback_bars:300 ~bar_reader:(_bar_reader ())
    ~prior_stages:(Hashtbl.create (module String))
    ~positions _exit_transition;
  !captured

(* For a LONG at $100: favourable = high $120 → +0.20; adverse = low $90 →
   -0.10. *)
let test_excursions_long _ =
  assert_that
    (_emit_and_capture ~side:Trading_base.Types.Long)
    (is_some_and
       (all_of
          [
            field
              (fun (e : AR.exit_event) -> e.max_favorable_excursion_pct)
              (float_equal 0.20);
            field
              (fun (e : AR.exit_event) -> e.max_adverse_excursion_pct)
              (float_equal (-0.10));
          ]))

(* For a SHORT at $100 the direction mirrors: favourable = low $90 → +0.10;
   adverse = high $120 → -0.20. *)
let test_excursions_short _ =
  assert_that
    (_emit_and_capture ~side:Trading_base.Types.Short)
    (is_some_and
       (all_of
          [
            field
              (fun (e : AR.exit_event) -> e.max_favorable_excursion_pct)
              (float_equal 0.10);
            field
              (fun (e : AR.exit_event) -> e.max_adverse_excursion_pct)
              (float_equal (-0.20));
          ]))

let suite =
  "Exit_audit_capture"
  >::: [
         "excursions long" >:: test_excursions_long;
         "excursions short" >:: test_excursions_short;
       ]

let () = run_test_tt_main suite
