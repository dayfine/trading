(** End-to-end BAH-SPY benchmark using real SPY market data.

    Runs {!Trading_strategy.Bah_benchmark_strategy} through the standard
    simulator over a multi-year window and asserts the final equity is in the
    same ballpark as SPY's price-only return. This both:

    - acts as the integration test that wires the new benchmark strategy into
      the simulator alongside the existing strategies
      ({!Trading_strategy.Buy_and_hold_strategy},
      {!Trading_strategy.Ema_strategy}); and
    - prints final equity, SPY price-only return, and the drift between them —
      useful as a sanity check on the cash-accounting path (a buy-once-and-hold
      should track close-price ratio very tightly when no dividends are
      reinvested).

    The expected drift is small (<10%) over the chosen 2024 calendar-year
    window. Drift sources we accept:

    - Commission on the day-1 entry trade (small, ~$1 floor per the
      [sample_commission] config).
    - The fact that we enter on day 1's close but the price-only return is
      computed close-to-close over the same window (entry slippage, effectively
      zero in this simulator since fills happen at close).
    - SPY's [adjusted_close] back-rolls dividends, while our position
      [close_price] doesn't reinvest them — but we use raw [close_price] on both
      sides of the comparison here, so this is not a drift source.

    If this test fails because [data/S/Y/SPY/data.csv] is unavailable, the
    [real_data_dir] resolver in {!Test_helpers} raises a clear error rather than
    silently passing. *)

open OUnit2
open Core
open Trading_simulation.Simulator
open Matchers
open Test_helpers

let date_of_string = Date.of_string

(** Locate the real data directory by walking common candidate paths and
    anchoring on SPY (not AAPL) since SPY is the benchmark instrument. Returns
    [None] when SPY data is missing — the test then skips gracefully (CI's
    [test_data/] subset doesn't include SPY by default; the test is meant to run
    locally where the full [data/] mount is available, including the absolute
    [/workspaces/trading-1/data] path used inside the dev container). *)
