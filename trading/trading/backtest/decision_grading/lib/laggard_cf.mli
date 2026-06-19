(** Laggard-rotation paired counterfactual — Phase 5 of the decision-grading
    lens (plan [dev/plans/decision-grading-lens-2026-06-17.md] §Phase 5).

    Laggard-rotation is the one exit type with a specific {b alternative}: it
    sells a laggard to free cash for the same-tick entry walk. The right
    question is therefore not "did the laggard recover after we sold?" (that is
    the {!Aggregate} continuation view) but
    {b "did the names we bought with the freed cash beat the laggard we sold?"}
    — did rotation {e pay}?

    There is no 1:1 sold→bought link in the engine (the runner frees cash into a
    pool the entry walk draws from — see [laggard_rotation_runner.mli] §"Side &
    ordering"). So the pairing is {b per-event cohort}: each rotation exit is
    compared against the cohort of new entries opened within a short allocation
    window after it. Both sides' "forward return" is the
    {!Post_exit.horizon_result.continuation_pct} over the same horizon —
    measured from the laggard's exit price forward, and from each new entry's
    entry price forward.

    Every function here is pure — it consumes caller-built forward returns (the
    CLI computes them via [Post_exit] + a snapshot [Bar_reader]). No I/O. *)

open Core

type event = {
  dumped_symbol : string;  (** The laggard that was rotated out. *)
  dumped_date : Date.t;  (** Its exit date (the rotation event). *)
  dumped_forward_pct : float;
      (** The laggard's forward return over the horizon, from its exit price
          (side-adjusted {!Post_exit} continuation): positive means it kept
          running after we sold — rotation gave up a winner. *)
  funded_forward_pcts : float list;
      (** Forward returns (same horizon, from each entry price) of the new
          entries opened in the allocation window after [dumped_date] — the
          cohort the freed cash plausibly funded. Empty when nothing was bought
          in the window (cash sat idle / was redeployed later). *)
}
[@@deriving show, eq, sexp]
(** One rotation event paired with the redeployment cohort it plausibly funded.
*)

type summary = {
  n_events : int;  (** Total rotation events considered. *)
  n_with_redeploy : int;
      (** Events with at least one funded entry in the window (the ones the
          paired comparison is computed over). *)
  mean_dumped_forward_pct : float;
      (** Mean [dumped_forward_pct] over the redeploy events — what the sold
          laggards did next, on average. *)
  mean_funded_forward_pct : float;
      (** Mean of each redeploy event's funded-cohort mean forward — what the
          bought names did next, on average. *)
  mean_paired_diff_pct : float;
      (** Mean over redeploy events of
          [(mean funded forward) - dumped_forward_pct]. Positive means rotation
          paid: the cohort we bought beat the laggard we sold. This is the
          {b paired, event-level} statistic (not two pooled population means).
      *)
  pct_rotation_paid : float;
      (** Fraction of redeploy events whose funded-cohort mean forward exceeded
          the dumped laggard's forward — the sign-rate of "rotation paid", in
          [[0.0, 1.0]]. *)
  diff_p10 : float;
  diff_p50 : float;
  diff_p90 : float;
      (** Percentiles (nearest-rank) of the per-event paired diff across
          redeploy events — the distribution, not just its mean. [0.0] when no
          redeploy events. *)
}
[@@deriving show, eq, sexp]
(** Aggregate verdict on whether laggard-rotation paid, over one horizon. *)

val build_events :
  alloc_window_days:int ->
  laggard_exits:(string * Date.t * float) list ->
  entries:(Date.t * float) list ->
  event list
(** [build_events ~alloc_window_days ~laggard_exits ~entries] pairs each
    [(symbol, exit_date, forward)] laggard exit with the [(entry_date, forward)]
    entries whose [entry_date] lies in [(exit_date, exit_date +
    alloc_window_days]] (exclusive of the exit day itself, inclusive of the
    window end). One {!event} per laggard exit, in input order. An entry may fund
    more than one rotation event (the freed-cash pool is shared); that is
    expected and not double-counted incorrectly — each event measures the
    redeployment opportunity available to it. Pure. *)

val summarize : event list -> summary
(** [summarize events] computes the paired counterfactual {!summary}. Events
    with an empty [funded_forward_pcts] are counted in [n_events] but excluded
    from every mean / percentile / sign-rate (no redeployment to compare
    against). All float fields are [0.0] when [n_with_redeploy = 0]. Pure: same
    input -> same output. *)

val to_markdown : horizon_weeks:int -> summary -> string
(** [to_markdown ~horizon_weeks s] renders [s] as a markdown section labelled
    with the horizon. Deterministic; trailing newline included. *)
