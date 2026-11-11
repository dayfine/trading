(** Aggregation by exit reason — Phase 3 of the decision-grading lens (plan
    [dev/plans/decision-grading-lens-2026-06-17.md] §Phase 3).

    Phases 1–2 grade a {b single} exit: {!Post_exit} measures how the stock
    moved after the exit, {!Grade} turns that into a {!Grade.exit_grade}. This
    module rolls a population of already-graded trades up {b by exit reason}
    ([stop_loss] / [stage3_force_exit] / [laggard_rotation] /
    [force_liquidation] / [end_of_period] / ...) so the lens can answer the
    decision-level question:
    {b which kinds of exit add value and which destroy it?}

    It is the systematized, repeatable form of the one-off
    [dev/experiments/trade-forensics-2026-06-12] finding (stops ≈ net-zero in
    chop; laggard-rotation = the profit engine).

    Every function here is pure — it consumes a caller-built {!graded_trade}
    list (the CLI in Phase 4 joins trades + audit + post-exit bars to build it).
    No I/O, no engine state. Unit-tested directly on synthetic {!graded_trade}
    lists. *)

type graded_trade = {
  exit_reason : string;
      (** Lowercase exit-trigger label the trade is grouped by, e.g.
          ["stop_loss"], ["laggard_rotation"], ["stage3_force_exit"],
          ["end_of_period"]. *)
  realized_pnl_pct : float;
      (** The round-trip's realized return, as a fraction of entry (e.g. [0.20]
          for +20%). *)
  continuation_pct : float;
      (** Side-adjusted post-exit continuation at the grade horizon
          ({!Post_exit.horizon_result.continuation_pct}): positive means the
          price kept moving in the trade's favour after the exit (we left gains
          on the table), negative means it reversed (we dodged a drop). *)
  exit_grade : Grade.exit_grade;
      (** The {!Grade.exit_grade} this trade earned at the grade horizon. *)
  entry_capture_ratio : float option;
      (** {!Grade.entry_capture_ratio} for the trade — fraction of in-trade peak
          gain realized. [None] when the trade never showed an in-trade gain. *)
  post_exit_max_adverse_pct : float;
      (** Worst move {b against} the trade after the exit, at the grade horizon
          ({!Post_exit.horizon_result.post_exit_max_adverse_pct}). For a long
          this is how far price fell {b below} the exit — i.e.
          {b the disaster dodged by being out} (typically [<= 0.0]). The benefit
          side of a stop: a large negative value is a deep decline we sat out.
      *)
  post_exit_max_favorable_pct : float;
      (** Best move {b in} the trade's direction after the exit, at the grade
          horizon ({!Post_exit.horizon_result.post_exit_max_favorable_pct}). The
          {b upside foregone} by exiting (typically [>= 0.0]). The cost side of
          a stop: a large positive value is a recovery/run we missed. *)
}
[@@deriving show, eq, sexp]
(** One graded round-trip, the unit of aggregation.

    [continuation_pct] is the {b net} post-exit move (favorable minus adverse,
    realized at the horizon close); [post_exit_max_adverse_pct] and
    [post_exit_max_favorable_pct] split that net into the {b benefit} (disaster
    dodged) and {b cost} (upside foregone) of the exit — the decomposition the
    mean continuation alone hides. *)

type group_stats = {
  exit_reason : string;  (** The reason all trades in this group share. *)
  n : int;  (** Number of trades in the group. *)
  mean_realized_pnl_pct : float;
      (** Mean {!graded_trade.realized_pnl_pct} over the group. [0.0] for an
          empty group (never produced by {!aggregate_by_exit_reason}). *)
  mean_continuation_pct : float;
      (** Mean {!graded_trade.continuation_pct} over the group. *)
  pct_premature : float;
      (** Fraction of the group graded {!Grade.Premature} (we gave up a winner),
          in [[0.0, 1.0]]. *)
  pct_good_exit : float;
      (** Fraction of the group graded {!Grade.Good_exit} (we dodged a drop). *)
  mean_net_value_add_pct : float;
      (** Mean per-trade value-add {b of having exited}: realized minus the
          counterfactual of holding through the grade horizon. Holding would
          have added [continuation_pct] on top of the realized return, so the
          exit's value-add is [-. continuation_pct]; this field is the group
          mean of that, i.e. [-. mean_continuation_pct]. Positive means the
          exits in this group were, on average, beneficial (price fell after
          exit); negative means they were premature (price kept rising). *)
  mean_entry_capture_ratio : float option;
      (** Mean {!graded_trade.entry_capture_ratio} over the trades in the group
          that have [Some] ratio. [None] when {b no} trade in the group has a
          defined ratio (none ever showed an in-trade gain). *)
  mean_post_exit_max_adverse_pct : float;
      (** Mean {!graded_trade.post_exit_max_adverse_pct} — the
          {b average disaster dodged} by exits in this group. For [stop_loss]
          this is the benefit side of the stop: how far the average stopped name
          fell after we were out. *)
  mean_post_exit_max_favorable_pct : float;
      (** Mean {!graded_trade.post_exit_max_favorable_pct} — the
          {b average upside foregone} by exits in this group (the whipsaw/cost
          side). *)
  continuation_p10 : float;
      (** 10th-percentile {!graded_trade.continuation_pct} in the group
          (nearest- rank). The left tail: the most-adverse-continuation exits —
          for a stop, the disasters it sat out (continuation deeply negative).
          [0.0] for an empty group. *)
  continuation_p90 : float;
      (** 90th-percentile {!graded_trade.continuation_pct} (nearest-rank). The
          right tail: the biggest runs given up by exiting. [0.0] for an empty
          group. *)
  disaster_dodge_rate : float;
      (** Fraction of the group whose {!graded_trade.post_exit_max_adverse_pct}
          is at or below the [disaster_threshold_pct] passed to
          {!aggregate_by_exit_reason} — i.e. the share of exits that sat out a
          drop of at least that magnitude. In [[0.0, 1.0]]. This is the
          {b frequency} of disaster-avoidance, complementing the magnitude in
          [mean_post_exit_max_adverse_pct]. *)
}
[@@deriving show, eq, sexp]
(** Aggregate statistics for one exit-reason group. *)

val default_disaster_threshold_pct : float
(** [-0.20] — the default cutoff for {!group_stats.disaster_dodge_rate}: a
    post-exit drop of 20% or more (as a fraction of exit price) counts as a
    disaster dodged. *)

val aggregate_by_exit_reason :
  ?disaster_threshold_pct:float -> graded_trade list -> group_stats list
(** [aggregate_by_exit_reason ?disaster_threshold_pct trades] partitions
    [trades] by {!graded_trade.exit_reason} and computes one {!group_stats} per
    distinct reason.

    [disaster_threshold_pct] (default {!default_disaster_threshold_pct}) is the
    [post_exit_max_adverse_pct] cutoff at or below which an exit counts toward
    {!group_stats.disaster_dodge_rate}. Expressed as a {b signed} fraction (e.g.
    [-0.20]); a trade counts when its [post_exit_max_adverse_pct <=] this value.

    The result is sorted by [exit_reason] ascending for deterministic output.
    Empty input -> empty output. Every emitted group has [n >= 1]. Pure: same
    input -> same output. *)

val to_markdown : group_stats list -> string
(** [to_markdown groups] renders the aggregation as a markdown table, one row
    per group, mirroring the {!Trade_audit_report.to_markdown} style. Output is
    deterministic for a given [groups] (no timestamps); the trailing newline is
    included. Rows appear in the order of [groups] (use the
    {!aggregate_by_exit_reason} ordering for sorted output). *)
