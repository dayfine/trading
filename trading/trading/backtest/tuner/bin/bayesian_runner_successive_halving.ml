open Core
module Runner = Bayesian_runner_runner
module Wf_spec = Walk_forward.Spec
module Wf_window = Walk_forward.Window_spec

type per_tier_result = {
  tier_name : string;
  candidates : ((string * float) list * float) list;
  survivor_count : int;
}

type result = {
  per_tier : per_tier_result list;
  best_params : (string * float) list;
  best_score : float;
}

type evaluator_builder = walk_forward_spec:Wf_spec.t -> Runner.evaluator

(** Default per-tier promotion fractions, matching the M1 plan defaults (cheap →
    medium: 50%, medium → expensive: 50% [= 25% of original], expensive →
    ambitious: 100% [no further pruning]). Excess tiers default to [1.0]. *)
let default_promotion_fractions = [ 0.5; 0.5; 1.0 ]

let _fraction_for_stage promotion_fractions ~stage =
  match List.nth promotion_fractions stage with
  | Some f -> f
  | None ->
      (* Excess tiers fall back to no further pruning. Documented in the .mli's
         contract for default_promotion_fractions. *)
      1.0

(** Ceiling-division survivor count with a minimum of 1. Pinned in the .mli so a
    tier can never fully prune the population. *)
let survivor_count ~prior ~fraction =
  if Float.(fraction <= 0.0) || Float.(fraction > 1.0) then
    raise
      (Invalid_argument
         (sprintf "survivor_count: fraction must be in (0.0, 1.0], got %f"
            fraction));
  let raw = Float.iround_up_exn (Float.of_int prior *. fraction) in
  Int.max 1 raw

(** Sort the candidates descending by score, take the top [n].
    [List.stable_sort] preserves original order for ties — important so the
    survivor selection is deterministic when the BO produces multiple equal
    scores. *)
let promote_top_n_by_score candidates ~n =
  if n <= 0 then []
  else
    let sorted =
      List.stable_sort candidates ~compare:(fun (_, sa) (_, sb) ->
          (* Descending: b before a. *)
          Float.compare sb sa)
    in
    List.take sorted n

(** [build_walk_forward_spec_for_tier] — substitute the template's window_spec
    with a single-tier Tiered shape carrying only [tier]. The tiered_spec's
    start_date / end_date / train_days are preserved so the fold layout is
    identical to what the original multi-tier spec would have produced for that
    tier. *)
let build_walk_forward_spec_for_tier ~(template : Wf_spec.t)
    ~(tiered : Wf_window.tiered_spec) ~(tier : Wf_window.tier) : Wf_spec.t =
  let single_tier_window : Wf_window.t =
    Tiered
      {
        start_date = tiered.start_date;
        end_date = tiered.end_date;
        train_days = tiered.train_days;
        tiers = [ tier ];
      }
  in
  { template with window_spec = single_tier_window }

(* ----------------------------------------------------------------- *)
(* Stage 0 — cheap tier: full BO loop via Runner.run_and_write.        *)
(* ----------------------------------------------------------------- *)

(** Run the BO loop on the cheap tier and project its observations into the
    [(parameters, score)] shape the higher tiers consume. The Runner's
    [run_and_write] writes the checkpoint + bo_log.csv into [out_dir]; we
    capture only the per-iteration scores here. *)
let _run_cheap_stage ~spec ~tier ~tiered ~walk_forward_spec_template
    ~build_evaluator ~out_dir : per_tier_result =
  let walk_forward_spec =
    build_walk_forward_spec_for_tier ~template:walk_forward_spec_template
      ~tiered ~tier
  in
  let evaluator = build_evaluator ~walk_forward_spec in
  let stage_out_dir = Filename.concat out_dir tier.name in
  let runner_result =
    Runner.run_and_write ~spec ~out_dir:stage_out_dir ~evaluator
  in
  let candidates =
    List.map runner_result.observations ~f:(fun obs ->
        (obs.Tuner.Bayesian_opt.parameters, obs.metric))
  in
  let sorted =
    List.stable_sort candidates ~compare:(fun (_, sa) (_, sb) ->
        Float.compare sb sa)
  in
  {
    tier_name = tier.name;
    candidates = sorted;
    survivor_count = List.length sorted;
  }

(* ----------------------------------------------------------------- *)
(* Stages 1+ — higher tiers: re-evaluate fixed survivors.              *)
(* ----------------------------------------------------------------- *)

(** Re-evaluate one survivor on a higher-tier evaluator. Returns the new
    (parameters, score) pair. *)
let _re_evaluate_one ~evaluator (parameters, _prior_score) =
  let score, _metric_sets = evaluator ~parameters in
  (parameters, score)

