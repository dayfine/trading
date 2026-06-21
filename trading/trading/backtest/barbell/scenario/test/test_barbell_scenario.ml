(** Integration test for {!Barbell_scenario}: the end-to-end barbell-overlay
    call-site wiring.

    Runs both sleeves end-to-end on the committed 7-symbol parity fixture
    ([smoke/tiered-loader-parity.sexp], H2-2019, the fastest scenario in the
    catalog) via two real {!Backtest.Runner.run_backtest} runs, then blends them
    through {!Barbell_scenario.run}. The legs are deliberately distinct so the
    blend is exercised on two different curves:
    - ENGINE leg — the full {!Backtest.Strategy_choice.Weinstein} engine;
    - FLOOR leg — a {!Backtest.Strategy_choice.Bah_benchmark} on [AAPL] (a
      symbol present in the parity universe), which buys day 1 and holds. Using
      BAH rather than [Spy_only_weinstein] keeps the fixture self-contained (no
      SPY bars are in the 7-symbol parity universe).

    The pure blend math itself is already pinned bit-exactly against [blend.awk]
    in [test_barbell_blend]; this test only pins the {b wiring} contract: that
    [run] actually forces two real backtests, projects each into an equity
    curve, and hands them to the blend core to produce a combined NAV.

    Each leg run takes a few seconds, so this lives in its own test target
    rather than the fast pure-blend suite. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Fixtures_root = Scenario_lib.Fixtures_root

let _fixtures_root () = Fixtures_root.resolve ()

let _load_parity_scenario () =
  let path =
    Filename.concat (_fixtures_root ()) "smoke/tiered-loader-parity.sexp"
  in
  Scenario.load path

(* Run the overlay end-to-end on the parity fixture at a given floor weight. The
   ENGINE leg is the default Weinstein engine; the FLOOR leg is a BAH on AAPL
   (present in the parity universe). CSV mode (no snapshot dir). *)
let _run_overlay ~floor_weight =
  let scenario = _load_parity_scenario () in
  let config =
    { Barbell.Barbell_config.enable = true; floor_weight; rebalance_weeks = 1 }
  in
  let floor =
    {
      Barbell_scenario.name = "floor";
      strategy = Backtest.Strategy_choice.Bah_benchmark { symbol = "AAPL" };
      overrides = [];
    }
  in
  let engine = Barbell_scenario.engine_leg () in
  Barbell_scenario.run ~scenario ~fixtures_root:(_fixtures_root ())
    ~bar_data_source:None ~config ~floor ~engine

(* Terminal (last) normalised NAV of a leg's equity curve, normalised the same
   way the blend core does (divide by the first value). Lets the test assert the
   blended terminal NAV lies between the two legs without re-deriving blend.awk's
   per-step compounding — for a degenerate (no-rebalance-needed within tolerance)
   blend the combined terminal sits between the two legs' terminal NAVs. *)
let _terminal_normalised_nav (curve : (Date.t * float) list) =
  match curve with
  | [] -> Float.nan
  | (_, first) :: _ ->
      let _, last = List.last_exn curve in
      last /. first

let test_run_produces_blended_curve _ =
  let result = _run_overlay ~floor_weight:0.5 in
  (* Both legs ran and produced a non-empty equity curve. *)
  assert_that result.floor.equity_curve
    (field List.length (gt (module Int_ord) 0));
  assert_that result.engine.equity_curve
    (field List.length (gt (module Int_ord) 0));
  (* The combined blended NAV is non-empty and starts normalised at 1.0. *)
  assert_that result.blend.nav_curve (field List.length (gt (module Int_ord) 0));
  assert_that (snd (List.hd_exn result.blend.nav_curve)) (float_equal 1.0)

let test_blended_terminal_between_legs _ =
  let result = _run_overlay ~floor_weight:0.5 in
  let floor_terminal = _terminal_normalised_nav result.floor.equity_curve in
  let engine_terminal = _terminal_normalised_nav result.engine.equity_curve in
  let blend_terminal = _terminal_normalised_nav result.blend.nav_curve in
  let low = Float.min floor_terminal engine_terminal in
  let high = Float.max floor_terminal engine_terminal in
  (* A 50/50 blend's terminal NAV must sit within the two legs' terminal NAVs
     (small epsilon for the daily-compounding vs terminal-ratio difference). *)
  assert_that blend_terminal
    (is_between (module Float_ord) ~low:(low -. 1e-6) ~high:(high +. 1e-6))

let test_zero_weight_is_pure_engine _ =
  (* floor_weight = 0.0 is the no-op: the blend short-circuits to the engine
     leg's own (normalised) curve, so the wiring reproduces a pure-engine run. *)
  let result = _run_overlay ~floor_weight:0.0 in
  let engine_terminal = _terminal_normalised_nav result.engine.equity_curve in
  let blend_terminal = _terminal_normalised_nav result.blend.nav_curve in
  assert_that blend_terminal (float_equal ~epsilon:1e-9 engine_terminal)

let suite =
  "barbell_scenario"
  >::: [
         "run_produces_blended_curve" >:: test_run_produces_blended_curve;
         "blended_terminal_between_legs" >:: test_blended_terminal_between_legs;
         "zero_weight_is_pure_engine" >:: test_zero_weight_is_pure_engine;
       ]

let () = run_test_tt_main suite
