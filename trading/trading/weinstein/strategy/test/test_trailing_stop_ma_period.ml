(** Tests for issue #3038's [trailing_stop_ma_period] dial (arm T2):
    {!Stop_ma_stage} and its wiring through {!Stops_runner.update}.

    Fixture: an 80-week tape (400 weekdays) compounding +4 % per week (daily
    factor [1.04 ** (1/5)]), with [adjusted_close = close] so no basis
    restatement is in play. The expected weekly MAs are computed here by an
    independent WMA over the Friday closes, so the runner's MA reads are pinned
    against a second implementation, not against themselves.

    A held long in [Trailing] state completes a correction cycle on the last bar
    (trend peak just under the last close, correction low 9 % below the peak).
    The correction low sits {b above} the 10-week MA and far above the 30-week
    MA, so the raise candidate [below (min (correction_low, MA))] is set by
    whichever MA the stop machine reads — that is what distinguishes the arms.
*)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _symbol = "GROW"
let _weekly_growth = 1.04
let _n_weekdays = 400
let _lookback_bars = 52

(* Short-arm period under test (the trader preset's 10-week MA). *)
let _trader_period = 10
let _stage_period = Stage.default_config.ma_period

(* [n] consecutive weekdays starting at [start]. *)
let _weekdays ~start ~n =
  Sequence.unfold ~init:start ~f:(fun d -> Some (d, Date.add_days d 1))
  |> Sequence.filter ~f:(fun d ->
      not (Day_of_week.is_sun_or_sat (Date.day_of_week d)))
  |> Fn.flip Sequence.take n |> Sequence.to_list

let _bar ~date ~close =
  {
    Types.Daily_price.date;
    open_price = close;
    high_price = close *. 1.001;
    low_price = close *. 0.999;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Monday 2022-01-03 .. a Friday; close_i = 100 * 1.04^(i/5). *)
let _tape () =
  let daily = _weekly_growth ** (1.0 /. 5.0) in
  List.mapi
    (_weekdays ~start:(Date.of_string "2022-01-03") ~n:_n_weekdays)
    ~f:(fun i date -> _bar ~date ~close:(100.0 *. (daily ** Float.of_int i)))

let _last_close () = (List.last_exn (_tape ())).Types.Daily_price.close_price

(* Independent WMA (weights 1..period, newest heaviest) over the last [period]
   Friday closes of the tape. *)
let _expected_wma period =
  let fridays =
    List.filter (_tape ()) ~f:(fun b ->
        Day_of_week.equal (Date.day_of_week b.Types.Daily_price.date) Fri)
    |> List.map ~f:(fun b -> b.Types.Daily_price.close_price)
  in
  let window = List.drop fridays (List.length fridays - period) in
  let weighted =
    List.foldi window ~init:0.0 ~f:(fun j acc c ->
        acc +. (Float.of_int (j + 1) *. c))
  in
  weighted /. Float.of_int (period * (period + 1) / 2)

(* Trailing state whose correction cycle completes on the last bar: peak just
   under the last close, correction low 9 % below it (>= the 8 % minimum), and a
   resting stop at half the last close so any MA-set candidate raises it. *)
let _trailing_state () =
  let last_close = _last_close () in
  let peak = last_close *. 0.999 in
  Weinstein_stops.Trailing
    {
      stop_level = last_close *. 0.5;
      last_correction_extreme = peak *. 0.91;
      last_trend_extreme = peak;
      ma_at_last_adjustment = last_close *. 0.5;
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

(* Everything one [Stops_runner.update] on the tape's last bar produced. *)
type run = {
  adjusts : Trading_strategy.Position.transition list;
  stop_mas : float list;  (** MA each stop decision read, in order. *)
  stage : Weinstein_types.stage option;  (** [prior_stages] after the call. *)
  mirror : float option;  (** [prior_stage_ma_values] after the call. *)
}

let _run ?trailing_stop_ma_period
    ?(stops_config = Weinstein_stops.default_config) () =
  let bars = _tape () in
  let last = List.last_exn bars in
  let pos = _make_holding_pos ~entry_date:(Date.of_string "2023-01-06") in
  let stop_states = ref (String.Map.singleton _symbol (_trailing_state ())) in
  let prior_stages = Hashtbl.create (module String) in
  let mirror = Hashtbl.create (module String) in
  let mas = ref [] in
  let _exits, adjusts =
    Stops_runner.update ?trailing_stop_ma_period ~prior_stage_ma_values:mirror
      ~on_stop_decision:(fun d ->
        mas := d.Weinstein_stops.Stop_decision.ma_value :: !mas)
      ~stops_config ~stage_config:Stage.default_config
      ~lookback_bars:_lookback_bars
      ~positions:(String.Map.singleton _symbol pos)
      ~get_price:(fun s -> Option.some_if (String.equal s _symbol) last)
      ~stop_states
      ~bar_reader:(Bar_reader.of_in_memory_bars [ (_symbol, bars) ])
      ~as_of:last.Types.Daily_price.date ~prior_stages ()
  in
  {
    adjusts;
    stop_mas = List.rev !mas;
    stage = Hashtbl.find prior_stages _symbol;
    mirror = Hashtbl.find mirror _symbol;
  }

let _new_stop_of (tr : Trading_strategy.Position.transition) =
  match tr.kind with
  | Trading_strategy.Position.UpdateRiskParams { new_risk_params } ->
      new_risk_params.stop_loss_price
  | _ -> None

(* The raise level the stop machine installs off an MA-bound candidate:
   [ma * (1 - trailing buffer)], before the round-number nudge. *)
let _raise_off_ma ma =
  ma *. (1.0 -. Weinstein_stops.default_config.trailing_stop_buffer_pct)

(* The nudge can move the level by up to [round_number_nudge] away from a
   half-dollar; twice that bounds the gap to the un-nudged level. *)
let _nudge_epsilon = 2.0 *. Weinstein_stops.default_config.round_number_nudge

(* ------------------------------------------------------------------ *)
(* Fixture sanity                                                       *)
(* ------------------------------------------------------------------ *)

(* The arms are only distinguishable if the two MAs differ and the correction
   low sits between them (so the MA, not the low, binds under both). *)
let test_fixture_mas_differ _ =
  let correction_low = _last_close () *. 0.999 *. 0.91 in
  assert_that
    (_expected_wma _trader_period, _expected_wma _stage_period)
    (pair
       (lt (module Float_ord) correction_low)
       (lt (module Float_ord) (_expected_wma _trader_period *. 0.9)))

(* ------------------------------------------------------------------ *)
(* Stops_runner wiring                                                  *)
(* ------------------------------------------------------------------ *)

(* Default [None]: the stop machine reads the 30-week stage MA and raises off
   it. *)
let test_none_reads_stage_ma _ =
  let stage_ma = _expected_wma _stage_period in
  assert_that (_run ())
    (all_of
       [
         field
           (fun r -> r.stop_mas)
           (elements_are [ float_equal ~epsilon:1e-6 stage_ma ]);
         field
           (fun r -> r.adjusts)
           (elements_are
              [
                field _new_stop_of
                  (is_some_and
                     (float_equal ~epsilon:_nudge_epsilon
                        (_raise_off_ma stage_ma)));
              ]);
       ])

(* [None] is the same as naming the stage period explicitly. *)
let test_none_equals_stage_period _ =
  let summary r = (r.stop_mas, List.map r.adjusts ~f:_new_stop_of) in
  assert_that
    (summary (_run ~trailing_stop_ma_period:_stage_period ()))
    (equal_to
       ~cmp:
         (Tuple2.equal ~eq1:(List.equal Float.equal)
            ~eq2:(List.equal (Option.equal Float.equal)))
       (summary (_run ())))

(* [Some 10]: the stop machine reads the 10-week MA and the raise follows it. *)
let test_some_10_trails_ten_week_ma _ =
  let trader_ma = _expected_wma _trader_period in
  assert_that
    (_run ~trailing_stop_ma_period:_trader_period ())
    (all_of
       [
         field
           (fun r -> r.stop_mas)
           (elements_are [ float_equal ~epsilon:1e-6 trader_ma ]);
         field
           (fun r -> r.adjusts)
           (elements_are
              [
                field _new_stop_of
                  (is_some_and
                     (float_equal ~epsilon:_nudge_epsilon
                        (_raise_off_ma trader_ma)));
              ]);
       ])

(* [Some 10] changes only the stop MA: the stage is still classified on the
   30-week MA (Stage 2 on a rising tape) and the Stage-3 margin mirror still
   holds the 30-week WMA. *)
let test_some_10_keeps_stage_classification _ =
  assert_that
    (_run ~trailing_stop_ma_period:_trader_period ())
    (all_of
       [
         field
           (fun r -> r.stage)
           (is_some_and
              (matching ~msg:"Expected Stage2"
                 (function Weinstein_types.Stage2 _ -> Some () | _ -> None)
                 (equal_to ())));
         field
           (fun r -> r.mirror)
           (is_some_and
              (float_equal ~epsilon:1e-6 (_expected_wma _stage_period)));
       ])

(* [Some 10] under [stop_ma_same_basis]: the trailing MA is restated onto the
   bar's raw basis like the stage MA. On a later-split tape (adjusted = close /
   10) the stop reads 10x the adjusted 10-week MA. *)
let test_some_10_restated_onto_stop_basis _ =
  let split_bars =
    List.map (_tape ()) ~f:(fun b ->
        { b with Types.Daily_price.adjusted_close = b.close_price /. 10.0 })
  in
  let last = List.last_exn split_bars in
  let weekly =
    Bar_reader.weekly_view_for
      (Bar_reader.of_in_memory_bars [ (_symbol, split_bars) ])
      ~symbol:_symbol ~n:_lookback_bars ~as_of:last.Types.Daily_price.date
  in
  let adjusted_ma =
    Stop_ma_stage.trailing_ma_value ~stage_config:Stage.default_config
      ~period:_trader_period ~symbol:_symbol weekly
  in
  let stop_ma =
    let _, ma, _ =
      Stop_ma_stage.compute ~trailing_stop_ma_period:_trader_period
        ~stage_config:Stage.default_config ~lookback_bars:_lookback_bars
        ~bar_reader:(Bar_reader.of_in_memory_bars [ (_symbol, split_bars) ])
        ~as_of:last.Types.Daily_price.date
        ~prior_stages:(Hashtbl.create (module String))
        ~symbol:_symbol ~side:Trading_base.Types.Long
        ~fallback_price:last.close_price
        ~to_stop_basis:(Stop_ma_basis.for_stops ~enabled:true ~bar:last)
        ()
    in
    ma
  in
  assert_that (adjusted_ma, stop_ma)
    (all_of
       [
         field fst
           (is_some_and
              (float_equal ~epsilon:1e-6 (_expected_wma _trader_period /. 10.0)));
         field snd (float_equal ~epsilon:1e-6 (_expected_wma _trader_period));
       ])

(* [Some 60] with a 52-week view: not enough weeks, fall back to the stage MA. *)
let test_period_longer_than_view_falls_back _ =
  assert_that (_run ~trailing_stop_ma_period:60 ()).stop_mas
    (elements_are [ float_equal ~epsilon:1e-6 (_expected_wma _stage_period) ])

(* A non-positive period is a configuration error. *)
let test_non_positive_period_raises _ =
  let weekly =
    Bar_reader.weekly_view_for
      (Bar_reader.of_in_memory_bars [ (_symbol, _tape ()) ])
      ~symbol:_symbol ~n:_lookback_bars
      ~as_of:(List.last_exn (_tape ())).Types.Daily_price.date
  in
  assert_raises
    (Invalid_argument "Stop_ma_stage.trailing_ma_value: period must be > 0 (0)")
    (fun () ->
      Stop_ma_stage.trailing_ma_value ~stage_config:Stage.default_config
        ~period:0 ~symbol:_symbol weekly)

let suite =
  "trailing_stop_ma_period"
  >::: [
         "fixture: 10w and 30w MAs differ" >:: test_fixture_mas_differ;
         "None reads the stage MA" >:: test_none_reads_stage_ma;
         "None = the stage period" >:: test_none_equals_stage_period;
         "Some 10 trails the 10-week MA" >:: test_some_10_trails_ten_week_ma;
         "Some 10 keeps stage classification on the 30w MA"
         >:: test_some_10_keeps_stage_classification;
         "Some 10 is restated onto the stop basis"
         >:: test_some_10_restated_onto_stop_basis;
         "period longer than the view falls back to the stage MA"
         >:: test_period_longer_than_view_falls_back;
         "non-positive period raises" >:: test_non_positive_period_raises;
       ]

let () = run_test_tt_main suite
