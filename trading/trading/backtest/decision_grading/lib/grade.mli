(** Exit-decision grade — the headline of the decision-grading lens (plan
    [dev/plans/decision-grading-lens-2026-06-17.md] §Phase 2).

    Phase 1 ([Post_exit]) measures how a stock moved {b after} an exit. This
    module turns that measurement into a verdict on the exit {b decision}: by
    selling, did we leave money on the table (price kept running in our
    direction = {!Premature}) or dodge a drop (price reversed against us =
    {!Good_exit})?

    Every function here is pure — it depends only on {!Post_exit} and the
    standard library. No [Bar_reader], no I/O, no engine state; whoever has the
    {!Post_exit.horizon_result} list (CLI, report) calls in. Phase 4 wires the
    real data source. *)

type exit_grade =
  | Premature
      (** The stock continued in the trade's direction past the threshold after
          we exited — we gave up a winner. *)
  | Good_exit
      (** The stock reversed against the trade past the threshold after we
          exited — we dodged a drop. *)
  | Neutral
      (** The post-exit move stayed inside the threshold band (or no graded
          horizon was available) — the exit was neither clearly premature nor
          clearly good. *)
[@@deriving show, eq, sexp]

type grade_config = {
  premature_threshold_pct : float;
      (** Continuation at the grade horizon [>=] this fraction grades the exit
          {!Premature} (we gave up a winner). Expressed as a fraction, e.g.
          [0.10] = +10%. *)
  good_exit_threshold_pct : float;
      (** Continuation at the grade horizon [<=] the negation of this fraction
          grades the exit {!Good_exit} (we dodged a drop). Expressed as a
          positive fraction, e.g. [0.10] means continuation [<= -0.10]. *)
  grade_horizon_weeks : int;
      (** Which {!Post_exit.horizon_result} (by its [horizon_weeks]) to grade
          on. *)
}
[@@deriving show, eq, sexp]

val default_config : grade_config
(** Faithful defaults: [premature_threshold_pct = 0.10],
    [good_exit_threshold_pct = 0.10], [grade_horizon_weeks = 13] (one quarter).
    A long that kept rising +10% over the quarter after we sold is {!Premature};
    one that fell -10% is {!Good_exit}. *)

val grade_exit :
  config:grade_config -> post_exit:Post_exit.horizon_result list -> exit_grade
(** [grade_exit ~config ~post_exit] grades an exit from its post-exit
    continuation.

    It selects the {!Post_exit.horizon_result} whose [horizon_weeks] equals
    [config.grade_horizon_weeks] (the first such, if duplicated). Its
    [continuation_pct] is {b already side-adjusted} by {!Post_exit} — positive
    means the price moved in the trade's favour after the exit (we left gains on
    the table), negative means it moved against us (we dodged a drop) — so no
    [side] argument is needed here. The grade is then:

    - [continuation_pct >= config.premature_threshold_pct] -> {!Premature}
    - [continuation_pct <= -. config.good_exit_threshold_pct] -> {!Good_exit}
    - otherwise -> {!Neutral}

    If no result in [post_exit] matches [config.grade_horizon_weeks] (e.g. the
    horizon was never computed, or [post_exit] is empty) the exit is graded
    {!Neutral} — there is no evidence on which to call it premature or good.

    The thresholds are compared on the {b same} sign convention as
    {!Post_exit.horizon_result.continuation_pct}. Boundary values land on the
    decisive side: exactly [premature_threshold_pct] is {!Premature}, exactly
    [-. good_exit_threshold_pct] is {!Good_exit}. Pure: same inputs -> same
    output. *)

val entry_capture_ratio :
  realized_pnl_pct:float -> max_favorable_pct:float -> float option
(** [entry_capture_ratio ~realized_pnl_pct ~max_favorable_pct] is the fraction
    of the trade's peak in-trade gain that the trade actually realized:
    [realized_pnl_pct /. max_favorable_pct].

    [max_favorable_pct] is the maximum favourable excursion {b during} the trade
    (a fraction, e.g. [0.20] for a peak +20% unrealized gain). A ratio of [1.0]
    means the trade captured its entire peak; [0.5] means it gave back half; a
    {b negative} ratio means the trade closed for a loss despite having been in
    the money at its peak.

    Returns [None] when [max_favorable_pct <= 0.0] — the trade never showed an
    in-trade gain, so "fraction of the peak captured" is undefined (no positive
    peak to measure against). Pure: same inputs -> same output. *)
