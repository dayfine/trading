(** Pure helpers for re-scoring existing BO sweep outputs with paired-Δ.

    Plan: [dev/plans/tuning-research-driven-program-v2-2026-05-25.md] §M1 T1.5.

    The v3–v6 production sweeps measured a flat ~0.81-spread score surface
    across 60+ candidates because per-fold absolute-Sharpe variance dominated
    knob-to-knob signal. T1.3 added the {!Bayesian_runner_scoring.paired_delta}
    primitive which cancels that common-mode noise by differencing each fold's
    candidate vs. Cell-E baseline. T1.5 (this module) is the consumer: read the
    per-iteration fold actuals from a previously-run BO sweep + Cell-E's
    per-fold actuals from the walk-forward baseline, re-score every candidate
    with paired-Δ, and report the spread across candidates.

    {b Input file shape — [bo_rescore_input].}

    The production [bo_checkpoint.sexp] (see {!Bayesian_runner_runner}) does not
    persist per-fold actuals per iteration — only the aggregated score. T1.5
    expects an {i enriched} input file that pairs each BO iteration's parameters
    / label with the per-fold {!Walk_forward.Walk_forward_types.fold_actual}
    list that produced its score. The shape is:

    {v
      ((schema_version 1)
       (candidates
         (((label "bo-iter-000")
           (parameters ((knob_a 0.30) (knob_b 0.65)))
           (fold_actuals
             (((fold_name "fold-000") (variant_label "bo-iter-000")
               (total_return_pct 5.0) (sharpe_ratio 0.7)
               (max_drawdown_pct -8.0) (calmar_ratio 0.6)
               (cagr_pct 5.0) (avg_holding_days 22.0))
              ...)))
          ((label "bo-iter-001") ...))))
    v}

    Production runs after T1.5 lands will need a small adapter to produce this
    file from BO sweep outputs (re-running each iteration's walk-forward CV
    captures the [fold_actuals]; the alternative is patching the BO runner to
    persist fold actuals inline as part of each iteration — out of scope here).
    The synthetic fixtures in the unit tests exercise the rescorer end-to-end
    without touching production data. *)

type candidate = {
  label : string;
      (** Stable label for this candidate (e.g. ["bo-iter-007"]). Surfaced in
          the report so the operator can correlate to the BO log. *)
  parameters : (string * float) list;
      (** Knob assignment that produced this candidate's score. Surfaced in the
          report only — the rescorer does not act on it. *)
  fold_actuals : Walk_forward.Walk_forward_types.fold_actual list;
      (** Per-fold actuals for this candidate. Matched by [fold_name] against
          the baseline fold_actuals; matching is order-independent. *)
}
[@@deriving sexp]
(** Per-iteration record carried in the input file: parameters that produced the
    iteration plus its per-fold actuals (used for paired-Δ matching). *)

type bo_rescore_input = { schema_version : int; candidates : candidate list }
[@@deriving sexp]
(** Top-level shape of the rescore input sexp file. [schema_version] guards
    against future shape drift; the current version is [1]. *)

val current_schema_version : int
(** Current [schema_version] for {!bo_rescore_input}. Files written today carry
    this value; the loader rejects files with a different value so the sexp
    shape can evolve safely. *)

type candidate_rescore = {
  label : string;
  parameters : (string * float) list;
  mean_delta : float;
      (** Mirror of {!Bayesian_runner_scoring.paired_delta_stats.mean_delta}. *)
  stdev_delta : float;
      (** Mirror of {!Bayesian_runner_scoring.paired_delta_stats.stdev_delta}.
      *)
  n_matched : int;
      (** Mirror of {!Bayesian_runner_scoring.paired_delta_stats.n_matched}. *)
}
[@@deriving sexp]
(** Per-candidate re-score result. Carries the candidate identity plus the
    paired-Δ stats produced by {!Bayesian_runner_scoring.paired_delta}.

    The stats are flattened into individual fields (rather than embedding
    {!Bayesian_runner_scoring.paired_delta_stats}) because that type does not
    derive [sexp] — flattening keeps the [sexp]-derived shape stable for on-disk
    debug dumps without coupling to upstream sexp annotations. *)

(** Verdict on whether the re-scored surface meets the T1.5 acceptance gate
    (spread > 5× the historical 0.81 flat surface = 4.05). *)
type verdict = Pass | Fail [@@deriving sexp]

