(** Unit tests for {!Weinstein_strategy.stock_analysis_config_for} — the seam
    that threads [Weinstein_strategy.config.resistance_min_history_bars] into
    the per-screen [Stock_analysis.config] (R2-searchability follow-up to PR
    #1941).

    - default [0] → the built [Stock_analysis.config] is bit-identical to
      {!Stock_analysis.default_config} (experiment-flag-discipline R1), so every
      existing golden/baseline replays unchanged.
    - non-zero [520] → [resistance.min_history_bars] is set on the shared
      [Resistance.config] record; because {!Stock_analysis} reuses that same
      record for the short-side support mirror, the floor applies to both the
      resistance and support cascades automatically (no record divergence). *)

open OUnit2
open Matchers

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"

(** Default [resistance_min_history_bars = 0]: the built [Stock_analysis.config]
    is byte-identical to {!Stock_analysis.default_config} — the no-op path, so
    the resistance/support [Insufficient_history] floor is never engaged. *)
let test_default_builds_stock_analysis_default_config _ =
  let built =
    Weinstein_strategy.stock_analysis_config_for ~config:(_default_config ())
  in
  assert_that built (equal_to Stock_analysis.default_config)

(** Non-zero [resistance_min_history_bars = 520] sets exactly
    [resistance.min_history_bars]; every other resistance field keeps its
    default, so the built resistance config equals
    [{ Resistance.default_config with min_history_bars = 520 }]. *)
let test_override_sets_resistance_min_history_bars _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy.resistance_min_history_bars = 520;
    }
  in
  let built = Weinstein_strategy.stock_analysis_config_for ~config in
  assert_that built.resistance
    (equal_to
       ({ Resistance.default_config with min_history_bars = 520 }
         : Resistance.config))

(** The short-side support mapper reads [Stock_analysis.config.resistance] (the
    same record), so arming the floor applies to the support cascade too. Pin
    the shared-record contract directly on the built config. *)
let test_override_mirrors_into_support_via_shared_record _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy.resistance_min_history_bars = 520;
    }
  in
  let built = Weinstein_strategy.stock_analysis_config_for ~config in
  assert_that built.resistance.min_history_bars (equal_to 520)

let suite =
  "stock_analysis_config_wiring"
  >::: [
         "default builds Stock_analysis.default_config"
         >:: test_default_builds_stock_analysis_default_config;
         "override sets resistance.min_history_bars"
         >:: test_override_sets_resistance_min_history_bars;
         "override mirrors into support via shared record"
         >:: test_override_mirrors_into_support_via_shared_record;
       ]

let () = run_test_tt_main suite
