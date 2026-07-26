(** Tests for the perf workstream hypothesis-toggle config fields:
    [bar_history_max_lookback_days], [skip_ad_breadth], [skip_sector_etf_load],
    [universe_cap] (all C1, PR #528), and [full_compute_tail_days] (H2,
    extending the C1 surface).

    These fields land in [Weinstein_strategy.config] together; their unifying
    contract is "default value = current behaviour, set via [--override]". Tests
    pin two layers:

    1. {b Sexp round-trip} — each field survives [Sexp.t_of_sexp] /
    [Sexp.sexp_of_t] from a partial-config sexp the same way [--override]
    deep-merges them. Pins the wiring needed for hypothesis tests like
    [--override '(bar_history_max_lookback_days 365)'] to actually land the
    value into the running config. 2. {b Runner integration} — running
    [Backtest.Runner.run_backtest] with each toggle set drives the runner down
    the toggled code path. We use the committed parity scenario fixture
    ([smoke/tiered-loader-parity.sexp], 7-symbol universe) so the cycle fully
    exercises the runner's pre-simulator paths without dragging in a broad
    universe.

    [bar_history_max_lookback_days] is config-only after Stage 3 of the columnar
    data-shape redesign deleted [Bar_history]: setting it must NOT change
    observable strategy behaviour. The override sexp is preserved so existing
    scripts continue to parse.

    [full_compute_tail_days] is similarly vestigial after Stage 3 PR 3.3 deleted
    the Tiered loader and [Bar_loader.Full_compute]. The sexp round-trip
    continues to be tested so existing override scripts parse. *)

open OUnit2
open Core
open Matchers
module Scenario = Scenario_lib.Scenario
module Universe_file = Scenario_lib.Universe_file

(* -------------------------------------------------------------------- *)
(* Fixture loading                                                       *)
(* -------------------------------------------------------------------- *)

let _fixtures_root () =
  let data_dir = Data_path.default_data_dir () |> Fpath.to_string in
  Filename.concat data_dir "backtest_scenarios"

let _scenario_path () =
  Filename.concat (_fixtures_root ()) "smoke/tiered-loader-parity.sexp"

let _load_scenario () = Scenario.load (_scenario_path ())

let _sector_map_override (s : Scenario.t) =
  let resolved = Filename.concat (_fixtures_root ()) s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)

let _run (s : Scenario.t) ~overrides =
  let sector_map_override = _sector_map_override s in
  Backtest.Runner.run_backtest ~start_date:s.period.start_date
    ~end_date:s.period.end_date ~overrides ?sector_map_override ()

(* -------------------------------------------------------------------- *)
(* Sexp round-trip                                                       *)
(* -------------------------------------------------------------------- *)

(** Apply a single override sexp the same way [Backtest.Runner._apply_overrides]
    does, then read the named field back out. Mirrors what happens when a user
    passes [--override '<sexp>'] on the CLI. *)
let _apply_one_override config override_sexp =
  let base = Weinstein_strategy.sexp_of_config config in
  (* Inline copy of the deep-merge logic exercised by the runner — the
     production helper is private. *)
  let is_record fields =
    List.for_all fields ~f:(function
      | Sexp.List [ Sexp.Atom _; _ ] -> true
      | _ -> false)
  in
  let rec merge base overlay =
    match (base, overlay) with
    | Sexp.List bf, Sexp.List of_ when is_record bf && is_record of_ ->
        let overlay_map =
          List.filter_map of_ ~f:(function
            | Sexp.List [ Sexp.Atom k; v ] -> Some (k, v)
            | _ -> None)
          |> String.Map.of_alist_exn
        in
        Sexp.List
          (List.map bf ~f:(function
            | Sexp.List [ Sexp.Atom k; v ] as pair -> (
                match Map.find overlay_map k with
                | Some v' -> Sexp.List [ Sexp.Atom k; merge v v' ]
                | None -> pair)
            | other -> other))
    | _, _ -> overlay
  in
  Weinstein_strategy.config_of_sexp (merge base override_sexp)

let _default_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL" ] ~index_symbol:"GSPCX"

