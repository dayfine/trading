(** Unit tests for the [Panel_runner.engine_costs_with_overlay] helper.

    Pins the rule that {!Backtest.Panel_runner.run} applies when resolving the
    effective [(commission, slippage_bps)] pair passed to the simulator:

    - [cost_model = None] → runner defaults flow through unchanged (byte-equal
      baseline contract).
    - [cost_model = Some cm] → {!Cost_model.to_engine_costs} fully replaces the
      runner default commission and the caller's [?slippage_bps].

    Open work item 1 in [dev/status/cost-model.md]. Follows
    [.claude/rules/test-patterns.md]. *)

open OUnit2
open Matchers
module CM = Backtest_cost_model.Cost_model

(* The runner-side default commission constant from [Backtest.Runner].
   Reproduced here so the test pins the resolved pair, not the source of
   the default. *)
let _runner_default_commission : Trading_engine.Types.commission_config =
  { per_share = 0.01; minimum = 1.0 }

let test_none_preserves_runner_defaults _ =
  (* When the scenario does not declare a [cost_model], the helper must
     return the runner's default commission verbatim and propagate the
     caller's [?slippage_bps] unchanged ([None] in this case → simulator
     uses its own slippage default, which is zero). Pins the byte-equal
     baseline contract: scenarios that pre-date the wiring see no
     behaviour change. *)
  let resolved =
    Backtest.Panel_runner.engine_costs_with_overlay
      ~default_commission:_runner_default_commission ()
  in
  assert_that resolved
    (all_of
       [
         field
           (fun ((c : Trading_engine.Types.commission_config), _) -> c)
           (equal_to
              ({ per_share = 0.01; minimum = 1.0 }
                : Trading_engine.Types.commission_config));
         field (fun (_, s) -> s) is_none;
       ])

let test_some_retail_default_overrides_runner_defaults _ =
  (* When the scenario declares [cost_model = Some retail_default], the
     helper must derive the engine's commission + slippage from
     [Cost_model.to_engine_costs]. Pin both fields explicitly:
     - [commission.per_share = 0.0] (retail flat-fee has no per-share
       component; the runner default's $0.01 is overridden).
     - [commission.minimum  = 0.0] (the cost-model overlay does not surface
       the engine's [minimum] floor; documented in [Cost_model.to_engine_costs]).
     - [slippage_bps        = Some 5] (rounded from
       [retail_default.bid_ask_spread_bps = 5.0]). *)
  let resolved =
    Backtest.Panel_runner.engine_costs_with_overlay
      ~default_commission:_runner_default_commission
      ~cost_model:CM.retail_default ()
  in
  assert_that resolved
    (all_of
       [
         field
           (fun ((c : Trading_engine.Types.commission_config), _) -> c)
           (equal_to
              ({ per_share = 0.0; minimum = 0.0 }
                : Trading_engine.Types.commission_config));
         field (fun (_, s) -> s) (is_some_and (equal_to 5));
       ])

let suite =
  "Panel_runner_cost_model"
  >::: [
         "cost_model=None preserves runner defaults"
         >:: test_none_preserves_runner_defaults;
         "cost_model=Some retail_default overrides commission + slippage"
         >:: test_some_retail_default_overrides_runner_defaults;
       ]

let () = run_test_tt_main suite
