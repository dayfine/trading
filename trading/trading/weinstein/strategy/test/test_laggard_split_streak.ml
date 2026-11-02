(* Issue #3426: laggard rotation must not read a split as a loss
   ([adjusted_returns]) and must not carry a streak across a close/re-entry
   ([clear_streak_on_close]). Both flags are default-off. *)
open OUnit2
open Core
open Matchers
open Weinstein_strategy
module P = Trading_strategy.Position

let _friday = Date.of_string "2024-04-05"
let _n_bars = 14
let _split_after_week = 6

let _bar ~date ~raw ~adjusted =
  {
    Types.Daily_price.date;
    open_price = raw;
    high_price = raw;
    low_price = raw;
    close_price = raw;
    adjusted_close = adjusted;
    volume = 1_000_000;
    active_through = None;
  }

let _date_of i = Date.add_days _friday (-(_n_bars - 1 - i) * 7)

(* Linear adjusted path [from_c -> to_c]; raw = 2x adjusted up to and including
   [split_after] (a 2:1 forward split), raw = adjusted afterwards. *)
let _bars ?split_after ~from_c ~to_c () =
  let step = (to_c -. from_c) /. Float.of_int (_n_bars - 1) in
  List.init _n_bars ~f:(fun i ->
      let adjusted = from_c +. (Float.of_int i *. step) in
      let pre_split =
        match split_after with Some s -> i <= s | None -> false
      in
      let raw = if pre_split then adjusted *. 2.0 else adjusted in
      _bar ~date:(_date_of i) ~raw ~adjusted)

let _holding ~id ~symbol =
  let tr kind = { P.position_id = id; date = _friday; kind } in
  let ok = function
    | Ok p -> p
    | Error _ -> assert_failure "position setup failed"
  in
  let p =
    P.create_entering
      (tr
         (P.CreateEntering
            {
              symbol;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = 100.0;
              reasoning = P.ManualDecision { description = "test" };
            }))
    |> ok
  in
  let p =
    P.apply_transition p
      (tr (P.EntryFill { filled_quantity = 10.0; fill_price = 100.0 }))
    |> ok
  in
  P.apply_transition p
    (tr
       (P.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> ok

let _closed ~id ~symbol =
  let tr kind = { P.position_id = id; date = _friday; kind } in
  let ok = function
    | Ok p -> p
    | Error _ -> assert_failure "close setup failed"
  in
  let p = _holding ~id ~symbol in
  let p =
    P.apply_transition p
      (tr
         (P.TriggerExit
            {
              exit_reason =
                P.StrategySignal { label = "laggard_rotation"; detail = None };
              exit_price = 99.0;
            }))
    |> ok
  in
  let p =
    P.apply_transition p
      (tr (P.ExitFill { filled_quantity = 10.0; fill_price = 99.0 }))
    |> ok
  in
  P.apply_transition p (tr P.ExitComplete) |> ok

let _run ~config ~positions ~streaks ~symbol_bars =
  let get_price sym =
    List.Assoc.find symbol_bars sym ~equal:String.equal
    |> Option.map ~f:(fun bars -> List.last_exn bars)
  in
  Laggard_rotation_runner.update ~config ~benchmark_symbol:"BENCH"
    ~is_screening_day:true ~positions
    ~bar_reader:(Bar_reader.of_in_memory_bars symbol_bars)
    ~get_price ~laggard_streaks:streaks ~skip_position_ids:String.Set.empty
    ~current_date:_friday

let _streaks_of pairs =
  let t = Hashtbl.create (module String) in
  List.iter pairs ~f:(fun (k, v) -> Hashtbl.set t ~key:k ~data:v);
  t

let _sorted_streaks t =
  Hashtbl.to_alist t
  |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)

let _k4 = { Laggard_rotation.default_config with hysteresis_weeks = 4 }
let _bench = _bars ~from_c:100.0 ~to_c:110.0 ()

let test_split_window_return _ =
  let bars = _bars ~split_after:_split_after_week ~from_c:200.0 ~to_c:265.0 () in
  assert_that
    ( Laggard_rotation_runner.window_return ~adjusted:true ~n:13 bars,
      Laggard_rotation_runner.window_return ~n:13 bars )
    (all_of
       [
         field (fun (a, _) -> a) (is_some_and (float_equal 0.325));
         field (fun (_, r) -> r) (is_some_and (float_equal (-0.3375)));
       ])

let _split_run ~config ~key =
  let positions = String.Map.singleton "SPL" (_holding ~id:"SPL" ~symbol:"SPL") in
  let streaks = _streaks_of [ (key, 3) ] in
  let spl = _bars ~split_after:_split_after_week ~from_c:200.0 ~to_c:265.0 () in
  let exits =
    _run ~config ~positions ~streaks
      ~symbol_bars:[ ("BENCH", _bench); ("SPL", spl) ]
  in
  (exits, Hashtbl.find streaks key)

let test_split_flag_on _ =
  let config = { _k4 with adjusted_returns = true; clear_streak_on_close = true } in
  assert_that (_split_run ~config ~key:"SPL")
    (all_of
       [
         field (fun (e, _) -> e) is_empty;
         field (fun (_, s) -> s) (is_some_and (equal_to 0));
       ])

let test_split_flag_off _ =
  assert_that (_split_run ~config:_k4 ~key:"SPL")
    (field (fun (e, _) -> e) (size_is 1))

let _reentry_run ~config ~seed_key ~positions =
  let streaks = _streaks_of [ (seed_key, 3) ] in
  let lag = _bars ~from_c:100.0 ~to_c:90.0 () in
  let exits =
    _run ~config ~positions ~streaks
      ~symbol_bars:[ ("BENCH", _bench); ("KAI", lag) ]
  in
  (exits, _sorted_streaks streaks)

let test_reentry_flag_on _ =
  let config = { _k4 with clear_streak_on_close = true } in
  let positions =
    String.Map.of_alist_exn
      [
        ("KAI-1", _closed ~id:"KAI-1" ~symbol:"KAI");
        ("KAI-2", _holding ~id:"KAI-2" ~symbol:"KAI");
      ]
  in
  assert_that
    (_reentry_run ~config ~seed_key:"KAI-1" ~positions)
    (all_of
       [
         field (fun (e, _) -> e) is_empty;
         field (fun (_, s) -> s) (elements_are [ equal_to ("KAI-2", 1) ]);
       ])

let test_reentry_flag_off _ =
  let positions =
    String.Map.singleton "KAI-2" (_holding ~id:"KAI-2" ~symbol:"KAI")
  in
  assert_that
    (_reentry_run ~config:_k4 ~seed_key:"KAI" ~positions)
    (field (fun (e, _) -> e) (size_is 1))

let suite =
  "laggard_split_streak"
  >::: [
         "window_return ~adjusted reads adjusted_close across a split"
         >:: test_split_window_return;
         "adjusted_returns: 2:1 split inside the window does not read as a loss"
         >:: test_split_flag_on;
         "adjusted_returns off: split reads as a loss and fires"
         >:: test_split_flag_off;
         "clear_streak_on_close: re-entry does not fire on first lagging Friday"
         >:: test_reentry_flag_on;
         "clear_streak_on_close off: re-entry fires on first lagging Friday"
         >:: test_reentry_flag_off;
       ]

let () = run_test_tt_main suite
