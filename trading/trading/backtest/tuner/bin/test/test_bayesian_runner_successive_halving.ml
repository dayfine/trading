(** Unit tests for {!Tuner_bin.Bayesian_runner_successive_halving}.

    Covers the pure promotion-by-rank helper + survivor-count arithmetic plus an
    end-to-end orchestration test that exercises the cheap → medium → expensive
    promotion using stub evaluators (no real backtest). The integration test
    uses a 1D parabolic surface so the BO ask/tell loop has a clear maximum to
    converge on; promoted candidates are RE-EVALUATED on the medium / expensive
    tiers with a different scaling per tier to verify each stage's score-ranking
    takes effect. *)

open OUnit2
open Core
open Matchers
module SH = Tuner_bin.Bayesian_runner_successive_halving
module Spec = Tuner_bin.Bayesian_runner_spec
module Runner = Tuner_bin.Bayesian_runner_runner
module Wf_spec = Walk_forward.Spec
module Wf_window = Walk_forward.Window_spec
module FG = Walk_forward.Fold_gate
module Metric_types = Trading_simulation_types.Metric_types

(* ---------- temp-dir helper ---------- *)

let _with_temp_dir f =
  let dir =
    Filename_unix.temp_dir ~in_dir:Filename.temp_dir_name
      "bayesian_runner_sh_test_" ""
  in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      let rec rm_tree p =
        if Sys_unix.is_directory_exn p then begin
          Sys_unix.readdir p
          |> Array.iter ~f:(fun child -> rm_tree (Filename.concat p child));
          Core_unix.rmdir p
        end
        else Core_unix.unlink p
      in
      try rm_tree dir with _ -> ())

(* ---------- promote_top_n_by_score ---------- *)

let _params_of s : (string * float) list = [ ("x", s) ]

let test_promote_top_n_takes_highest_scores _ =
  (* Higher scores first; ties preserve original order (stable). *)
  let candidates =
    [
      (_params_of 1.0, 0.5);
      (_params_of 2.0, 0.9);
      (_params_of 3.0, 0.7);
      (_params_of 4.0, 0.3);
    ]
  in
  let promoted = SH.promote_top_n_by_score candidates ~n:2 in
  assert_that promoted
    (elements_are
       [
         all_of
           [
             field (fun (_, s) -> s) (float_equal 0.9);
             field
               (fun (p, _) -> List.Assoc.find_exn p ~equal:String.equal "x")
               (float_equal 2.0);
           ];
         all_of
           [
             field (fun (_, s) -> s) (float_equal 0.7);
             field
               (fun (p, _) -> List.Assoc.find_exn p ~equal:String.equal "x")
               (float_equal 3.0);
           ];
       ])

let test_promote_top_n_n_at_or_above_size_returns_all _ =
  let candidates =
    [ (_params_of 1.0, 0.5); (_params_of 2.0, 0.3); (_params_of 3.0, 0.9) ]
  in
  let promoted = SH.promote_top_n_by_score candidates ~n:5 in
  assert_that promoted (size_is 3)

let test_promote_top_n_zero_returns_empty _ =
  let candidates = [ (_params_of 1.0, 0.5); (_params_of 2.0, 0.9) ] in
  let promoted = SH.promote_top_n_by_score candidates ~n:0 in
  assert_that promoted (size_is 0)

let test_promote_top_n_negative_returns_empty _ =
  let candidates = [ (_params_of 1.0, 0.5); (_params_of 2.0, 0.9) ] in
  let promoted = SH.promote_top_n_by_score candidates ~n:(-3) in
  assert_that promoted (size_is 0)

let test_promote_top_n_ties_stable_by_input_order _ =
  (* Equal scores must preserve input order (List.stable_sort contract). The
     first equal-scored element is taken when only one is promoted. *)
  let candidates =
    [ (_params_of 1.0, 0.5); (_params_of 2.0, 0.5); (_params_of 3.0, 0.5) ]
  in
  let promoted = SH.promote_top_n_by_score candidates ~n:1 in
  assert_that promoted
    (elements_are
       [
         field
           (fun (p, _) -> List.Assoc.find_exn p ~equal:String.equal "x")
           (float_equal 1.0);
       ])

(* ---------- survivor_count ---------- *)

