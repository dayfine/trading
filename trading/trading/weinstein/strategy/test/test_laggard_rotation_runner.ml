open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close ?low ?high () =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
  }

let cfg_k4 = { Laggard_rotation.hysteresis_weeks = 4; rs_window_weeks = 13 }
let cfg_k1 = { Laggard_rotation.hysteresis_weeks = 1; rs_window_weeks = 13 }
let _friday = Date.of_string "2024-04-05" (* Friday *)
let _monday = Date.of_string "2024-04-08" (* Monday *)

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

(** Build a sequence of N weekly Friday daily bars ending at [_friday], with the
    close prices tracing [from_close → to_close] linearly across the range. Used
    to seed [Bar_reader.of_in_memory_bars] so [weekly_bars_for ~n:14] returns 14
    weekly closes that produce a known 13-week return. *)
let _make_weekly_bars_to_friday ~from_close ~to_close ~n =
  let step = (to_close -. from_close) /. Float.of_int (n - 1) in
  List.init n ~f:(fun i ->
      (* Each Friday is 7 days before the previous; bar [n-1] = _friday. *)
      let days_back = (n - 1 - i) * 7 in
      let d = Date.add_days _friday (-days_back) in
      let close = from_close +. (Float.of_int i *. step) in
      {
        Types.Daily_price.date = d;
        open_price = close;
        high_price = close *. 1.005;
        low_price = close *. 0.995;
        close_price = close;
        adjusted_close = close;
        volume = 1_000_000;
      })

(** Build a [Bar_reader.t] backed by in-memory bars for the given (symbol, bars)
    pairs. *)
let _make_reader symbol_bars = Bar_reader.of_in_memory_bars symbol_bars

let get_price_of bars symbol = List.Assoc.find bars symbol ~equal:String.equal

(* ------------------------------------------------------------------ *)
(* Off-cadence: non-Friday is a no-op                                   *)
(* ------------------------------------------------------------------ *)

let test_non_friday_no_op _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:3;
  let reader = Bar_reader.empty () in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:false ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-08" ~close:95.0 ()) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_monday
  in
  assert_that exits is_empty;
  (* Non-Friday call must not advance the streak counter. *)
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 3))

(* ------------------------------------------------------------------ *)
(* Empty positions: no exits                                            *)
(* ------------------------------------------------------------------ *)

let test_empty_positions_returns_empty _ =
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions:String.Map.empty
      ~bar_reader:(Bar_reader.empty ()) ~get_price:(get_price_of [])
      ~laggard_streaks:(Hashtbl.create (module String))
      ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty

(* ------------------------------------------------------------------ *)
(* Insufficient benchmark history → empty exits + streak untouched      *)
(* ------------------------------------------------------------------ *)

let test_short_benchmark_history_no_exit_streak_untouched _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:2;
  (* Benchmark only has 5 weekly bars — far less than required 14. *)
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:5
  in
  let reader = _make_reader [ ("GSPCX", bench_bars) ] in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-05" ~close:95.0 ()) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Benchmark gap leaves the streak untouched — no fresh observation. *)
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 2))

(* ------------------------------------------------------------------ *)
(* Insufficient position history → no exit, streak untouched            *)
(* ------------------------------------------------------------------ *)

let test_short_position_history_skips_position _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:2;
  (* Benchmark has full history; AAPL has only 5 weeks. *)
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:90.0 ~n:5
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-05" ~close:90.0 ()) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty;
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 2))

(* ------------------------------------------------------------------ *)
(* Long position: negative RS below hysteresis → no exit                *)
(* ------------------------------------------------------------------ *)

let test_neg_rs_below_hysteresis_no_exit _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  (* AAPL falls 10% over 13 weeks; benchmark rises 10%. RS sharply negative. *)
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:90.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-05" ~close:90.0 ()) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  (* First negative-RS read brings streak to 1 < hysteresis_weeks = 4. *)
  assert_that exits is_empty;
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 1))

(* ------------------------------------------------------------------ *)
(* Long position: negative RS at hysteresis → exit emitted              *)
(* ------------------------------------------------------------------ *)

let test_neg_rs_at_hysteresis_emits_exit _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:3;
  (* Pre-seeded streak = 3 → fourth observation fires under K=4. *)
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:90.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let bar = make_bar "2024-04-05" ~close:90.0 () in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_strategy.Position.transition) -> t.position_id)
               (equal_to "AAPL");
             field
               (fun (t : Trading_strategy.Position.transition) -> t.date)
               (equal_to _friday);
             field
               (fun (t : Trading_strategy.Position.transition) -> t.kind)
               (matching
                  ~msg:
                    "Expected TriggerExit with StrategySignal laggard_rotation"
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
                       field (fun (l, _, _) -> l) (equal_to "laggard_rotation");
                       field
                         (fun (_, d, _) -> d)
                         (is_some_and (equal_to "rs_13w_neg_weeks=4"));
                       field (fun (_, _, p) -> p) (float_equal 90.0);
                     ]));
           ];
       ])

(* ------------------------------------------------------------------ *)
(* Long position: positive RS resets the streak                         *)
(* ------------------------------------------------------------------ *)

