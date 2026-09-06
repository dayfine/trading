(** #2672 guard 3, wiring half: the simulator's bar source and the strategy's
    bar reader must agree, bar for bar, about which rows the stub-print tail
    guard removed.

    Both are driven from ONE {!Snapshot_runtime.Stub_tail.t} in
    {!Backtest.Panel_runner}, and these tests pin that this actually produces
    agreement rather than merely being plumbed:

    - the simulator's [get_price] answers [None] on a stub date, so
      [Engine.update_market] receives no bar for it and there is nothing for a
      resting stop to fill against — that absence IS the mechanism that stops
      the STMP $0.04 [stop_loss] fill;
    - the simulator's [get_previous_bar] forward-fills from the last {b real}
      close, not from a penny print;
    - the strategy's [Bar_reader.daily_bars_for] ends on the same date the
      simulator's last visible bar does.

    The last pair closes the loop end to end: a long's protective stop, resting
    far above the penny prints, is walked through [Engine.update_market] over
    the whole series. Unarmed it fills at $0.045 — the phantom [stop_loss]
    itself, reproduced; armed it never fills, because no bar in the tail ever
    reaches the engine.

    The unarmed arm of each test shows the defect side by side: with the guard
    off, [get_price] hands back the $0.03 bar the record's phantom stop_loss
    filled at. *)

open OUnit2
open Core
open Matchers
module Bar_reader = Weinstein_strategy.Bar_reader
module Create_order = Trading_orders.Create_order
module Engine = Trading_engine.Engine
module Order_manager = Trading_orders.Manager
module Price_path = Trading_engine.Price_path
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Stub_tail = Snapshot_runtime.Stub_tail
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _ratio = 0.05
let _symbol = "STMP"
let _start = Date.create_exn ~y:2021 ~m:Month.Sep ~d:27
let _day i = Date.add_days _start i

(* The STMP shape from the #2672 scan: real bars up to $329.61 on day 3, then
   penny prints to the end of the series. *)
let _closes = [ 318.0; 322.5; 327.0; 329.61; 0.045; 0.04; 0.03 ]
let _last_real_day = _day 3
let _last_real_close = 329.61
let _first_stub_day = _day 4

let _row ~date ~close =
  let values =
    Array.map (Array.of_list Snapshot_schema.default.fields) ~f:(fun field ->
        match field with
        | Snapshot_schema.Open | Snapshot_schema.High | Snapshot_schema.Low
        | Snapshot_schema.Close | Snapshot_schema.Adjusted_close ->
            close
        | Snapshot_schema.Volume -> 5_000.0
        | _ -> Float.nan)
  in
  match
    Snapshot.create ~schema:Snapshot_schema.default ~symbol:_symbol ~date
      ~values
  with
  | Ok r -> r
  | Error err -> assert_failure ("Snapshot.create: " ^ Status.show err)

let _panels () =
  let dir = Filename_unix.temp_dir ~in_dir:"/tmp" "stub_tail_src_" "" in
  let rows = List.mapi _closes ~f:(fun i c -> _row ~date:(_day i) ~close:c) in
  let path = Filename.concat dir (_symbol ^ ".snap") in
  (match Snapshot_format.write ~path rows with
  | Ok () -> ()
  | Error err -> assert_failure ("Snapshot_format.write: " ^ Status.show err));
  let entries =
    [
      ({
         symbol = _symbol;
         path;
         byte_size = 0;
         payload_md5 = "ignored";
         csv_mtime = 0.0;
         active_through = None;
       }
        : Snapshot_manifest.file_metadata);
    ]
  in
  let manifest =
    Snapshot_manifest.create ~schema:Snapshot_schema.default ~entries
  in
  match Daily_panels.create ~snapshot_dir:dir ~manifest ~max_cache_mb:1 with
  | Ok panels -> panels
  | Error err -> assert_failure ("Daily_panels.create: " ^ Status.show err)

(* Both readers, wired exactly as [Panel_runner._setup_hybrid] wires them: one
   resolver built over the raw callbacks, then shared. Returns
   [(get_price, get_previous_bar, bar_reader)]. *)