let test_survivor_count_ceil_division _ =
  (* 10 * 0.5 = 5; 10 * 0.25 = 2.5 → ceil → 3. *)
  assert_that (SH.survivor_count ~prior:10 ~fraction:0.5) (equal_to 5);
  assert_that (SH.survivor_count ~prior:10 ~fraction:0.25) (equal_to 3)

let test_survivor_count_minimum_one _ =
  (* No tier ever fully prunes. With prior=1 and fraction=0.5,
     ceil(0.5)=1 — but even with prior=0 the floor is 1. *)
  assert_that (SH.survivor_count ~prior:0 ~fraction:0.5) (equal_to 1);
  assert_that (SH.survivor_count ~prior:1 ~fraction:0.5) (equal_to 1)

let test_survivor_count_fraction_one_keeps_all _ =
  assert_that (SH.survivor_count ~prior:7 ~fraction:1.0) (equal_to 7)

let test_survivor_count_invalid_fraction_raises _ =
  let raised =
    try
      let _ = SH.survivor_count ~prior:10 ~fraction:0.0 in
      false
    with Invalid_argument _ -> true
  in
  assert_that raised (equal_to true);
  let raised_high =
    try
      let _ = SH.survivor_count ~prior:10 ~fraction:1.5 in
      false
    with Invalid_argument _ -> true
  in
  assert_that raised_high (equal_to true)

(* ---------- build_walk_forward_spec_for_tier ---------- *)

let _date y m d = Date.create_exn ~y ~m:(Month.of_int_exn m) ~d

let _make_template_spec () : Wf_spec.t =
  {
    base_scenario = "ignored.sexp";
    window_spec =
      Tiered
        {
          start_date = _date 2020 1 1;
          end_date = _date 2020 12 31;
          train_days = 60;
          tiers =
            [
              { name = "cheap"; fold_count = 2; horizon_days = 30 };
              { name = "medium"; fold_count = 4; horizon_days = 30 };
            ];
        };
    variants = [];
    baseline_label = "cell-E";
    gate = { metric = Sharpe; m = 2; n = 3; worst_delta = 0.30 };
  }

let _make_tiered_spec () : Wf_window.tiered_spec =
  {
    start_date = _date 2020 1 1;
    end_date = _date 2020 12 31;
    train_days = 60;
    tiers =
      [
        { name = "cheap"; fold_count = 2; horizon_days = 30 };
        { name = "medium"; fold_count = 4; horizon_days = 30 };
      ];
  }

let test_build_walk_forward_spec_for_tier_isolates_one_tier _ =
  (* The substituted window_spec must carry exactly one tier (the one we asked
     for) and preserve start_date / end_date / train_days from the original
     tiered spec. *)
  let template = _make_template_spec () in
  let tiered = _make_tiered_spec () in
  let medium_tier =
    { Wf_window.name = "medium"; fold_count = 4; horizon_days = 30 }
  in
  let result =
    SH.build_walk_forward_spec_for_tier ~template ~tiered ~tier:medium_tier
  in
  assert_that result.window_spec
    (matching ~msg:"expected single-tier Tiered window_spec"
       (function Wf_window.Tiered ts -> Some ts | _ -> None)
       (all_of
          [
            field
              (fun ts -> ts.Wf_window.start_date)
              (equal_to (_date 2020 1 1));
            field
              (fun ts -> ts.Wf_window.end_date)
              (equal_to (_date 2020 12 31));
            field (fun ts -> ts.Wf_window.train_days) (equal_to 60);
            field
              (fun ts -> ts.Wf_window.tiers)
              (elements_are
                 [
                   all_of
                     [
                       field
                         (fun (t : Wf_window.tier) -> t.name)
                         (equal_to "medium");
                       field
                         (fun (t : Wf_window.tier) -> t.fold_count)
                         (equal_to 4);
                       field
                         (fun (t : Wf_window.tier) -> t.horizon_days)
                         (equal_to 30);
                     ];
                 ]);
          ]))

