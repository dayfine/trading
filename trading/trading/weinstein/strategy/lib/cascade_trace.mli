(** Per-Friday candidate capture for the [candidates.sexp] artefact (#2490).

    Owns the three things {!Weinstein_strategy_screening.screen_universe} would
    otherwise have to carry inline — a parking slot for the cascade's private
    candidate list, a parking slot for what the entry walk passed over, and the
    construction of the Friday's {!Audit_recorder.cascade_event}. It lives in
    its own module because that coordinator sits at the file-length cap and its
    screen function at the function-length cap, so the capture had nowhere to go
    ([.claude/rules/code-health-discipline.md]: extract, do not raise the
    limit).

    The whole module is {b inert} unless the recorder opted into capture: the
    handle installs no callback, neither the screener nor the strategy computes
    a projection, and the emitted event carries empty lists — bit-identical to
    the pre-#2490 path. *)

val of_screen :
  config:Screener.config ->
  macro_trend:Weinstein_types.market_trend ->
  candidates:(Stock_analysis.t * Screener.sector_context) list ->
  result:Screener.result ->
  Audit_recorder.cascade_drop list
(** [of_screen ~config ~macro_trend ~candidates ~result] names every candidate
    the cascade evaluated and the phase that dropped it, longs first then
    shorts. A pure function of its four arguments, so the mapping is testable
    without driving a screen.

    Both sides are traced, so a candidate the cascade weighed for a long and a
    short appears twice, distinguished by {!Audit_recorder.cascade_drop.side} —
    the two sides score and gate the same name differently, and collapsing them
    would silently pick one.

    {b A macro-blocked side is omitted entirely} rather than emitted as a run of
    [Dropped_at_macro] rows. Nothing is lost: the same Friday's
    [cascade_summary] records [long_macro_admitted = 0] (resp. short), which
    already says the whole side was blocked, and emitting one row per universe
    member to repeat it would dominate the artefact. The macro gate applied here
    is the {b diagnostics'} gate ([macro_trend <> Bearish] for longs,
    [<> Bullish] for shorts), not the live evaluation's [neutral_blocks_longs]
    or [deteriorating_blocks_longs] variant, so the trace and the counts agree
    on a Neutral tape. The divergence is deliberate and is shared with
    {!Screener_candidate_trace}: the trace answers "which phase dropped this
    name", and pinning it to the diagnostics' gate keeps it consistent with the
    [cascade_summary] counts emitted for the same Friday. When either
    long-tightening flag is armed the trace therefore still emits long rows for
    a tape the live cascade blocked; read [cascade_summary.long_macro_admitted]
    for the live answer.

    {b Cost.} One score per candidate per admitted side — paid only when the
    caller opts into capture. The artefact is O(universe x sides x Fridays), so
    a broad-universe multi-decade run produces a large file; this is a
    diagnostic you ask for, not one you get by default. *)

(** {1 The top-N view}

    The screener caps its sorted output at [max_buy_candidates] before the entry
    walk checks anything, so a name ranked past the cap is never asked whether
    it was buyable. These two functions ask it, offline, with the walk's own
    check, and attach the answer ({!Audit_recorder.Top_n.t}) to the cascade rows
    that cleared every per-candidate gate. *)

val shadow_verdict :
  Entry_walk.walk_report ->
  Screener.scored_candidate ->
  Audit_recorder.Top_n.shadow
(** [shadow_verdict report cand]: [Already_held] when [report.held] holds the
    symbol; otherwise [report.stop_check cand] — the walk's own initial-stop
    computation — read as the walk reads it: the investor-preset gate first
    ([No_structural_stop]), then the [max_stop_distance_pct] width gate
    ([Stop_too_wide] on its [Drop], [Buyable] on either admit), each carrying
    the distance that gate measured.

    {b Pure.} It places no order, debits no cash, registers no stop state,
    consumes no position id and emits no debug trace: [stop_check] is
    {!Entry_stop_check.evaluate}, which does none of those. Cash, the notional
    and sector caps, the share-class rule and sizing are deliberately ignored.
    So are the entry-assembly gates (short side off, liquidity, bar recency,
    delisting, declining MA) and, under [freeze_entry_at_first_breakout]
    (default off), the re-pinning of a previously walked name's entry: the
    shadow judges the screener's candidate as the cap cut it, and must not touch
    the pin table. *)

val with_top_n :
  config:Screener.config ->
  date:Core.Date.t ->
  candidates:(Stock_analysis.t * Screener.sector_context) list ->
  decisions:Audit_recorder.walk_decision list ->
  report:Entry_walk.walk_report ->
  Audit_recorder.cascade_drop list ->
  Audit_recorder.cascade_drop list
(** Fill [top_n] on every [Admitted] and [Dropped_at_top_n] row of [drops]
    (others keep [None]), in place of order.

    The rank is the row's position in {!Screener.rank_survivors}
    [~config ~as_of:date ~candidates] for its side — the order the cap cut. An
    [Admitted] row gets [Walked] with its entry in [decisions] (matched on
    ticker and side) and, when the walk built a stop for it, the distance
    [report.stop_check] measures on the walk's own copy of the candidate; with
    no entry it gets [Not_reached]. A [Dropped_at_top_n] row gets
    [Shadow (shadow_verdict report cand)] on the screener's candidate.

    Neither the walk's order nor its decisions can change: this runs after the
    walk, on its finished output. Cost, paid only under capture: one uncapped
    re-sort of the cascade survivors and one stop check per cleared row (every
    survivor past the cap, plus the walked names that built a stop). Pure. *)

(** {1 Per-Friday capture handle}

    {!of_screen} is the whole computation, but a caller also needs somewhere to
    park the two callbacks' output between the screen, the entry walk, and the
    cascade event. This handle is that place, so the screening coordinator gains
    three lines rather than two refs, a gate and a conditional. *)

type t

val create : Audit_recorder.t -> t
(** A capture handle for one Friday. The G1/G2 capture is {b inert} unless
    [recorder.capture_candidates] is [true]: {!on_candidates} and
    {!on_walk_report} then return [None] (neither the screener nor the walk is
    handed a callback) and {!record} emits an event whose [candidates] and
    [drops] are empty and whose [long_cash_left_pct] is [None]. The weekly
    decision record (#3139) is not gated: {!on_walk_candidates} always offers a
    sink and the event's [decisions] always carries the walk's top-N outcomes.
*)

val on_candidates :
  t -> ((Stock_analysis.t * Screener.sector_context) list -> unit) option
(** Pass straight to {!Screener.screen_with_cooldown}'s [?on_candidates]. [None]
    when inert. *)

val on_walk_candidates : t -> (Audit_recorder.walk_decision list -> unit) option
(** Pass straight to {!Entry_walk.entries_from_candidates}'s
    [?on_candidates_considered]. Always [Some] since #3139: the walk's decisions
    feed {!Audit_recorder.cascade_event.decisions} on every Friday, and, when
    capture is on, its passed-over rows feed [candidates]. *)

val on_walk_report : t -> (Entry_walk.walk_report -> unit) option
(** Pass straight to {!Entry_walk.entries_from_candidates}'s [?on_walk_report].
    [None] when inert, so the walk never builds the report and no top-N view is
    computed. When capturing, {!record} hands the report to {!with_top_n} and
    copies its [long_cash_left_pct] onto the event. *)

val record :
  t ->
  audit_recorder:Audit_recorder.t ->
  date:Core.Date.t ->
  config:Screener.config ->
  macro:Macro.result ->
  result:Screener.result ->
  entered:int ->
  unit
(** Build this Friday's {!Audit_recorder.cascade_event} — [result]'s
    [cascade_diagnostics], the macro reading, [entered], whatever
    {!on_walk_candidates} captured, and {!of_screen} over whatever
    {!on_candidates} captured, with the top-N view ({!with_top_n}) and the long
    walk's unspent cash when {!on_walk_report} captured a report — and route it
    through [audit_recorder.record_cascade_summary].

    [~macro] supplies two independent things and only two: its [breadth_state]
    is recorded verbatim on the event, and its [trend] drives the drop trace's
    own macro gate exactly as before. The trace never consults [breadth_state],
    so a five-state reading cannot silently move which candidates it reports.

    Call once per screened Friday, {b after} the entry walk — [entered] must
    count the transitions actually emitted, not the screener's top-N. *)