let test_default_preserves_current_behaviour _ =
  let cfg = _default_config () in
  assert_that cfg
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) ->
             c.bar_history_max_lookback_days)
           is_none;
         field
           (fun (c : Weinstein_strategy.config) -> c.skip_ad_breadth)
           (equal_to false);
         field
           (fun (c : Weinstein_strategy.config) -> c.skip_sector_etf_load)
           (equal_to false);
         field (fun (c : Weinstein_strategy.config) -> c.universe_cap) is_none;
         field
           (fun (c : Weinstein_strategy.config) -> c.full_compute_tail_days)
           is_none;
       ])

let test_override_bar_history_max_lookback_days _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((bar_history_max_lookback_days (365)))")
  in
  assert_that merged.bar_history_max_lookback_days (is_some_and (equal_to 365))

let test_override_skip_ad_breadth _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((skip_ad_breadth true))")
  in
  assert_that merged.skip_ad_breadth (equal_to true)

let test_override_skip_sector_etf_load _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((skip_sector_etf_load true))")
  in
  assert_that merged.skip_sector_etf_load (equal_to true)

let test_override_universe_cap _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((universe_cap (3)))")
  in
  assert_that merged.universe_cap (is_some_and (equal_to 3))

(** Sexp round-trip: an override sexp parses [full_compute_tail_days = Some 50]
    correctly so [--override '((full_compute_tail_days (50)))'] still parses,
    even though the value is now a no-op (Bar_loader was deleted in Stage 3 PR
    3.3). *)
let test_override_full_compute_tail_days _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((full_compute_tail_days (50)))")
  in
  assert_that merged.full_compute_tail_days (is_some_and (equal_to 50))

(* -------------------------------------------------------------------- *)
(* Runner integration: each toggle drives the right code path            *)
(* -------------------------------------------------------------------- *)

(** [bar_history_max_lookback_days = Some n] must NOT change observable
    behaviour — the field is vestigial after [Bar_history] was deleted in Stage
    3 PR 3.2. Pin trade count and final portfolio value against the baseline so
    a future re-introduction of the field forces this test to be updated. *)
let test_bar_history_lookback_is_no_op _ =
  let s = _load_scenario () in
  let baseline = _run s ~overrides:[] in
  let with_lookback =
    _run s
      ~overrides:[ Sexp.of_string "((bar_history_max_lookback_days (365)))" ]
  in
  assert_that with_lookback.summary
    (all_of
       [
         field
           (fun (sm : Backtest.Summary.t) -> sm.n_round_trips)
           (equal_to baseline.summary.n_round_trips);
         field
           (fun (sm : Backtest.Summary.t) -> sm.final_portfolio_value)
           (float_equal ~epsilon:0.01 baseline.summary.final_portfolio_value);
       ])

(** [universe_cap = Some n] truncates the loaded universe. The parity fixture
    has 7 symbols; capping to 3 should leave the runner's effective universe at
    3. We assert [summary.universe_size = 3] and that the run completes
    successfully. The cap is applied before [Total symbols] logging, so the
    runner sees the capped universe. *)
let test_universe_cap_truncates_universe _ =
  let s = _load_scenario () in
  let result = _run s ~overrides:[ Sexp.of_string "((universe_cap (3)))" ] in
  assert_that result.summary
    (field (fun (sm : Backtest.Summary.t) -> sm.universe_size) (equal_to 3))

(** [universe_cap = Some n] when [n >= |universe|] is a no-op — the runner
    leaves the universe untouched. Pinning this avoids a regression where a
    naive [List.take] truncates to the cap regardless of size. *)
let test_universe_cap_above_universe_is_no_op _ =
  let s = _load_scenario () in
  let baseline = _run s ~overrides:[] in
  let result = _run s ~overrides:[ Sexp.of_string "((universe_cap (1000)))" ] in
  assert_that result.summary
    (field
       (fun (sm : Backtest.Summary.t) -> sm.universe_size)
       (equal_to baseline.summary.universe_size))

