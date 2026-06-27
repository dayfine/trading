(** Unit tests for {!Liquidity_exit_runner} — the held-position liquidity
    degradation exit (the user's #1 ask for the liquidity-realism overlay).

    Pins:
    - Default-off bit-identity: with [min_hold_dollar_adv = 0.0] a held position
      is left untouched (no liquidity_exit transition).
    - The ELCO reproducer: a held position whose trailing volume COLLAPSES over
      time fires a [liquidity_exit] on the degradation cycle, BEFORE any
      spurious high-tick can trip a worst-case stop fill. Asserts the
      [StrategySignal] label, the forensic [dollar_adv] detail, and that it
      fires at the close.
    - Both sides (long AND short) are eligible — illiquidity is untradeable
      regardless of direction.
    - Off-cadence (non-screening-day) and skip-list collisions are no-ops. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close ~volume =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(** Build a Position.t in the Holding state for [ticker] at [price]. Mirrors the
    helper in [test_stage3_force_exit_runner.ml]. *)
let make_holding_pos ?(side = Trading_base.Types.Long) ticker price date =
  let pos_id = ticker in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
    |> unwrap
  in
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

let get_price_of bars symbol = List.Assoc.find bars symbol ~equal:String.equal
let _friday = Date.of_string "2024-03-29" (* Friday *)
let _monday = Date.of_string "2024-04-01" (* Monday *)

(* Healthy liquid history: close ~$100, volume 1M => dollar-ADV ~$100M. *)
let _healthy_bars ticker =
  [ (ticker, [ make_bar "2024-03-25" ~close:100.0 ~volume:1_000_000 ]) ]

(* Config with the held threshold armed at $1M dollar-ADV, lookback 5d. *)
let _armed_config =
  {
    Liquidity_config.adv_lookback_days = 5;
    min_entry_dollar_adv = 0.0;
    min_hold_dollar_adv = 1_000_000.0;
  }

let run ?(is_screening_day = true) ?(skip_position_ids = String.Set.empty)
    ~config ~positions ~bar_reader ~get_price ~current_date () =
  Liquidity_exit_runner.update ~config ~is_screening_day ~positions ~bar_reader
    ~get_price ~skip_position_ids ~current_date

(* ------------------------------------------------------------------ *)
(* Default-off bit-identity: no exit at the no-op default               *)
(* ------------------------------------------------------------------ *)

let test_default_off_no_exit _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  (* Even with a degraded (tiny) ADV, the default config never fires. *)
  let bars = [ ("AAPL", [ make_bar "2024-03-29" ~close:1.0 ~volume:1 ]) ] in
  let bar_reader = Bar_reader.of_in_memory_bars bars in
  let result =
    run ~config:Liquidity_config.default_config ~positions ~bar_reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-03-29" ~close:1.0 ~volume:1) ])
      ~current_date:_friday ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* ELCO reproducer: degraded volume fires liquidity_exit at the close   *)
(* ------------------------------------------------------------------ *)

(* The degraded micro-cap: a name we HELD whose trailing volume collapsed to
   ~2 shares/day at a junk ~$6.60 close => dollar-ADV ~$13/day, far below the
   $1M hold threshold. The runner must fire on this degradation cycle. *)
let _degraded_bars =
  [ ("ELCO", [ make_bar "2024-03-29" ~close:6.60 ~volume:2 ]) ]

let test_elco_degradation_fires_exit _ =
  let pos =
    make_holding_pos ~side:Trading_base.Types.Short "ELCO" 6.60 _friday
  in
  let positions = String.Map.singleton "ELCO" pos in
  let bar_reader = Bar_reader.of_in_memory_bars _degraded_bars in
  let result =
    run ~config:_armed_config ~positions ~bar_reader
      ~get_price:
        (get_price_of [ ("ELCO", make_bar "2024-03-29" ~close:6.60 ~volume:2) ])
      ~current_date:_friday ()
  in
  (* dollar_adv = 6.60 * 2 = 13.2; exit fires at the close (6.60). *)
  assert_that result
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_strategy.Position.transition) -> t.position_id)
               (equal_to "ELCO");
             field
               (fun (t : Trading_strategy.Position.transition) -> t.date)
               (equal_to _friday);
             field
               (fun (t : Trading_strategy.Position.transition) -> t.kind)
               (matching
                  ~msg:"Expected TriggerExit with StrategySignal liquidity_exit"
                  (function
                    | Trading_strategy.Position.TriggerExit
                        {
                          exit_reason =
                            Trading_strategy.Position.StrategySignal
                              { label; detail };
                          exit_price;
                        } ->
                        Some (label, detail, exit_price)
                    | _ -> None)
                  (all_of
                     [
                       field (fun (l, _, _) -> l) (equal_to "liquidity_exit");
                       field
                         (fun (_, d, _) -> d)
                         (is_some_and (equal_to "dollar_adv=13.2"));
                       field (fun (_, _, p) -> p) (float_equal 6.60);
                     ]));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* A liquid held position is not exited                                 *)
(* ------------------------------------------------------------------ *)