let _wire ~ratio =
  let panels = _panels () in
  let base = Snapshot_callbacks.of_daily_panels panels in
  let stub_tail = Stub_tail.of_callbacks ~ratio base in
  let stub_tail_opt =
    if Stub_tail.is_armed stub_tail then Some stub_tail else None
  in
  let get_price, get_previous_bar =
    Backtest.Snapshot_bar_source.make_callbacks ?stub_tail:stub_tail_opt ~panels
      ~callbacks:base ()
  in
  let bar_reader =
    Bar_reader.of_snapshot_views (Stub_tail.wrap_callbacks stub_tail base)
  in
  (get_price, get_previous_bar, bar_reader)

let _price ~ratio ~date =
  let get_price, _, _ = _wire ~ratio in
  get_price ~symbol:_symbol ~date

let _previous ~ratio ~date =
  let _, get_previous_bar, _ = _wire ~ratio in
  get_previous_bar ~symbol:_symbol ~date

let _strategy_last_bar_date ~ratio =
  let _, _, bar_reader = _wire ~ratio in
  Bar_reader.daily_bars_for bar_reader ~symbol:_symbol ~as_of:(_day 6)
  |> List.last
  |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.date)

(* --- The defect, unguarded ------------------------------------------- *)

(** Unarmed (the default), the simulator sees the $0.045 print as a tradeable
    bar. This is the row [Weinstein_stops.check_stop_hit] trips on and
    [Fill_rules.would_fill_market] fills at — the −$594k STMP phantom loss. *)
let test_unarmed_price_returns_the_stub_bar _ =
  assert_that
    (_price ~ratio:0.0 ~date:_first_stub_day)
    (is_some_and
       (field
          (fun (b : Types.Daily_price.t) -> b.close_price)
          (float_equal 0.045)))

