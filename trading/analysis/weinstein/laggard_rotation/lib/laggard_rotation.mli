(** Laggard-rotation detector — capital recycling on the long side (#887).

    Per Weinstein Ch. 4 §portfolio sizing (~lines 4929–4933), surfaced as §5.6
    in [docs/design/weinstein-book-reference.md]:

    > "If it's lagging badly and acting poorly, lighten up on that position >
    even if the sell-stop isn't hit. Move the proceeds into a new Stage 2 >
    stock with greater promise."

    Distinct from the Stage-3 force exit (#872): laggard rotation fires
    {b mid-Stage-2}, before the 30-week MA flattens, on weak relative-strength
    behaviour alone. The empirical motivation is identical (long-runners that
    never stop out lock cash that the cascade keeps rejecting candidates against
    because of [Insufficient_cash] — see
    [dev/notes/capital-recycling-framing-2026-05-06.md] §"Two proposed
    mechanisms"), but the trigger is RS-vs-market, not stage transition.

    {1 Detection signature}

    A position is a {b laggard} when its rolling 13-week return minus the
    benchmark's rolling 13-week return (i.e. relative strength over the
    intermediate-term window) has been
    {b negative for at least [config.hysteresis_weeks] consecutive Friday
       observations}. Any positive or zero RS reading resets the
    consecutive-negative count to zero.

    The 13-week window matches the Weinstein-canonical "intermediate-term"
    horizon used elsewhere in the strategy and is the smallest window that
    smooths through one earnings-season noise pulse.

    {1 What the module does NOT do}

    - Does NOT compute the 13-week returns itself — call [Bar_reader] (or any
      bar source) to read the position's and benchmark's weekly close sequences
      and pass the computed returns in.
    - Does NOT generate the [Position.transition] — the strategy wiring layer
      builds the [Position.TriggerExit] with the
      [Position.exit_reason.StrategySignal] variant
      ([label = "laggard_rotation"]) once this detector decides [Laggard_exit].
    - Does NOT touch trailing-stop state. A position rotated under this
      mechanism leaves its stop state stale; the wiring layer is responsible for
      any cleanup (typically by removing the stop-state entry on exit).
    - Does NOT apply to short positions. Short-side relative-strength semantics
      are inverted (short profits when RS is negative — exactly the laggard
      signal here would mean the short is winning), so the runner filters to
      long positions only and the detector itself takes no side argument. *)

type config = {
  hysteresis_weeks : int;
      (** Number of consecutive negative-RS Friday observations required before
          the detector emits [Laggard_exit]. Default 4 (issue #887:
          "configurable; e.g., 4-6 weeks").

          - K = 1 fires on first negative-RS observation — most aggressive,
            prone to whipsaw on a single noisy week.
          - K = 4 (default) requires roughly one trading month of negative
            relative strength. Book-aligned with §5.6 "lagging badly" — a single
            down week is not "lagging badly".
          - K ≥ 6 is more conservative; trades alpha for stability. *)
  rs_window_weeks : int;
      (** Rolling window (in weeks) over which the position's return is compared
          to the benchmark's return. Default 13 — Weinstein-canonical
          intermediate-term horizon. *)
}
[@@deriving sexp]

val default_config : config
(** Defaults: [{ hysteresis_weeks = 4; rs_window_weeks = 13 }]. *)

(** Decision emitted by {!observe}. *)
type decision =
  | Hold
      (** Either current RS is non-negative, or the consecutive-negative-RS
          count has not yet reached [config.hysteresis_weeks]. The caller takes
          no exit action. *)
  | Laggard_exit of { rs_13w_neg_weeks : int }
      (** RS has been negative for [rs_13w_neg_weeks] consecutive Friday
          observations and [rs_13w_neg_weeks >= config.hysteresis_weeks]. The
          strategy wiring layer should emit a [Position.TriggerExit] with
          [exit_reason = StrategySignal { label = "laggard_rotation"; detail }]
          where [detail] encodes [rs_13w_neg_weeks]. *)
[@@deriving show, eq]

val observe :
  config:config ->
  prior_consecutive_neg_rs:int ->
  position_13w_return:float ->
  benchmark_13w_return:float ->
  int * decision
(** [observe ~config ~prior_consecutive_neg_rs ~position_13w_return
     ~benchmark_13w_return] is the pure state-transition core of the detector.

    Returns a pair [(new_consecutive_neg_rs, decision)]:
    - When [position_13w_return < benchmark_13w_return] (strict — RS is
      negative): increments the consecutive count and emits [Laggard_exit] iff
      the new count [>= config.hysteresis_weeks].
    - When [position_13w_return >= benchmark_13w_return] (RS is zero or
      positive): resets the consecutive count to [0] and emits [Hold].

    Pure function — same inputs always produce the same outputs.

    The detector treats RS as a strict comparison: a tied RS (both returns
    equal) resets the counter rather than continuing the streak. This avoids
    streak persistence on a perfectly-correlated tracker that happens to match
    the benchmark exactly — a tracking position is not "lagging badly".

    Edge case: when [config.hysteresis_weeks <= 0], the function treats
    [hysteresis_weeks = 1] (a single negative-RS observation fires immediately).
    Defensive — a non-positive hysteresis would otherwise disable the detector
    entirely. The default config has K = 4; callers are expected to pass a
    positive value. *)

(** {1 Symbol-keyed convenience wrapper} *)

val observe_position :
  config:config ->
  state:(string, int) Core.Hashtbl.t ->
  symbol:string ->
  position_13w_return:float ->
  benchmark_13w_return:float ->
  decision
(** [observe_position ~config ~state ~symbol ~position_13w_return
     ~benchmark_13w_return] looks up the prior consecutive-negative-RS count for
    [symbol] in [state] (defaulting to [0] when missing), calls {!observe}, then
    writes the new count back into [state]. Mutates [state] in place. Returns
    the [decision].

    Parallel to the [stage3_streaks] table threaded through
    [Stage3_force_exit_runner] — kept as a separate hashtable so the detector's
    state is independent of the Stage-3 detector's streak threading. *)
