(** Bar_reader parity gate — see PR-H of the columnar-data-shape plan
    ([dev/plans/columnar-data-shape-2026-04-25.md] §Stage 2).

    Exercises [Weinstein_strategy.Bar_reader] with both backends (Bar_history
    and Bar_panels) over a synthetic scenario — both fed the SAME bars through
    different storage shapes. Asserts the bar-list outputs of [daily_bars_for]
    and [weekly_bars_for] are bit-identical for every reader site (per the audit
    in [dev/notes/bar-history-readers-2026-04-24.md]).

    This is the load-bearing parity check that pins panel-backed reads as a
    drop-in replacement for the parallel Bar_history cache. The Stage 2 PR that
    deletes Bar_history can rely on this test to catch any drift in the
    Bar_panels reconstruction.

    Scope: pure read parity. Strategy-level parity (full backtest with the
    runner-level swap) is the {!Backtest.Test_panel_loader_parity} job — that
    test currently runs Panel mode WITHOUT bar_panels (still using bar_history
    via the Tiered loader). The runner-level swap lands in Stage 3 after the
    Tiered cycle is collapsed; until then the runner-level parity gate would
    diverge for structural reasons (Tiered's incremental Friday-cycle seeding vs
    Bar_panels' upfront load) that have nothing to do with the readers
    themselves. *)

open OUnit2
open Core
open Matchers
module Bar_panels = Data_panel.Bar_panels
module Bar_reader = Weinstein_strategy.Bar_reader
module Symbol_index = Data_panel.Symbol_index
module Ohlcv_panels = Data_panel.Ohlcv_panels

(* ------------------------------------------------------------------ *)
(* Synthetic bar fixtures                                                *)
(* ------------------------------------------------------------------ *)

(** Build [n] consecutive weekday bars starting at [start_date] with
    deterministic price progression. *)
let _make_bars ~start_date ~n ~start_price =
  let rec weekdays d acc count =
    if count = 0 then List.rev acc
    else
      let next = Date.add_days d 1 in
      match Date.day_of_week d with
      | Day_of_week.Sat | Day_of_week.Sun -> weekdays next acc count
      | _ -> weekdays next (d :: acc) (count - 1)
  in
  let dates = weekdays start_date [] n in
  List.mapi dates ~f:(fun i date ->
      let price = start_price +. (Float.of_int i *. 0.5) in
      {
        Types.Daily_price.date;
        open_price = price;
        high_price = price *. 1.01;
        low_price = price *. 0.99;
        close_price = price;
        adjusted_close = price;
        volume = 1_000_000;
      })

(** Calendar matching the bars' dates, in chronological order. *)
let _calendar_of bars =
  bars |> List.map ~f:(fun b -> b.Types.Daily_price.date) |> Array.of_list

(* ------------------------------------------------------------------ *)
(* Build the two backends                                                *)
(* ------------------------------------------------------------------ *)

let _build_bar_history ~symbols_with_bars =
  let h = Weinstein_strategy.Bar_history.create () in
  List.iter symbols_with_bars ~f:(fun (symbol, bars) ->
      Weinstein_strategy.Bar_history.seed h ~symbol ~bars);
  h

let _build_bar_panels ~symbols_with_bars ~calendar =
  let universe = List.map symbols_with_bars ~f:fst in
  let symbol_index =
    match Symbol_index.create ~universe with
    | Ok t -> t
    | Error err -> failwith ("Symbol_index.create: " ^ err.Status.message)
  in
  let n_days = Array.length calendar in
  let ohlcv = Ohlcv_panels.create symbol_index ~n_days in
  let calendar_idx = Hashtbl.create (module Date) in
  Array.iteri calendar ~f:(fun i d ->
      Hashtbl.add calendar_idx ~key:d ~data:i
      |> (ignore : [ `Ok | `Duplicate ] -> unit));
  List.iter symbols_with_bars ~f:(fun (symbol, bars) ->
      match Symbol_index.to_row symbol_index symbol with
      | None -> ()
      | Some row ->
          List.iter bars ~f:(fun (bar : Types.Daily_price.t) ->
              match Hashtbl.find calendar_idx bar.date with
              | None -> ()
              | Some day ->
                  Ohlcv_panels.write_row ohlcv ~symbol_index:row ~day bar));
  match Bar_panels.create ~ohlcv ~calendar with
  | Ok p -> p
  | Error err -> failwith ("Bar_panels.create: " ^ err.Status.message)

(* ------------------------------------------------------------------ *)
(* Daily / weekly bar parity                                             *)
(* ------------------------------------------------------------------ *)

(** Equality predicate over [Daily_price.t list] — the matcher tree's structural
    [equal_to] would work but produces an opaque error on mismatch. *)
let _bars_equal (a : Types.Daily_price.t list) (b : Types.Daily_price.t list) =
  List.equal
    (fun (x : Types.Daily_price.t) (y : Types.Daily_price.t) ->
      Date.equal x.date y.date
      && Float.equal x.open_price y.open_price
      && Float.equal x.high_price y.high_price
      && Float.equal x.low_price y.low_price
      && Float.equal x.close_price y.close_price
      && Int.equal x.volume y.volume
      && Float.equal x.adjusted_close y.adjusted_close)
    a b

let test_daily_bars_for_parity _ =
  let start = Date.of_string "2024-01-01" in
  let bars = _make_bars ~start_date:start ~n:30 ~start_price:100.0 in
  let symbols_with_bars = [ ("AAPL", bars) ] in
  let calendar = _calendar_of bars in
  let history = _build_bar_history ~symbols_with_bars in
  let panels = _build_bar_panels ~symbols_with_bars ~calendar in
  let history_reader = Bar_reader.of_history history in
  let panels_reader = Bar_reader.of_panels panels in
  let as_of = (List.last_exn bars).date in
  let history_bars =
    Bar_reader.daily_bars_for history_reader ~symbol:"AAPL" ~as_of
  in
  let panels_bars =
    Bar_reader.daily_bars_for panels_reader ~symbol:"AAPL" ~as_of
  in
  assert_that (_bars_equal history_bars panels_bars) (equal_to true);
  assert_that (List.length history_bars) (equal_to 30)

let test_weekly_bars_for_parity _ =
  (* 250 daily bars (~50 weeks) so weekly aggregation produces a meaningful
     series. *)
  let start = Date.of_string "2024-01-01" in
  let bars = _make_bars ~start_date:start ~n:250 ~start_price:100.0 in
  let symbols_with_bars = [ ("AAPL", bars) ] in
  let calendar = _calendar_of bars in
  let history = _build_bar_history ~symbols_with_bars in
  let panels = _build_bar_panels ~symbols_with_bars ~calendar in
  let history_reader = Bar_reader.of_history history in
  let panels_reader = Bar_reader.of_panels panels in
  let as_of = (List.last_exn bars).date in
  let history_weekly =
    Bar_reader.weekly_bars_for history_reader ~symbol:"AAPL" ~n:52 ~as_of
  in
  let panels_weekly =
    Bar_reader.weekly_bars_for panels_reader ~symbol:"AAPL" ~n:52 ~as_of
  in
  assert_that (_bars_equal history_weekly panels_weekly) (equal_to true);
  assert_that (List.length history_weekly) (gt (module Int_ord) 30)

let test_unknown_symbol_returns_empty _ =
  let start = Date.of_string "2024-01-01" in
  let bars = _make_bars ~start_date:start ~n:30 ~start_price:100.0 in
  let symbols_with_bars = [ ("AAPL", bars) ] in
  let calendar = _calendar_of bars in
  let history = _build_bar_history ~symbols_with_bars in
  let panels = _build_bar_panels ~symbols_with_bars ~calendar in
  let history_reader = Bar_reader.of_history history in
  let panels_reader = Bar_reader.of_panels panels in
  let as_of = (List.last_exn bars).date in
  let history_bars =
    Bar_reader.daily_bars_for history_reader ~symbol:"UNKNOWN" ~as_of
  in
  let panels_bars =
    Bar_reader.daily_bars_for panels_reader ~symbol:"UNKNOWN" ~as_of
  in
  assert_that history_bars is_empty;
  assert_that panels_bars is_empty

let test_as_of_truncation_panels _ =
  (* Bar_panels respects [as_of_day] — bars after [as_of] should not appear.
     Bar_history doesn't filter by [as_of] (returns all accumulated bars), so
     this divergence is structural — the panels backend is more conservative.
     The strategy uses [as_of] = today's primary-index date, so the contracts
     converge at the call site. *)
  let start = Date.of_string "2024-01-01" in
  let bars = _make_bars ~start_date:start ~n:30 ~start_price:100.0 in
  let calendar = _calendar_of bars in
  let panels =
    _build_bar_panels ~symbols_with_bars:[ ("AAPL", bars) ] ~calendar
  in
  let panels_reader = Bar_reader.of_panels panels in
  let mid_as_of = (List.nth_exn bars 14).date in
  let truncated =
    Bar_reader.daily_bars_for panels_reader ~symbol:"AAPL" ~as_of:mid_as_of
  in
  assert_that (List.length truncated) (equal_to 15)

let test_out_of_calendar_as_of_returns_empty _ =
  (* Date not in the panel calendar → the panels reader returns empty.
     This handles the simulator's edge cases (e.g. weekends, holidays
     between calendar boundaries) gracefully without raising. *)
  let start = Date.of_string "2024-01-01" in
  let bars = _make_bars ~start_date:start ~n:30 ~start_price:100.0 in
  let calendar = _calendar_of bars in
  let panels =
    _build_bar_panels ~symbols_with_bars:[ ("AAPL", bars) ] ~calendar
  in
  let panels_reader = Bar_reader.of_panels panels in
  let outside = Date.of_string "2025-06-01" in
  let result =
    Bar_reader.daily_bars_for panels_reader ~symbol:"AAPL" ~as_of:outside
  in
  assert_that result is_empty

(* ------------------------------------------------------------------ *)
(* Suite                                                                 *)
(* ------------------------------------------------------------------ *)

let () =
  run_test_tt_main
    ("bar_reader_parity"
    >::: [
           "daily_bars_for parity (history vs panels)"
           >:: test_daily_bars_for_parity;
           "weekly_bars_for parity (history vs panels)"
           >:: test_weekly_bars_for_parity;
           "unknown symbol returns empty in both backends"
           >:: test_unknown_symbol_returns_empty;
           "panels backend truncates at as_of" >:: test_as_of_truncation_panels;
           "panels backend tolerates out-of-calendar as_of"
           >:: test_out_of_calendar_as_of_returns_empty;
         ])