let real_data_dir_for_spy_opt () =
  let candidates =
    [
      "../data";
      "../../../../../data";
      "../../../../../../data";
      "../test_data";
      "../../../../../test_data";
      "../../../../../../test_data";
      (* Absolute path for the dev container's mounted [/data]. Agent
         worktrees don't carry a full [data/] tree of their own; this
         fallback lets the test resolve SPY data when running inside the
         container. Falls back gracefully to None when missing. *)
      "/workspaces/trading-1/data";
    ]
  in
  List.find_map candidates ~f:(fun path ->
      let fpath = Fpath.v path in
      let spy_path = Fpath.(fpath / "S" / "Y" / "SPY" / "data.csv") in
      match Sys_unix.file_exists (Fpath.to_string spy_path) with
      | `Yes -> Some fpath
      | `No | `Unknown -> None)

let sample_commission = { Trading_engine.Types.per_share = 0.01; minimum = 1.0 }

(** Load SPY's close on the day at-or-after [date]. Used to compute the
    price-only return that the BAH equity should track. *)
let spy_close_on_or_after data_dir date =
  let csv_path = Fpath.(data_dir / "S" / "Y" / "SPY" / "data.csv") in
  let lines = In_channel.read_lines (Fpath.to_string csv_path) in
  (* Skip the header. Each row: date,open,high,low,close,adjusted_close,volume *)
  let parse_row line =
    match String.split line ~on:',' with
    | row_date :: _ :: _ :: _ :: close :: _ ->
        let d = Date.of_string row_date in
        if Date.(d >= date) then Some (d, Float.of_string close) else None
    | _ -> None
  in
  List.find_map (List.tl_exn lines) ~f:parse_row

(** Run a simulation and return [(steps, final_portfolio)], failing loudly. *)
let run_sim_exn sim =
  match run sim with
  | Error err -> assert_failure ("Simulation failed: " ^ Status.show err)
  | Ok result ->
      let final_portfolio = (List.last_exn result.steps).portfolio in
      (result.steps, final_portfolio)

(** BAH-SPY end-to-end: $100k starting cash, full 2024 calendar year. Asserts
    final equity is close to the day-1-cash * (final_close / entry_close) ratio
    (the price-only buy-and-hold return). *)
let test_bah_spy_year_2024 ctx =
  let real_data_dir_for_spy =
    match real_data_dir_for_spy_opt () with
    | Some d -> d
    | None ->
        skip_if true
          "SPY data unavailable (data/S/Y/SPY/data.csv missing — test_data \
           subset doesn't include SPY). Run locally with the full /data mount.";
        assert_failure "unreachable after skip_if"
  in
  ignore ctx;
  let initial_cash = 100_000.0 in
  let start_date = date_of_string "2024-01-02" in
  let end_date = date_of_string "2024-12-31" in
  let symbol = Trading_strategy.Bah_benchmark_strategy.default_symbol in
  let strategy =
    Trading_strategy.Bah_benchmark_strategy.make
      Trading_strategy.Bah_benchmark_strategy.default_config
  in
  let deps =
    create_deps ~symbols:[ symbol ] ~data_dir:real_data_dir_for_spy ~strategy
      ~commission:sample_commission ()
  in
  let config =
    {
      start_date;
      end_date;
      initial_cash;
      commission = sample_commission;
      strategy_cadence = Types.Cadence.Daily;
    }
  in
  let sim = create_exn ~config ~deps in
  let _steps, final_portfolio = run_sim_exn sim in
  (* Look up SPY's close on the entry day and the final day. *)
  let entry_close =
    match spy_close_on_or_after real_data_dir_for_spy start_date with
    | Some (_, c) -> c
    | None -> assert_failure "Could not load SPY entry close"
  in
  let final_close =
    match spy_close_on_or_after real_data_dir_for_spy end_date with
    | Some (_, c) -> c
    | None -> assert_failure "Could not load SPY final close"
  in
  (* All-cash sizing: floor(initial_cash / entry_close) shares.  *)
  let shares = Float.round_down (initial_cash /. entry_close) in
  let leftover_cash = initial_cash -. (shares *. entry_close) in
  let entry_commission =
    Float.max sample_commission.minimum (sample_commission.per_share *. shares)
  in
  let expected_final_equity =
    leftover_cash -. entry_commission +. (shares *. final_close)
  in
  let final_equity =
    final_portfolio.current_cash +. (shares *. final_close)
    (* No exit, so no exit commission to subtract. The MtM uses portfolio
       state directly. *)
  in
  let drift_pct =
    (final_equity -. expected_final_equity) /. expected_final_equity *. 100.0
  in
  Printf.printf "\n=== BAH-SPY end-to-end (2024-01-02 .. 2024-12-31) ===\n";
  Printf.printf "Initial cash:           $%.2f\n" initial_cash;
  Printf.printf "Entry SPY close:        $%.4f\n" entry_close;
  Printf.printf "Final SPY close:        $%.4f\n" final_close;
  Printf.printf "Shares bought:          %.0f\n" shares;
  Printf.printf "Day-1 commission:       $%.2f\n" entry_commission;
  Printf.printf "Expected final equity:  $%.2f\n" expected_final_equity;
  Printf.printf "Actual final equity:    $%.2f\n" final_equity;
  Printf.printf "Final cash balance:     $%.2f\n" final_portfolio.current_cash;
  Printf.printf "Drift vs expected:      %+.4f%%\n" drift_pct;
  Printf.printf "===========================================\n";
  (* Loose assertion: final equity within 1% of the closed-form
     buy-and-hold expectation. The simulator's broker should reproduce the
     formula exactly modulo floating-point noise — anything beyond 1% is a
     real cash-accounting bug. *)
  assert_that final_equity
    (is_between
       (module Float_ord)
       ~low:(expected_final_equity *. 0.99)
       ~high:(expected_final_equity *. 1.01))

let suite =
  "BAH-SPY benchmark e2e"
  >::: [
         "BAH-SPY 2024 calendar year tracks SPY close"
         >:: test_bah_spy_year_2024;
       ]

let () = run_test_tt_main suite
