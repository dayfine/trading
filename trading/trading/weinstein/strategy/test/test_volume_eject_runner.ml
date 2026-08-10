(** Unit tests for {!Volume_eject_runner} — F5's at-fill breakout-volume
    confirmation and the eject that is inseparable from it (plan
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F5;
    [docs/design/weinstein-book-reference.md] §4.2 + §4.7).

    Pins:
    - Both §4.2 branches confirm and HOLD: a fill week at 2x the prior 4 weeks
      (spike), and a fill week that only qualifies via the 3-4-week build-up.
    - Neither branch ⇒ eject, carrying the [volume_eject] label at the close.
    - Default config ([volume_confirm_at_fill = false]) ⇒ no eject on the same
      unconfirmed bars (R1 bit-identity), and arming the flag WITHOUT the
      StopLimit family is likewise inert.
    - An unfilled ticket ([Entering]) is never volume-checked.
    - No partial-week lookahead: a mid-week (non-screening) tick evaluates
      nothing; the same position ejects on the week's closing tick.
    - Fail-soft: too little history for either branch holds the position.
    - Short side, stale fills, and skip-list collisions are no-ops. *)

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

(** A [Holding] position for [ticker] whose entry (fill) date is [date] — the
    date the runner reads to locate the fill week. Mirrors the helper in
    [test_liquidity_exit_runner.ml]. *)
let make_holding_pos ?(side = Trading_base.Types.Long) ticker price date =
  let make_trans kind =
    { Trading_strategy.Position.position_id = ticker; date; kind }
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

(** An [Entering] position — the ticket is resting, nothing has filled. *)
let make_entering_pos ticker price date =
  match
    Trading_strategy.Position.create_entering
      {
        Trading_strategy.Position.position_id = ticker;
        date;
        kind =
          Trading_strategy.Position.CreateEntering
            {
              symbol = ticker;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = price;
              reasoning =
                Trading_strategy.Position.ManualDecision
                  { description = "test" };
            };
      }
  with
  | Ok p -> p
  | Error _ -> OUnit2.assert_failure "position setup failed"

let _ticker = "AXTI"

(* The evaluation tick: the Friday closing the fill week. *)
let _screening_friday = Date.of_string "2024-03-29"

(* The fill: the Monday inside that same week. *)
let _fill_date = Date.of_string "2024-03-25"

(* Mid-week tick — used to pin the no-partial-week-lookahead contract. *)
let _midweek = Date.of_string "2024-03-27"

(** One daily bar per week (each on that week's Friday), so each weekly bucket's
    summed volume is exactly the value given here and its date is that Friday.
    [weekly_volumes] runs oldest-first and ends with the FILL week. *)
let _bars_of_weekly_volumes weekly_volumes =
  let fridays =
    [
      "2024-01-26";
      "2024-02-02";
      "2024-02-09";
      "2024-02-16";
      "2024-02-23";
      "2024-03-01";
      "2024-03-08";
      "2024-03-15";
      "2024-03-22";
      "2024-03-29";
    ]
  in
  let n = List.length weekly_volumes in
  List.zip_exn (List.drop fridays (List.length fridays - n)) weekly_volumes
  |> List.map ~f:(fun (d, v) -> make_bar d ~close:100.0 ~volume:v)

(* Branch (a): fill week 3000 vs 1000-average prior 4 weeks => ratio 3.0. *)
let _spike_volumes = [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 1000; 3000 ]

(* Branch (b) only: the fill week is 1500 against a 1100 prior-4-week average
   (ratio 1.36 — branch (a) FAILS), but the 4-week build-up (1500/1400/1300/
   1200, mean 1350) is 2.7x the prior 4-week baseline (500, mean 500) and the
   fill week increases over the week before it. *)
let _buildup_volumes = [ 500; 500; 500; 500; 500; 1200; 1300; 1400; 1500 ]

(* Neither branch: the fill week is BELOW the prior week and the build-up is
   flat against its baseline. *)
let _unconfirmed_volumes =
  [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 1000; 900 ]

let _default_config () =
  Weinstein_strategy_config.default_config ~universe:[ _ticker ]
    ~index_symbol:"GSPCX"

let _armed_config =
  {
    (_default_config ()) with
    Weinstein_strategy_config.volume_confirm_at_fill = true;
    sim_entry_trigger_at_suggested = true;
    enable_sim_entry_stoplimit = true;
  }

let run ?(config = _armed_config) ?(is_screening_day = true)
    ?(skip_position_ids = String.Set.empty) ?(current_date = _screening_friday)
    ~positions ~weekly_volumes () =
  let bars = _bars_of_weekly_volumes weekly_volumes in
  let bar_reader = Bar_reader.of_in_memory_bars [ (_ticker, bars) ] in
  let last_bar = List.last_exn bars in
  Volume_eject_runner.update ~config ~volume_config:Volume.default_config
    ~is_screening_day ~positions ~bar_reader
    ~get_price:(fun s -> if String.equal s _ticker then Some last_bar else None)
    ~skip_position_ids ~current_date

let _held_positions ?(side = Trading_base.Types.Long) ?(fill_date = _fill_date)
    () =
  String.Map.singleton _ticker (make_holding_pos ~side _ticker 100.0 fill_date)

(** The [volume_eject] transition shape: a full [TriggerExit] on the evaluation
    tick, at that bar's close, labelled with the [Volume_eject] audit tag. *)
let _is_volume_eject ~at_date =
  all_of
    [
      field
        (fun (t : Trading_strategy.Position.transition) -> t.position_id)
        (equal_to _ticker);
      field
        (fun (t : Trading_strategy.Position.transition) -> t.date)
        (equal_to at_date);
      field
        (fun (t : Trading_strategy.Position.transition) -> t.kind)
        (matching ~msg:"Expected TriggerExit with StrategySignal volume_eject"
           (function
             | Trading_strategy.Position.TriggerExit
                 {
                   exit_reason =
                     Trading_strategy.Position.StrategySignal { label; _ };
                   exit_price;
                 } ->
                 Some (label, exit_price)
             | _ -> None)
           (all_of
              [
                field (fun (l, _) -> l) (equal_to "volume_eject");
                field (fun (_, p) -> p) (float_equal 100.0);
              ]));
    ]

(* ------------------------------------------------------------------ *)
(* Both §4.2 branches confirm => the position is HELD                    *)
(* ------------------------------------------------------------------ *)

(** Branch (a) — "breakout-week volume >= 2x average volume of prior 4 weeks".
    3x confirms, so nothing is ejected. *)
let test_fill_week_spike_confirms_and_holds _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_spike_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** Branch (b) — "volume build-up over 3-4 weeks that is >= 2x average of prior
    several weeks, with at least some increase on breakout week". The fill week
    alone is only 1.36x its prior 4 weeks, so implementing branch (a) alone
    would eject this book-valid breakout (plan §3-F5 amendment (ii)). *)
let test_buildup_branch_confirms_and_holds _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_buildup_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Neither branch => eject                                              *)
(* ------------------------------------------------------------------ *)