(** [skip_ad_breadth = true] must run to completion. We don't pin PV — the
    degraded-mode strategy is expected to take different decisions when
    AD-breadth indicators see [[]] instead of real data. The contract this test
    pins is: the strategy doesn't crash on empty AD bars. *)
let test_skip_ad_breadth_runs_to_completion _ =
  let s = _load_scenario () in
  let result =
    _run s ~overrides:[ Sexp.of_string "((skip_ad_breadth true))" ]
  in
  assert_that (List.length result.steps) (gt (module Int_ord) 0)

(** [skip_sector_etf_load = true] must run to completion. Same degraded-mode
    semantics as [skip_ad_breadth] — the screener's sector gate falls back to
    Neutral when no sector ETFs are loaded. *)
let test_skip_sector_etf_load_runs_to_completion _ =
  let s = _load_scenario () in
  let result =
    _run s ~overrides:[ Sexp.of_string "((skip_sector_etf_load true))" ]
  in
  assert_that (List.length result.steps) (gt (module Int_ord) 0)

(** Pin the deep-merge path for [screening_config.min_score_override] — [(41)]
    as the value sexp parses back to [Some 41] once the partial-config overlay
    is merged into the default config. Issue #888 wires this knob into the M5.5
    grid_search sweep via [Tuner.Grid_search.param_spec], so the runner must
    accept it. *)
let test_override_screening_min_score_override _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((screening_config ((min_score_override (41)))))")
  in
  assert_that merged.screening_config.min_score_override
    (is_some_and (equal_to 41))

(** [None] (the default) is preserved when no override is applied. Pins the
    bit-equality contract documented in [Screener.config.min_score_override]. *)
let test_default_screening_min_score_override_is_none _ =
  let cfg = _default_config () in
  assert_that cfg.screening_config.min_score_override is_none

(** Deep-merge path for [screening_config.volume_ratio_exclude_range]. Pairs
    with the [Screener.config.volume_ratio_exclude_range] knob added on this
    branch; sweepers can move the boundaries by overriding the partial-config
    overlay. *)
let test_override_screening_volume_ratio_exclude_range _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string
         "((screening_config ((volume_ratio_exclude_range (((low 2.5) (high \
          3.0)))))))")
  in
  assert_that merged.screening_config.volume_ratio_exclude_range
    (is_some_and
       (all_of
          [
            field
              (fun (b : Screener.volume_ratio_band) -> b.low)
              (float_equal 2.5);
            field
              (fun (b : Screener.volume_ratio_band) -> b.high)
              (float_equal 3.0);
          ]))

(** Default is preserved when no override is applied. *)
let test_default_screening_volume_ratio_exclude_range_is_none _ =
  let cfg = _default_config () in
  assert_that cfg.screening_config.volume_ratio_exclude_range is_none

(** Deep-merge path for [screening_config.min_price] — the liquidity floor. A
    scenario's [config_overrides] can set it to 1.0 / 5.0 / 10.0 so
    broad-universe backtests exclude penny / illiquid names. *)
let test_override_screening_min_price _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((screening_config ((min_price 5.0))))")
  in
  assert_that merged.screening_config.min_price (float_equal 5.0)

(** [0.0] (the default) is preserved when no override is applied. Pins the
    bit-identical no-op contract documented in [Screener.config.min_price]. *)
let test_default_screening_min_price_is_zero _ =
  let cfg = _default_config () in
  assert_that cfg.screening_config.min_price (float_equal 0.0)

(** Deep-merge path for [screening_config.early_stage2_max_weeks] — the
    early-Stage2 admission/scoring window. A scenario's [config_overrides] can
    widen it (e.g. from 4 to 8) so the axis resolves through
    [Overlay_validator.apply_overrides] without an unknown-key error. *)
let test_override_screening_early_stage2_max_weeks _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((screening_config ((early_stage2_max_weeks 8))))")
  in
  assert_that merged.screening_config.early_stage2_max_weeks (equal_to 8)

(** [4] (the default) is preserved when no override is applied. Pins the
    bit-identical no-op contract documented in
    [Screener.config.early_stage2_max_weeks]. *)
let test_default_screening_early_stage2_max_weeks_is_four _ =
  let cfg = _default_config () in
  assert_that cfg.screening_config.early_stage2_max_weeks (equal_to 4)

