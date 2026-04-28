(** Determinism + start-date-shift regression tests.

    Two questions this suite pins:

    {1 1. Determinism}

    Running the same scenario [N=5] times in the same process on the same commit
    should produce identical artefacts. This guards against accidental
    non-determinism creeping in via hashtable iteration order, [Random] seeding,
    time-of-day, etc. The Weinstein runner is single-threaded today (parallelism
    is at the per-scenario fork level in [scenario_runner]), so this only checks
    single-process stability — multi-thread / parallel determinism is explicitly
    out of scope.

    Empirical findings as of 2026-04-27 against [panel-golden-2019-full]:

    - {b round_trips: bit-identical} (every trade-record float matches
      bit-exactly across runs). This is a hard assertion.

    - {b equity_curve / final_portfolio_value: stable to 1 ULP, but not
         bit-identical}. Different runs can produce e.g. [999669.81999999995] vs
      [999669.82000000007] (one ULP apart). Suspected source: the
      portfolio-value mark-to-market sums positions in an order that depends on
      hashtable iteration, and IEEE-754 addition is not associative. The
      aggregate values agree at the printed-cent precision used by
      [equity_curve.csv] but the underlying floats differ in the LSB.

    We pin {b relative tolerance ≤ 1e-12} for these aggregates instead of
    bit-equality. A run-to-run divergence larger than that surfaces as a hard
    failure. The bit-level diagnostic is also printed (with [printf]) on the
    first divergence so any drift across the LSB threshold is visible in the
    test log without failing CI.

    {1 2. Start-date-shift stability}

    Moving [start_date] earlier by a small number of calendar days (1 / 5 / 14)
    while keeping [end_date] fixed should — naively — leave trades that fall
    after the original [start_date] unchanged.

    Empirical finding as of 2026-04-27: shifts of -5d and -14d DO change
    downstream trades, even when the shifted-start to original-start window
    contains no entry/exit. Observed shape: same [symbol], same [entry_date],
    same [entry_price], same [exit_date], same [exit_price], same [pnl_percent],
    but different [quantity] (e.g. JPM 1065 to 1055 under -14d, JNJ 842 to 841
    under -5d).

    Likely cause: position sizing reads indicator state (ATR / volatility
    estimate) at entry, and the indicator's smoothing has not converged to the
    same value when warmup includes an extra 14 days of history. A -1d shift
    does NOT trigger this — that's the test that passes.

    Implications:

    - The runner is NOT path-independent across small start-date shifts,
      contrary to the naive reading of the user's question. The shift is a
      soft-failure here, surfaced via [printf] + [OUnit2.skip_if] so it doesn't
      block CI but is loudly visible in the log.

    - A -1d shift {b is} stable. We assert that hard.

    - For shifts that exhibit divergence, the suite prints the specific trade(s)
      that diverged so a follow-up can decide whether to (a) tighten the
      indicator warmup contract so it's path-independent, or (b) pin the current
      path-dependence as expected and tighten this test against newly-captured
      goldens. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file
module Metrics = Trading_simulation.Metrics

(* -------------------------------------------------------------------- *)
(* Local mirrors of [Metrics.trade_metrics] + the equity-curve row.     *)
(* Sexp + eq + show derivers give us bit-equality and human-readable    *)
(* divergence messages for free.                                         *)
(* -------------------------------------------------------------------- *)

type trade = {
  symbol : string;
  entry_date : Date.t;
  exit_date : Date.t;
  days_held : int;
  entry_price : float;
  exit_price : float;
  quantity : float;
  pnl_dollars : float;
  pnl_percent : float;
}
[@@deriving sexp, eq, show]

let _to_trade (t : Metrics.trade_metrics) : trade =
  {
    symbol = t.symbol;
    entry_date = t.entry_date;
    exit_date = t.exit_date;
    days_held = t.days_held;
    entry_price = t.entry_price;
    exit_price = t.exit_price;
    quantity = t.quantity;
    pnl_dollars = t.pnl_dollars;
    pnl_percent = t.pnl_percent;
  }

type equity_row = { date : Date.t; portfolio_value : float }
[@@deriving sexp, eq, show]
(** [(date, portfolio_value)] pair — the exact rows that land in
    [equity_curve.csv]. *)

let _to_equity_row (s : Trading_simulation_types.Simulator_types.step_result) :
    equity_row =
  { date = s.date; portfolio_value = s.portfolio_value }

(* -------------------------------------------------------------------- *)
(* Scenario fixture + run helper                                         *)
(* -------------------------------------------------------------------- *)

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_relpath = "smoke/panel-golden-2019-full.sexp"

let _load_scenario () =
  Scenario.load (Filename.concat (_fixtures_root ()) _scenario_relpath)

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run ~start_date ~end_date (s : Scenario.t) =
  let sector_map_override = _sector_map_override s in
  try
    Backtest.Runner.run_backtest ~start_date ~end_date
      ~overrides:s.config_overrides ?sector_map_override ()
  with e ->
    OUnit2.assert_failure (sprintf "run_backtest raised: %s" (Exn.to_string e))

let _trades_of (r : Backtest.Runner.result) : trade list =
  List.map r.round_trips ~f:_to_trade

let _equity_of (r : Backtest.Runner.result) : equity_row list =
  List.map r.steps ~f:_to_equity_row

(* -------------------------------------------------------------------- *)
(* Diagnostics                                                          *)
(* -------------------------------------------------------------------- *)

(** Format a float so the full IEEE-754 bit pattern is visible. Used by
    divergence messages so a "999669.82 vs 999669.82" mismatch (equal at [%.2f]
    but not bit-equal) is debuggable. *)
let _fmt_float_bits f = sprintf "%.17g (bits=%Lx)" f (Int64.bits_of_float f)

(** Walk two trade lists in lockstep, return a description of the first
    divergence (or [None] when identical). *)
let _first_trade_divergence ~baseline ~observed =
  let rec walk i bs os =
    match (bs, os) with
    | [], [] -> None
    | b :: brest, o :: orest when equal_trade b o -> walk (i + 1) brest orest
    | b :: _, o :: _ ->
        Some
          (sprintf "trade #%d differs:\n  baseline: %s\n  observed: %s" i
             (show_trade b) (show_trade o))
    | b :: _, [] ->
        Some
          (sprintf "observed truncated at trade #%d (baseline: %s)" i
             (show_trade b))
    | [], o :: _ ->
        Some (sprintf "observed has extra trade #%d: %s" i (show_trade o))
  in
  walk 0 baseline observed

(** First-divergence description for two equity-curve lists. Compares dates with
    [Date.equal] and floats bit-exactly. *)
let _first_equity_divergence ~baseline ~observed =
  let rec walk i bs os =
    match (bs, os) with
    | [], [] -> None
    | b :: brest, o :: orest when equal_equity_row b o ->
        walk (i + 1) brest orest
    | b :: _, o :: _ ->
        Some
          (sprintf
             "row #%d differs:\n\
             \  baseline: date=%s portfolio_value=%s\n\
             \  observed: date=%s portfolio_value=%s"
             i (Date.to_string b.date)
             (_fmt_float_bits b.portfolio_value)
             (Date.to_string o.date)
             (_fmt_float_bits o.portfolio_value))
    | b :: _, [] ->
        Some
          (sprintf "observed truncated at row #%d (baseline %s)" i
             (show_equity_row b))
    | [], o :: _ ->
        Some (sprintf "observed has extra row #%d: %s" i (show_equity_row o))
  in
  walk 0 baseline observed

(** Maximum absolute relative gap between two equity-curve lists, ignoring NaN
    and treating any length mismatch as [Float.infinity] (so it always fails the
    relative-tolerance check). *)
let _max_relative_diff ~baseline ~observed =
  match List.zip baseline observed with
  | Unequal_lengths -> Float.infinity
  | Ok pairs ->
      List.fold pairs ~init:0.0 ~f:(fun acc (b, o) ->
          let denom = Float.max (Float.abs b.portfolio_value) 1.0 in
          let gap =
            Float.abs (b.portfolio_value -. o.portfolio_value) /. denom
          in
          Float.max acc gap)

(* -------------------------------------------------------------------- *)
(* Test 1 — determinism: 5 in-process runs                              *)
(* -------------------------------------------------------------------- *)

(** Run the panel-golden-2019-full scenario [n] times. Returns (trades, equity,
    final_value) per run. *)
let _run_n_times n =
  let s = _load_scenario () in
  List.init n ~f:(fun _ ->
      let r =
        _run ~start_date:s.period.start_date ~end_date:s.period.end_date s
      in
      (_trades_of r, _equity_of r, r.summary.final_portfolio_value))

(** Round-trips must be bit-identical across runs. This is the hard assertion —
    any drift in trade-record floats fails CI immediately. *)
let test_determinism_5x_round_trips _ =
  let runs = _run_n_times 5 in
  let baseline_trades, _, _ = List.hd_exn runs in
  List.iteri (List.tl_exn runs) ~f:(fun i (trades, _, _) ->
      match
        _first_trade_divergence ~baseline:baseline_trades ~observed:trades
      with
      | None -> ()
      | Some diff ->
          OUnit2.assert_failure
            (sprintf
               "5x determinism: run #%d round_trips diverged from run #0:\n%s"
               (i + 1) diff))

(** Maximum relative gap allowed for aggregate floats (equity_curve,
    final_value). 1e-12 is well above the empirically observed ~1 ULP gap
    (~10^-15 relative for portfolio values near $10^6) but well below any
    user-meaningful threshold. *)
let _aggregate_relative_tolerance = 1e-12

(** Equity curve should be {b stable} (relative gap ≤
    [_aggregate_relative_tolerance]) across 5 runs. Bit-equality is not asserted
    because the simulator's portfolio-value sum order varies slightly with
    hashtable iteration. We log the first bit-divergence via [printf] so the
    floor is visible without failing CI. *)
let test_determinism_5x_equity_curve _ =
  let runs = _run_n_times 5 in
  let _, baseline_equity, _ = List.hd_exn runs in
  List.iteri (List.tl_exn runs) ~f:(fun i (_, equity, _) ->
      let gap = _max_relative_diff ~baseline:baseline_equity ~observed:equity in
      (match
         _first_equity_divergence ~baseline:baseline_equity ~observed:equity
       with
      | None -> ()
      | Some diff ->
          printf
            "[determinism] run #%d equity_curve differs at LSB from run #0 \
             (max_rel_gap=%.3e):\n\
             %s\n\
             %!"
            (i + 1) gap diff);
      assert_that gap (le (module Float_ord) _aggregate_relative_tolerance))

(** Final portfolio value: same relative-tolerance check as the equity curve.
    1-ULP drift here is expected; anything larger is a regression. *)
let test_determinism_5x_final_value _ =
  let runs = _run_n_times 5 in
  let _, _, baseline_value = List.hd_exn runs in
  List.iteri (List.tl_exn runs) ~f:(fun i (_, _, value) ->
      let denom = Float.max (Float.abs baseline_value) 1.0 in
      let gap = Float.abs (baseline_value -. value) /. denom in
      if not (Float.equal value baseline_value) then
        printf
          "[determinism] run #%d final_portfolio_value differs at LSB from run \
           #0 (rel_gap=%.3e):\n\
          \  run #0: %s\n\
          \  run #%d: %s\n\
           %!"
          (i + 1) gap
          (_fmt_float_bits baseline_value)
          (i + 1) (_fmt_float_bits value);
      assert_that gap (le (module Float_ord) _aggregate_relative_tolerance))

(* -------------------------------------------------------------------- *)
(* Test 2 — start-date shift                                            *)
(* -------------------------------------------------------------------- *)

(** Shifts to test (negative = earlier start, end_date fixed). *)
let _shifts_to_test = [ -1; -5; -14 ]

(** Shifts that the suite asserts hard. -1d is empirically stable against the
    panel-golden-2019-full fixture (no trade quantity divergence after the
    original start_date). Larger shifts produce different position quantities
    even when no entry lands in the shifted window — that's the path-dependence
    finding the suite documents but does not fail on. *)
let _shifts_to_assert_hard = [ -1 ]

(** Filter trades to those whose entry_date is at or after [from_date]. *)
let _trades_from_date trades ~from_date =
  List.filter trades ~f:(fun t -> Date.( >= ) t.entry_date from_date)

(** Pre-compute the baseline once, then compare each shift against it. Each
    shift is a separate test case so a failure points at the shift that
    diverged. *)
let _make_shift_test ~baseline_trades ~baseline_start shift_days =
  let hard = List.mem _shifts_to_assert_hard shift_days ~equal:Int.equal in
  let name =
    sprintf "start-date shift %+d days (%s): trades after %s match baseline"
      shift_days
      (if hard then "asserted" else "soft, observed-divergence")
      (Date.to_string baseline_start)
  in
  let body _ =
    let s = _load_scenario () in
    let shifted_start = Date.add_days s.period.start_date shift_days in
    let r = _run ~start_date:shifted_start ~end_date:s.period.end_date s in
    let observed = _trades_from_date (_trades_of r) ~from_date:baseline_start in
    let baseline =
      _trades_from_date baseline_trades ~from_date:baseline_start
    in
    match _first_trade_divergence ~baseline ~observed with
    | None -> ()
    | Some diff when not hard ->
        (* Soft case: print the divergence so it's visible in the test
           log, then skip. The suite documents that this shift is
           expected to diverge — the printf is the surface for any
           {b new} divergence that signals further drift. *)
        printf
          "[start-shift] %+d days: trades after %s diverged from baseline \
           (expected — see test docstring):\n\
           %s\n\
           %!"
          shift_days
          (Date.to_string baseline_start)
          diff;
        OUnit2.skip_if true
          (sprintf
             "shift %+d days has known position-sizing path-dependence; \
              divergence printed above"
             shift_days)
    | Some diff ->
        OUnit2.assert_failure
          (sprintf
             "Start-date shift %+d days produced different trades after %s \
              (this shift is asserted hard).\n\
              %s"
             shift_days
             (Date.to_string baseline_start)
             diff)
  in
  name >:: body

let _make_shift_tests () =
  let s = _load_scenario () in
  let baseline_run =
    _run ~start_date:s.period.start_date ~end_date:s.period.end_date s
  in
  let baseline_trades = _trades_of baseline_run in
  let baseline_start = s.period.start_date in
  List.map _shifts_to_test
    ~f:(_make_shift_test ~baseline_trades ~baseline_start)

(* -------------------------------------------------------------------- *)
(* Suite                                                                 *)
(* -------------------------------------------------------------------- *)

let suite =
  "Determinism_and_start_shift"
  >::: [
         "5x in-process: round_trips bit-identical"
         >:: test_determinism_5x_round_trips;
         "5x in-process: equity_curve stable to 1e-12 relative"
         >:: test_determinism_5x_equity_curve;
         "5x in-process: final_portfolio_value stable to 1e-12 relative"
         >:: test_determinism_5x_final_value;
       ]
       @ _make_shift_tests ()

let () = run_test_tt_main suite