let test_positive_rs_resets_streak _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:7;
  (* AAPL rises 20%; benchmark rises 5%. RS strongly positive. *)
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:105.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:120.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-05" ~close:120.0 ()) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty;
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 0))

(* ------------------------------------------------------------------ *)
(* Short position: never triggers laggard rotation                      *)
(* ------------------------------------------------------------------ *)

let test_short_position_never_emits_exit _ =
  let pos =
    make_holding_pos ~side:Trading_base.Types.Short "AAPL" 100.0 _friday
  in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  (* Pre-seed streak above threshold to make sure even a streak that would
     fire on a long is suppressed for a short. *)
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:10;
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:90.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-05" ~close:90.0 ()) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter stays at the pre-seeded 10 — the runner does not
     advance state for shorts. *)
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 10))

(* ------------------------------------------------------------------ *)
(* Skip-list collision: position already exited via stop is skipped     *)
(* ------------------------------------------------------------------ *)

let test_skips_position_already_exited _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:3;
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:90.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let skip_position_ids = String.Set.singleton pos.id in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:
        (get_price_of [ ("AAPL", make_bar "2024-04-05" ~close:90.0 ()) ])
      ~laggard_streaks ~skip_position_ids ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter still advances even though the exit was suppressed —
     accurate accounting against the RS stream is kept. *)
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 4))

(* ------------------------------------------------------------------ *)
(* Missing bar from get_price: no exit, but streak still advances       *)
(* ------------------------------------------------------------------ *)

let test_missing_get_price_skips_position _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  Hashtbl.set laggard_streaks ~key:"AAPL" ~data:3;
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:90.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k4 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:(fun _ -> None)
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits is_empty;
  (* Streak counter still advanced via observe_position. *)
  assert_that (Hashtbl.find laggard_streaks "AAPL") (is_some_and (equal_to 4))

(* ------------------------------------------------------------------ *)
(* K=1 fast path: single negative-RS observation fires                  *)
(* ------------------------------------------------------------------ *)

let test_k1_fires_first_week _ =
  let pos = make_holding_pos "AAPL" 100.0 _friday in
  let positions = String.Map.singleton "AAPL" pos in
  let laggard_streaks = Hashtbl.create (module String) in
  let bench_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:110.0 ~n:14
  in
  let aapl_bars =
    _make_weekly_bars_to_friday ~from_close:100.0 ~to_close:105.0 ~n:14
  in
  let reader = _make_reader [ ("GSPCX", bench_bars); ("AAPL", aapl_bars) ] in
  let bar = make_bar "2024-04-05" ~close:105.0 () in
  let exits =
    Laggard_rotation_runner.update ~config:cfg_k1 ~benchmark_symbol:"GSPCX"
      ~is_screening_day:true ~positions ~bar_reader:reader
      ~get_price:(get_price_of [ ("AAPL", bar) ])
      ~laggard_streaks ~skip_position_ids:String.Set.empty ~current_date:_friday
  in
  assert_that exits
    (elements_are
       [
         field
           (fun (t : Trading_strategy.Position.transition) -> t.kind)
           (matching ~msg:"Expected TriggerExit with rs_13w_neg_weeks=1"
              (function
                | Trading_strategy.Position.TriggerExit
                    {
                      exit_reason =
                        Trading_strategy.Position.StrategySignal
                          { label; detail };
                      _;
                    } ->
                    Some (label, detail)
                | _ -> None)
              (all_of
                 [
                   field (fun (l, _) -> l) (equal_to "laggard_rotation");
                   field
                     (fun (_, d) -> d)
                     (is_some_and (equal_to "rs_13w_neg_weeks=1"));
                 ]));
       ])

(* ------------------------------------------------------------------ *)
(* runner                                                                *)
(* ------------------------------------------------------------------ *)

let suite =
  "laggard_rotation_runner"
  >::: [
         "non-Friday is a no-op (does not advance streak)"
         >:: test_non_friday_no_op;
         "empty positions returns empty list"
         >:: test_empty_positions_returns_empty;
         "insufficient benchmark history: no exit, streak untouched"
         >:: test_short_benchmark_history_no_exit_streak_untouched;
         "insufficient position history: position skipped, streak untouched"
         >:: test_short_position_history_skips_position;
         "negative RS below hysteresis: no exit, streak advances to 1"
         >:: test_neg_rs_below_hysteresis_no_exit;
         "negative RS at hysteresis: emits TriggerExit with \
          StrategySignal(laggard_rotation)"
         >:: test_neg_rs_at_hysteresis_emits_exit;
         "positive RS resets the streak to 0" >:: test_positive_rs_resets_streak;
         "short position never emits exit, streak untouched"
         >:: test_short_position_never_emits_exit;
         "skip-list collision: position already exited is skipped (streak \
          still advances)" >:: test_skips_position_already_exited;
         "missing bar from get_price: no exit, streak still advances"
         >:: test_missing_get_price_skips_position;
         "K=1 fires on first negative-RS week" >:: test_k1_fires_first_week;
       ]

let () = run_test_tt_main suite
