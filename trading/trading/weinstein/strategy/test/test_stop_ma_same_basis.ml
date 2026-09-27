(** Tests for issue #2982's [Weinstein_stops.config.stop_ma_same_basis] flag.

    The stop machine's raise candidate is [below (min (correction_low, MA))].
    The correction low and the stop are raw daily prices; the MA comes from the
    weekly view's back-adjusted closes. On a name with a later split the MA
    reads a fraction of its raw value and the ratchet can never raise the stop.

    Two layers are pinned:
    - {!Stop_ma_basis} itself (factor, restatement, degenerate bars, the
      disabled pass-through).
    - The production path, {!Stops_runner.update}, on a synthetic 80-week
      Stage-2 tape whose every bar carries [adjusted_close = close / 10] (a 10:1
      split after the window). A completed correction cycle raises the stop only
      when the flag is on; with the flag off (the default) the cycle stalls,
      exactly as on main. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _symbol = "SPLT"

(* raw close / adjusted close on every bar of the tape. *)
let _split_factor = 10.0

let _bar ~date ~close ~adjusted_close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close;
    volume = 1_000_000;
    active_through = None;
  }

(* ------------------------------------------------------------------ *)
(* Stop_ma_basis                                                        *)
(* ------------------------------------------------------------------ *)

let _split_bar =
  _bar ~date:(Date.of_string "2024-01-05") ~close:130.0 ~adjusted_close:13.0

let test_factor_is_raw_over_adjusted _ =
  assert_that
    (Stop_ma_basis.raw_basis_factor _split_bar)
    (is_some_and (float_equal 10.0))

let test_restate_scales_ma_onto_raw_basis _ =
  assert_that
    (Stop_ma_basis.restate_to_raw ~bar:_split_bar 14.0)
    (float_equal 140.0)

let test_degenerate_adjusted_close_keeps_ma _ =
  let bar = { _split_bar with Types.Daily_price.adjusted_close = 0.0 } in
  assert_that
    ( Stop_ma_basis.raw_basis_factor bar,
      Stop_ma_basis.restate_to_raw ~bar 14.0 )
    (all_of [ field fst is_none; field snd (float_equal 14.0) ])

let test_for_stops_disabled_is_identity _ =
  assert_that
    ( Stop_ma_basis.for_stops ~enabled:false ~bar:_split_bar 14.0,
      Stop_ma_basis.for_stops ~enabled:true ~bar:_split_bar 14.0 )
    (all_of [ field fst (float_equal 14.0); field snd (float_equal 140.0) ])

(* ------------------------------------------------------------------ *)
(* Stops_runner on a later-split tape                                   *)
(* ------------------------------------------------------------------ *)

(* [n] consecutive weekdays starting at [start]. *)
let _weekdays ~start ~n =
  Sequence.unfold ~init:start ~f:(fun d -> Some (d, Date.add_days d 1))
  |> Sequence.filter ~f:(fun d ->
      not (Day_of_week.is_sun_or_sat (Date.day_of_week d)))
  |> Fn.flip Sequence.take n |> Sequence.to_list

(* 400 weekdays (80 weeks, Monday 2022-01-03 .. a Friday) of a steady advance
   from 50 to 149.75 raw. Every bar is back-adjusted by the later 10:1 split, so
   the weekly MA the classifier reads is ~13.8 (adjusted) while its raw value
   is ~137.7 (a 30-week WMA lags a linear tape by ~9.7 weeks). *)
let _split_tape () =
  List.mapi
    (_weekdays ~start:(Date.of_string "2022-01-03") ~n:400)
    ~f:(fun i date ->
      let close = 50.0 +. (0.25 *. Float.of_int i) in
      _bar ~date ~close ~adjusted_close:(close /. _split_factor))

(* A Trailing state whose cycle completes on the tape's last bar: peak 149 (the
   last close 149.75 recovers it), correction low 120 (a 19% pullback), and a
   resting stop of 30. The raise candidate is [min (120, MA) *. 0.99]:
   - adjusted MA ~13.8 -> ~13.6, below the stop -> Stalled, no raise;
   - raw MA ~137.7 -> the correction low binds -> 118.8 > 30 -> raise. *)
let _trailing_state =
  Weinstein_stops.Trailing
    {
      stop_level = 30.0;
      last_correction_extreme = 120.0;
      last_trend_extreme = 149.0;
      ma_at_last_adjustment = 30.0;
      correction_count = 0;
      correction_observed_since_reset = false;
    }

let _make_holding_pos ~entry_date =
  let make_trans kind =
    { Trading_strategy.Position.position_id = _symbol; date = entry_date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> failwith "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = _symbol;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = 100.0;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = 100.0 }))
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

(* Run one [Stops_runner.update] on the tape's last bar with the flag set as
   given. Returns [(exits, adjusts)]. *)
let _run_tape ~stop_ma_same_basis =
  let bars = _split_tape () in
  let last = List.last_exn bars in
  let pos = _make_holding_pos ~entry_date:(Date.of_string "2023-01-06") in
  let stop_states = ref (String.Map.singleton _symbol _trailing_state) in
  Stops_runner.update
    ~stops_config:
      {
        Weinstein_stops.default_config with
        Weinstein_stops.stop_ma_same_basis;
      }
    ~stage_config:Stage.default_config ~lookback_bars:52
    ~positions:(String.Map.singleton _symbol pos)
    ~get_price:(fun s -> Option.some_if (String.equal s _symbol) last)
    ~stop_states
    ~bar_reader:(Bar_reader.of_in_memory_bars [ (_symbol, bars) ])
    ~as_of:last.Types.Daily_price.date
    ~prior_stages:(Hashtbl.create (module String))
    ()

let _new_stop_of (tr : Trading_strategy.Position.transition) =
  match tr.kind with
  | Trading_strategy.Position.UpdateRiskParams { new_risk_params } ->
      new_risk_params.stop_loss_price
  | _ -> None

(* Flag off (default): the adjusted MA collapses the candidate below the resting
   stop, the cycle stalls, and nothing is emitted — today's behaviour. *)
let test_split_tape_flag_off_does_not_raise _ =
  assert_that
    (_run_tape ~stop_ma_same_basis:false)
    (all_of [ field fst is_empty; field snd is_empty ])

(* Flag on: the MA is restated to the raw basis, the correction low binds, and
   the stop is raised to 120 * 0.99 = 118.8. *)
let test_split_tape_flag_on_raises_to_correction_low _ =
  assert_that
    (_run_tape ~stop_ma_same_basis:true)
    (all_of
       [
         field fst is_empty;
         field snd
           (elements_are
              [ field _new_stop_of (is_some_and (float_equal 118.8)) ]);
       ])

let suite =
  "stop_ma_same_basis"
  >::: [
         "factor = close / adjusted_close" >:: test_factor_is_raw_over_adjusted;
         "restate scales the MA onto the raw basis"
         >:: test_restate_scales_ma_onto_raw_basis;
         "degenerate adjusted_close keeps the MA"
         >:: test_degenerate_adjusted_close_keeps_ma;
         "for_stops disabled is the identity"
         >:: test_for_stops_disabled_is_identity;
         "later-split tape: flag off stalls (no raise)"
         >:: test_split_tape_flag_off_does_not_raise;
         "later-split tape: flag on raises to the correction low"
         >:: test_split_tape_flag_on_raises_to_correction_low;
       ]

let () = run_test_tt_main suite