let test_build_walk_forward_spec_for_tier_preserves_template_fields _ =
  (* Other template fields (base_scenario, baseline_label, gate) flow through
     unchanged so the per-tier scoring inherits the same gate + baseline as
     the multi-tier template. *)
  let template = _make_template_spec () in
  let tiered = _make_tiered_spec () in
  let cheap_tier =
    { Wf_window.name = "cheap"; fold_count = 2; horizon_days = 30 }
  in
  let result =
    SH.build_walk_forward_spec_for_tier ~template ~tiered ~tier:cheap_tier
  in
  assert_that result
    (all_of
       [
         field (fun s -> s.Wf_spec.base_scenario) (equal_to "ignored.sexp");
         field (fun s -> s.Wf_spec.baseline_label) (equal_to "cell-E");
         field
           (fun s -> s.Wf_spec.gate)
           (field (fun (g : FG.t) -> g.m) (equal_to 2));
       ])

(* ---------- end-to-end SH orchestration (stub evaluators) ---------- *)

(** A tier-aware stub evaluator builder: the score for a given [x] depends on
    the tier (looked up by [walk_forward_spec.window_spec]'s single tier name).
    Higher tiers apply a scaling so the score-ranking shifts predictably; this
    lets the test pin that survivors are re-evaluated at the new tier rather
    than reusing the cheap-tier score. *)
let _tier_scale_for_name name =
  match name with
  | "cheap" -> 1.0
  | "medium" -> 2.0
  | "expensive" -> 3.0
  | _ -> 1.0

(** Extract the single-tier name from a per-stage walk-forward spec — every spec
    the orchestrator hands the builder is a single-tier Tiered shape per
    [build_walk_forward_spec_for_tier]'s contract. *)
let _single_tier_name (wf_spec : Wf_spec.t) =
  match wf_spec.window_spec with
  | Tiered ts -> (List.hd_exn ts.tiers).name
  | _ -> failwith "test stub: expected single-tier Tiered window_spec"

(** Build a parabolic evaluator whose maximum is at [x=3.0] with peak
    [_tier_scale_for_name tier_name * 0.0] — i.e. the apex value at x=3 is 0.0
    irrespective of tier (so the BO cheap stage and the higher-tier re-eval both
    prefer x ≈ 3). Away from the apex the score scales with tier; this pins that
    re-eval at the higher tier returns a tier-scaled value (medium = 2x,
    expensive = 3x the cheap loss magnitude). *)
let _make_stub_evaluator_builder ~calls_per_tier : SH.evaluator_builder =
 fun ~walk_forward_spec ->
  let tier_name = _single_tier_name walk_forward_spec in
  let scale = _tier_scale_for_name tier_name in
  fun ~parameters ->
    Hashtbl.update calls_per_tier tier_name ~f:(function
      | None -> 1
      | Some n -> n + 1);
    let x = List.Assoc.find_exn parameters ~equal:String.equal "x" in
    let loss = (x -. 3.0) *. (x -. 3.0) in
    let metric = -.(loss *. scale) in
    let empty = Map.empty (module Metric_types.Metric_type) in
    (metric, [ empty ])

let _make_sh_spec ~total_budget ~seed : Spec.t =
  {
    bounds = [ ("x", (0.0, 10.0)) ];
    acquisition = Spec.Expected_improvement;
    initial_random = 4;
    total_budget;
    seed = Some seed;
    n_acquisition_candidates = None;
    objective = Spec.Sharpe;
    scenarios = [ "stub-scenario" ];
    holdout_folds = None;
    sentinel_bounds = None;
    length_scales = None;
    early_stop = None;
    gate_penalty_value = None;
    int_keys = [];
  }

let _make_three_tier_spec () : Wf_window.tiered_spec =
  {
    start_date = _date 2020 1 1;
    end_date = _date 2020 12 31;
    train_days = 60;
    tiers =
      [
        { name = "cheap"; fold_count = 2; horizon_days = 30 };
        { name = "medium"; fold_count = 3; horizon_days = 30 };
        { name = "expensive"; fold_count = 4; horizon_days = 30 };
      ];
  }

let _make_three_tier_template () : Wf_spec.t =
  {
    base_scenario = "ignored.sexp";
    window_spec = Wf_window.Tiered (_make_three_tier_spec ());
    variants = [];
    baseline_label = "cell-E";
    gate = { metric = Sharpe; m = 2; n = 3; worst_delta = 0.30 };
  }

let test_run_produces_one_per_tier_result_per_tier _ =
  let spec = _make_sh_spec ~total_budget:10 ~seed:7 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      (* Three tiers in: cheap → medium → expensive. *)
      assert_that result.per_tier (size_is 3))

let test_run_survivor_count_decreases_per_stage _ =
  (* Cheap stage: 10 BO iterations → 10 candidates. Medium (fraction 0.5) →
     5 survivors. Expensive (fraction 0.5) → 3 survivors (ceil(5*0.5)). *)
  let spec = _make_sh_spec ~total_budget:10 ~seed:7 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      assert_that result.per_tier
        (elements_are
           [
             field (fun r -> r.SH.survivor_count) (equal_to 10);
             field (fun r -> r.SH.survivor_count) (equal_to 5);
             field (fun r -> r.SH.survivor_count) (equal_to 3);
           ]))

