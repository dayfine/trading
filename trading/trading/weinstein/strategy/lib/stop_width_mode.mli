(** F3 — what the entry walk does with a candidate whose structural initial stop
    sits further from entry than [Weinstein_stops.config.max_stop_distance_pct].

    {1 Honest citation — this is a READING, not a documented book mechanism}

    Weinstein §5.1 says that when a structurally-placed stop would require more
    than ~15% risk you should "prefer other candidates". That sentence is
    {b comparative}, not an absolute ban — but the book's own remedies for a
    wide stop are, in order: (i) anchor the stop at the {e nearest} prior
    correction low rather than the deepest one (implemented as
    {!Weinstein_stops.Support_floor.Nearest}); (ii) the §5.3 trader preset's
    tighter 4–6% stop; (iii) pass on the trade. The book {b never} prescribes
    keeping the wide stop and shrinking the share count to hold dollar risk
    constant.

    So {!Size_down} is a {e tolerated-participation reading} of §5.1 and is
    labelled as such: it is the hypothesis that the 15% drop-filter's real cost
    is the structural exclusion of a whole population (the ladder-v3 finding —
    crash-recovery names tripped [Stop_too_wide] 22–28× on the exact entry weeks
    that produced the record run's largest winners, see
    [dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md] and
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F3), and that admitting
    them at risk-parity size is better than excluding them. The competing
    {b faithful} arm — shrink the stop distance the book's way instead of
    shrinking shares — is [stops_config.support_floor_anchor_scope = Nearest].
    Ladder v4 runs the two as rival cells; neither is promoted without a ledger
    ACCEPT plus the confirmation grid.

    Default {!Drop_over_max} reproduces today's G15 step-3 behaviour exactly
    (R1). Both the mode and its ceiling are plain
    {!Weinstein_strategy_config.config} fields, so they expand as
    [Variant_matrix] axes (R2). *)

(** Which admission rule the wide-stop gate applies. *)
type t =
  | Drop_over_max
      (** Today's behaviour: a candidate whose stop distance exceeds
          [max_stop_distance_pct] is dropped (the [Stop_too_wide] skip reason).
          The no-op default. *)
  | Size_down
      (** The candidate is admitted instead of dropped, and fixed-risk sizing
          ({!Portfolio_risk.compute_position_size}) shrinks the share count
          ~[1 / stop_distance] so dollar risk-to-stop still equals
          [risk_per_trade_pct * portfolio_value]. [max_stop_distance_pct] stops
          being the {e admission} threshold and becomes the boundary above which
          the entry is tagged [Sized_down_wide_stop]; the drop threshold moves
          to [size_down_max_pct] (the swept sanity ceiling). *)
[@@deriving show, eq, sexp]

type policy = {
  mode : t;
  size_down_max_pct : float;
      (** Sanity ceiling for {!Size_down}: stop distances above this fraction
          are still dropped, so the mechanism cannot admit unbounded structural
          risk. [0.0] (unset) falls back to [max_stop_distance_pct], which makes
          an armed-but-unconfigured {!Size_down} admit exactly the population
          {!Drop_over_max} admits. Unread under {!Drop_over_max}. *)
}
(** The mode plus its ceiling, bundled so the entry-construction path takes one
    argument rather than two. Built by the strategy from
    [config.stop_width_mode] / [config.stop_width_size_down_max_pct]. *)

val default_policy : policy
(** [{ mode = Drop_over_max; size_down_max_pct = 0.0 }] — the no-op. *)

(** What the gate decided for one candidate. *)
type outcome =
  | Admit
      (** Stop distance is within [max_stop_distance_pct]; unchanged under both
          modes. *)
  | Admit_sized_down
      (** {!Size_down} only: distance is over [max_stop_distance_pct] but within
          the sanity ceiling. The candidate proceeds to sizing and its
          [entry_meta] carries [sized_down_wide_stop = true]. *)
  | Drop  (** Rejected — maps to [Audit_recorder.Stop_too_wide]. *)

val gate :
  policy:policy ->
  max_stop_distance_pct:float ->
  stop_distance_pct:float ->
  outcome
(** [gate ~policy ~max_stop_distance_pct ~stop_distance_pct] classifies one
    candidate's structural stop width.

    Under [Drop_over_max]: [Drop] iff
    [stop_distance_pct > max_stop_distance_pct], else [Admit] — bit-identical to
    the pre-F3 inline test, including the strict [>] (a distance exactly equal
    to the limit admits).

    Under [Size_down]: [Drop] iff [stop_distance_pct] exceeds the ceiling
    ([policy.size_down_max_pct] when [> 0.0], else [max_stop_distance_pct]);
    [Admit_sized_down] when it is within the ceiling but over
    [max_stop_distance_pct]; [Admit] otherwise. {!Admit_sized_down} is never
    produced under [Drop_over_max]. *)