(** §4.2's low-volume-breakout SELL rule: a buy-stop that filled on unconfirmed
    volume is sold, not held. *)
let test_unconfirmed_fill_week_ejects _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that result
    (elements_are [ _is_volume_eject ~at_date:_screening_friday ])

(* ------------------------------------------------------------------ *)
(* R1 — the default config is inert on the very same bars               *)
(* ------------------------------------------------------------------ *)

(** [volume_confirm_at_fill = false] (default): volume stays a screen-time gate
    and no eject path is reachable — bit-identical to pre-F5. *)
let test_default_config_never_ejects _ =
  let result =
    run ~config:(_default_config ()) ~positions:(_held_positions ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** The flag alone does not arm F5: the mechanism is defined only for the
    resting E-anchored ticket family, so without
    [sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit] the runner
    stays inert ({!Weinstein_strategy_config.volume_confirm_at_fill_armed}). *)
let test_flag_without_stoplimit_family_never_ejects _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy_config.volume_confirm_at_fill = true;
    }
  in
  let result =
    run ~config ~positions:(_held_positions ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* An unfilled ticket is never volume-checked                           *)
(* ------------------------------------------------------------------ *)

(** The confirmation is defined on the week the ticket FILLS. A resting
    ([Entering]) ticket has no fill week, so no check runs — however bad the
    current volume looks. *)
let test_unfilled_ticket_is_never_checked _ =
  let positions =
    String.Map.singleton _ticker (make_entering_pos _ticker 100.0 _fill_date)
  in
  let result = run ~positions ~weekly_volumes:_unconfirmed_volumes () in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* No partial-week lookahead                                            *)
(* ------------------------------------------------------------------ *)

(** A fill lands mid-week; the Wednesday tick is not a screening tick, so the
    still-open fill week is never judged. The identical position ejects on the
    Friday tick that closes that week — pinning that the verdict waits for a
    complete week. *)
let test_no_partial_week_lookahead _ =
  let midweek_result =
    run ~is_screening_day:false ~current_date:_midweek
      ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  let friday_result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that
    (List.length midweek_result, List.length friday_result)
    (equal_to (0, 1))

(* ------------------------------------------------------------------ *)
(* Window, side, skip-list and fail-soft no-ops                         *)
(* ------------------------------------------------------------------ *)

(** A fill from three weeks back is outside the evaluation window: it was
    already judged (and, if unconfirmed, ejected) at the time. *)
let test_stale_fill_week_is_not_re_judged _ =
  let result =
    run
      ~positions:(_held_positions ~fill_date:(Date.of_string "2024-03-05") ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** F5 is a property of the long-side breakout ticket; shorts are untouched. *)
let test_short_position_is_not_ejected _ =
  let result =
    run
      ~positions:(_held_positions ~side:Trading_base.Types.Short ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** A position already exiting this tick via another channel is skipped — two
    exits on one position would be rejected by the state machine. *)
let test_skip_list_collision_is_a_no_op _ =
  let result =
    run
      ~skip_position_ids:(String.Set.singleton _ticker)
      ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** Fail-soft: with only three weekly bars neither branch can be evaluated
    ([Volume.confirms_breakout] returns [None]). Absence of evidence is not an
    unconfirmed breakout, so the position is held. *)
let test_insufficient_history_holds _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:[ 1000; 1000; 900 ] ()
  in
  assert_that (List.length result) (equal_to 0)

let suite =
  "volume_eject_runner"
  >::: [
         "fill-week 2x volume confirms and holds"
         >:: test_fill_week_spike_confirms_and_holds;
         "3-4-week build-up branch confirms and holds"
         >:: test_buildup_branch_confirms_and_holds;
         "neither branch ejects with the volume_eject tag"
         >:: test_unconfirmed_fill_week_ejects;
         "default config never ejects" >:: test_default_config_never_ejects;
         "flag without the StopLimit family never ejects"
         >:: test_flag_without_stoplimit_family_never_ejects;
         "unfilled ticket is never volume-checked"
         >:: test_unfilled_ticket_is_never_checked;
         "no partial-week lookahead" >:: test_no_partial_week_lookahead;
         "stale fill week is not re-judged"
         >:: test_stale_fill_week_is_not_re_judged;
         "short position is not ejected" >:: test_short_position_is_not_ejected;
         "skip-list collision is a no-op"
         >:: test_skip_list_collision_is_a_no_op;
         "insufficient history holds" >:: test_insufficient_history_holds;
       ]

let () = run_test_tt_main suite