let test_liquid_position_not_exited _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let bar_reader = Bar_reader.of_in_memory_bars (_healthy_bars "AAPL") in
  let result =
    run ~config:_armed_config ~positions ~bar_reader
      ~get_price:
        (get_price_of
           [ ("AAPL", make_bar "2024-03-25" ~close:100.0 ~volume:1_000_000) ])
      ~current_date:_friday ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Off-cadence: a non-screening-day call is a no-op                     *)
(* ------------------------------------------------------------------ *)

let test_off_cadence_no_op _ =
  let pos = make_holding_pos "ELCO" 6.60 _monday in
  let positions = String.Map.singleton "ELCO" pos in
  let bar_reader = Bar_reader.of_in_memory_bars _degraded_bars in
  let result =
    run ~is_screening_day:false ~config:_armed_config ~positions ~bar_reader
      ~get_price:
        (get_price_of [ ("ELCO", make_bar "2024-03-29" ~close:6.60 ~volume:2) ])
      ~current_date:_monday ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Skip-list collision: a position already exiting this tick is skipped *)
(* ------------------------------------------------------------------ *)

let test_skip_list_collision_no_op _ =
  let pos = make_holding_pos "ELCO" 6.60 _friday in
  let positions = String.Map.singleton "ELCO" pos in
  let bar_reader = Bar_reader.of_in_memory_bars _degraded_bars in
  let result =
    run
      ~skip_position_ids:(String.Set.singleton "ELCO")
      ~config:_armed_config ~positions ~bar_reader
      ~get_price:
        (get_price_of [ ("ELCO", make_bar "2024-03-29" ~close:6.60 ~volume:2) ])
      ~current_date:_friday ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Special_exits.run integration: a force-liquidated illiquid position  *)
(* must NOT also receive a liquidity TriggerExit (skip-set seeding)      *)
(* ------------------------------------------------------------------ *)

