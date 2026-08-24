(** Per-week candidate emission — the on-disk shape of [candidates.sexp].

    Answers the one question no existing artefact does:
    {i "which names did the cascade look at on week W, and where did each one
       fall out?"} See [dev/plans/candidate-emission-2026-08-23.md] and issue
    #2490.

    {1 Why this is not [trade_audit.sexp]}

    [Trade_audit.cascade_summary] carries per-phase admission {b counts} but no
    names. [Trade_audit.entry_decision.alternatives_considered] carries names —
    but only ever attached to a {b funded} entry, so a Friday that funds nothing
    emits no candidate list at all (gap G1). This module is the unconditional
    per-week sink: it is populated from the same
    {!Weinstein_strategy.Audit_recorder.cascade_event} the cascade summary comes
    from, so a zero-funded week still carries its list.

    {1 Opt-in, observability only}

    Nothing here is on any default path. Emission is gated by
    [scenario_runner.exe --emit-candidates] (default OFF, mirroring
    [--no-emit-all-eligible]), which routes into
    [Runner.run_backtest ?candidate_log] with a {!collector} built by
    {!create_if}. The gate reaching the strategy lives on the {b recorder}
    ([Audit_recorder.t.capture_candidates]), never on
    [Weinstein_strategy.config] or [Screener.config] — so it can never become a
    [Variant_matrix] axis, never routes through [Overlay_validator], and never
    appears in a golden's [config_overrides]. With the gate off the strategy
    allocates nothing and no file is written. *)

open Core

(** Where in the screener cascade a candidate stopped.

    [Admitted] means the candidate survived every cascade phase and reached the
    screener's top-N — i.e. the strategy's entry walk actually considered it.
    Every candidate emitted by the G1 (per-week walk population) path is
    [Admitted] by construction; the [Dropped_at_*] constructors are populated by
    the G2 pre-top-N trace, which names the candidates the cascade evaluated and
    rejected. *)
type cascade_outcome =
  | Admitted
  | Dropped_at_macro
  | Dropped_at_breakout
      (** Long side: breakout predicate / price floor / volume band / the
          failed-breakout gate. Short side: the mirrored breakdown phase. *)
  | Dropped_at_sector
  | Dropped_at_rs
      (** Short side only today — the long side's relative strength folds into
          the grade rather than a standalone phase. See [Screener_admission]. *)
  | Dropped_at_grade
  | Dropped_at_top_n
[@@deriving sexp, eq, show]

type signals = {
  score : int;
  grade : Weinstein_types.grade;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
      (** [weeks_advancing] when [stage] is [Stage2], else [None]. *)
  rs_value : float option;
      (** Normalised relative-strength value at decision time, [None] when the
          candidate carried no RS analysis. *)
  volume_ratio : float option;
      (** Breakout-bar volume / 4-week average, [None] when no breakout volume
          event was classified. *)
  sector_name : string;  (** Empty string when unknown. *)
}
[@@deriving sexp, eq]
(** Decision-time signals for one candidate.

    Deliberately field-for-field the decision-time subset of
    {!Trade_audit.alternative_candidate}: the two must stay projectable onto
    each other so a reader can join a candidate row against the funded path's
    near-miss rows without a schema translation. {!signals_of_alternative} is
    that projection, and it is the only way this record is built — which is what
    keeps the two from drifting. *)

type candidate = {
  symbol : string;
  side : Trading_base.Types.position_side;
  outcome : cascade_outcome;
  signals : signals;
}
[@@deriving sexp, eq]

type week = { date : Date.t; candidates : candidate list } [@@deriving sexp, eq]
(** One Friday's candidate population. Emitted for {b every} screened Friday
    when capture is on — including Fridays that funded nothing, which is the
    whole point (G1). *)

type t = week list [@@deriving sexp]
(** On-disk payload of [<scenario_dir>/candidates.sexp]. *)

val signals_of_alternative : Trade_audit.alternative_candidate -> signals
(** Project a near-miss row onto {!signals}, field-for-field. Every [signals]
    value on an {b entry-walk} row comes through here, so the candidate log and
    [trade_audit.sexp]'s [alternatives_considered] cannot disagree about a
    candidate's decision-time signals. *)

val signals_of_analysis :
  analysis:Stock_analysis.t ->
  sector_name:string ->
  score:int ->
  grade:Weinstein_types.grade ->
  signals
(** The same projection for a {b cascade} row, whose candidate never reached the
    entry walk and so has no [alternative_candidate] to read from — the score
    and grade come from the screener's own trace instead.

    Reads the identical fields off [analysis] that {!Trade_audit_recorder}'s
    near-miss projection does, so the two row kinds in one artefact describe a
    candidate the same way. A test pins that they agree on a candidate reachable
    through both paths. *)

(** {1 Collector} *)

type collector
(** Mutable per-run accumulator of weeks, in record order. One per backtest run;
    not safe to share across threads. Mirrors {!Trade_audit.t}'s shape rather
    than growing a [Queue] on [Trade_audit.t] itself, so [trade_audit.sexp]'s
    on-disk shape does not move. *)

val create : unit -> collector
val record : collector -> week -> unit

val create_if : bool -> collector option
(** [Some (create ())] when capture is on, [None] otherwise — the shape the
    recorder and the runner both thread, so the opt-in test is written once. *)

val weeks : collector -> t
(** Recorded weeks, oldest first. *)

val filter_from : t -> start_date:Date.t -> t
(** Drop weeks before [start_date]. Warmup-window screens must not pollute the
    artefact, matching the treatment [Trade_audit.cascade_summary]s already get.
*)

val weeks_in_window : collector option -> start_date:Date.t -> t
(** {!weeks} then {!filter_from}, and [[]] for [None] — what a runner wants at
    teardown regardless of whether capture was on. *)

val week_of :
  date:Date.t ->
  alternatives:Trade_audit.alternative_candidate list ->
  drops:Weinstein_strategy.Audit_recorder.cascade_drop list ->
  week
(** Assemble one screened Friday's row set.

    [alternatives] are the candidates the {i entry walk} passed over (G1),
    already projected by the caller (which owns the near-miss projection);
    [drops] are the candidates the {i cascade} evaluated (G2), each carrying the
    phase that dropped it.

    Emitted even when both are empty: a Friday that funded nothing is still a
    screened Friday, and eliding it would make "no week" and "no candidates"
    indistinguishable.

    {b A non-empty [drops] supersedes [alternatives].} The cascade population
    already contains the entry walk's top-N as its [Admitted] tail, so emitting
    both would double-count those names under two different outcome
    vocabularies. [alternatives] remains the sole source when no cascade trace
    was captured — which is what keeps a G1-only caller working unchanged. *)

(** {1 Emission} *)

val emit : enabled:bool -> scenario_dir:string -> t -> unit
(** Write [<scenario_dir>/candidates.sexp] when [enabled] is [true].

    No-op when [enabled] is [false]: no file is created, nothing is serialised.

    {b Failure isolation.} A writer failure (unwritable directory, full disk) is
    logged to [stderr] and swallowed — this is a diagnostic artefact and must
    never abort the parent backtest, whose [actual.sexp] / [summary.sexp] are
    already on disk by the time this runs. Same contract as
    [Backtest_all_eligible.Scenario_post_step.emit]. *)
