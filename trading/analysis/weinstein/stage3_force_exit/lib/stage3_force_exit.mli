(** Stage-3 force-exit detector — capital recycling on the long side (#872).

    Per Weinstein Ch. 6 §5.2 (STAGE3_TIGHTENING) and Ch. 2 (Stage 3 detail):
    when a held long position transitions from Stage 2 to Stage 3
    ("topping/distribution" — 30-week MA flattening, price oscillating around
    the MA), the book authority calls for either tightening the trailing stop or
    exiting outright. This detector implements the exit-outright variant — the
    trader-side discipline ("Traders: exit with profits") — to free portfolio
    cash for fresh Stage-2 candidates. See
    [dev/notes/856-optimal-strategy-diagnostic-15y-2026-05-06.md] for the
    empirical motivation: the live strategy generated zero Stage-3 exits over a
    16-year window, locking ~$1M in 18 long-runners that the cascade kept
    rejecting candidates against because of [Insufficient_cash].

    {1 Detection signature}

    The detector reuses the existing {!Stage.classify} authority: a position is
    "in Stage 3" when its weekly classification yields [Stage3 _]. The
    classifier already encodes the book's MA-flat + price-oscillation rules, so
    this module does not re-implement them. The detector adds {b hysteresis} on
    top: a force-exit fires only when [Stage3 _] is observed for
    [config.hysteresis_weeks] consecutive Friday classifications. This avoids
    whipsaw on a single transient flattening that resolves back into Stage 2.

    Any non-[Stage3] classification resets the consecutive count to zero.

    {1 What the module does NOT do}

    - Does NOT classify stages itself — call {!Stage.classify} (or its callback
      variants) and pass the result in.
    - Does NOT generate the [Position.transition] — the strategy wiring layer
      builds the {!Position.TriggerExit} with the
      {!Position.exit_reason.Stage3ForceExit} variant once this detector decides
      [Force_exit].
    - Does NOT touch trailing-stop state. A position force-exited under this
      mechanism leaves its stop state stale; the wiring layer is responsible for
      the cleanup (typically by removing the stop-state entry on exit).
    - Does NOT apply to short positions. The book authority for shorts (§6.3)
      uses different stage transitions; short-side force-exit would require a
      separate analysis. Today the detector returns [Hold] for any non-long
      classification result; callers wire only the long branch. *)

type config = {
  hysteresis_weeks : int;
      (** Number of consecutive Stage-3 classifications required before the
          detector emits [Force_exit]. Default 2.

          - K = 1 fires on first Stage-3 observation — most aggressive, prone to
            whipsaw on transient flattening.
          - K = 2 (default) requires two consecutive Friday Stage-3 reads —
            book-aligned with §5.2 STAGE3_TIGHTENING which fires "when MA
            flattens out" rather than on a single noisy week.
          - K ≥ 3 is more conservative; trades alpha for stability. *)
}
[@@deriving sexp]
(** Configuration for the detector. *)

val default_config : config
(** Defaults: [{ hysteresis_weeks = 2 }]. *)

(** Decision emitted by {!observe}. *)
type decision =
  | Hold
      (** Either the current stage is not Stage 3, or the consecutive Stage-3
          count has not yet reached [config.hysteresis_weeks]. The caller takes
          no exit action. *)
  | Force_exit of { weeks_in_stage3 : int }
      (** Stage 3 has been observed for [weeks_in_stage3] consecutive Friday
          classifications and [weeks_in_stage3 >= config.hysteresis_weeks]. The
          strategy wiring layer should emit a [Position.TriggerExit] with
          [exit_reason = Stage3ForceExit { weeks_in_stage3 }]. *)
[@@deriving show, eq]

val observe :
  config:config ->
  prior_consecutive_stage3:int ->
  current_stage:Weinstein_types.stage ->
  int * decision
(** [observe ~config ~prior_consecutive_stage3 ~current_stage] is the pure
    state-transition core of the detector.

    Returns a pair [(new_consecutive_stage3, decision)]:
    - When [current_stage] is [Stage3 _]: increments the consecutive count and
      emits [Force_exit] iff the new count [>= config.hysteresis_weeks].
    - When [current_stage] is anything other than [Stage3 _]: resets the
      consecutive count to [0] and emits [Hold].

    The detector does not consider the [weeks_topping] payload of [Stage3]
    directly — [weeks_topping] is the Stage classifier's own count (which can
    include weeks before the position was opened) and uses a different state
    machine (sticky across MA-direction noise). The detector's own
    consecutive-Friday count is a distinct, bounded measure of how long the
    detector has seen Stage 3 reads on this position.

    Pure function — same inputs always produce the same outputs.

    Edge case: when [config.hysteresis_weeks <= 0], the function treats
    [hysteresis_weeks = 1] (a single Stage-3 read fires immediately). This is
    defensive — a non-positive hysteresis would otherwise disable the detector
    entirely. The default config has K = 2; callers are expected to pass a
    positive value. *)

(** {1 Symbol-keyed convenience wrapper} *)

val observe_position :
  config:config ->
  state:(string, int) Core.Hashtbl.t ->
  symbol:string ->
  current_stage:Weinstein_types.stage ->
  decision
(** [observe_position ~config ~state ~symbol ~current_stage] looks up the prior
    consecutive-Stage-3 count for [symbol] in [state] (defaulting to [0] when
    missing), calls {!observe}, then writes the new count back into [state].
    Mutates [state] in place. Returns the [decision].

    Parallel to the [prior_stages] table in
    {!Weinstein_strategy._on_market_close} — kept as a separate hashtable so the
    detector's state is independent of the stage classifier's prior-stage
    threading. *)
