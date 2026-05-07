(** Wire-format regression for the [actual.sexp] file
    {!Scenario_runner._write_crashed_actual} writes when a scenario crashes in a
    child process (PR #911 follow-up).

    Background: PR #911 added a sentinel-write path so a child that crashes with
    an unhandled exception still emits [actual.sexp] — with sentinel metric
    values (-100% return, 100% drawdown, 0 trades) and two new fields
    ([crashed : bool] and [crash_message : string]) — instead of the silent "did
    not write actual.sexp" failure mode that lost the crash signature in CI
    logs.

    The two contracts pinned by this test:

    - Round-trip: a crashed [actual] with sentinel field values round-trips
      through [sexp_of_t] / [t_of_sexp] without losing data.
    - Backwards compatibility: a pre-flag [actual.sexp] that lacks the new
      [crashed] and [crash_message] fields still parses, with the defaults
      [crashed = false] and [crash_message = ""] applied per the
      [[@sexp.default ...]] annotations.

    Why a local mirror type rather than [Scenario_runner]'s production type:
    [scenario_runner.ml] is an executable, not a library — its [actual] type is
    not exposed on any module path that test code can import. Pinning the wire
    format from a parallel type definition is the lightest viable test surface
    that respects the "test files only — do NOT modify production code"
    constraint of the rework. The mirror type's field shape, defaults, and
    derivation MUST be kept bit-equivalent to the production type at
    [scenario_runner.ml] lines 53–82; if they ever drift, both sides need to
    land together (production change first, then this test updated to match in
    the same PR). A future refactor that hoists [actual] into [scenario_lib]
    should replace this mirror with a direct [Scenario_runner_actual.t]
    reference. *)

open OUnit2
open Core
open Matchers

type actual = {
  total_return_pct : float;
  total_trades : float;
  win_rate : float;
  sharpe_ratio : float;
  max_drawdown_pct : float;
  avg_holding_days : float;
  open_positions_value : float; [@sexp.default Float.nan]
  unrealized_pnl : float;
  force_liquidations_count : int; [@sexp.default 0]
  crashed : bool; [@sexp.default false]
  crash_message : string; [@sexp.default ""]
}
[@@deriving sexp]
(** Local mirror of [Scenario_runner.actual] (scenario_runner.ml lines 53–82).
    MUST match the production shape exactly — same field names, same types, same
    [[@sexp.default ...]] annotations, same record field order. *)

(** Mirror of [Scenario_runner._crashed_actual] (scenario_runner.ml lines
    108–121). Builds the sentinel record the production code writes when a child
    crashes. *)
let _crashed_actual ~msg =
  {
    total_return_pct = -100.0;
    total_trades = 0.0;
    win_rate = 0.0;
    sharpe_ratio = 0.0;
    max_drawdown_pct = 100.0;
    avg_holding_days = 0.0;
    open_positions_value = 0.0;
    unrealized_pnl = 0.0;
    force_liquidations_count = 0;
    crashed = true;
    crash_message = msg;
  }

(** Round-trip: a crashed sentinel record sexps and parses back to a
    bit-equivalent record.

    Fields under load-bearing scrutiny:
    - [crashed = true] — the boolean that distinguishes a crashed run from a
      normal-but-degenerate run with -100% return.
    - [crash_message] — the [Exn.to_string] payload that flows from the child's
      [eprintf] line into the parent's row renderer.
    - [total_return_pct = -100.0] / [max_drawdown_pct = 100.0] — out- of-range
      sentinels picked so the parent's [Scenario.in_range] checks fail
      explicitly rather than silently passing on NaN.
    - [total_trades = 0.0] — sentinel that pins this is not a normal run with a
      small trade count. *)
let test_crashed_actual_round_trips _ =
  let sentinel = _crashed_actual ~msg:"unhandled exception (test)" in
  let parsed = actual_of_sexp (sexp_of_actual sentinel) in
  assert_that parsed
    (all_of
       [
         field (fun a -> a.crashed) (equal_to true);
         field
           (fun a -> a.crash_message)
           (equal_to "unhandled exception (test)");
         field (fun a -> a.total_return_pct) (float_equal (-100.0));
         field (fun a -> a.max_drawdown_pct) (float_equal 100.0);
         field (fun a -> a.total_trades) (float_equal 0.0);
         field (fun a -> a.force_liquidations_count) (equal_to 0);
       ])

(** Backwards-compat: a pre-flag [actual.sexp] (one written before PR #911 added
    [crashed] and [crash_message]) must still parse cleanly, with the defaults
    [crashed = false] and [crash_message = ""] applied. This is what the
    [[@sexp.default ...]] annotations are for — without them, any historical
    [actual.sexp] sitting under [dev/backtest/] or in CI artefact archives would
    fail to parse on re-read.

    The sexp string below is exactly the shape a successful (non-crash)
    pre-PR-#911 child wrote: the seven core metric fields, plus
    [open_positions_value] / [unrealized_pnl] / [force_liquidations_count]
    (which were already present pre-#911), and crucially WITHOUT the new
    [crashed] / [crash_message] fields. *)
let test_pre_flag_sexp_parses_with_defaults _ =
  let pre_flag_sexp_str =
    {|((total_return_pct 12.5)
      (total_trades 42.0)
      (win_rate 55.5)
      (sharpe_ratio 1.2)
      (max_drawdown_pct 15.0)
      (avg_holding_days 22.5)
      (open_positions_value 5000.0)
      (unrealized_pnl 1234.56)
      (force_liquidations_count 3))|}
  in
  let parsed = actual_of_sexp (Sexp.of_string pre_flag_sexp_str) in
  assert_that parsed
    (all_of
       [
         (* The new fields take their declared defaults. *)
         field (fun a -> a.crashed) (equal_to false);
         field (fun a -> a.crash_message) (equal_to "");
         (* The pre-existing fields parse through to the values declared
            in the pre-flag sexp, confirming the shape isn't reordered
            or otherwise mangled. *)
         field (fun a -> a.total_return_pct) (float_equal 12.5);
         field (fun a -> a.total_trades) (float_equal 42.0);
         field (fun a -> a.force_liquidations_count) (equal_to 3);
       ])

(** Backwards-compat (deeper): a pre-G4 [actual.sexp] (one written before
    [force_liquidations_count] was added) must also parse — exercising the chain
    of [[@sexp.default ...]] defaults the type carries. Pinning this protects
    every historical sexp shape simultaneously, not just the most recent one
    before #911. *)
let test_pre_g4_sexp_parses_with_chained_defaults _ =
  let pre_g4_sexp_str =
    {|((total_return_pct 7.0)
      (total_trades 10.0)
      (win_rate 60.0)
      (sharpe_ratio 0.8)
      (max_drawdown_pct 12.0)
      (avg_holding_days 18.0)
      (open_positions_value 1000.0)
      (unrealized_pnl 500.0))|}
  in
  let parsed = actual_of_sexp (Sexp.of_string pre_g4_sexp_str) in
  assert_that parsed
    (all_of
       [
         field (fun a -> a.force_liquidations_count) (equal_to 0);
         field (fun a -> a.crashed) (equal_to false);
         field (fun a -> a.crash_message) (equal_to "");
         field (fun a -> a.total_return_pct) (float_equal 7.0);
       ])

let suite =
  "Scenario_runner_actual_sexp"
  >::: [
         "crashed actual round-trips with sentinel values"
         >:: test_crashed_actual_round_trips;
         "pre-flag sexp parses with crashed/crash_message defaults"
         >:: test_pre_flag_sexp_parses_with_defaults;
         "pre-G4 sexp parses with chained sexp.default values"
         >:: test_pre_g4_sexp_parses_with_chained_defaults;
       ]

let () = run_test_tt_main suite
