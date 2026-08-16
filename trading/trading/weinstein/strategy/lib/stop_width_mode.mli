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
  | Demote_over_max
      (** The literal reading of §5.1: "prefer other candidates" is a
          {b ranking} instruction, not a ban. The candidate is admitted at
          {e normal} size, but every candidate whose stop is within
          [max_stop_distance_pct] gets first claim on the week's capital — the
          wide-stop ones are walked afterwards, with whatever is left. A wide
          stop costs priority, never existence, and on a week with enough
          capital for everyone it costs nothing at all.

          The codebase already has this shape: [overhead_supply] is a rank
          demotion and never an exclusion. This is the same treatment for the
          §5.1 width rule.

          {b Distinct from {!Size_down}} in what it gives up. [Size_down] keeps
          rank and shrinks the position so dollar risk stays constant;
          [Demote_over_max] keeps the size and gives up rank. The first is a
          risk-parity reading the book never states; the second is the book's
          own comparative wording. They disagree in both directions — on a
          capital-rich week [Demote_over_max] admits at full size where
          [Size_down] admits a fraction; on a capital-tight week
          [Demote_over_max] admits nothing where [Size_down] still admits a
          sliver.

          [size_down_max_pct] is the shared sanity ceiling (see {!policy}): a
          stop beyond it is still dropped, so demotion cannot admit unbounded
          structural risk. Leaving it at [0.0] makes this mode admit exactly the
          population [Drop_over_max] admits — an armed-but-unconfigured demotion
          is a no-op, so a spec must set the ceiling for it to bite.

          {b Why it exists.} On the 26-year top-3000 core arm AXTI was rejected
          {b 21 times} with [Stop_too_wide] at a correct, fresh entry anchor,
          and went on to be the single largest winner in the record run
          ([dev/notes/entry-anchor-defect-a-refuted-2026-08-16.md]). The width
          gate — not the entry anchor — is what excludes that cohort. *)
[@@deriving show, eq, sexp]

type policy = {
  mode : t;
  size_down_max_pct : float;
      (** Sanity ceiling for {!Size_down} {b and} {!Demote_over_max}: stop
          distances above this fraction are still dropped, so neither mechanism
          can admit unbounded structural risk. [0.0] (unset) falls back to
          [max_stop_distance_pct], which makes an armed-but-unconfigured mode
          admit exactly the population {!Drop_over_max} admits. Unread under
          {!Drop_over_max}. The name predates {!Demote_over_max}; it is the
          ceiling for both non-default modes. *)
}
(** The mode plus its ceiling, bundled so the entry-construction path takes one
    argument rather than two. Built by the strategy from
    [config.stop_width_mode] / [config.stop_width_size_down_max_pct]. *)

val default_policy : policy
(** [{ mode = Drop_over_max; size_down_max_pct = 0.0 }] — the no-op. *)

(** What the gate decided for one candidate. *)
type outcome =
  | Admit
      (** Admitted at normal size. Under every mode when the distance is within
          [max_stop_distance_pct]; also the {!Demote_over_max} verdict for a
          wide-but-under-ceiling stop, since demotion changes {e order}, not
          sizing — the reordering happens before the walk (see
          {!Entry_stop_width_order}), not here. *)
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
    produced under [Drop_over_max].

    Under [Demote_over_max]: [Drop] iff [stop_distance_pct] exceeds the same
    ceiling, else [Admit] — the mode never returns {!Admit_sized_down}, because
    what it changes is the candidate's {e position in the walk}, not its size.
*)

val over_book_limit :
  max_stop_distance_pct:float -> stop_distance_pct:float -> bool
(** The §5.1 width test on its own, without a mode: [true] when the stop sits
    further than [max_stop_distance_pct] from entry. Exposed so
    {!Entry_stop_width_order} can partition candidates by the same predicate
    {!gate} applies, rather than re-deriving the strict [>] and risking a
    boundary disagreement between the ordering and the gate. *)

val demotes : policy:policy -> bool
(** [true] only for {!Demote_over_max}. Lets the entry walk skip the ordering
    pass — and its per-candidate stop recomputation — entirely under the other
    two modes, so the default path allocates nothing new (R1). *)