let test_run_higher_tiers_only_evaluate_survivors _ =
  (* Cheap tier evaluator: 10 calls (= total_budget). Medium: 5 calls (top 5
     survivors). Expensive: 3 calls (top 3 of the medium survivors).
     Pins that higher tiers do NOT re-sample; they only re-eval. *)
  let spec = _make_sh_spec ~total_budget:10 ~seed:7 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      assert_that
        ( Hashtbl.find_exn calls_per_tier "cheap",
          Hashtbl.find_exn calls_per_tier "medium",
          Hashtbl.find_exn calls_per_tier "expensive" )
        (equal_to (10, 5, 3)))

let test_run_writes_summary_and_best_files _ =
  let spec = _make_sh_spec ~total_budget:8 ~seed:3 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      let summary_path =
        Filename.concat out_dir "successive_halving_summary.md"
      in
      let best_path = Filename.concat out_dir "best.sexp" in
      assert_that
        ( Sys_unix.file_exists_exn summary_path,
          Sys_unix.file_exists_exn best_path )
        (equal_to (true, true)))

let test_run_writes_per_tier_promotion_csvs _ =
  let spec = _make_sh_spec ~total_budget:8 ~seed:3 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      let cheap_csv = Filename.concat out_dir "promotion_cheap.csv" in
      let medium_csv = Filename.concat out_dir "promotion_medium.csv" in
      let expensive_csv = Filename.concat out_dir "promotion_expensive.csv" in
      assert_that
        ( Sys_unix.file_exists_exn cheap_csv,
          Sys_unix.file_exists_exn medium_csv,
          Sys_unix.file_exists_exn expensive_csv )
        (equal_to (true, true, true)))

let test_run_writes_cheap_stage_files_in_per_tier_subdir _ =
  (* The cheap-stage BO loop runs via Runner.run_and_write, which emits its
     standard quartet (bo_log.csv / convergence.md / bo_checkpoint.sexp /
     best.sexp) into the out_dir it is handed. The SH orchestrator hands it
     <out_dir>/<cheap-tier-name>/ so those files live in a per-tier
     subdirectory — pinned here so the .mli's documented layout cannot
     silently drift away from the implementation. *)
  let spec = _make_sh_spec ~total_budget:8 ~seed:3 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      let cheap_dir = Filename.concat out_dir "cheap" in
      let cheap_bo_log = Filename.concat cheap_dir "bo_log.csv" in
      let cheap_convergence = Filename.concat cheap_dir "convergence.md" in
      let cheap_checkpoint = Filename.concat cheap_dir "bo_checkpoint.sexp" in
      assert_that
        ( Sys_unix.file_exists_exn cheap_bo_log,
          Sys_unix.file_exists_exn cheap_convergence,
          Sys_unix.file_exists_exn cheap_checkpoint )
        (equal_to (true, true, true)))

let test_run_best_is_from_last_tier_scores _ =
  (* The per_tier candidates are sorted descending; the final winner must
     equal per_tier's last tier's head. *)
  let spec = _make_sh_spec ~total_budget:8 ~seed:3 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ()
      in
      let last_tier = List.last_exn result.per_tier in
      let head_params, head_score = List.hd_exn last_tier.candidates in
      assert_that
        (result.best_params, result.best_score)
        (equal_to (head_params, head_score)))