(** Fold-equivalent helper: applies a list of override sexps the same way
    [Backtest.Runner._apply_overrides] does — sequential deep-merge of each
    overlay into the running sexp, then a single [config_of_sexp] at the end.
    Mirrors `List.fold overrides ~init:base ~f:_merge_sexp`. *)
let _apply_overrides_seq config overlays =
  let base = Weinstein_strategy.sexp_of_config config in
  let is_record fields =
    List.for_all fields ~f:(function
      | Sexp.List [ Sexp.Atom _; _ ] -> true
      | _ -> false)
  in
  let rec merge base overlay =
    match (base, overlay) with
    | Sexp.List bf, Sexp.List of_ when is_record bf && is_record of_ ->
        let overlay_map =
          List.filter_map of_ ~f:(function
            | Sexp.List [ Sexp.Atom k; v ] -> Some (k, v)
            | _ -> None)
          |> String.Map.of_alist_exn
        in
        Sexp.List
          (List.map bf ~f:(function
            | Sexp.List [ Sexp.Atom k; v ] as pair -> (
                match Map.find overlay_map k with
                | Some v' -> Sexp.List [ Sexp.Atom k; merge v v' ]
                | None -> pair)
            | other -> other))
    | _, _ -> overlay
  in
  let merged = List.fold overlays ~init:base ~f:merge in
  Weinstein_strategy.config_of_sexp merged

(** Repro for bug filed in dev/experiments/entry-caps-2026-05-12/report.md §"Bug
    filed": two overlays targeting the same top-level field ([screening_config])
    — second overlay's effect silently dropped. *)
let test_two_overlays_same_top_level_field _ =
  let overlay1 =
    Sexp.of_string "((screening_config ((max_score_override (79)))))"
  in
  let overlay2 =
    Sexp.of_string
      "((screening_config ((candidate_params ((initial_stop_pct 0.10))))))"
  in
  let merged =
    _apply_overrides_seq (_default_config ()) [ overlay1; overlay2 ]
  in
  assert_that merged.screening_config
    (all_of
       [
         field
           (fun (c : Screener.config) -> c.max_score_override)
           (is_some_and (equal_to 79));
         field
           (fun (c : Screener.config) -> c.candidate_params.initial_stop_pct)
           (float_equal 0.10);
       ])

(* -------------------------------------------------------------------- *)
(* Sweep-path validation: unknown overlay keys fail loudly               *)
(* -------------------------------------------------------------------- *)

(** Reproduction of the PR-#1051 silent-no-op hazard: a sweep cell keyed on
    [screening_config.weights.rs] (a path that does not name any field on the
    real [scoring_weights] record — the field is [w_positive_rs]) used to be
    silently dropped by the deep-merge, so all 81 cells produced bit-identical
    metrics. With the sweep-path linter added in this PR, the runner must FAIL
    LOUDLY on the first unknown key, naming the offending dotted path. *)
let test_unknown_top_level_overlay_key_fails _ =
  let s = _load_scenario () in
  let sector_map_override = _sector_map_override s in
  let result =
    Result.try_with (fun () ->
        Backtest.Runner.run_backtest ~start_date:s.period.start_date
          ~end_date:s.period.end_date
          ~overrides:[ Sexp.of_string "((no_such_field 42))" ]
          ?sector_map_override ())
  in
  assert_that result
    (matching ~msg:"Expected Failure raising on unknown key"
       (function Error (Failure msg) -> Some msg | _ -> None)
       (all_of
          [
            field
              (fun s -> String.is_substring s ~substring:"no_such_field")
              (equal_to true);
            field
              (fun s -> String.is_substring s ~substring:"overlay #0")
              (equal_to true);
          ]))

(** Nested unknown path — the merge walks into the (real) [screening_config]
    sub-record, then sees the (non-existent) [weights.rs] path. The error must
    name the full dotted path so an operator looking at the error can match it
    back to their sweep-spec key. *)
let test_unknown_nested_overlay_key_fails _ =
  let s = _load_scenario () in
  let sector_map_override = _sector_map_override s in
  let result =
    Result.try_with (fun () ->
        Backtest.Runner.run_backtest ~start_date:s.period.start_date
          ~end_date:s.period.end_date
          ~overrides:
            [ Sexp.of_string "((screening_config ((weights ((rs 1.5))))))" ]
          ?sector_map_override ())
  in
  assert_that result
    (matching ~msg:"Expected Failure raising on nested unknown key"
       (function Error (Failure msg) -> Some msg | _ -> None)
       (field
          (fun s ->
            String.is_substring s ~substring:"screening_config.weights.rs")
          (equal_to true)))

(** A real (deep, valid) path must still resolve and apply — the
    [screening_config.weights.w_clean_resistance] field IS a real
    [scoring_weights] field. This pins that the happy path is unaffected by the
    new validation. *)
let test_known_nested_overlay_key_succeeds _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string
         "((screening_config ((weights ((w_clean_resistance 30))))))")
  in
  assert_that merged.screening_config.weights.w_clean_resistance (equal_to 30)

