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
       ]

let () = run_test_tt_main suite
