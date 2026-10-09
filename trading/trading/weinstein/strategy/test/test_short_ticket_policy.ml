(** #3218 (Shorts Phase B v1) — the two default-off short-side resting-ticket
    levers, driven through one real Friday screen
    ({!Weinstein_strategy.Weinstein_strategy_macro.run_screen_after_macro}):

    - [short_cancel_on_non_bearish] cancels a resting short ticket the first
      week the macro trend is Neutral or Bullish, keeps it when Bearish or when
      the flag is off, and never touches a long ticket;
    - [short_entry_order_max_rest_weeks] expires a short ticket after N weeks
      while a long ticket of the same age keeps the long limit; [None] inherits.

    Both fields default to the no-op, pinned at the end. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy
module Position = Trading_strategy.Position
module WSM = Weinstein_strategy.Weinstein_strategy_macro

let _index_symbol = "GSPCX"
let _long_symbol = "LONGY"
let _short_symbol = "SHORTY"
let _friday = Date.of_string "2024-04-26"

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

let _daily_bar ~date ~price : Types.Daily_price.t =
  {
    date;
    open_price = price;
    high_price = price *. 1.01;
    low_price = price *. 0.99;
    close_price = price;
    adjusted_close = price;
    volume = 1_000_000;
    active_through = None;
  }

let _daily_bars ~n ~start_price ~step =
  let start_date = Date.add_days _friday (-(n - 1)) in
  List.init n ~f:(fun i ->
      _daily_bar
        ~date:(Date.add_days start_date i)
        ~price:(start_price +. (Float.of_int i *. step)))

(* [_long_symbol] rises (Stage 2) and [_short_symbol] falls (Stage 4) over
   260 daily bars (~37 weeks). *)
let _bar_reader =
  Bar_reader.of_in_memory_bars
    [
      (_index_symbol, _daily_bars ~n:260 ~start_price:100.0 ~step:1.0);
      (_long_symbol, _daily_bars ~n:260 ~start_price:200.0 ~step:1.0);
      (_short_symbol, _daily_bars ~n:260 ~start_price:400.0 ~step:(-1.0));
    ]

let _index_view =
  Bar_reader.weekly_view_for _bar_reader ~symbol:_index_symbol ~n:52
    ~as_of:_friday

(** A macro result carrying [index_stage]; callers override [trend]. *)
let _macro_with ~(index_stage : Weinstein_types.stage) : Macro.result =
  {
    index_stage =
      {
        stage = index_stage;
        ma_value = 100.0;
        ma_direction = Weinstein_types.Declining;
        ma_slope_pct = -0.01;
        transition = None;
        above_ma_count = 0;
      };
    indicators = [];
    trend = Weinstein_types.Bullish;
    breadth_state = Weinstein_types.Bullish_breadth;
    confidence = 0.8;
    regime_changed = false;
    rationale = [];
  }

let _stage4 = Weinstein_types.Stage4 { weeks_declining = 9 }
let _stage3 = Weinstein_types.Stage3 { weeks_topping = 6 }
let _stage2 = Weinstein_types.Stage2 { weeks_advancing = 8; late = false }

let _unwrap = function
  | Ok p -> p
  | Error err -> assert_failure ("position setup failed: " ^ Status.show err)

let _macro ~trend : Macro.result =
  { (_macro_with ~index_stage:_stage4) with trend }

let _ticket ~weeks_old ~id ~symbol ~side =
  Position.create_entering
    {
      position_id = id;
      date = Date.add_days _friday (-7 * weeks_old);
      kind =
        Position.CreateEntering
          {
            symbol;
            side;
            target_quantity = 10.0;
            entry_price = 100.0;
            reasoning = ManualDecision { description = "short policy test" };
          };
    }
  |> _unwrap

let _short ~weeks_old =
  _ticket ~weeks_old ~id:"S1" ~symbol:_short_symbol
    ~side:Trading_base.Types.Short

let _long ~weeks_old =
  _ticket ~weeks_old ~id:"L1" ~symbol:_long_symbol ~side:Trading_base.Types.Long

let _positions ps =
  List.map ps ~f:(fun (p : Position.t) -> (p.id, p)) |> String.Map.of_alist_exn

(* Re-screen off and the long clock unbounded (or [long_weeks]), so any cancel
   below is attributable to the two #3218 levers or the long clock. *)
let _config ?(short_cancel_on_non_bearish = false)
    ?(short_entry_order_max_rest_weeks = None) ?(long_weeks = 0) () =
  {
    (Weinstein_strategy_config.default_config
       ~universe:[ _long_symbol; _short_symbol ]
       ~index_symbol:_index_symbol)
    with
    enable_entry_ticket_rescreen = false;
    entry_order_max_rest_weeks = long_weeks;
    short_cancel_on_non_bearish;
    short_entry_order_max_rest_weeks;
  }

(** (id, reason) of every [CancelEntry] one real Friday screen emits. *)
let _cancels ~config ~trend ~positions =
  WSM.run_screen_after_macro ~pending_entry_e:(Entry_freeze.create ())
    ~suspended_tickets:(Entry_ticket_suspend.create ())
    ~fold_start_date:None ~universe_membership_at:None ~config
    ~stop_states:(ref String.Map.empty)
    ~last_stop_out_dates:(Hashtbl.create (module String))
    ~bar_reader:_bar_reader
    ~prior_stages:(Hashtbl.create (module String))
    ~sector_prior_stages:(Hashtbl.create (module String))
    ~ticker_sectors:(Hashtbl.create (module String))
    ~get_price:(fun _ -> None)
    ~portfolio:{ cash = 100_000.0; positions = _positions positions }
    ~current_date:_friday ~index_view:_index_view
    ~audit_recorder:Audit_recorder.noop ~macro_result:(_macro ~trend)
  |> List.filter_map ~f:(fun (t : Position.transition) ->
      match t.kind with
      | Position.CancelEntry { reason } -> Some (t.position_id, reason)
      | _ -> None)

let _macro_cancel = ("S1", Short_ticket_policy.cancel_reason)
let _ttl_cancel = ("S1", "entry_ticket_ttl_expired")

let test_flag_on_cancels_short_when_neutral_or_bullish _ =
  let cancels trend =
    _cancels
      ~config:(_config ~short_cancel_on_non_bearish:true ())
      ~trend
      ~positions:[ _short ~weeks_old:1 ]
  in
  assert_that
    (cancels Weinstein_types.Neutral, cancels Weinstein_types.Bullish)
    (pair
       (elements_are [ equal_to _macro_cancel ])
       (elements_are [ equal_to _macro_cancel ]))

let test_flag_on_keeps_short_when_bearish _ =
  assert_that
    (_cancels
       ~config:(_config ~short_cancel_on_non_bearish:true ())
       ~trend:Weinstein_types.Bearish
       ~positions:[ _short ~weeks_old:1 ])
    (size_is 0)

let test_flag_off_keeps_short_when_neutral _ =
  assert_that
    (_cancels ~config:(_config ()) ~trend:Weinstein_types.Neutral
       ~positions:[ _short ~weeks_old:1 ])
    (size_is 0)

let test_flag_on_leaves_long_ticket_alone _ =
  assert_that
    (_cancels
       ~config:(_config ~short_cancel_on_non_bearish:true ())
       ~trend:Weinstein_types.Neutral
       ~positions:[ _long ~weeks_old:1; _short ~weeks_old:1 ])
    (elements_are [ equal_to _macro_cancel ])

let test_override_expires_short_but_long_keeps_long_limit _ =
  assert_that
    (_cancels
       ~config:
         (_config ~short_entry_order_max_rest_weeks:(Some 4) ~long_weeks:52 ())
       ~trend:Weinstein_types.Bearish
       ~positions:[ _long ~weeks_old:5; _short ~weeks_old:5 ])
    (elements_are [ equal_to _ttl_cancel ])

let test_override_keeps_short_within_limit _ =
  assert_that
    (_cancels
       ~config:
         (_config ~short_entry_order_max_rest_weeks:(Some 4) ~long_weeks:52 ())
       ~trend:Weinstein_types.Bearish
       ~positions:[ _short ~weeks_old:4 ])
    (size_is 0)

let test_no_override_inherits_long_limit _ =
  assert_that
    (_cancels ~config:(_config ~long_weeks:4 ()) ~trend:Weinstein_types.Bearish
       ~positions:[ _short ~weeks_old:5 ])
    (elements_are [ equal_to _ttl_cancel ])

let test_long_clock_still_expires_long_under_override _ =
  assert_that
    (_cancels
       ~config:
         (_config ~short_entry_order_max_rest_weeks:(Some 20) ~long_weeks:4 ())
       ~trend:Weinstein_types.Bearish
       ~positions:[ _long ~weeks_old:5; _short ~weeks_old:5 ])
    (elements_are [ equal_to ("L1", "entry_ticket_ttl_expired") ])

let _fill pos ~quantity =
  Position.apply_transition pos
    {
      position_id = pos.Position.id;
      date = _friday;
      kind =
        Position.EntryFill { filled_quantity = quantity; fill_price = 100.0 };
    }
  |> _unwrap

let _held pos =
  Position.apply_transition (_fill pos ~quantity:10.0)
    {
      position_id = pos.Position.id;
      date = _friday;
      kind =
        Position.EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          };
    }
  |> _unwrap

let _named pos ~id = { pos with Position.id }

(** Only a wholly unfilled short is cancelled: a part-filled short, a held short
    and a resting long are all skipped (open shorts are never covered). *)
let test_macro_cancellations_skip_filled_held_and_long _ =
  let part_filled =
    _fill (_named (_short ~weeks_old:1) ~id:"S2") ~quantity:4.0
  in
  let held = _held (_named (_short ~weeks_old:1) ~id:"S3") in
  assert_that
    (Short_ticket_policy.macro_cancellations
       ~positions:
         (_positions
            [ _short ~weeks_old:1; part_filled; held; _long ~weeks_old:1 ])
       ~current_date:_friday
    |> List.map ~f:(fun (t : Position.transition) -> t.position_id))
    (elements_are [ equal_to "S1" ])

let _candidate ~ticker ~entry : Screener.scored_candidate =
  let base =
    Stock_analysis.analyze ~config:Stock_analysis.default_config ~ticker
      ~bars:[] ~benchmark_bars:[] ~prior_stage:None ~as_of_date:_friday
  in
  {
    ticker;
    analysis = base;
    side = Trading_base.Types.Short;
    sector =
      {
        sector_name = "Tech";
        rating = Screener.Neutral;
        stage = base.stage.stage;
      };
    grade = Weinstein_types.A;
    score = 70;
    suggested_entry = entry;
    suggested_stop = entry *. 1.05;
    risk_pct = 0.05;
    swing_target = None;
    rationale = [];
  }

let _pin_apply pending ?(held_set = String.Set.empty) candidates =
  Entry_freeze.apply ~enabled:true ~pending ~held_set ~candidates

(** A macro cancel releases the ticket's frozen [E], so the symbol re-pins at
    the fresh level (60), not the cancelled ticket's (50). The symbol is still
    held on the cancelling tick, so [apply]'s own stale-release rule would keep
    the pin. MUTATION: drop the release loop in [Short_ticket_policy.run] and
    this reads 50.0. *)
let test_macro_cancel_releases_pin_so_symbol_repins_fresh _ =
  let pending = Entry_freeze.create () in
  let _wk1 =
    _pin_apply pending [ _candidate ~ticker:_short_symbol ~entry:50.0 ]
  in
  let cancelled =
    Short_ticket_policy.run
      (_config ~short_cancel_on_non_bearish:true ())
      ~macro_result:(_macro ~trend:Weinstein_types.Neutral)
      ~pending_entry_e:pending
      ~positions:(_positions [ _short ~weeks_old:1 ])
      ~still_qualifies:(fun ~symbol:_ ~side:_ -> true)
      ~current_date:_friday
  in
  let _same_tick =
    _pin_apply pending ~held_set:(String.Set.of_list [ _short_symbol ]) []
  in
  let later =
    _pin_apply pending [ _candidate ~ticker:_short_symbol ~entry:60.0 ]
  in
  assert_that
    ( List.length cancelled,
      List.map later ~f:(fun (c : Screener.scored_candidate) ->
          c.suggested_entry) )
    (equal_to (1, [ 60.0 ]))

(** A short that is both macro-cancelled and TTL-expired gets exactly one
    [CancelEntry], the macro one: the TTL pass sees only the remaining
    positions. MUTATION: pass [positions] instead of [remaining] to [_ttl_pass]
    and this emits two. *)
let test_macro_cancelled_short_is_not_cancelled_twice _ =
  assert_that
    (_cancels
       ~config:
         (_config ~short_cancel_on_non_bearish:true
            ~short_entry_order_max_rest_weeks:(Some 4) ())
       ~trend:Weinstein_types.Neutral
       ~positions:[ _short ~weeks_old:5 ])
    (elements_are [ equal_to _macro_cancel ])

let test_both_fields_default_to_the_no_op _ =
  let c =
    Weinstein_strategy_config.default_config ~universe:[]
      ~index_symbol:_index_symbol
  in
  assert_that
    (c.short_cancel_on_non_bearish, c.short_entry_order_max_rest_weeks)
    (equal_to (false, (None : int option)))

let suite =
  "short ticket policy"
  >::: [
         "flag on cancels short when neutral or bullish"
         >:: test_flag_on_cancels_short_when_neutral_or_bullish;
         "flag on keeps short when bearish"
         >:: test_flag_on_keeps_short_when_bearish;
         "flag off keeps short when neutral"
         >:: test_flag_off_keeps_short_when_neutral;
         "flag on leaves long ticket alone"
         >:: test_flag_on_leaves_long_ticket_alone;
         "override expires short but long keeps long limit"
         >:: test_override_expires_short_but_long_keeps_long_limit;
         "override keeps short within limit"
         >:: test_override_keeps_short_within_limit;
         "no override inherits long limit"
         >:: test_no_override_inherits_long_limit;
         "long clock still expires long under override"
         >:: test_long_clock_still_expires_long_under_override;
         "macro cancellations skip filled, held and long"
         >:: test_macro_cancellations_skip_filled_held_and_long;
         "macro cancel releases pin so symbol re-pins fresh"
         >:: test_macro_cancel_releases_pin_so_symbol_repins_fresh;
         "macro cancelled short is not cancelled twice"
         >:: test_macro_cancelled_short_is_not_cancelled_twice;
         "both fields default to the no-op"
         >:: test_both_fields_default_to_the_no_op;
       ]

let () = run_test_tt_main suite
