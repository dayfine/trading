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
  effective_entry_price : float;
      (** The price the strategy installs into [Position.t] state — most recent
          close from [bar_reader] at order placement, or
          [candidate.suggested_entry] when no bars are available (G14 fix). The
          dollar-denominated audit fields ([initial_position_value],
          [initial_risk_dollars] in {!build_entry_event}) key off this rather
          than [candidate.suggested_entry] so the audit reflects the realised
          entry rather than the screener's pre-fill intent. *)
}
(** Audit-relevant intermediates computed during entry-transition construction.
    Returned alongside the transition so the audit recorder can capture them
    without duplicating the underlying support-floor lookup. *)

(** Outcome of {!make_entry_transition}'s strategy-internal entry-construction
    attempt for one candidate.

    The strategy applies two pre-cash gates before {!classify_candidate}'s
    cash-and-cap walk: the G15-step-3 [max_stop_distance_pct] gate, and
    round-share sizing collapsing to zero. {!Entry_ok} carries the
    successfully-built transition + audit meta forward. {!Stop_too_wide} and
    {!Sized_zero} are mapped one-to-one into
    [Audit_recorder.skip_reason.Stop_too_wide] / [Sized_to_zero] by
    {!classify_candidate}; they are exposed here so callers running the entry
    construction outside the classifier can act on them directly. *)
type entry_attempt_result =
  | Entry_ok of Trading_strategy.Position.transition * entry_meta
  | Stop_too_wide
      (** G15 step 3: support-floor-derived [installed_stop] sits more than
          [stops_config.max_stop_distance_pct] from [effective_entry]. *)
  | Sized_zero
      (** [Portfolio_risk.compute_position_size] rounded shares down to 0 (risk
          dollars too small relative to per-share cost, or stop on the wrong
          side of entry). *)

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
    [meta.effective_entry_price], and [meta.installed_stop]. The audit row's
    [candidate] field still carries the screener-original
    [candidate.suggested_entry], so consumers can compare the screener's
    pre-fill intent against the strategy's realised entry. *)

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
  entry_attempt_result
(** Try to build a [CreateEntering] transition for [cand]. Returns:

    - [Stop_too_wide]: the support-floor-derived initial stop sits more than
      [stops_config.max_stop_distance_pct] from [effective_entry] (G15 step 3,
      Weinstein book §5.1). No [stop_states] entry written; no position id
      consumed.
    - [Sized_zero]: [Portfolio_risk.compute_position_size] rounded the share
      count to 0. No [stop_states] entry written; no position id consumed.
    - [Entry_ok (transition, meta)]: an entry-side transition with audit meta.
      Side-effects: registers the initial stop in [stop_states]; bumps the
      global position-id counter.

    Order of operations within: (1) compute [effective_entry] from [bar_reader];
    (2) compute the support-floor-aware [initial_stop] via
    {!Weinstein_stops.compute_initial_stop_with_floor_with_callbacks}; (3)
    compare [|installed_stop - effective_entry| / effective_entry] against
    [stops_config.max_stop_distance_pct]; (4) compute sizing using the
    [installed_stop] (not [cand.suggested_stop]) so risk-per-share matches the
    actual structural risk; (5) build the transition and meta on success.

    The G15 step 3 fix moves sizing to step (4), AFTER the support-floor logic
    has run, so that risk-per-share — and therefore share count — keys off the
    actual [installed_stop] the position will operate under. Pre-step-3
    behaviour sized off [cand.suggested_stop], which left a structural sizing
    drift whenever support-floor produced a wider stop than the screener's
    pre-fill suggestion. *)

val check_cash_and_deduct :
  remaining_cash:float ref ->
  Trading_strategy.Position.transition * entry_meta ->
  (Trading_strategy.Position.transition * entry_meta) option
(** Check that the transition's cost ([target_quantity * entry_price]) fits in
    [remaining_cash]. Deducts and returns [Some] when it does, returns [None]
    otherwise. Pass-through for non-[CreateEntering] transitions. *)

val check_short_notional_cap :
  short_notional_acc:float ref ->
  short_notional_cap:float ->
  Trading_strategy.Position.transition * entry_meta ->
  Screener.scored_candidate ->
  (Trading_strategy.Position.transition * entry_meta) option
(** G15 step 2: aggregate short-notional cap. For [Long] candidates:
    pass-through [Some]. For [Short] candidates: returns [Some] only when
    [!short_notional_acc + (shares * effective_entry_price) <=
     short_notional_cap]; otherwise [None]. Bumps [short_notional_acc] on the
    pass case so later candidates in the same entry walk see the up-to-date
    running total. *)

val classify_candidate :
  held_set:Core.String.Set.t ->
  make_entry:(Screener.scored_candidate -> entry_attempt_result) ->
  remaining_cash:float ref ->
  short_notional_acc:float ref ->
  short_notional_cap:float ->
  Screener.scored_candidate ->
  candidate_decision
(** Classify one candidate as [Kept] or [Skipped reason]. The four skip reasons
    match {!Audit_recorder.skip_reason}: held, sized to zero, rejected by the
    running cash check, or rejected by the running short-notional cap. Order:
    held-check, sizing via [make_entry], cash check, then short-notional cap.

    The cash check tentatively deducts before the short-notional gate; on a
    [Short_notional_cap] rejection the deducted cash is refunded into
    [remaining_cash] so subsequent candidates see the correct balance. *)
