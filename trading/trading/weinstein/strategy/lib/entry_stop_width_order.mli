(** The {!Stop_width_mode.Demote_over_max} ordering pass: put every candidate
    whose structural stop is within [max_stop_distance_pct] ahead of the ones
    whose stop is wider, so the narrow-stop candidates get first claim on the
    week's capital.

    {1 Why this is a reordering and not a gate}

    Weinstein §5.1 says that when a structurally-placed stop would require more
    than ~15% risk you should {b "prefer other candidates"}. That is a
    comparative instruction about {e order}, and the codebase already implements
    exactly that shape elsewhere: [overhead_supply] demotes a candidate's rank
    and never excludes it. {!Stop_width_mode.Drop_over_max}, the default, reads
    the same sentence as a ban.

    A demotion cannot be expressed inside {!Stop_width_mode.gate}, which sees
    one candidate at a time and has no view of the others. It has to happen
    before the walk, over the whole list — hence this module.

    {1 Stability, and why it matters}

    The partition is {b stable}: within each group the screener's ranking is
    preserved exactly, so a demoted candidate never overtakes another demoted
    candidate, and a narrow-stop candidate never overtakes a better-ranked
    narrow-stop one. The only thing that changes is that every wide-stop
    candidate now sits behind every narrow-stop one. Anything less than a stable
    partition would silently re-rank the majority population as a side effect of
    a rule about the minority.

    {1 Cost, and the default path}

    Deciding the partition requires each candidate's structural stop distance,
    which means recomputing the {!Entry_audit_capture} prefix (daily view,
    support floor, split-safe basis) once per candidate before the walk computes
    it again. That is real work, so {!prefer_narrow_stops} is a no-op returning
    the input list {b physically unchanged} under every mode except
    {!Stop_width_mode.Demote_over_max} — the default path does not pay it, and
    is bit-identical (R1). *)

val prefer_narrow_stops :
  config:Weinstein_strategy_config.config ->
  bar_reader:Bar_reader.t ->
  current_date:Core.Date.t ->
  Screener.scored_candidate list ->
  Screener.scored_candidate list
(** [prefer_narrow_stops ~config ~bar_reader ~current_date candidates] stably
    partitions [candidates] into (stop within [max_stop_distance_pct]) followed
    by (stop wider), when [config.stop_width_mode = Demote_over_max].

    Returns [candidates] unchanged under {!Stop_width_mode.Drop_over_max} and
    {!Stop_width_mode.Size_down}.

    The width test is {!Stop_width_mode.over_book_limit} against the same
    structural stop {!Entry_audit_capture.make_entry_transition} will install,
    computed through the same helpers — so a candidate this pass calls "wide" is
    exactly one the gate would call wide. A candidate whose stop cannot be
    computed (no resident bars) is treated as narrow, i.e. it keeps its rank: an
    unmeasurable stop is not evidence of a wide one. *)