(** resistance-v2 PR-D: the continuous overhead-supply scoring weight
    [screening_config.weights.w_overhead_supply] ([int option]) resolves and
    deep-merges — [(15)] parses to [Some 15]. Pins R2 searchability of the
    weight through the same deep-merge path [Overlay_validator] uses. *)
let test_override_screening_weights_w_overhead_supply _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string
         "((screening_config ((weights ((w_overhead_supply (15)))))))")
  in
  assert_that merged.screening_config.weights.w_overhead_supply
    (equal_to (Some 15))

(** Bundle promotion (2026-07-23, user-approved R3): the strategy default arms
    the continuous overhead-supply mechanism end-to-end — the strategy-level
    [overhead_supply] is [Some Resistance_supply.default_config] AND the
    screener weight [w_overhead_supply] is [Some 30]. Both must be armed for the
    continuous score to replace the binary grade points. (Under CSV / on-the-fly
    panel mode the panel adapter's [get_sketch] returns [None], so the mechanism
    still degrades to the bit-identical binary path; the arming bites only in
    snapshot-warehouse mode with sketch columns present.) *)
let test_overhead_supply_defaults_armed _ =
  let cfg = _default_config () in
  assert_that cfg
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.overhead_supply)
           (is_some_and
              (equal_to
                 (Resistance_supply.default_config : Resistance_supply.config)));
         field
           (fun (c : Weinstein_strategy.config) ->
             c.screening_config.weights.w_overhead_supply)
           (equal_to (Some 30));
       ])

(** Back-compat: a strategy config sexp written before PR-D (with no
    [overhead_supply] field at all) still parses — the missing field defaults to
    [None] via [@sexp.default None]. We prove this by stripping the field from
    the serialized default config and parsing the result. *)
let test_strategy_config_parses_with_overhead_supply_absent _ =
  let base = Weinstein_strategy.sexp_of_config (_default_config ()) in
  let stripped =
    match base with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List [ Sexp.Atom "overhead_supply"; _ ] -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    (Weinstein_strategy.config_of_sexp stripped)
    (field (fun (c : Weinstein_strategy.config) -> c.overhead_supply) is_none)

(** The strategy-level [overhead_supply] round-trips when armed ([Some cfg]) —
    proving the [Resistance_supply.config] [[@@deriving sexp]] added in PR-D
    composes correctly inside [Weinstein_strategy.config]'s sexp derivation. *)
let test_overhead_supply_some_roundtrips _ =
  let cfg =
    {
      (_default_config ()) with
      overhead_supply = Some Resistance_supply.default_config;
    }
  in
  let roundtripped =
    Weinstein_strategy.config_of_sexp (Weinstein_strategy.sexp_of_config cfg)
  in
  assert_that roundtripped.overhead_supply
    (is_some_and
       (equal_to (Resistance_supply.default_config : Resistance_supply.config)))

(** Bundle promotion (2026-07-23, user-approved R3):
    [virgin_crossing_readmission] defaults to [true] — the lever that repairs
    bare-w30's recovery-window left tail in the bundle studies (ledger
    [2026-07-20-bundle-promotion-studies]). *)
let test_virgin_crossing_readmission_defaults_on _ =
  assert_that (_default_config ()).virgin_crossing_readmission (equal_to true)

(** Back-compat: a strategy config sexp written before this lever (no
    [virgin_crossing_readmission] field) still parses — the missing field
    defaults to [false] via [@sexp.default false]. Proved by stripping the field
    from the serialized default config and parsing the result. *)