type report = {
  candidates : candidate_rescore list;
  spread : float;
      (** [max(mean_delta) - min(mean_delta)] across candidates. Empty candidate
          list yields [0.0] (will FAIL the acceptance gate). *)
  min_spread : float;
      (** Acceptance threshold the spread is compared against. Default
          {!default_min_spread}; CLI [--min-spread] overrides. *)
  verdict : verdict;
}
[@@deriving sexp]
(** Full re-score report — one row per candidate plus the aggregate spread
    metric and verdict. *)

val historical_flat_surface : float
(** The v3–v6 production flat-surface score range, in absolute-Sharpe units.
    Value: [0.81]. Source: per-track diagnosis recorded in
    `dev/notes/bayesian-prod-v6-result-*.md` (referenced from plan §M1 T1.3).
    Exposed so the report can quote it next to the threshold. *)

val flat_surface_multiplier : float
(** Multiplier on {!historical_flat_surface} that defines the acceptance gate.
    Value: [5.0]. Plan §M1 T1.5: "spread > 5× the old 0.81". *)

val default_min_spread : float
(** Default minimum-spread acceptance threshold —
    [historical_flat_surface *. flat_surface_multiplier = 4.05]. The CLI's
    [--min-spread] flag overrides this value. *)

val load_input : string -> bo_rescore_input
(** [load_input path] loads + sexp-parses the {!bo_rescore_input} from [path].
    Raises [Failure] if [schema_version] does not equal
    {!current_schema_version}. *)

val load_baseline_fold_actuals :
  string -> Walk_forward.Walk_forward_types.fold_actual list
(** [load_baseline_fold_actuals path] loads the Cell-E baseline's per-fold
    actuals from [path]. The expected on-disk shape matches the
    [fold_actuals.sexp] produced by
    {!Walk_forward.Walk_forward_runner._write_fold_actuals}: a top-level
    [Sexp.List] of {!Walk_forward.Walk_forward_types.fold_actual} sexps. *)

val rescore_candidate :
  candidate ->
  baseline_fold_actuals:Walk_forward.Walk_forward_types.fold_actual list ->
  metric:[ `Sharpe | `Total_return_pct | `Calmar | `CAGR ] ->
  candidate_rescore
(** [rescore_candidate cand ~baseline_fold_actuals ~metric] re-scores a single
    candidate by computing per-fold Δ vs. the baseline via
    {!Bayesian_runner_scoring.paired_delta}, matched by [fold_name].

    Raises [Failure] (propagated from {!Bayesian_runner_scoring.paired_delta})
    when no fold names overlap between [cand.fold_actuals] and
    [baseline_fold_actuals]. A disjoint pair is a callsite bug — the candidate
    and baseline must have been run on the same walk-forward spec. *)

val spread_of : float list -> float
(** [spread_of xs] returns [max xs - min xs], or [0.0] for an empty list. Pure
    helper exposed for test introspection. *)

val build_report :
  input:bo_rescore_input ->
  baseline_fold_actuals:Walk_forward.Walk_forward_types.fold_actual list ->
  metric:[ `Sharpe | `Total_return_pct | `Calmar | `CAGR ] ->
  min_spread:float ->
  report
(** [build_report ~input ~baseline_fold_actuals ~metric ~min_spread] re-scores
    every candidate in [input] and returns the assembled {!report}.

    Per-candidate semantics match {!rescore_candidate}: each candidate's fold
    actuals are matched against [baseline_fold_actuals] by [fold_name]. The
    overall [spread] is [max(mean_delta) - min(mean_delta)] across all
    candidates; verdict is {!Pass} when [spread > min_spread], else {!Fail}.

    [min_spread] defaults to {!default_min_spread} at the CLI surface; this
    function does not apply a default — the caller passes it explicitly so the
    test cases can pin the boundary. *)

val report_to_markdown :
  report -> metric:[ `Sharpe | `Total_return_pct | `Calmar | `CAGR ] -> string
(** [report_to_markdown report ~metric] renders the re-score report as markdown.
    Layout:

    {v
      # Paired-Δ re-score report

      Metric: <metric>
      Verdict: PASS | FAIL (threshold: spread > <min_spread>)

      | Candidate | parameters | mean Δ | stdev Δ | n_matched |
      | --- | --- | --- | --- | --- |
      | <label> | <k1>=<v1> ... | <m> | <s> | <n> |
      | ... |

      ## Spread
      max(mean Δ) - min(mean Δ) = <spread>
      Historical flat-surface spread: 0.81 (v3–v6 absolute-Sharpe scoring).
      Acceptance gate: spread > <min_spread> (= 5 × 0.81 by default).
    v}

    The renderer is pure — no I/O, no time, no environment reads — so the test
    suite can pin its output byte-for-byte. *)
