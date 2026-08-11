open Core
open Trading_strategy

(** F5 — at-fill breakout-volume confirmation, and the eject that is inseparable
    from it.

    Plan: [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F5. Book:
    [docs/design/weinstein-book-reference.md] §4.7 ("Volume is judged AT the
    fill, not at placement") + §4.2 (the two confirmation branches and the
    low-volume-breakout SELL rule).

    {1 Why this exists}

    Weinstein's §4.7 entry is a GTC buy-stop written {i before} the breakout. At
    the moment the ticket is placed the breakout week has not happened, so its
    volume is unknowable — yet §4.2 requires the breakout to carry volume. The
    two are reconciled by evaluating volume on the week the ticket {b fills},
    which is the breakout week. Under
    [Weinstein_strategy_config.volume_confirm_at_fill] the screener stops
    demanding volume at placement
    ([Stock_analysis.config.require_breakout_volume = false]) and this runner
    takes over the check.

    {1 The eject is inseparable from the flag}

    There is deliberately no "confirm but hold" cell. Holding a
    volume-unconfirmed breakout would drop spine item 3 ("entry on a breakout
    above resistance {b with} volume confirmation",
    [.claude/rules/weinstein-faithful-core.md] W1), and §4.2's
    low-volume-breakout SELL rule is explicit that a buy-stop filled on
    unconfirmed volume is sold rather than held. The placement waiver and this
    runner therefore read one predicate,
    {!Weinstein_strategy_config.volume_confirm_at_fill_armed}; neither half is
    reachable alone.

    A later trader/investor variant of the unconfirmed branch
    ([eject | hold_with_stop_at_breakout], plan §3-F5 amendment (iv)) is {b not}
    built here.

    {1 Timing — no partial-week lookahead}

    The verdict is computed from the {i completed} weekly bar containing the
    position's entry date, and only on a screening tick (Friday, the week's
    closing bar). A mid-week tick never evaluates, so the runner can never read
    a partial week's volume. The eject transition is emitted at that screening
    tick's close and executes on the following session under the simulator's
    exit-fill model — the plan's "eject at next fresh open".

    Evaluation is confined to a two-week window after the fill (the fill week's
    own closing tick, plus one week of slack so a fill landing {i on} a
    screening day is still checked). The verdict is a pure function of a fixed
    historical bar, so a repeat evaluation inside that window is idempotent: a
    confirmed position is never ejected later, and an unconfirmed one is already
    gone.

    {1 Fail-soft}

    Missing bars, or too little history for either §4.2 branch
    ([Volume.confirms_breakout] returning [None]), produce {b no} eject. Absence
    of evidence is not an unconfirmed breakout. *)

val update :
  config:Weinstein_strategy_config.config ->
  volume_config:Volume.config ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  bar_reader:Bar_reader.t ->
  get_price:(string -> Types.Daily_price.t option) ->
  skip_position_ids:Set.M(String).t ->
  current_date:Date.t ->
  Position.transition list
(** [update ~config ~volume_config ~is_screening_day ~positions ~bar_reader
     ~get_price ~skip_position_ids ~current_date] returns one [TriggerExit] per
    freshly-filled LONG position whose fill-week volume confirms {b neither}
    §4.2 branch.

    Returns [[]] — with no bar reads at all — when
    [Weinstein_strategy_config.volume_confirm_at_fill_armed config] is [false]
    (the default), when [is_screening_day] is [false], or when there are no
    positions. This is the R1 no-op: the default config is bit-identical to
    pre-F5 behaviour.

    [volume_config] is the same [Volume.config] the screener's confirmation
    grade uses (threaded from [Stock_analysis.config.volume] by the caller), so
    the at-fill thresholds and the screen-time thresholds cannot drift.

    Only [Holding] LONG positions are eligible: F5 is a property of the
    long-side E-anchored breakout ticket. Positions listed in
    [skip_position_ids] (already exiting this tick via another channel) are
    skipped — two exits on one position would be rejected by the position state
    machine.

    The emitted [exit_reason] is
    [Position.StrategySignal { label = "volume_eject"; detail }] — the
    [Volume_eject] audit tag, surfacing in the [exit_trigger] column of
    [trades.csv]; [detail] carries the fill-week offset for forensics. Same
    close-fill convention as the sibling special-exit runners. *)