let test_run_empty_tiers_raises _ =
  let spec = _make_sh_spec ~total_budget:8 ~seed:3 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  let empty_tiered : Wf_window.tiered_spec =
    {
      start_date = _date 2020 1 1;
      end_date = _date 2020 12 31;
      train_days = 60;
      tiers = [];
    }
  in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let raised =
        try
          let _ =
            SH.run ~spec ~tiered:empty_tiered
              ~walk_forward_spec_template:(_make_three_tier_template ())
              ~build_evaluator ~out_dir ()
          in
          false
        with Failure msg ->
          String.is_substring msg ~substring:"tiers must be non-empty"
      in
      assert_that raised (equal_to true))

let test_run_custom_promotion_fractions _ =
  (* With three tiers + promotion_fractions=[0.30; 1.0] and budget 10:
     cheap → 10 candidates → top 30% = 3 → medium runs 3 → top 100% = 3 →
     expensive runs 3. *)
  let spec = _make_sh_spec ~total_budget:10 ~seed:5 in
  let calls_per_tier = Hashtbl.create (module String) in
  let build_evaluator = _make_stub_evaluator_builder ~calls_per_tier in
  _with_temp_dir (fun dir ->
      let out_dir = Filename.concat dir "out" in
      let _result =
        SH.run ~spec ~tiered:(_make_three_tier_spec ())
          ~walk_forward_spec_template:(_make_three_tier_template ())
          ~build_evaluator ~out_dir ~promotion_fractions:[ 0.30; 1.0 ] ()
      in
      assert_that
        ( Hashtbl.find_exn calls_per_tier "cheap",
          Hashtbl.find_exn calls_per_tier "medium",
          Hashtbl.find_exn calls_per_tier "expensive" )
        (equal_to (10, 3, 3)))

let test_default_promotion_fractions_match_plan _ =
  (* M1 plan defaults: 0.50, 0.50, 1.0. Greppable assertion so the constants
     don't silently drift. *)
  assert_that SH.default_promotion_fractions
    (elements_are [ float_equal 0.5; float_equal 0.5; float_equal 1.0 ])

let suite =
  "Tuner_bin.Bayesian_runner_successive_halving"
  >::: [
         "promote_top_n: takes the highest-scored candidates"
         >:: test_promote_top_n_takes_highest_scores;
         "promote_top_n: n >= size returns the full list"
         >:: test_promote_top_n_n_at_or_above_size_returns_all;
         "promote_top_n: n = 0 returns empty"
         >:: test_promote_top_n_zero_returns_empty;
         "promote_top_n: n < 0 returns empty"
         >:: test_promote_top_n_negative_returns_empty;
         "promote_top_n: ties resolved by stable input order"
         >:: test_promote_top_n_ties_stable_by_input_order;
         "survivor_count: ceiling division"
         >:: test_survivor_count_ceil_division;
         "survivor_count: minimum 1" >:: test_survivor_count_minimum_one;
         "survivor_count: fraction 1.0 keeps all"
         >:: test_survivor_count_fraction_one_keeps_all;
         "survivor_count: invalid fraction raises Invalid_argument"
         >:: test_survivor_count_invalid_fraction_raises;
         "build_walk_forward_spec_for_tier: isolates one tier"
         >:: test_build_walk_forward_spec_for_tier_isolates_one_tier;
         "build_walk_forward_spec_for_tier: preserves template fields"
         >:: test_build_walk_forward_spec_for_tier_preserves_template_fields;
         "run: produces one per_tier_result per tier"
         >:: test_run_produces_one_per_tier_result_per_tier;
         "run: survivor count decreases per stage"
         >:: test_run_survivor_count_decreases_per_stage;
         "run: higher tiers only evaluate survivors (no re-sampling)"
         >:: test_run_higher_tiers_only_evaluate_survivors;
         "run: writes summary + best.sexp"
         >:: test_run_writes_summary_and_best_files;
         "run: writes per-tier promotion csvs"
         >:: test_run_writes_per_tier_promotion_csvs;
         "run: writes cheap-stage files in <cheap-tier-name>/ subdirectory"
         >:: test_run_writes_cheap_stage_files_in_per_tier_subdir;
         "run: best_params is the last tier's top survivor"
         >:: test_run_best_is_from_last_tier_scores;
         "run: empty tiers list raises Failure" >:: test_run_empty_tiers_raises;
         "run: custom promotion_fractions threaded through"
         >:: test_run_custom_promotion_fractions;
         "default_promotion_fractions match plan"
         >:: test_default_promotion_fractions_match_plan;
       ]

let () = run_test_tt_main suite
