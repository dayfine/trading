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
  split_safe_basis : Audit_recorder.split_safe_basis;
      (** F5 telemetry: which price basis the support-floor scan for this entry
          ran on. [Raw_fallback] means [stops_config.split_safe_floors] was on
          but the lookback window could not be rescaled, so the scan returned
          the flag-off answer — invisible in [installed_stop] alone. Carried
          straight into {!Audit_recorder.entry_event}. *)
  effective_entry_price : float;
      (** The price the strategy installs into [Position.t] state — most recent
          close from [bar_reader] at order placement, or
          [candidate.suggested_entry] when no bars are available (G14 fix). The
          dollar-denominated audit fields ([initial_position_value],
          [initial_risk_dollars] in {!build_entry_event}) key off this rather
          than [candidate.suggested_entry] so the audit reflects the realised
          entry rather than the screener's pre-fill intent. *)
  close_at_decision : float option;
      (** Most recent close from [bar_reader] at entry construction — recorded
          even when the entry basis is E-anchored ([trigger_at_suggested]), so
          the audit can always compare [candidate.suggested_entry] against the
          decision-time close. [None] when no bars were available. Carried into
          {!Audit_recorder.entry_event.close_at_decision}. *)
  sized_down_wide_stop : bool;
      (** F3 audit tag ([Sized_down_wide_stop]). [true] when
          [config.stop_width_mode = Size_down] admitted this candidate even
          though its structural stop sits further than
          [stops_config.max_stop_distance_pct] from entry — i.e. the entry
          exists only because the §5.1 drop was waived, and its share count is
          the risk-parity-shrunk one. Always [false] under the default
          [Drop_over_max] (such candidates are dropped, never entered), so this
          field partitions a [Size_down] run's entries into "would have been
          entered anyway" and "admitted by the mechanism".

          PR-5 ([dev/plans/entry-ticket-async-v2-2026-08-10.md] §4) discharges
          PR-2's deferral: {!build_entry_event} now also carries the tag onto
          {!Audit_recorder.entry_event.sized_down_wide_stop}, from where it is
          persisted in the [Backtest.Trade_audit.entry_decision] row. The
          strategy-internal meta and the [PANEL_GOLDEN_DEBUG] candidate trace
          are unchanged. *)
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

val all_alternatives_of_decisions :
  decisions:(Screener.scored_candidate * candidate_decision) list ->
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
  meta:entry_meta ->
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
  ?min_stop_distance_pct:float ->
  ?trigger_at_suggested:bool ->
  ?stop_anchor_at_entry_base:bool ->
  ?stop_width:Stop_width_mode.policy ->
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
    pre-fill suggestion.

    [?min_stop_distance_pct] (default [0.0] = no floor) is plumbed into step (2)
    via {!Weinstein_stops.widen_initial_to_min_distance}. When [> 0.0], the
    [Initial] stop is widened if needed so its [stop_level] sits at least
    [min_stop_distance_pct] away from [effective_entry]. Used by the strategy to
    re-wire {!Screener.candidate_params.initial_stop_pct} into the
    installed-stop path — preserves the G15 sizing invariant because sizing
    still keys off the final installed [stop_level].

    [?trigger_at_suggested] (default [false]) is the book-faithful E-anchored
    entry override (user decision 2026-08-05): when [true], step (1) pins
    [effective_entry] to [cand.suggested_entry] (the breakout level [E]) instead
    of the current close, so the emitted [StopLimit] rests at [E] and sizing
    (step 4) anchors at [E]. The caller sets this to
    [config.sim_entry_trigger_at_suggested && config.enable_sim_entry_stoplimit];
    default [false] is bit-identical to the current-close path (R1). See
    {!Entry_audit_helpers.effective_entry_price} and
    {!Weinstein_strategy_config.sim_entry_trigger_at_suggested}.

    [?stop_anchor_at_entry_base] (default [false]) is the book §5.1 initial-stop
    re-anchoring that PAIRS with the E-anchored entry (user go 2026-08-06). It
    fires only when this flag AND [trigger_at_suggested] are both [true] (the
    E-family armed): a support-floor initial stop farther than
    [stops_config.max_stop_distance_pct] from [E] — the crash-floor mismatch
    that trips step (3)'s [Stop_too_wide] gate for crash-recovery names — is
    re-anchored in step (2) to the buffer-below-breakout stop
    ([initial_stop_buffer] fallback), so the ticket's risk pairs faithfully with
    its E entry and clears the gate. Structural floors already within the 15%
    limit are unchanged. INITIAL stop only; the gate itself and the trailing
    machinery are untouched. The caller sets it to
    [config.stop_anchor_at_entry_base]; default [false] is bit-identical (R1).
    See {!Entry_audit_helpers.initial_stop_and_kind} and
    {!Weinstein_strategy_config.stop_anchor_at_entry_base}.

    [?stop_width] (default {!Stop_width_mode.default_policy}) parameterises step
    (3). Under the default [Drop_over_max] the step is bit-identical to the
    pre-F3 code: distance over [stops_config.max_stop_distance_pct] ⇒
    [Stop_too_wide] (R1). Under [Size_down] such a candidate is admitted instead
    (up to [stop_width.size_down_max_pct], the sanity ceiling above which it is
    still dropped) and its [entry_meta.sized_down_wide_stop] is [true]. Sizing
    itself is untouched — step (4) already keys off the installed stop, so the
    wider stop mechanically yields ~[1 / stop_distance] fewer shares, which is
    exactly the risk-parity size-down. The caller builds the policy from
    [config.stop_width_mode] / [config.stop_width_size_down_max_pct]; see
    {!Stop_width_mode} for the honest-citation framing (a tolerated-
    participation reading of §5.1, not a documented book mechanism). *)

