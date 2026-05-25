(** Multi-fidelity successive-halving orchestrator for the Bayesian-optimisation
    runner.

    M1 T1.2 of the tuning research-driven program (see
    [dev/plans/tuning-research-driven-program-v2-2026-05-25.md]).

    The successive-halving (SH) loop processes a
    {!Walk_forward.Window_spec.Tiered} spec in tier order (cheap → medium →
    expensive → ambitious). For each tier:

    + {b Stage 0 (the cheap / first tier).} A standard BO ask/tell loop runs for
      [spec.total_budget] iterations on a walk-forward spec restricted to that
      tier's folds. Every suggestion is scored on the cheap-fidelity proxy.
    + {b Stage 1+ (medium / expensive / ambitious).} The top-K survivors of the
      prior stage's score-ranking are RE-EVALUATED on this tier's folds. No new
      BO sampling — the candidates are fixed at the cheap-tier choices. Each
      stage refits no GP (BOHB-style: subsequent tiers are pure re-scoring).
    + Survivor count per stage is computed by applying the configured fraction
      to the prior stage's survivor count (rounded up, minimum 1).

    The final winner is the highest-scoring survivor at the last tier.

    {b Why pure re-eval at higher tiers?} The plan's task description names the
    flag [--fidelity-strategy successive_halving], which is the canonical BOHB
    rung-pattern: sample once (or BO-sample) at the cheap rung, then promote
    top-K% to higher rungs unchanged. The expensive rungs are not a sampling
    surface; they're a verification surface.

    Output layout under [out_dir]:

    {v
      <cheap-tier-name>/bo_log.csv         ← cheap stage, full BO loop
      <cheap-tier-name>/convergence.md
      <cheap-tier-name>/bo_checkpoint.sexp ← cheap-stage checkpoint (resume source)
      <cheap-tier-name>/best.sexp          ← cheap-stage argmax (Runner-emitted)
      promotion_<tier-name>.csv            ← per-tier survivor scores (one per tier, top-level)
      best.sexp                            ← final winner across all tiers (top-level)
      successive_halving_summary.md        ← per-stage survivor counts + best score
    v}

    The cheap-stage artefacts live in a per-tier subdirectory (named for the
    cheap tier's [name]) because they are written by
    {!Bayesian_runner_runner.run_and_write}, which always emits its [bo_log.csv]
    / [convergence.md] / [bo_checkpoint.sexp] / [best.sexp] quartet into the
    [out_dir] it is given. The orchestrator hands it
    [<out_dir>/<cheap-tier-name>/] to keep cheap-stage files isolated from the
    top-level SH outputs and from any future per-tier artefacts.

    Cross-tier files ([promotion_<tier>.csv], [best.sexp],
    [successive_halving_summary.md]) live at the top level of [out_dir] —
    they're synthesised by the orchestrator across all tiers, not by any one
    tier's BO loop. *)

type per_tier_result = {
  tier_name : string;
      (** [Walk_forward.Window_spec.tier.name] this stage targeted. *)
  candidates : ((string * float) list * float) list;
      (** Every candidate evaluated at this tier paired with its tier-fidelity
          score, in descending-score order (best first). For the cheap tier this
          is the full BO loop's observations; for later tiers it is the
          re-scored survivors of the prior tier. *)
  survivor_count : int;
      (** [List.length candidates] before any further promotion — the actual
          population that entered the next tier (or the winner pool for the
          final tier). *)
}
(** What one stage of the SH pipeline produced. *)

type result = {
  per_tier : per_tier_result list;
      (** One entry per tier in evaluation order (cheap first). *)
  best_params : (string * float) list;
      (** Parameter assignment of the highest-scoring survivor at the FINAL
          tier. The successive-halving promotion criterion is the last tier's
          score, by design — that tier carries the most fidelity. *)
  best_score : float;  (** Final-tier score of [best_params]. *)
}
(** Outcome of an end-to-end successive-halving run. *)

type evaluator_builder =
  walk_forward_spec:Walk_forward.Spec.t -> Bayesian_runner_runner.evaluator
(** Build an evaluator parameterised by the per-tier walk-forward spec.
    Production wiring captures the [base], [baseline_aggregate], [executor],
    [objective], [fixtures_root], and [gate_penalty_value] in a closure and only
    varies the [walk_forward_spec] per call. *)

val promote_top_n_by_score :
  ((string * float) list * float) list ->
  n:int ->
  ((string * float) list * float) list
(** [promote_top_n_by_score candidates ~n] returns the [n] candidates with the
    highest scores, sorted descending by score. Ties resolve in original list
    order (stable sort, then take prefix). Returns the full input list when
    [n >= List.length candidates]; returns [[]] when [n <= 0]. *)

val survivor_count : prior:int -> fraction:float -> int
(** [survivor_count ~prior ~fraction] returns the integer survivor count for the
    next tier, computed as [ceil (prior * fraction)] with a minimum of 1 (no
    tier ever fully prunes the population). [fraction] must be in [(0.0, 1.0\]];
    raises [Invalid_argument] otherwise. *)

val default_promotion_fractions : float list
(** Default per-tier promotion fractions matching the plan defaults:

    - [0.50] — cheap tier keeps top 50% (promoted to medium tier).
    - [0.50] — medium tier keeps top 50% (= 25% of original; promoted to
      expensive tier).
    - [1.0] — expensive tier keeps all (= 25% of original; promoted to ambitious
      tier when present).

    The list length is [N - 1] where [N] is the number of tiers; the final tier
    has no further promotion. When the tiered spec has more than 4 tiers, excess
    tiers default to [1.0] (no further pruning). *)

val build_walk_forward_spec_for_tier :
  template:Walk_forward.Spec.t ->
  tiered:Walk_forward.Window_spec.tiered_spec ->
  tier:Walk_forward.Window_spec.tier ->
  Walk_forward.Spec.t
(** [build_walk_forward_spec_for_tier ~template ~tiered ~tier] returns a copy of
    [template] whose [window_spec] is restricted to a single-tier
    [Window_spec.Tiered] containing only [tier]. The [start_date], [end_date],
    and [train_days] from [tiered] are preserved. All other [template] fields
    ([base_scenario], [variants], [baseline_label], [gate]) pass through
    unchanged.

    Used by the orchestrator to materialise per-stage walk-forward specs from
    the input multi-tier spec — the evaluator's [walk_forward_spec] argument
    only carries one tier at a time. *)

val run :
  spec:Bayesian_runner_spec.t ->
  tiered:Walk_forward.Window_spec.tiered_spec ->
  walk_forward_spec_template:Walk_forward.Spec.t ->
  build_evaluator:evaluator_builder ->
  out_dir:string ->
  ?promotion_fractions:float list ->
  unit ->
  result
(** [run ~spec ~tiered ~walk_forward_spec_template ~build_evaluator ~out_dir
     ?promotion_fractions ()] drives the successive-halving pipeline.

    Cheap stage: builds a per-tier walk-forward spec via
    {!build_walk_forward_spec_for_tier}, constructs the evaluator with
    [build_evaluator], and runs the standard BO ask/tell loop via
    {!Bayesian_runner_runner.run_and_write}, which is handed
    [<out_dir>/<cheap-tier-name>/] so its standard quartet ([bo_log.csv] /
    [convergence.md] / [bo_checkpoint.sexp] / [best.sexp]) lands inside that
    subdirectory.

    Higher stages: for each tier after the first, the prior stage's top-K
    candidates (per [promotion_fractions]) are re-evaluated on this tier's
    walk-forward spec. Re-evaluation is sequential — one evaluator call per
    survivor. The new scores produce a fresh ranking for the next promotion.

    Final outputs at the top level of [out_dir]:

    - [promotion_<tier-name>.csv] — one file per tier (cheap + each higher
      tier), holding that tier's candidates sorted descending by score
    - [best.sexp] — the winner's parameter overrides (last tier's argmax)
    - [successive_halving_summary.md] — per-stage table of (tier, survivors,
      best_score)

    Cheap-stage Runner-emitted files live in the per-tier subdirectory
    [<out_dir>/<cheap-tier-name>/] — see the module-level Output Layout block.

    Raises [Failure] when [tiered.tiers = []] (caller's responsibility to reject
    empty tier lists; this is a defensive check), and propagates any [Failure]
    from the evaluator. *)
