(** Entry-side audit emission.

    Projects the entry walk's tagged decisions
    ({!Entry_audit_capture.candidate_decision}) into audit rows: the
    [alternatives_considered] lists, the per-Friday passed-over population, and
    the {!Audit_recorder.entry_event} for every funded candidate. Split out of
    {!Entry_audit_capture} (which owns per-candidate entry construction and the
    cash / notional / sector gate chain) so each module stays under the
    file-length cap. Pure projections plus the [audit_recorder.record_entry]
    call — no effect on which candidates are funded. *)

val alternatives_of_decisions :
  decisions:
    (Screener.scored_candidate * Entry_audit_capture.candidate_decision) list ->
  exclude_position_id:string ->
  Audit_recorder.alternative_input list
(** Build the [alternatives_considered] list for a chosen candidate's audit row.
    Every other candidate from the same screen call surfaces here:

    - [Skipped reason] candidates pass through verbatim with the captured
      [reason].
    - [Kept] rivals (other entered candidates) are excluded — they have their
      own [entry_decision] records, and cross-trade analysis joins on
      [position_id]. *)

val all_alternatives_of_decisions :
  decisions:
    (Screener.scored_candidate * Entry_audit_capture.candidate_decision) list ->
  Audit_recorder.alternative_input list
(** Project the {b whole} walk's passed-over candidates, unscoped to any chosen
    entry — the per-Friday counterpart to {!alternatives_of_decisions}.

    Same per-candidate content, different addressing:
    [alternatives_of_decisions] answers "what did {i this} funded entry
    outrank?" and so is only reachable when something was funded, while this
    answers "what did the walk pass over {i this Friday}?" and is therefore
    emitted even on a Friday that funded nothing. That is issue #2490's gap G1;
    the caller hands the result to {!Audit_recorder.cascade_event.candidates}.

    [Kept] decisions are excluded — a funded candidate has its own
    {!Audit_recorder.entry_event}, and cross-artefact joins key on
    [position_id]. So the emitted list plus the week's [entered] count together
    account for the screener's top-N population. *)

val build_entry_event :
  macro:Macro.result ->
  current_date:Core.Date.t ->
  candidate:Screener.scored_candidate ->
  meta:Entry_audit_capture.entry_meta ->
  alternatives:Audit_recorder.alternative_input list ->
  Audit_recorder.entry_event
(** Project [(candidate, meta, alternatives)] into an
    {!Audit_recorder.entry_event}. Computes the dollar-denominated sizing fields
    ([initial_position_value], [initial_risk_dollars]) from [meta.shares],
    [meta.effective_entry_price], and [meta.installed_stop]. The audit row's
    [candidate] field still carries the screener-original
    [candidate.suggested_entry], so consumers can compare the screener's
    pre-fill intent against the strategy's realised entry.

    Also stamps the PR-5 placement-time ticket tags: [sized_down_wide_stop] from
    [meta], and the F1 freshness basis + F6 §4.5 triple-confirmation
    measurements projected off [candidate.analysis] by {!Entry_ticket_tags}. All
    three are pure reads of values already in scope — no extra bar walk, no
    behaviour change. *)

val emit_entries :
  audit_recorder:Audit_recorder.t ->
  macro:Macro.result option ->
  current_date:Core.Date.t ->
  decisions:
    (Screener.scored_candidate * Entry_audit_capture.candidate_decision) list ->
  unit
(** For every [Kept] entry in [decisions], compute the [alternatives] list,
    build an [entry_event], and route it through [audit_recorder.record_entry].
    [Skipped] entries are silently dropped — they surface as alternatives in
    other Kept entries' rows.

    No-op when [macro] is [None] (the strategy did not run macro this tick, so
    the entry walk is being driven from a test fixture without macro state —
    skip audit emission rather than fabricate a Neutral macro). *)
