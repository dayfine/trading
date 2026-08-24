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
    variant, so the trace and the counts agree on a Neutral tape.

    {b Cost.} One score per candidate per admitted side — paid only when the
    caller opts into capture. The artefact is O(universe x sides x Fridays), so
    a broad-universe multi-decade run produces a large file; this is a
    diagnostic you ask for, not one you get by default. *)

(** {1 Per-Friday capture handle}

    {!of_screen} is the whole computation, but a caller also needs somewhere to
    park the two callbacks' output between the screen, the entry walk, and the
    cascade event. This handle is that place, so the screening coordinator gains
    three lines rather than two refs, a gate and a conditional. *)

type t

val create : Audit_recorder.t -> t
(** A capture handle for one Friday, {b inert} unless
    [recorder.capture_candidates] is [true]: {!on_candidates} and
    {!on_walk_candidates} then return [None] (so neither the screener nor the
    entry walk installs a callback or allocates anything) and {!record} emits an
    event carrying empty lists. Inert is the default and every non-audit
    context. *)

val on_candidates :
  t -> ((Stock_analysis.t * Screener.sector_context) list -> unit) option
(** Pass straight to {!Screener.screen_with_cooldown}'s [?on_candidates]. [None]
    when inert. *)

val on_walk_candidates :
  t -> (Audit_recorder.alternative_input list -> unit) option
(** Pass straight to {!Entry_walk.entries_from_candidates}'s
    [?on_candidates_considered]. [None] when inert, so the entry walk never
    computes the projection. *)

val record :
  t ->
  audit_recorder:Audit_recorder.t ->
  date:Core.Date.t ->
  config:Screener.config ->
  macro_trend:Weinstein_types.market_trend ->
  result:Screener.result ->
  entered:int ->
  unit
(** Build this Friday's {!Audit_recorder.cascade_event} — [result]'s
    [cascade_diagnostics], [entered], whatever {!on_walk_candidates} captured,
    and {!of_screen} over whatever {!on_candidates} captured — and route it
    through [audit_recorder.record_cascade_summary].

    Call once per screened Friday, {b after} the entry walk — [entered] must
    count the transitions actually emitted, not the screener's top-N. *)
