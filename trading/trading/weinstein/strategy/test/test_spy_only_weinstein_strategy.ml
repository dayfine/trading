open OUnit2
open Core
open Matchers
module Spy = Weinstein_strategy.Spy_only_weinstein_strategy
module Bar_reader = Weinstein_strategy.Bar_reader
module Strategy_interface = Trading_strategy.Strategy_interface
module Portfolio_view = Trading_strategy.Portfolio_view

let symbol = "SPY"

(* One daily bar; [open]/[high]/[low] default around [close]. *)
let make_bar date ~close ?low ?high () : Types.Daily_price.t =
  let low = Option.value low ~default:(close *. 0.99) in
  let high = Option.value high ~default:(close *. 1.01) in
  {
    date = Date.of_string date;
    open_price = close;
    high_price = high;
    low_price = low;
    close_price = close;
    adjusted_close = close;
    volume = 1_000_000;
    active_through = None;
  }

(* Generate [n] weekly bars, one per consecutive Friday ending at [last_friday],
   with [close i] giving the close of the i-th bar (0 = oldest). ISO-week
   grouping in [daily_to_weekly] turns one Friday-dated daily bar into one
   weekly bar, so the resulting weekly series is exactly the [close]
   trajectory. *)
let weekly_closes ~last_friday ~n ~close : Types.Daily_price.t list =
  let last = Date.of_string last_friday in
  List.init n ~f:(fun i ->
      let d = Date.add_days last (-7 * (n - 1 - i)) in
      make_bar (Date.to_string d) ~close:(close i) ())

(* A long, smoothly rising trajectory: price climbs well above a rising 30-week
   MA → Stage 2. *)
let rising_closes i = 50.0 +. (Float.of_int i *. 1.5)

(* A long, smoothly falling trajectory off a prior peak: price below a declining
   30-week MA → Stage 4. *)
let falling_closes ~peak i = peak -. (Float.of_int i *. 1.5)
let last_friday = "2021-12-31"
let n_weeks = 60
let bar_reader_of bars = Bar_reader.of_in_memory_bars [ (symbol, bars) ]

let make_portfolio ~cash ?position () : Portfolio_view.t =
  let positions =
    match position with
    | None -> String.Map.empty
    | Some (p : Trading_strategy.Position.t) -> String.Map.singleton p.id p
  in
  { cash; positions }

(* Build a Holding SPY position at [entry_price] / [entry_date] on [side]
   (default Long). *)
