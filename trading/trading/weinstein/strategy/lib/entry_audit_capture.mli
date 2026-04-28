(** Entry-side trade-audit capture.

    Holds the data shapes and builders the strategy uses to populate
    {!Audit_recorder.entry_event}s when the entry walk produces a kept
    candidate. The strategy keeps {!Weinstein_strategy._make_entry_transition} /
    {!Weinstein_strategy.entries_from_candidates} but delegates the
    audit-emission bookkeeping (the candidate-decision tagging, the alternatives
    projection, the entry-event construction) to this module so the strategy
    file stays under its file-length cap. *)

type entry_meta = {
  position_id : string;
  shares : int;
  installed_stop : float;
  stop_floor_kind : Audit_recorder.stop_floor_kind;
}
(** Audit-relevant intermediates computed during entry-transition construction.
    Returned alongside the transition so the audit recorder can capture them
    without duplicating the underlying support-floor lookup. *)

(** Per-candidate decision tag emitted by the entry walk. The [Kept] case
    carries the produced transition + audit meta; [Skipped] records why the
    candidate was passed over so the audit can populate
    [alternatives_considered]. Matches one-to-one with
    {!Audit_recorder.skip_reason}. *)
type candidate_decision =
  | Kept of Trading_strategy.Position.transition * entry_meta
  | Skipped of Audit_recorder.skip_reason

val classify_stop_floor_kind :
  stops_config:Weinstein_stops.config ->
  callbacks:Weinstein_stops.callbacks ->
  side:Trading_base.Types.position_side ->
  Audit_recorder.stop_floor_kind
(** Decide [stop_floor_kind] for a freshly-installed initial stop. Mirrors
    {!Weinstein_stops.compute_initial_stop_with_floor_with_callbacks}'s internal
    branch — [Some _] from
    {!Weinstein_stops.Support_floor.find_recent_level_with_callbacks} →
    [Support_floor]; [None] → [Buffer_fallback].

    The lookup is repeated here rather than threaded out of the stops primitive
    to keep that primitive's surface clean; the cost is one extra bar walk per
    entered candidate, bounded by [stops_config.support_floor_lookback_bars]. *)

val alternatives_of_decisions :
  decisions:(Screener.scored_candidate * candidate_decision) list ->
  exclude_position_id:string ->
  Audit_recorder.alternative_input list
(** Build the [alternatives_considered] list for a chosen candidate's audit row.
    Every other candidate from the same screen call surfaces here:

    - [Skipped reason] candidates pass through verbatim with the captured
      [reason].
    - [Kept] rivals (other entered candidates) are excluded — they have their
      own [entry_decision] records, and cross-trade analysis joins on
      [position_id]. *)

val build_entry_event :
  macro:Macro.result ->
  current_date:Core.Date.t ->
  candidate:Screener.scored_candidate ->
  meta:entry_meta ->
  alternatives:Audit_recorder.alternative_input list ->
  Audit_recorder.entry_event
(** Project [(candidate, meta, alternatives)] into an
    {!Audit_recorder.entry_event}. Computes the dollar-denominated sizing fields
    ([initial_position_value], [initial_risk_dollars]) from [meta.shares],
    [candidate.suggested_entry], and [meta.installed_stop]. *)

val emit_entries :
  audit_recorder:Audit_recorder.t ->
  macro:Macro.result option ->
  current_date:Core.Date.t ->
  decisions:(Screener.scored_candidate * candidate_decision) list ->
  unit
(** For every [Kept] entry in [decisions], compute the [alternatives] list,
    build an [entry_event], and route it through [audit_recorder.record_entry].
    [Skipped] entries are silently dropped — they surface as alternatives in
    other Kept entries' rows.

    No-op when [macro] is [None] (the strategy did not run macro this tick, so
    the entry walk is being driven from a test fixture without macro state —
    skip audit emission rather than fabricate a Neutral macro). *)

(** {1 Per-candidate entry construction}

    These primitives are factored out of the strategy file so the strategy stays
    under its file-length cap. Behaviour is bit-equivalent to the inline
    pre-PR-2 code: same sizing inputs, same stop computation, same side-effects
    on [stop_states]. *)

val gen_position_id : string -> string
(** Generate a fresh position id of the form [<ticker>-wein-<n>] with [n] a
    monotonically-increasing global counter. Same shape the strategy used
    pre-PR-2; preserved verbatim so existing transition / stop_log identities
    don't change. *)

val make_entry_transition :
  portfolio_risk_config:Portfolio_risk.config ->
  stops_config:Weinstein_stops.config ->
  initial_stop_buffer:float ->
  stop_states:Weinstein_stops.stop_state Core.String.Map.t ref ->
  bar_reader:Bar_reader.t ->
  portfolio_value:float ->
  current_date:Core.Date.t ->
  Screener.scored_candidate ->
  (Trading_strategy.Position.transition * entry_meta) option
(** Try to build a [CreateEntering] transition for [cand]. Returns [None] when
    sizing yields zero shares (un-sizeable). Side-effects: registers the initial
    stop in [stop_states]; bumps the global position-id counter. The initial
    stop comes from
    {!Weinstein_stops.compute_initial_stop_with_floor_with_callbacks}, which
    pulls a prior correction low (long) or counter-rally high (short) from
    [cand]'s bar history, falling back to [initial_stop_buffer] when no
    qualifying counter-move is in the lookback window. *)

val check_cash_and_deduct :
  remaining_cash:float ref ->
  Trading_strategy.Position.transition * entry_meta ->
  (Trading_strategy.Position.transition * entry_meta) option
(** Check that the transition's cost ([target_quantity * entry_price]) fits in
    [remaining_cash]. Deducts and returns [Some] when it does, returns [None]
    otherwise. Pass-through for non-[CreateEntering] transitions. *)

val classify_candidate :
  held_set:Core.String.Set.t ->
  make_entry:
    (Screener.scored_candidate ->
    (Trading_strategy.Position.transition * entry_meta) option) ->
  remaining_cash:float ref ->
  Screener.scored_candidate ->
  candidate_decision
(** Classify one candidate as [Kept] or [Skipped reason]. The three skip reasons
    match {!Audit_recorder.skip_reason}: held, sized to zero, or rejected by the
    running cash check. Order: held-check, then sizing via [make_entry], finally
    the cash check. *)