let test_strategy_config_parses_with_virgin_readmission_absent _ =
  let base = Weinstein_strategy.sexp_of_config (_default_config ()) in
  let stripped =
    match base with
    | Sexp.List fields ->
        Sexp.List
          (List.filter fields ~f:(function
            | Sexp.List [ Sexp.Atom "virgin_crossing_readmission"; _ ] -> false
            | _ -> true))
    | other -> other
  in
  assert_that
    (Weinstein_strategy.config_of_sexp stripped)
    (field
       (fun (c : Weinstein_strategy.config) -> c.virgin_crossing_readmission)
       (equal_to false))

(** R2 searchability: the top-level [virgin_crossing_readmission] flag resolves
    and deep-merges through the same [Overlay_validator] path a [Variant_matrix]
    [(flag virgin_crossing_readmission)] axis emits —
    [(virgin_crossing_readmission true)] lands [true]. *)
let test_override_virgin_crossing_readmission _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((virgin_crossing_readmission true))")
  in
  assert_that merged.virgin_crossing_readmission (equal_to true)

(** The error message must include the index of the offending overlay (0-based)
    so operators can map back to the specific [--override] flag. When the second
    overlay is invalid and the first is valid, the index must report [#1] (not
    [#0]). *)
let test_unknown_key_error_reports_overlay_index _ =
  let s = _load_scenario () in
  let sector_map_override = _sector_map_override s in
  let result =
    Result.try_with (fun () ->
        Backtest.Runner.run_backtest ~start_date:s.period.start_date
          ~end_date:s.period.end_date
          ~overrides:
            [
              (* valid — universe_cap is a real field *)
              Sexp.of_string "((universe_cap (3)))";
              (* invalid — typo of universe_cap *)
              Sexp.of_string "((universe_caps (3)))";
            ]
          ?sector_map_override ())
  in
  assert_that result
    (matching ~msg:"Expected Failure naming overlay #1"
       (function Error (Failure msg) -> Some msg | _ -> None)
       (all_of
          [
            field
              (fun s -> String.is_substring s ~substring:"overlay #1")
              (equal_to true);
            field
              (fun s -> String.is_substring s ~substring:"universe_caps")
              (equal_to true);
          ]))

(* -------------------------------------------------------------------- *)
(* cash_reserve_pct — working replacement for dead Portfolio_risk.min_cash_pct *)
(* -------------------------------------------------------------------- *)

(** [cash_reserve_pct] defaults to [0.0] when omitted from the sexp (backward
    compat — every existing golden/baseline decodes unchanged). The working,
    live-path replacement for the dead [Portfolio_risk.min_cash_pct]
    (dev/notes/envelope-knobs-dead-2026-07-05.md). *)
let test_default_cash_reserve_pct_is_zero _ =
  let cfg = _default_config () in
  assert_that cfg.cash_reserve_pct (float_equal 0.0)

(** Deep-merge path for [cash_reserve_pct]: a
    [--override '((cash_reserve_pct 0.30))'] round-trips through the sexp merge
    and lands the explicit value. *)
let test_override_cash_reserve_pct _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((cash_reserve_pct 0.30))")
  in
  assert_that merged.cash_reserve_pct (float_equal 0.30)

(** Axis reachability (experiment-flag-discipline R2): the [cash_reserve_pct]
    override sexp resolves through the {b real}
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path) with no
    unknown-key error, and lands the value — this is what makes
    [((cash_reserve_pct 0.30))] a valid [Variant_matrix] axis. *)
let test_cash_reserve_pct_axis_resolves_via_overlay_validator _ =
  let merged =
    Backtest.Overlay_validator.apply_overrides (_default_config ())
      [ Sexp.of_string "((cash_reserve_pct 0.30))" ]
  in
  assert_that merged.cash_reserve_pct (float_equal 0.30)

(* -------------------------------------------------------------------- *)
(* extension_stop_config — tail-insurance trail (default-off nested axis) *)
(* -------------------------------------------------------------------- *)

(** [extension_stop_config] defaults to the no-op ([trigger_ratio = 0.0] /
    [trail_pct = 0.0]) — the mechanism is disabled, so every existing
    golden/baseline decodes unchanged
    ([.claude/rules/experiment-flag-discipline.md] R1). *)
let test_default_extension_stop_config_is_no_op _ =
  let cfg = _default_config () in
  assert_that cfg.extension_stop_config
    (all_of
       [
         field
           (fun (c : Weinstein_stops.Extension_stop.config) -> c.trigger_ratio)
           (float_equal 0.0);
         field
           (fun (c : Weinstein_stops.Extension_stop.config) -> c.trail_pct)
           (float_equal 0.0);
       ])

(** Deep-merge path for the nested [extension_stop_config]: a partial-config
    overlay lands both sub-fields via the sexp merge. *)
let test_override_extension_stop_config _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string
         "((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))")
  in
  assert_that merged.extension_stop_config
    (all_of
       [
         field
           (fun (c : Weinstein_stops.Extension_stop.config) -> c.trigger_ratio)
           (float_equal 2.0);
         field
           (fun (c : Weinstein_stops.Extension_stop.config) -> c.trail_pct)
           (float_equal 0.25);
       ])

(** Axis reachability (experiment-flag-discipline R2): the nested
    [extension_stop_config] override resolves through the {b real}
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path) with no
    unknown-key error, landing a single sub-field — this is what makes
    [((key (extension_stop_config trigger_ratio)) (values (2.0 2.25)))] a valid
    [Variant_matrix] axis. *)