val check_cash_and_deduct :
  leverage_enabled:bool ->
  remaining_cash:float ref ->
  Trading_strategy.Position.transition * entry_meta ->
  (Trading_strategy.Position.transition * entry_meta) option
(** Check that the transition's cost ([target_quantity * entry_price]) fits in
    [remaining_cash]. Deducts and returns [Some] when it does, returns [None]
    otherwise. Pass-through for non-[CreateEntering] transitions.

    M1b long-margin leverage: when [leverage_enabled = true] (the config's
    [initial_long_margin_req < 1.0]) a [Long] transition is funded even when its
    cost exceeds [remaining_cash] — [remaining_cash] is driven negative (the
    debit / borrowed balance) and [Some] is always returned. The buying-power
    ceiling is enforced downstream by {!check_long_notional_cap} against
    [long_notional_cap], which is finite whenever leverage is engaged, so the
    debit is bounded by [equity / initial_long_margin_req]. When
    [leverage_enabled = false] (the default cash-account setting) and for every
    [Short], this is byte-identical to the pre-M1b gate: a cost over
    [remaining_cash] returns [None] (R1). *)

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

val check_long_notional_cap :
  long_notional_acc:float ref ->
  long_notional_cap:float ->
  Trading_strategy.Position.transition * entry_meta ->
  Screener.scored_candidate ->
  (Trading_strategy.Position.transition * entry_meta) option
(** P0b 2026-07-13: aggregate long-notional cap. Mirror of
    {!check_short_notional_cap} for the long side. For [Short] candidates:
    pass-through [Some]. For [Long] candidates: returns [Some] only when
    [!long_notional_acc + (shares * effective_entry_price) <= long_notional_cap];
    otherwise [None]. Bumps [long_notional_acc] on the pass case so later
    candidates in the same entry walk see the up-to-date running total.

    The default [long_notional_cap = Float.infinity] (config field [<= 0.0])
    makes every long admit — an exact no-op that preserves all long-only
    goldens. The cap is entry-price-denominated (committed-at-entry notional),
    NOT marked value, so unrealized appreciation of held winners can push marked
    exposure over 100% of NAV without tripping the gate — only entries funded
    beyond the cap at entry time are rejected (the 2026-07-13 Run-E artifact).
    See [Weinstein_strategy_config.max_long_exposure_pct_entry]. *)

val check_sector_exposure_cap :
  sector_exposure_acc:(string, float) Core.Hashtbl.t ->
  max_sector_exposure_pct:float option ->
  portfolio_value:float ->
  Trading_strategy.Position.transition * entry_meta ->
  Screener.scored_candidate ->
  (Trading_strategy.Position.transition * entry_meta) option
(** P1 2026-05-15: aggregate per-sector exposure cap evaluated at entry-decision
    time. Mirrors {!check_short_notional_cap}'s shape so the gate composes
    uniformly in {!classify_candidate}.

    Pass-through [Some] on every candidate when [max_sector_exposure_pct = None]
    (default-off; preserves all goldens). When [Some pct] and the candidate's
    sector is non-empty, returns [Some] only when
    [(existing_sector_exposure + (shares * effective_entry_price)) /
     portfolio_value <= pct].

    The empty-string (unknown) sector is exempt — pass-through [Some]; its
    discipline comes from the count-cap [max_unknown_sector_positions] instead.

    Side-effect on the pass case: bumps [sector_exposure_acc] for the
    candidate's sector by [shares * effective_entry_price] so later candidates
    in the same entry walk see the up-to-date running total. *)

val classify_candidate :
  ?leverage_enabled:bool ->
  held_set:Core.String.Set.t ->
  make_entry:(Screener.scored_candidate -> entry_attempt_result) ->
  remaining_cash:float ref ->
  short_notional_acc:float ref ->
  short_notional_cap:float ->
  long_notional_acc:float ref ->
  long_notional_cap:float ->
  sector_exposure_acc:(string, float) Core.Hashtbl.t ->
  max_sector_exposure_pct:float option ->
  portfolio_value:float ->
  Screener.scored_candidate ->
  candidate_decision
(** Classify one candidate as [Kept] or [Skipped reason]. The skip reasons match
    {!Audit_recorder.skip_reason}: held, sized to zero, rejected by the running
    cash check, rejected by the running short-notional cap, rejected by the
    running long-notional cap, or rejected by the running sector-exposure cap.
    Order: held-check, sizing via [make_entry], cash check, short-notional cap,
    long-notional cap, then sector-exposure cap.

    [?leverage_enabled] (default [false]) is threaded into the cash gate
    ({!check_cash_and_deduct}) for M1b long-margin leverage. At the default
    ([false], the cash-account setting) the cash gate is byte-identical to
    pre-M1b; when [true] a [Long] may be funded beyond [remaining_cash] with the
    buying-power ceiling ([long_notional_cap]) as the sole bound.

    The cash check tentatively deducts before the notional and sector-exposure
    gates; on a [Short_notional_cap], [Long_exposure_cap], or
    [Sector_exposure_cap] rejection the deducted cash is refunded into
    [remaining_cash] so subsequent candidates see the correct balance. The
    long-notional cap is a no-op ([long_notional_cap = Float.infinity]) under
    the default config, so ordering it before the sector gate does not perturb
    baseline behaviour. *)
