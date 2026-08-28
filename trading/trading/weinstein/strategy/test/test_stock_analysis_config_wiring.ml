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

(** The seam copies the strategy default's resistance-v2 fields into the
    per-screen [Stock_analysis.config]. Since the 2026-07-23 bundle promotion
    the strategy default arms
    [overhead_supply = Some Resistance_supply.default_config] and
    [virgin_crossing_readmission = true], so the built config equals
    {!Stock_analysis.default_config} with exactly those two fields armed (every
    other field, including [resistance_min_history_bars = 0], keeps its default
    — the [Insufficient_history] floor is still never engaged).

    EFFECTIVENESS-PIN: overhead_supply -- severing
    [overhead_supply = config.overhead_supply] in [_stock_analysis_config_for]
    would leave [built.overhead_supply = None] (the pre-2026-07-23 default),
    which this equality assertion catches. EFFECTIVENESS-PIN:
    virgin_crossing_readmission -- same mechanism; a severed thread would leave
    [built.virgin_crossing_readmission = false]. *)
let test_default_builds_stock_analysis_default_config _ =
  let built =
    Weinstein_strategy.stock_analysis_config_for ~config:(_default_config ())
  in
  assert_that built
    (equal_to
       ({
          Stock_analysis.default_config with
          overhead_supply = Some Resistance_supply.default_config;
          virgin_crossing_readmission = true;
        }
         : Stock_analysis.config))

(** Non-zero [resistance_min_history_bars = 520] sets exactly
    [resistance.min_history_bars]; every other resistance field keeps its
    default, so the built resistance config equals
    [{ Resistance.default_config with min_history_bars = 520 }].

    EFFECTIVENESS-PIN: resistance_min_history_bars -- arms the field away from
    its [0] default and asserts the built value; severing the copy in
    [_stock_analysis_config_for] would leave
    [built.resistance.min_history_bars = 0] and fail this assertion. *)
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

(** The seam threads [entry_anchor_local_range_weeks] verbatim into the built
    per-screen [Stock_analysis.config] (ticket-level local-range entry anchor).
    Default [0] leaves it off — covered by
    [test_default_builds_stock_analysis_default_config], which pins the built
    config equal to {!Stock_analysis.default_config} (whose
    [entry_anchor_local_range_weeks] is also [0]). A non-zero value flows
    through unchanged.

    EFFECTIVENESS-PIN: entry_anchor_local_range_weeks -- arms the field away
    from its [0] default; severing the copy would leave
    [built. entry_anchor_local_range_weeks = 0] and fail the assertion below. *)
let test_threads_entry_anchor_local_range_weeks _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy.entry_anchor_local_range_weeks = 26;
    }
  in
  let built = Weinstein_strategy.stock_analysis_config_for ~config in
  assert_that built.entry_anchor_local_range_weeks (equal_to 26)

(** The seam threads [entry_freshness_basis] (F1, the admission-clock basis —
    {!Entry_freshness.basis}) verbatim into the built per-screen
    [Stock_analysis.config]. Found uncovered by the 2026-08-28 census
    (dev/plans/silent-null-effectiveness-2026-08-28.md): unlike its sibling
    fields above, nothing previously armed this field away from its default and
    checked the built config, so a severed copy
    ([entry_freshness_basis = Entry_freshness.Ma_cross], hardcoded) would have
    stayed invisible to the whole suite — the exact silent-null shape issue
    #2567 is about.

    EFFECTIVENESS-PIN: entry_freshness_basis -- arms the field away from its
    [Ma_cross] default; severing the copy would leave
    [built. entry_freshness_basis = Entry_freshness.Ma_cross] and fail the
    assertion below. *)
let test_threads_entry_freshness_basis _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy.entry_freshness_basis =
        Entry_freshness.Range_top_breakout;
    }
  in
  let built = Weinstein_strategy.stock_analysis_config_for ~config in
  assert_that built.entry_freshness_basis
    (equal_to Entry_freshness.Range_top_breakout)

(* ------------------------------------------------------------------ *)
(* F5 — volume_confirm_at_fill => require_breakout_volume = false       *)
(* ------------------------------------------------------------------ *)

(** The armed F5 config, through the REAL config→strategy seam, waives the
    screen-time volume gate. This is the placement half of the mechanism (book
    §4.7: a GTC ticket is written before the breakout, so its volume is
    unknowable at placement); its counterpart, {!Volume_eject_runner}, reads the
    same arming predicate and confirms the volume at the fill. *)
let test_armed_f5_waives_screen_time_volume_gate _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy.volume_confirm_at_fill = true;
      sim_entry_trigger_at_suggested = true;
      enable_sim_entry_stoplimit = true;
    }
  in
  let built = Weinstein_strategy.stock_analysis_config_for ~config in
  assert_that built.require_breakout_volume (equal_to false)

(** R1: at the default config the gate stays armed, so admission is
    bit-identical to pre-F5. (Also covered structurally by
    {!test_default_builds_stock_analysis_default_config}, which pins the whole
    built record.) *)
let test_default_keeps_screen_time_volume_gate _ =
  let built =
    Weinstein_strategy.stock_analysis_config_for ~config:(_default_config ())
  in
  assert_that built.require_breakout_volume (equal_to true)

(** The flag alone does not arm F5 — the mechanism is defined only for the
    resting E-anchored ticket family. Each StopLimit half on its own leaves the
    screen-time gate in place.

    Every arm pins {b both} StopLimit fields explicitly rather than leaning on
    their defaults, so the isolation this test asserts survives a default flip:
    since 2026-08-26 [enable_sim_entry_stoplimit] defaults to [true] (#2405),
    and an arm that only set [sim_entry_trigger_at_suggested] would silently
    become the fully-armed family. *)
let test_flag_without_stoplimit_family_keeps_gate _ =
  let with_overrides ~stoplimit ~trigger_at_suggested =
    let config =
      {
        (_default_config ()) with
        Weinstein_strategy.volume_confirm_at_fill = true;
        enable_sim_entry_stoplimit = stoplimit;
        sim_entry_trigger_at_suggested = trigger_at_suggested;
      }
    in
    (Weinstein_strategy.stock_analysis_config_for ~config)
      .require_breakout_volume
  in
  assert_that
    ( with_overrides ~stoplimit:false ~trigger_at_suggested:false,
      with_overrides ~stoplimit:true ~trigger_at_suggested:false,
      with_overrides ~stoplimit:false ~trigger_at_suggested:true )
    (equal_to (true, true, true))

let suite =
  "stock_analysis_config_wiring"
  >::: [
         "armed F5 waives the screen-time volume gate"
         >:: test_armed_f5_waives_screen_time_volume_gate;
         "default keeps the screen-time volume gate"
         >:: test_default_keeps_screen_time_volume_gate;
         "flag without the StopLimit family keeps the gate"
         >:: test_flag_without_stoplimit_family_keeps_gate;
         "default builds Stock_analysis.default_config"
         >:: test_default_builds_stock_analysis_default_config;
         "override sets resistance.min_history_bars"
         >:: test_override_sets_resistance_min_history_bars;
         "override mirrors into support via shared record"
         >:: test_override_mirrors_into_support_via_shared_record;
         "threads entry_anchor_local_range_weeks into built config"
         >:: test_threads_entry_anchor_local_range_weeks;
         "threads entry_freshness_basis into built config"
         >:: test_threads_entry_freshness_basis;
       ]

let () = run_test_tt_main suite