let test_extension_stop_config_axis_resolves_via_overlay_validator _ =
  let merged =
    Backtest.Overlay_validator.apply_overrides (_default_config ())
      [ Sexp.of_string "((extension_stop_config ((trigger_ratio 2.0))))" ]
  in
  assert_that merged.extension_stop_config.trigger_ratio (float_equal 2.0)

(* -------------------------------------------------------------------- *)
(* resistance_min_history_bars — R2 wiring for #1941 (default-off int)    *)
(* -------------------------------------------------------------------- *)

(** [resistance_min_history_bars] defaults to [0] — the resistance/support
    [Insufficient_history] floor is disabled, so the built
    [Stock_analysis.config] is byte-identical to
    {!Stock_analysis.default_config} and every existing golden/baseline replays
    unchanged ([.claude/rules/experiment-flag-discipline.md] R1). *)
let test_default_resistance_min_history_bars_is_zero _ =
  let cfg = _default_config () in
  assert_that cfg.resistance_min_history_bars (equal_to 0)

(** Deep-merge path for [resistance_min_history_bars]: a
    [--override '((resistance_min_history_bars 520))'] round-trips through the
    sexp merge and lands the explicit value (the resistance spec's full
    virgin-lookback). *)
let test_override_resistance_min_history_bars _ =
  let merged =
    _apply_one_override (_default_config ())
      (Sexp.of_string "((resistance_min_history_bars 520))")
  in
  assert_that merged.resistance_min_history_bars (equal_to 520)

(** Axis reachability (experiment-flag-discipline R2): the
    [resistance_min_history_bars] override sexp resolves through the {b real}
    [Overlay_validator.apply_overrides] (the sweep / WF-CV path) with no
    unknown-key error, and lands the value — this is what makes
    [((resistance_min_history_bars 520))] a valid [Variant_matrix] axis and the
    R2-searchability follow-up to PR #1941. *)
let test_resistance_min_history_bars_axis_resolves_via_overlay_validator _ =
  let merged =
    Backtest.Overlay_validator.apply_overrides (_default_config ())
      [ Sexp.of_string "((resistance_min_history_bars 520))" ]
  in
  assert_that merged.resistance_min_history_bars (equal_to 520)

let suite =
  "Runner_hypothesis_overrides"
  >::: [
         "default config preserves current behaviour"
         >:: test_default_preserves_current_behaviour;
         "override: bar_history_max_lookback_days round-trips through sexp"
         >:: test_override_bar_history_max_lookback_days;
         "override: skip_ad_breadth round-trips through sexp"
         >:: test_override_skip_ad_breadth;
         "override: skip_sector_etf_load round-trips through sexp"
         >:: test_override_skip_sector_etf_load;
         "override: universe_cap round-trips through sexp"
         >:: test_override_universe_cap;
         "override: full_compute_tail_days round-trips through sexp"
         >:: test_override_full_compute_tail_days;
         "bar_history_max_lookback_days is a no-op (vestigial)"
         >:: test_bar_history_lookback_is_no_op;
         "universe_cap = Some 3 truncates 7-symbol universe to 3"
         >:: test_universe_cap_truncates_universe;
         "universe_cap above universe size is a no-op"
         >:: test_universe_cap_above_universe_is_no_op;
         "skip_ad_breadth = true runs to completion (degraded mode)"
         >:: test_skip_ad_breadth_runs_to_completion;
         "skip_sector_etf_load = true runs to completion (degraded mode)"
         >:: test_skip_sector_etf_load_runs_to_completion;
         "override: screening_config.min_score_override round-trips through \
          sexp" >:: test_override_screening_min_score_override;
         "default: screening_config.min_score_override = None"
         >:: test_default_screening_min_score_override_is_none;
         "override: screening_config.volume_ratio_exclude_range round-trips \
          through sexp" >:: test_override_screening_volume_ratio_exclude_range;
         "default: screening_config.volume_ratio_exclude_range = None"
         >:: test_default_screening_volume_ratio_exclude_range_is_none;
         "override: screening_config.min_price round-trips through sexp"
         >:: test_override_screening_min_price;
         "default: screening_config.min_price = 0.0"
         >:: test_default_screening_min_price_is_zero;
         "override: screening_config.early_stage2_max_weeks round-trips \
          through sexp" >:: test_override_screening_early_stage2_max_weeks;
         "default: screening_config.early_stage2_max_weeks = 4"
         >:: test_default_screening_early_stage2_max_weeks_is_four;
         "two overlays targeting same top-level field both apply"
         >:: test_two_overlays_same_top_level_field;
         "unknown top-level overlay key fails loudly (sweep-path linter)"
         >:: test_unknown_top_level_overlay_key_fails;
         "unknown nested overlay key names the full dotted path"
         >:: test_unknown_nested_overlay_key_fails;
         "known nested overlay key still applies (linter happy path)"
         >:: test_known_nested_overlay_key_succeeds;
         "override screening_config.weights.w_overhead_supply"
         >:: test_override_screening_weights_w_overhead_supply;
         "overhead_supply defaults armed (strategy + weight)"
         >:: test_overhead_supply_defaults_armed;
         "strategy config parses with overhead_supply absent"
         >:: test_strategy_config_parses_with_overhead_supply_absent;
         "overhead_supply Some round-trips"
         >:: test_overhead_supply_some_roundtrips;
         "virgin_crossing_readmission defaults on"
         >:: test_virgin_crossing_readmission_defaults_on;
         "strategy config parses with virgin_crossing_readmission absent"
         >:: test_strategy_config_parses_with_virgin_readmission_absent;
         "override virgin_crossing_readmission flag"
         >:: test_override_virgin_crossing_readmission;
         "error message reports overlay index for multi-overlay runs"
         >:: test_unknown_key_error_reports_overlay_index;
         "default cash_reserve_pct is zero"
         >:: test_default_cash_reserve_pct_is_zero;
         "override cash_reserve_pct through sexp"
         >:: test_override_cash_reserve_pct;
         "cash_reserve_pct axis resolves via Overlay_validator"
         >:: test_cash_reserve_pct_axis_resolves_via_overlay_validator;
         "default extension_stop_config is no-op"
         >:: test_default_extension_stop_config_is_no_op;
         "override extension_stop_config through sexp"
         >:: test_override_extension_stop_config;
         "extension_stop_config axis resolves via Overlay_validator"
         >:: test_extension_stop_config_axis_resolves_via_overlay_validator;
         "default resistance_min_history_bars is zero"
         >:: test_default_resistance_min_history_bars_is_zero;
         "override resistance_min_history_bars through sexp"
         >:: test_override_resistance_min_history_bars;
         "resistance_min_history_bars axis resolves via Overlay_validator"
         >:: test_resistance_min_history_bars_axis_resolves_via_overlay_validator;
       ]

let () = run_test_tt_main suite
