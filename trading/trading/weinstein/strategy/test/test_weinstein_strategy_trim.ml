(** Tests for the rolling-window trim wired into [Weinstein_strategy] in PR 3 of
    [dev/plans/bar-history-trim-2026-04-24.md].

    The trim ([Bar_history.trim_before], landed in #525) caps each per-symbol
    daily-bar buffer at [config.bar_history_max_lookback_days] calendar days
    relative to the simulated date. It runs once per [on_market_close], after
    [Bar_history.accumulate] (so today's bar is retained) and before any reader
    (so they observe the trimmed state).

    What this file pins:

    - {b Bound} — after a 2-year synthetic backtest with [Some 365], every
      symbol's daily-bar buffer holds <= 366 entries (trimmed). Without the trim
      a daily-cadence run accumulates ~520 entries.
    - {b Sentinel safety} — when [get_price] returns [None] for the primary
      index on a sim day (weekend / holiday), the strategy's
      [Date.today]-fallback path must NOT trim; otherwise the real-world date
      would be used as [as_of] and every bar in the buffer would be dropped.

    Bit-identical parity assertions for the trim ([Some 365] vs unset baseline)
    live in [test_runner_hypothesis_overrides.ml] alongside the other C1
    hypothesis-toggle field tests; the Tiered/Legacy parity assertion under
    [Some 365] lives in [test_tiered_loader_parity.ml]. *)

open OUnit2
open Core
open Matchers

let run_deferred d = Async.Thread_safe.block_on_async_exn (fun () -> d)
let date_of_string s = Date.of_string s
let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Generate bars for every symbol in [syn_config] and write them to [data_dir]
    as CSV files. Mirrors the helper in [test_weinstein_strategy_smoke.ml] —
    duplicated rather than extracted because the smoke test file is already at
    its size budget. *)
let write_synthetic_bars data_dir (syn_config : Synthetic_source.config) =
  let ds = Synthetic_source.make syn_config in
  let module DS = (val ds : Data_source.DATA_SOURCE) in
  List.iter syn_config.symbols ~f:(fun (symbol, _) ->
      let query : Data_source.bar_query =
        {
          symbol;
          period = Types.Cadence.Daily;
          start_date = Some syn_config.start_date;
          end_date = None;
        }
      in
      let bars =
        match run_deferred (DS.get_bars ~query ()) with
        | Ok b -> b
        | Error e -> OUnit2.assert_failure ("get_bars failed: " ^ Status.show e)
      in
      match Csv.Csv_storage.create ~data_dir:(Fpath.v data_dir) symbol with
      | Error e -> OUnit2.assert_failure ("csv create: " ^ Status.show e)
      | Ok storage -> (
          match Csv.Csv_storage.save storage ~override:true bars with
          | Error e -> OUnit2.assert_failure ("csv save: " ^ Status.show e)
          | Ok () -> ()))

(* -------------------------------------------------------------------- *)
(* Helpers — sim setup                                                   *)
(* -------------------------------------------------------------------- *)

let _trending price gain volume : Synthetic_source.symbol_pattern =
  Trending { start_price = price; weekly_gain_pct = gain; volume }

(** Build a simulator that exposes the strategy's internal [Bar_history.t] via a
    caller-supplied buffer. Returns [(simulator, bar_history)]. *)
let _build_sim ~data_dir ~start_date ~end_date ~lookback ~symbols =
  let bar_history = Weinstein_strategy.Bar_history.create () in
  let base_config =
    Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"
  in
  let config = { base_config with bar_history_max_lookback_days = lookback } in
  let strategy = Weinstein_strategy.make ~bar_history config in
  let deps =
    Trading_simulation.Simulator.create_deps ~symbols
      ~data_dir:(Fpath.v data_dir) ~strategy ~commission:sample_commission ()
  in
  let sim_config =
    Trading_simulation.Simulator.
      {
        start_date;
        end_date;
        initial_cash = 100_000.0;
        commission = sample_commission;
        strategy_cadence = Types.Cadence.Daily;
      }
  in
  let sim =
    match Trading_simulation.Simulator.create ~config:sim_config ~deps with
    | Ok s -> s
    | Error e -> OUnit2.assert_failure ("create failed: " ^ Status.show e)
  in
  (sim, bar_history)

let _run_or_fail sim =
  match Trading_simulation.Simulator.run sim with
  | Ok r -> r
  | Error e -> OUnit2.assert_failure ("run failed: " ^ Status.show e)

(* -------------------------------------------------------------------- *)
(* Test 1: trim caps daily-bar buffer length                             *)
(* -------------------------------------------------------------------- *)

(** With [Some 365], after a 2-year synthetic backtest, the AAPL daily-bar
    buffer must hold <= 366 entries. The exact count depends on the trading
    calendar (weekends + holidays + the trim's idempotency boundary), so we pin
    only the upper bound — a 365-day calendar window can hold at most 366
    entries (one for each of [as_of - 365 .. as_of] inclusive, if every day were
    a trading day).

    Without the trim, the same backtest accumulates ~520 entries (5 trading
    days/week * 52 weeks * 2 years), so a [<= 366] bound is comfortably distinct
    from the no-trim case. *)
let test_trim_some_365_bounds_daily_buffer _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_trim_bounds" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      (* hist_start two years before sim_start so the synthetic source's
         3-year ceiling (Synthetic_source._max_gen_bars = 252 * 3) covers
         the full sim window with bars to spare. *)
      let hist_start = date_of_string "2022-01-01" in
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = hist_start;
            symbols =
              [
                ("AAPL", _trending 180.0 0.005 50_000_000);
                ("GSPCX", _trending 4500.0 0.005 1_000_000_000);
              ];
          };
      let sim, bar_history =
        _build_sim ~data_dir
          ~start_date:(date_of_string "2023-01-02")
          ~end_date:(date_of_string "2024-12-31")
          ~lookback:(Some 365) ~symbols:[ "AAPL"; "GSPCX" ]
      in
      let _result = _run_or_fail sim in
      let aapl_bars =
        Weinstein_strategy.Bar_history.daily_bars_for bar_history ~symbol:"AAPL"
      in
      assert_that (List.length aapl_bars) (le (module Int_ord) 366))