(* A weekly_view whose last bar is a Friday so [is_screening_day_view] is true
   and the liquidity exit's weekly cadence is active. *)
let _friday_weekly_view : Snapshot_runtime.Snapshot_bar_views.weekly_view =
  {
    closes = [| 6.60 |];
    raw_closes = [| 6.60 |];
    highs = [| 6.60 |];
    lows = [| 6.60 |];
    volumes = [| 2.0 |];
    dates = [| _friday |];
    n = 1;
  }

(* The same position breaches BOTH the force-liquidation threshold (short
   entered $100, now $160 => 60% loss, default short threshold 15% fires) AND
   the held-liquidity floor (degraded volume => dollar-ADV far below $1M). The
   force-liq channel must be the only exit; the liquidity exit skips it because
   the force-liq id is folded into its skip set. Pre-fix, the liquidity exit
   emitted a second TriggerExit on the same id (merged into one force_exit
   channel), which the Position state machine rejects from a non-Holding
   state. *)
let test_force_liq_position_skipped_by_liquidity_exit _ =
  let symbol = "ILQD" in
  let entry_price = 100.0 in
  let crash_price = 160.0 in
  let pos =
    make_holding_pos ~side:Trading_base.Types.Short symbol entry_price _friday
  in
  let pos_id = pos.Trading_strategy.Position.id in
  let positions = String.Map.singleton symbol pos in
  (* Bars carry the degraded volume so the liquidity metric sees an illiquid
     name; the close at the crash price drives the force-liq P&L. *)
  let crash_bar = make_bar "2024-03-29" ~close:crash_price ~volume:2 in
  let bar_reader = Bar_reader.of_in_memory_bars [ (symbol, [ crash_bar ]) ] in
  let get_price s = if String.equal s symbol then Some crash_bar else None in
  let config =
    {
      (Weinstein_strategy_config.default_config ~universe:[ symbol ]
         ~index_symbol:"INDEX")
      with
      liquidity_config = _armed_config;
    }
  in
  let no_op_record_force_exit ~last_stop_out_dates:_ ~positions:_
      ~current_date:_ ~cooldown_weeks:_ ~label:_ _ =
    ()
  in
  let ( force_exit_ts,
        _stage3_ts,
        _laggard_ts,
        _stop_ids,
        _stage3_ids,
        _laggard_ids ) =
    Special_exits.run ~config ~record_force_exit:no_op_record_force_exit
      ~positions
      ~last_stop_out_dates:(Hashtbl.create (module String))
      ~portfolio:{ cash = 1_000_000.0; positions }
      ~get_price
      ~peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.(create ())
      ~audit_recorder:Audit_recorder.noop ~prior_macro_result:(ref None)
      ~prior_stages:(Hashtbl.create (module String))
      ~prior_stage_ma_values:(Hashtbl.create (module String))
      ~stage3_streaks:(Hashtbl.create (module String))
      ~laggard_streaks:(Hashtbl.create (module String))
      ~bar_reader ~index_view:_friday_weekly_view ~exit_transitions:[]
      ~current_date:_friday
  in
  (* Exactly one exit for the position — the force-liquidation one — and no
     duplicate liquidity TriggerExit. *)
  let exits_for_pos =
    List.filter force_exit_ts
      ~f:(fun (t : Trading_strategy.Position.transition) ->
        String.equal t.position_id pos_id
        &&
        match t.kind with
        | Trading_strategy.Position.TriggerExit _ -> true
        | _ -> false)
  in
  assert_that (List.length exits_for_pos) (equal_to 1)

(* ------------------------------------------------------------------ *)
(* Special_exits.run integration: a Stage-3 force-exited illiquid       *)
(* position must NOT also receive a liquidity TriggerExit. This is the  *)
(* channel the previous skip-set fix missed: [_apply_exit_channel]      *)
(* FILTERS the Stage-3 id OUT of [force_exit_ts], so reconstructing the *)
(* liquidity skip set from [force_exit_ts] alone omits it. Without the  *)
(* Stage-3 id in the skip set the liquidity exit emits a second         *)
(* TriggerExit on the same id (merged into one force_exit channel),     *)
(* which the Position state machine rejects from a non-Holding state.   *)
(* ------------------------------------------------------------------ *)

let test_stage3_force_exit_position_skipped_by_liquidity_exit _ =
  let symbol = "S3IL" in
  let price = 100.0 in
  (* A long position, flat at entry (no force-liq loss), but illiquid: degraded
     volume drives dollar-ADV far below the $1M hold floor. The Stage-3
     force-exit channel must be the only exit. *)
  let pos =
    make_holding_pos ~side:Trading_base.Types.Long symbol price _friday
  in
  let pos_id = pos.Trading_strategy.Position.id in
  let positions = String.Map.singleton symbol pos in
  let flat_bar = make_bar "2024-03-29" ~close:price ~volume:2 in
  let bar_reader = Bar_reader.of_in_memory_bars [ (symbol, [ flat_bar ]) ] in
  let get_price s = if String.equal s symbol then Some flat_bar else None in
  (* Arm Stage-3 force-exit and seed the detector so it fires this tick:
     prior_stages = Stage3, streak 1 => next observe reaches hysteresis (2). *)
  let prior_stages = Hashtbl.create (module String) in
  Hashtbl.set prior_stages ~key:symbol
    ~data:(Weinstein_types.Stage3 { weeks_topping = 1 });
  let stage3_streaks = Hashtbl.create (module String) in
  Hashtbl.set stage3_streaks ~key:symbol ~data:1;
  let config =
    {
      (Weinstein_strategy_config.default_config ~universe:[ symbol ]
         ~index_symbol:"INDEX")
      with
      liquidity_config = _armed_config;
      enable_stage3_force_exit = true;
    }
  in
  let no_op_record_force_exit ~last_stop_out_dates:_ ~positions:_
      ~current_date:_ ~cooldown_weeks:_ ~label:_ _ =
    ()
  in
  let ( force_exit_ts,
        stage3_ts,
        _laggard_ts,
        _stop_ids,
        _stage3_ids,
        _laggard_ids ) =
    Special_exits.run ~config ~record_force_exit:no_op_record_force_exit
      ~positions
      ~last_stop_out_dates:(Hashtbl.create (module String))
      ~portfolio:{ cash = 1_000_000.0; positions }
      ~get_price
      ~peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.(create ())
      ~audit_recorder:Audit_recorder.noop ~prior_macro_result:(ref None)
      ~prior_stages
      ~prior_stage_ma_values:(Hashtbl.create (module String))
      ~stage3_streaks
      ~laggard_streaks:(Hashtbl.create (module String))
      ~bar_reader ~index_view:_friday_weekly_view ~exit_transitions:[]
      ~current_date:_friday
  in
  (* Guard: the Stage-3 channel actually fired (otherwise the skip set is not
     exercised and the test would pass vacuously). *)
  assert_that (List.length stage3_ts) (equal_to 1);
  (* The Stage-3 exit lives in [stage3_ts]; the liquidity exit (if it fired)
     would land in [force_exit_ts]. Both channels are assembled into the
     strategy's output, so a duplicate shows up as one TriggerExit in EACH.
     Count TriggerExits for the position across both: pre-fix the liquidity
     exit adds a second (=> 2); post-fix it is skipped (=> 1). *)
  let is_trigger_exit_for_pos (t : Trading_strategy.Position.transition) =
    String.equal t.position_id pos_id
    &&
    match t.kind with
    | Trading_strategy.Position.TriggerExit _ -> true
    | _ -> false
  in
  let exits_for_pos =
    List.count (stage3_ts @ force_exit_ts) ~f:is_trigger_exit_for_pos
  in
  assert_that exits_for_pos (equal_to 1)

let () =
  run_test_tt_main
    ("liquidity_exit_runner"
    >::: [
           "default-off: no exit" >:: test_default_off_no_exit;
           "ELCO degradation fires exit" >:: test_elco_degradation_fires_exit;
           "liquid position not exited" >:: test_liquid_position_not_exited;
           "off-cadence is a no-op" >:: test_off_cadence_no_op;
           "skip-list collision is a no-op" >:: test_skip_list_collision_no_op;
           "force-liq position skipped by liquidity exit"
           >:: test_force_liq_position_skipped_by_liquidity_exit;
           "stage3 force-exit position skipped by liquidity exit"
           >:: test_stage3_force_exit_position_skipped_by_liquidity_exit;
         ])