let _run_higher_stage ~tier ~tiered ~walk_forward_spec_template ~build_evaluator
    ~(survivors : ((string * float) list * float) list) : per_tier_result =
  let walk_forward_spec =
    build_walk_forward_spec_for_tier ~template:walk_forward_spec_template
      ~tiered ~tier
  in
  let evaluator = build_evaluator ~walk_forward_spec in
  let rescored = List.map survivors ~f:(_re_evaluate_one ~evaluator) in
  let sorted =
    List.stable_sort rescored ~compare:(fun (_, sa) (_, sb) ->
        Float.compare sb sa)
  in
  {
    tier_name = tier.name;
    candidates = sorted;
    survivor_count = List.length sorted;
  }

(* ----------------------------------------------------------------- *)
(* Output writers.                                                     *)
(* ----------------------------------------------------------------- *)

let _write_best_sexp ~out_dir ~int_keys ~best_params =
  let path = Filename.concat out_dir "best.sexp" in
  let sexps = Tuner.Grid_search.cell_to_overrides ~int_keys best_params in
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum (Sexp.List sexps));
      Out_channel.output_string oc "\n")

let _summary_line tier_result =
  let best_score =
    match tier_result.candidates with
    | [] -> Float.neg_infinity
    | (_, s) :: _ -> s
  in
  sprintf "| %s | %d | %.6f |\n" tier_result.tier_name
    tier_result.survivor_count best_score

let _write_summary ~out_dir ~per_tier ~best_score =
  let path = Filename.concat out_dir "successive_halving_summary.md" in
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc
        "# Successive halving summary\n\n\
         Per-stage survivor count + best score on that tier's fidelity. The \
         final winner's score is the LAST tier's best score (highest \
         fidelity).\n\n\
         | Tier | Survivors | Best score |\n\
         |---|---:|---:|\n";
      List.iter per_tier ~f:(fun r ->
          Out_channel.output_string oc (_summary_line r));
      Out_channel.output_string oc
        (sprintf "\nFinal best score: %.6f\n" best_score))

let _write_promotion_csv ~out_dir ~tier_name ~candidates =
  let path = Filename.concat out_dir (sprintf "promotion_%s.csv" tier_name) in
  Out_channel.with_file path ~f:(fun oc ->
      Out_channel.output_string oc "rank,score,parameters\n";
      List.iteri candidates ~f:(fun i (params, score) ->
          let params_str =
            List.map params ~f:(fun (k, v) -> sprintf "%s=%.6g" k v)
            |> String.concat ~sep:";"
          in
          Out_channel.output_string oc
            (sprintf "%d,%.6f,%s\n" i score params_str)))

(* ----------------------------------------------------------------- *)
(* Top-level run.                                                      *)
(* ----------------------------------------------------------------- *)

let _validate_inputs ~(tiered : Wf_window.tiered_spec) =
  if List.is_empty tiered.tiers then
    failwith
      "Bayesian_runner_successive_halving.run: tiered.tiers must be non-empty"

let _final_winner per_tier =
  match List.last per_tier with
  | None ->
      (* Defensive — _validate_inputs already ensures tiers non-empty. *)
      ([], Float.neg_infinity)
  | Some last_stage -> (
      match last_stage.candidates with
      | [] -> ([], Float.neg_infinity)
      | (params, score) :: _ -> (params, score))

let run ~(spec : Bayesian_runner_spec.t) ~(tiered : Wf_window.tiered_spec)
    ~(walk_forward_spec_template : Wf_spec.t)
    ~(build_evaluator : evaluator_builder) ~(out_dir : string)
    ?(promotion_fractions = default_promotion_fractions) () : result =
  _validate_inputs ~tiered;
  Core_unix.mkdir_p out_dir;
  let tiers = tiered.tiers in
  let first_tier = List.hd_exn tiers in
  let rest_tiers = List.tl_exn tiers in
  let cheap =
    _run_cheap_stage ~spec ~tier:first_tier ~tiered ~walk_forward_spec_template
      ~build_evaluator ~out_dir
  in
  _write_promotion_csv ~out_dir ~tier_name:cheap.tier_name
    ~candidates:cheap.candidates;
  let _, all_stages_rev =
    List.foldi rest_tiers ~init:(cheap, [ cheap ])
      ~f:(fun stage_idx (prior, acc) tier ->
        let fraction =
          _fraction_for_stage promotion_fractions ~stage:stage_idx
        in
        let n =
          survivor_count ~prior:(List.length prior.candidates) ~fraction
        in
        let survivors = promote_top_n_by_score prior.candidates ~n in
        let stage =
          _run_higher_stage ~tier ~tiered ~walk_forward_spec_template
            ~build_evaluator ~survivors
        in
        _write_promotion_csv ~out_dir ~tier_name:stage.tier_name
          ~candidates:stage.candidates;
        (stage, stage :: acc))
  in
  let per_tier = List.rev all_stages_rev in
  let best_params, best_score = _final_winner per_tier in
  _write_best_sexp ~out_dir ~int_keys:spec.int_keys ~best_params;
  _write_summary ~out_dir ~per_tier ~best_score;
  { per_tier; best_params; best_score }