(** Companion to the bound test: with [None] (the default), no trim runs and the
    same scenario accumulates substantially more bars (every trading day in the
    2-year window). Asserts a strict lower bound that is impossible under
    [Some 365] so the difference is observable.

    Two trading years span ~520 weekdays minus ~10-15 US holidays per year =
    ~490 entries. We pin [> 400] to leave wide margin against calendar quirks
    while still being clearly above the trimmed cap of 366. *)
let test_no_trim_accumulates_full_history _ =
  let data_dir = Core_unix.mkdtemp "/tmp/test_weinstein_trim_none" in
  Fun.protect
    ~finally:(fun () ->
      let _ = Core_unix.system (Printf.sprintf "rm -rf %s" data_dir) in
      ())
    (fun () ->
      let hist_start = date_of_string "2022-01-01" in
      write_synthetic_bars data_dir
        Synthetic_source.
          {
            start_date = hist_start;
            symbols =
              [
                ("AAPL", _trending 180.0 0.005 50_000_000);
                ("GSPCX", _trending 4500.0 0.005 1_000_000_000);
              ];
          };
      let sim, bar_history =
        _build_sim ~data_dir
          ~start_date:(date_of_string "2023-01-02")
          ~end_date:(date_of_string "2024-12-31")
          ~lookback:None ~symbols:[ "AAPL"; "GSPCX" ]
      in
      let _result = _run_or_fail sim in
      let aapl_bars =
        Weinstein_strategy.Bar_history.daily_bars_for bar_history ~symbol:"AAPL"
      in
      assert_that (List.length aapl_bars) (gt (module Int_ord) 400))

(* -------------------------------------------------------------------- *)
(* Test 2: missing-primary-index sim day must NOT trim                   *)
(* -------------------------------------------------------------------- *)

(** Sentinel safety: if a sim day has no bar for the primary index (weekend,
    holiday, or missing data), the strategy's existing [Date.today] fallback for
    [current_date] would corrupt the trim's [as_of]. The wiring in PR 3 handles
    this by skipping the trim on those days — confirmed by checking that a
    buffer survives a strategy invocation where the primary index is absent.

    We exercise this by calling [on_market_close] directly with a [get_price]
    that returns [None] for the primary index but a valid bar for an entry
    universe symbol. Pre-state: 100 bars seeded into the buffer, all dated well
    within [Some 365]'s window. Post-state: the buffer must still hold 100 bars
    (no trim happened). *)
let test_missing_primary_index_skips_trim _ =
  let bar_history = Weinstein_strategy.Bar_history.create () in
  let base_date = date_of_string "2024-01-01" in
  let make_bar offset price : Types.Daily_price.t =
    {
      date = Date.add_days base_date offset;
      open_price = price;
      high_price = price +. 1.0;
      low_price = price -. 1.0;
      close_price = price;
      volume = 1_000;
      adjusted_close = price;
    }
  in
  let aapl_bars = List.init 100 ~f:(fun i -> make_bar i 100.0) in
  Weinstein_strategy.Bar_history.seed bar_history ~symbol:"AAPL" ~bars:aapl_bars;
  let config =
    {
      (Weinstein_strategy.default_config ~universe:[ "AAPL" ]
         ~index_symbol:"GSPCX")
      with
      bar_history_max_lookback_days = Some 365;
    }
  in
  let strategy = Weinstein_strategy.make ~bar_history config in
  let module S = (val strategy : Trading_strategy.Strategy_interface.STRATEGY)
  in
  (* get_price: AAPL has a recent bar, GSPCX (the primary index) is absent.
     [Bar_history.accumulate] therefore appends only AAPL's bar; the primary
     index lookup downstream returns None and the trim must skip. *)
  let get_price symbol =
    if String.equal symbol "AAPL" then Some (make_bar 200 100.0) else None
  in
  let portfolio_view : Trading_strategy.Portfolio_view.t =
    { cash = 100_000.0; positions = String.Map.empty }
  in
  let get_indicator _ _ _ _ = None in
  let _ =
    S.on_market_close ~get_price ~get_indicator ~portfolio:portfolio_view
  in
  let post =
    Weinstein_strategy.Bar_history.daily_bars_for bar_history ~symbol:"AAPL"
  in
  (* Pre-call: 100 bars seeded. accumulate appends 1 (the new AAPL bar at
     offset 200). Trim must NOT run, so post-call has 101 bars — none
     dropped despite the buffer's earliest bar (offset 0) being only 200
     days old, which under [Some 365] would be safe anyway, but the contract
     is "no trim when primary index is absent". *)
  assert_that (List.length post) (equal_to 101)

(* -------------------------------------------------------------------- *)
(* Suite                                                                 *)
(* -------------------------------------------------------------------- *)

let suite =
  "weinstein_strategy_trim"
  >::: [
         "Some 365 caps AAPL daily-bar buffer at <= 366 after 2yr backtest"
         >:: test_trim_some_365_bounds_daily_buffer;
         "None accumulates >400 bars over the same 2yr backtest"
         >:: test_no_trim_accumulates_full_history;
         "primary-index-absent sim day does not trigger trim"
         >:: test_missing_primary_index_skips_trim;
       ]

let () = run_test_tt_main suite