(** Unarmed, the strategy's bar list runs to the last penny print. *)
let test_unarmed_strategy_sees_the_stub_tail _ =
  assert_that
    (_strategy_last_bar_date ~ratio:0.0)
    (is_some_and (equal_to (_day 6)))

(* --- The guard ------------------------------------------------------- *)

(** Armed, there is no bar on the stub date at all. No bar reaches
    [Engine.update_market], so no order — a resting stop included — can fill
    there. *)
let test_armed_price_has_no_bar_in_the_tail _ =
  assert_that (_price ~ratio:_ratio ~date:_first_stub_day) is_none

(** Armed, the last real bar is still fully readable — the guard removes the
    tail, not the series. *)
let test_armed_price_keeps_the_last_real_bar _ =
  assert_that
    (_price ~ratio:_ratio ~date:_last_real_day)
    (is_some_and
       (field
          (fun (b : Types.Daily_price.t) -> b.close_price)
          (float_equal _last_real_close)))

(** Armed, forward-fill marks the position at the last real close rather than at
    a penny print — so the NAV mark and the stale-exit price (guard 2) both come
    off a real bar. *)
let test_armed_previous_bar_forward_fills_from_the_last_real_close _ =
  assert_that
    (_previous ~ratio:_ratio ~date:(_day 6))
    (is_some_and
       (all_of
          [
            field
              (fun (b : Types.Daily_price.t) -> b.date)
              (equal_to _last_real_day);
            field
              (fun (b : Types.Daily_price.t) -> b.close_price)
              (float_equal _last_real_close);
          ]))

(** The agreement contract: the strategy's last visible bar is the same date as
    the simulator's. A disagreement here is exactly the hazard the shared
    resolver exists to prevent — the simulator filling against a bar the
    strategy cannot see. *)
let test_both_paths_end_on_the_same_date _ =
  assert_that
    (_strategy_last_bar_date ~ratio:_ratio)
    (is_some_and (equal_to _last_real_day))

(* --- End to end through the engine ----------------------------------- *)

(* A held long's protective stop, resting far above the penny prints. *)
let _stop_price = 300.0
let _held_quantity = 100.0

(* [Price_path] draws from the bar unless a seed is fixed; pin one so the fill
   price is a function of the bar alone, as [test_engine.ml] does. *)
let _path_config = { Price_path.default_config with seed = Some 42 }

let _resting_stop_order () =
  match
    Create_order.create_order
      {
        Create_order.symbol = _symbol;
        side = Trading_base.Types.Sell;
        order_type = Trading_base.Types.Stop _stop_price;
        quantity = _held_quantity;
        time_in_force = Trading_orders.Types.GTC;
      }
  with
  | Ok order -> order
  | Error err -> assert_failure ("create_order: " ^ Status.show err)

(* Walk the whole series exactly as [Simulator._get_today_bars] does — one
   [get_price] per (symbol, day), [None] filtered out — feeding each day's bars
   to [Engine.update_market] and then processing the resting stop. Returns every
   trade the engine produced, in order. *)
let _stop_fills_over_series ~ratio =
  let get_price, _, _ = _wire ~ratio in
  let engine =
    Engine.create
      {
        Trading_engine.Types.commission = { per_share = 0.0; minimum = 0.0 };
        slippage_bps = 0;
      }
  in
  let order_mgr = Order_manager.create () in
  (match Order_manager.submit_orders order_mgr [ _resting_stop_order () ] with
  | [ Ok () ] -> ()
  | _ -> assert_failure "submit_orders rejected the resting stop");
  List.concat_map
    (List.range 0 (List.length _closes))
    ~f:(fun i ->
      let today_bars =
        get_price ~symbol:_symbol ~date:(_day i)
        |> Option.to_list
        |> List.map ~f:(fun (b : Types.Daily_price.t) ->
            {
              Trading_engine.Types.symbol = _symbol;
              open_price = b.open_price;
              high_price = b.high_price;
              low_price = b.low_price;
              close_price = b.close_price;
            })
      in
      Engine.update_market ~path_config:_path_config engine today_bars;
      match Engine.process_orders engine order_mgr with
      | Ok reports ->
          List.concat_map reports ~f:(fun r -> r.Trading_engine.Types.trades)
      | Error err -> assert_failure ("process_orders: " ^ Status.show err))

(** Unarmed (the default), the $0.045 print reaches [Engine.update_market] and
    the resting stop — 300.0, far above it — fills against it at that price.
    This is the −$594k STMP phantom [stop_loss] the guard exists to prevent,
    reproduced end to end. *)
let test_unarmed_stop_fills_at_the_stub_print _ =
  assert_that
    (_stop_fills_over_series ~ratio:0.0)
    (elements_are
       [
         all_of
           [
             field
               (fun (t : Trading_base.Types.trade) -> t.side)
               (equal_to (Trading_base.Types.Sell : Trading_base.Types.side));
             field
               (fun (t : Trading_base.Types.trade) -> t.price)
               (float_equal 0.045);
           ];
       ])

(** Armed, no bar exists on any stub date, so [Engine.update_market] is handed
    an empty bar list and the engine's last known bar for the symbol stays the
    $329.61 real one — nothing ever crosses 300.0 and the stop produces no fill
    at all. *)
let test_armed_stop_never_fills _ =
  assert_that (_stop_fills_over_series ~ratio:_ratio) (elements_are [])

let () =
  run_test_tt_main
    ("stub_tail_bar_source"
    >::: [
           "unarmed: get_price returns the stub bar"
           >:: test_unarmed_price_returns_the_stub_bar;
           "unarmed: the strategy sees the stub tail"
           >:: test_unarmed_strategy_sees_the_stub_tail;
           "armed: no bar in the tail"
           >:: test_armed_price_has_no_bar_in_the_tail;
           "armed: the last real bar is kept"
           >:: test_armed_price_keeps_the_last_real_bar;
           "armed: forward-fill uses the last real close"
           >:: test_armed_previous_bar_forward_fills_from_the_last_real_close;
           "armed: both paths end on the same date"
           >:: test_both_paths_end_on_the_same_date;
           "unarmed: a resting stop fills at the stub print"
           >:: test_unarmed_stop_fills_at_the_stub_print;
           "armed: a resting stop never fills" >:: test_armed_stop_never_fills;
         ])
