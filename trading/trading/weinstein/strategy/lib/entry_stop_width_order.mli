(** The {!Stop_width_mode.Demote_over_max} ordering pass: put every candidate
    whose structural stop is within [max_stop_distance_pct] ahead of the ones
    whose stop is wider, so the narrow-stop candidates get first claim on the
    week's capital.

    {1 Why this is a reordering and not a gate}

    Weinstein §5.1 says that when a structurally-placed stop would require more
    than ~15% risk you should {b "prefer other candidates"}. That is a
    comparative instruction about {e order} — the book reserves ban vocabulary
    ("NEVER buy, no matter how good other factors", §4.4 on negative RS) for the
    cases it means as bans, and grades the rest (§4.3 A+/A/B/C on overhead
    resistance). {!Stop_width_mode.Drop_over_max}, the default, reads §5.1 as a
    ban anyway.

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
    exactly one the gate would call wide.
    {b Agreeing with the gate is the contract}, and it settles the edge cases:
    there is no separate policy here for thin data, because whatever stop the
    gate would install is the stop this pass measures.

    In particular, a symbol with {b no resident bars} is not a special case.
    {!Entry_audit_helpers.latest_close} returns [None], the effective entry
    falls back to the candidate's own [suggested_entry], and the support-floor
    scan finds nothing — so the stop is the [initial_stop_buffer] fallback and
    the candidate is classified by {i that} width. Under a wide buffer it sorts
    with the wide group, which is exactly where the gate would put it. (The
    fixture in [test_entry_stop_width_order.ml] relies on this: its [WIDE]
    candidate is a data-poor symbol.)

    The one genuinely unmeasurable case is a non-positive effective entry, where
    a distance ratio is undefined. Such a candidate keeps its rank rather than
    being demoted on a division that has no answer; sizing rejects it
    downstream. *)