val fill_week_confirmations :
  config:Weinstein_strategy_config.config ->
  volume_config:Volume.config ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  bar_reader:Bar_reader.t ->
  current_date:Date.t ->
  (string * Volume.breakout_confirmation option) list
(** The {b audit} counterpart of {!update}: [(position_id, classification)] for
    every evaluable fill-week LONG holding this tick — not only the ones
    {!update} ejects, and {b not only the ones it was allowed to act on}.

    {b The population is deliberately WIDER than {!update}'s, by exactly
       [skip_position_ids].} {!update} skips a position that another exit
    channel (stop, Stage-3, laggard, force-liq, liquidity, extension) has
    already claimed this tick; this function does not, because the fill's volume
    verdict is a property of the {i fill}, independent of whatever else befell
    the position that day — and that skipped cohort (weak-volume breakout that
    stops out in week 0/1) is precisely what the plan's §5 prediction 4
    measures. A count of [Unconfirmed] rows here is therefore {b not} an eject
    count; {!emit_fill_week_audit} pairs each row with the outcome that
    disambiguates it.

    The shared private fill-week-window helper guarantees the two surfaces judge
    the same {b bar} and apply the same shape test (LONG, [Holding], inside the
    evaluation window); it does {i not} equalise their {b eligibility}. The
    classification is {!Volume.classify_breakout} rather than its boolean
    projection, so the audit can separate:

    - [Some (Spike r)] — confirmed via §4.2 branch (a), at multiple [r];
    - [Some (Buildup m)] — confirmed via branch (b), at multiple [m];
    - [Some (Unconfirmed _)] — evaluated, neither branch confirmed ⇒ the F5 rule
      {i would} eject (and did, unless the position was in [skip_position_ids]);
    - [None] — {b no verdict}: neither branch had enough history, so the runner
      {b held} the position. This is the held-without-verdict cell, which the
      eject count alone cannot distinguish from a confirmed hold. Measuring its
      size is a precondition for reading a ladder-v4 F5 arm's eject rate
      (qc-behavioral #2267 recommendation).

    Returns [[]] — with no bar reads — when
    [Weinstein_strategy_config.volume_confirm_at_fill_armed config] is [false]
    (the default) or [is_screening_day] is [false]. Order follows [positions]
    key order. Pure: no transitions, no state, no effect on the run. *)

val emit_fill_week_audit :
  config:Weinstein_strategy_config.config ->
  audit_recorder:Audit_recorder.t ->
  volume_config:Volume.config ->
  is_screening_day:bool ->
  positions:Position.t Map.M(String).t ->
  bar_reader:Bar_reader.t ->
  skip_position_ids:Set.M(String).t ->
  ejected_position_ids:Set.M(String).t ->
  current_date:Date.t ->
  unit
(** Route every {!fill_week_confirmations} row through
    [audit_recorder.record_fill_volume], so the per-entry [Backtest.Trade_audit]
    row records the fill-week verdict {b and} what the run did about it. Lives
    next to the runner that owns the verdict rather than in the exit pipeline
    that calls it.

    Each row's [Audit_recorder.fill_volume_outcome] is read off the two id sets
    the caller observed on this very tick — [ejected_position_ids] (the
    [volume_eject] transitions {!update} just returned) and [skip_position_ids]
    (the same set passed to {!update}) — never inferred from the verdict:

    - in [ejected_position_ids] ⇒ [Ejected];
    - otherwise in [skip_position_ids] ⇒ [Skipped_other_exit] — evaluated by
      this surface but never considered by {!update};
    - otherwise ⇒ [Held].

    Pass the {i same} [skip_position_ids] given to {!update} on this tick;
    passing a different set mislabels the divergent cohort.

    Inherits {!fill_week_confirmations}'s guards verbatim: a no-op emitting
    nothing, and reading no bars, unless F5 is armed on a screening tick.
    Observational only — emits no transitions and cannot influence any simulated
    number. *)

val eject_label : string
(** ["volume_eject"] — the [StrategySignal] label carried by every transition
    this runner emits (the [Volume_eject] audit tag). Exposed so tests and audit
    consumers assert against one constant. *)