let make_holding ?(side = Trading_strategy.Position.Long) ~entry_price
    ~entry_date ~quantity () : Trading_strategy.Position.t =
  let pos_id = symbol ^ "-spy-only-weinstein" in
  let make_trans kind =
    { Trading_strategy.Position.position_id = pos_id; date = entry_date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error e ->
        OUnit2.assert_failure ("position setup failed: " ^ Status.show e)
  in
  let open Trading_strategy.Position in
  create_entering
    (make_trans
       (CreateEntering
          {
            symbol;
            side;
            target_quantity = quantity;
            entry_price;
            reasoning = ManualDecision { description = "test" };
          }))
  |> unwrap
  |> fun p ->
  apply_transition p
    (make_trans
       (EntryFill { filled_quantity = quantity; fill_price = entry_price }))
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

let no_indicator : Strategy_interface.get_indicator_fn = fun _ _ _ _ -> None

let run_once (module M : Strategy_interface.STRATEGY) ~today_bar ~portfolio =
  M.on_market_close
    ~get_price:(fun s -> if String.equal s symbol then Some today_bar else None)
    ~get_indicator:no_indicator ~portfolio

(* A matcher pinning a single CreateEntering(Long) transition for SPY. The
   inlined record from [CreateEntering] cannot escape the match, so the matcher
   projects its [(symbol, side)] into a tuple. *)
let is_long_entry =
  is_ok_and_holds
    (field
       (fun (o : Strategy_interface.output) -> o.transitions)
       (elements_are
          [
            field
              (fun (t : Trading_strategy.Position.transition) -> t.kind)
              (matching ~msg:"Expected CreateEntering Long"
                 (function
                   | Trading_strategy.Position.CreateEntering c ->
                       Some (c.symbol, c.side)
                   | _ -> None)
                 (equal_to
                    ((symbol, Trading_strategy.Position.Long)
                      : string * Trading_strategy.Position.position_side)));
          ]))

(* A matcher pinning a single CreateEntering(Short) transition for SPY with a
   given [target_quantity] — projects [(symbol, side, target_quantity)] out of
   the inlined record. *)
let is_short_entry ~target_quantity =
  is_ok_and_holds
    (field
       (fun (o : Strategy_interface.output) -> o.transitions)
       (elements_are
          [
            field
              (fun (t : Trading_strategy.Position.transition) -> t.kind)
              (matching ~msg:"Expected CreateEntering Short"
                 (function
                   | Trading_strategy.Position.CreateEntering c ->
                       Some (c.symbol, c.side, c.target_quantity)
                   | _ -> None)
                 (all_of
                    [
                      field (fun (s, _, _) -> s) (equal_to symbol);
                      field
                        (fun (_, side, _) -> side)
                        (equal_to Trading_strategy.Position.Short);
                      field
                        (fun (_, _, qty) -> qty)
                        (float_equal target_quantity);
                    ]));
          ]))

(* A matcher pinning a single TriggerExit transition whose exit_reason satisfies
   [reason_ok]. The inlined [TriggerExit] record cannot escape, so the matcher
   projects out [exit_reason] (a regular top-level variant) inside the match. *)
let is_exit ~reason_ok =
  is_ok_and_holds
    (field
       (fun (o : Strategy_interface.output) -> o.transitions)
       (elements_are
          [
            field
              (fun (t : Trading_strategy.Position.transition) -> t.kind)
              (matching ~msg:"Expected TriggerExit"
                 (function
                   | Trading_strategy.Position.TriggerExit e ->
                       Some e.exit_reason
                   | _ -> None)
                 reason_ok);
          ]))

let is_no_transitions =
  is_ok_and_holds
    (field (fun (o : Strategy_interface.output) -> o.transitions) is_empty)

(* ---------------------------------------------------------------- *)
(* Sanity: the synthetic trajectories classify as intended.         *)
(* ---------------------------------------------------------------- *)

let stage_of bars =
  (Stage.classify ~config:Stage.default_config ~bars ~prior_stage:None).stage

let test_rising_is_stage2 _ =
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:rising_closes in
  assert_that (stage_of bars)
    (matching ~msg:"rising series should be Stage2"
       (function Weinstein_types.Stage2 _ -> Some () | _ -> None)
       (equal_to ()))

let test_falling_is_stage4 _ =
  let bars =
    weekly_closes ~last_friday ~n:n_weeks ~close:(falling_closes ~peak:140.0)
  in
  assert_that (stage_of bars)
    (matching ~msg:"falling series should be Stage4"
       (function Weinstein_types.Stage4 _ -> Some () | _ -> None)
       (equal_to ()))

(* ---------------------------------------------------------------- *)
(* Behavioural tests.                                               *)
(* ---------------------------------------------------------------- *)

let test_stage2_friday_enters_when_flat _ =
  (* Flat (no position), Stage 2, on a Friday → buy SPY with all cash. *)
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:rising_closes in
  let today = List.last_exn bars in
  let strat = Spy.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result is_long_entry

let test_stage2_non_friday_no_entry _ =
  (* Same Stage-2 tape, but mid-week (Wednesday) → no action when flat. *)
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:rising_closes in
  let wed_bar = make_bar "2021-12-29" ~close:(rising_closes (n_weeks - 1)) () in
  let strat = Spy.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:wed_bar
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result is_no_transitions

let test_stage4_friday_exits_when_holding _ =
  (* Holding SPY into a Stage-4 Friday → sell-all via the stage signal. The
     entry is anchored at today's close so the trailing stop sits ~8% BELOW
     today's bar and does not fire — isolating the stage-exit path from the
     (higher-precedence) stop-exit path. *)
  let bars =
    weekly_closes ~last_friday ~n:n_weeks ~close:(falling_closes ~peak:140.0)
  in
  let today = List.last_exn bars in
  let pos =
    make_holding ~entry_price:today.close_price ~entry_date:today.date
      ~quantity:700.0 ()
  in
  let strat = Spy.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  assert_that result
    (is_exit
       ~reason_ok:
         (matching ~msg:"Expected StrategySignal stage4_exit"
            (function
              | Trading_strategy.Position.StrategySignal s -> Some s.label
              | _ -> None)
            (equal_to "stage4_exit")))

let test_stop_hit_exits_when_holding _ =
  (* Holding SPY; today's bar gaps the low far below entry so the trailing
     stop's trigger fires immediately, producing a StopLoss exit — independent
     of the day-of-week (trigger is continuous). *)
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:rising_closes in
  let entry_price = rising_closes (n_weeks - 1) in
  (* A violent down-day well below any plausible support floor. *)
  let crash_bar =
    make_bar "2021-12-30" ~close:(entry_price *. 0.5) ~low:(entry_price *. 0.5)
      ~high:entry_price ()
  in
  let pos =
    make_holding ~entry_price
      ~entry_date:(Date.of_string "2021-12-24")
      ~quantity:700.0 ()
  in
  let strat = Spy.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:crash_bar
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  assert_that result
    (is_exit
       ~reason_ok:
         (matching ~msg:"Expected StopLoss"
            (function
              | Trading_strategy.Position.StopLoss s -> Some s.actual_price
              | _ -> None)
            (float_equal (entry_price *. 0.5))))

let test_stage1_friday_no_entry_when_flat _ =
  (* A flat, choppy tape that never establishes a Stage-2 advance: no entry. *)
  let flat_closes _ = 50.0 in
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:flat_closes in
  let today = List.last_exn bars in
  let strat = Spy.make ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result is_no_transitions

(* A long, steep decline into a trough at week [_rally_trough], then a SHORT
   sharp recent rally over the final weeks. The fast 10-week MA sits inside the
   rally — rising, price above it for the full confirm window → Stage 2. The slow
   30-week MA is still dominated by the long decline — declining, price not yet
   above it for enough of the confirm window → Stage 3, no Stage-2 entry. Same
   tape, opposite entry decision; the only difference between the two runs is
   [ma_period_weeks]. (Verified empirically against [Stage.classify].) *)
let _rally_trough = 51

let decline_then_rally i =
  if i <= _rally_trough then 130.0 -. (Float.of_int i *. 2.0)
  else
    130.0
    -. (Float.of_int _rally_trough *. 2.0)
    +. (Float.of_int (i - _rally_trough) *. 3.0)

let test_trader_preset_enters_where_investor_waits _ =
  (* On the same decline-then-rally tape, the 10-week (trader) preset enters on
     the Friday while the 30-week (investor) preset does not — the only
     difference between the two runs is [ma_period_weeks]. *)
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:decline_then_rally in
  let today = List.last_exn bars in
  let bar_reader = bar_reader_of bars in
  let run_with ~ma_period_weeks =
    let config = Spy.config_with ~ma_period_weeks () in
    run_once
      (Spy.make ~config ~bar_reader ())
      ~today_bar:today
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that
    (run_with ~ma_period_weeks:10, run_with ~ma_period_weeks:30)
    (all_of
       [
         field (fun (trader, _) -> trader) is_long_entry;
         field (fun (_, investor) -> investor) is_no_transitions;
       ])

(* ---------------------------------------------------------------- *)
(* Stage-4 short leg (default-off testbed dial).                     *)
(* ---------------------------------------------------------------- *)

(* Expected whole-share notional for [cash] all-cash sizing at [close], mirroring
   the strategy's [_shares_from_cash] (1% gap buffer, rounded down). *)
let shares_at ~cash ~close = Float.round_down (cash /. (close *. 1.01))

let short_falling_bars =
  weekly_closes ~last_friday ~n:n_weeks ~close:(falling_closes ~peak:140.0)

let test_stage4_flat_stays_flat_when_short_off _ =
  (* Flag OFF (default): a flat portfolio on a Stage-4 Friday takes NO action —
     long/flat stays flat, bit-identical to the pre-short-leg strategy. *)
  let today = List.last_exn short_falling_bars in
  let strat = Spy.make ~bar_reader:(bar_reader_of short_falling_bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result is_no_transitions

let test_stage4_flat_goes_short_when_on _ =
  (* Flag ON: the SAME Stage-4 Friday + flat portfolio now opens a SHORT, sized
     by the same all-cash [floor(cash / (close * 1.01))] rule as the long. *)
  let today = List.last_exn short_falling_bars in
  let config =
    Spy.config_with ~enable_stage4_short:true ~ma_period_weeks:30 ()
  in
  let strat =
    Spy.make ~config ~bar_reader:(bar_reader_of short_falling_bars) ()
  in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:100_000.0 ())
  in
  assert_that result
    (is_short_entry
       ~target_quantity:(shares_at ~cash:100_000.0 ~close:today.close_price))

let test_short_stop_fires_when_holding _ =
  (* Holding a SHORT; today's bar gaps the HIGH far above entry so the short
     trailing stop (which sits above entry and ratchets down) triggers — a
     StopLoss exit, independent of the day-of-week (trigger is continuous). *)
  let entry_price = falling_closes ~peak:140.0 (n_weeks - 1) in
  (* A violent up-day well above any plausible counter-rally-high floor. *)
  let squeeze_bar =
    make_bar "2021-12-30" ~close:(entry_price *. 2.0) ~low:entry_price
      ~high:(entry_price *. 2.0) ()
  in
  let pos =
    make_holding ~side:Trading_strategy.Position.Short ~entry_price
      ~entry_date:(Date.of_string "2021-12-24")
      ~quantity:1000.0 ()
  in
  let config =
    Spy.config_with ~enable_stage4_short:true ~ma_period_weeks:30 ()
  in
  let strat =
    Spy.make ~config ~bar_reader:(bar_reader_of short_falling_bars) ()
  in
  let result =
    run_once strat ~today_bar:squeeze_bar
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  assert_that result
    (is_exit
       ~reason_ok:
         (matching ~msg:"Expected StopLoss"
            (function
              | Trading_strategy.Position.StopLoss s -> Some s.actual_price
              | _ -> None)
            (float_equal (entry_price *. 2.0))))

let test_short_covers_on_stage2_friday _ =
  (* Holding a SHORT into a Stage-2 (rising-tape) Friday → cover via the stage
     signal. The short is anchored at today's close/date so its seeded stop sits
     just ABOVE today's counter-rally high (the short stop sits above entry),
     and today's bar therefore does not breach it — isolating the stage-cover
     path from the (higher-precedence) short-stop path. *)
  let bars = weekly_closes ~last_friday ~n:n_weeks ~close:rising_closes in
  let today = List.last_exn bars in
  let pos =
    make_holding ~side:Trading_strategy.Position.Short
      ~entry_price:today.close_price ~entry_date:today.date ~quantity:300.0 ()
  in
  let config =
    Spy.config_with ~enable_stage4_short:true ~ma_period_weeks:30 ()
  in
  let strat = Spy.make ~config ~bar_reader:(bar_reader_of bars) () in
  let result =
    run_once strat ~today_bar:today
      ~portfolio:(make_portfolio ~cash:0.0 ~position:pos ())
  in
  assert_that result
    (is_exit
       ~reason_ok:
         (matching ~msg:"Expected StrategySignal stage4_cover"
            (function
              | Trading_strategy.Position.StrategySignal s -> Some s.label
              | _ -> None)
            (equal_to "stage4_cover")))

let suite =
  "spy_only_weinstein_strategy"
  >::: [
         "rising series classifies Stage2" >:: test_rising_is_stage2;
         "falling series classifies Stage4" >:: test_falling_is_stage4;
         "Stage2 Friday enters when flat"
         >:: test_stage2_friday_enters_when_flat;
         "Stage2 mid-week does not enter" >:: test_stage2_non_friday_no_entry;
         "Stage4 Friday exits when holding"
         >:: test_stage4_friday_exits_when_holding;
         "stop hit exits when holding" >:: test_stop_hit_exits_when_holding;
         "flat tape Friday does not enter"
         >:: test_stage1_friday_no_entry_when_flat;
         "trader preset enters where investor waits"
         >:: test_trader_preset_enters_where_investor_waits;
         "Stage4 flat stays flat when short off"
         >:: test_stage4_flat_stays_flat_when_short_off;
         "Stage4 flat goes short when short on"
         >:: test_stage4_flat_goes_short_when_on;
         "short stop fires when holding" >:: test_short_stop_fires_when_holding;
         "short covers on Stage2 Friday" >:: test_short_covers_on_stage2_friday;
       ]

let () = run_test_tt_main suite
