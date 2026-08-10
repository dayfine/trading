open Types

(** Volume confirmation analysis for Weinstein breakouts and breakdowns.

    Weinstein rule (Ch. 4): "Never trust a breakout that isn't accompanied by a
    significant increase in volume."

    - Breakout volume ≥ 2× average of prior 4 bars → Strong
    - Breakout volume 1.5–2× average → Adequate
    - Breakout volume < 1.5× average → Weak

    For pullback confirmation: volume should contract 75%+ from peak (i.e.,
    pullback_volume ≤ 0.25 × breakout_volume).

    All functions are pure. *)

type config = {
  lookback_bars : int;
      (** Number of bars used to compute average volume before the event bar.
          Default: 4 (as specified by Weinstein for weekly bars). *)
  strong_threshold : float;
      (** Volume ratio ≥ this is [Strong]. Default: 2.0. *)
  adequate_threshold : float;
      (** Volume ratio ≥ this (but < strong_threshold) is [Adequate]. Default:
          1.5. *)
  pullback_contraction : float;
      (** Pullback is confirmed if its volume ≤ this fraction of the peak
          breakout volume. Default: 0.25 (75%+ contraction). *)
}
(** Configuration for volume analysis. All thresholds are configurable. *)

val default_config : config
(** [default_config] provides Weinstein's recommended defaults. *)

type result = {
  confirmation : Weinstein_types.volume_confirmation;
      (** Quality classification of the volume event. *)
  event_volume : int;
      (** Volume on the event bar (breakout or breakdown bar). *)
  avg_volume : float;
      (** Average volume over [config.lookback_bars] prior bars. *)
  volume_ratio : float;  (** event_volume / avg_volume. *)
}
(** Result of volume confirmation for a single event bar. *)

type callbacks = {
  get_volume : week_offset:int -> float option;
      (** Bar volume at [week_offset] weeks back from the newest bar, encoded as
          a float (matches the panel encoding). [week_offset:0] is the newest
          bar; offsets past available depth return [None]. *)
}
(** Bundle of indicator callbacks consumed by
    {!analyze_breakout_with_callbacks}.

    Higher-level callback APIs (e.g. {!Stock_analysis.analyze_with_callbacks})
    embed this record so panel-backed callers don't have to re-expose the
    individual closure at every layer. *)

val callbacks_from_bars : bars:Daily_price.t list -> callbacks
(** [callbacks_from_bars ~bars] precomputes a [week_offset]-indexed volume
    closure over [bars]. The constructor {!analyze_breakout} uses internally;
    exposed for callers (e.g. tests) that already hold a bar list and want to
    delegate to {!analyze_breakout_with_callbacks}. *)

val analyze_breakout :
  config:config -> bars:Daily_price.t list -> event_idx:int -> result option
(** [analyze_breakout ~config ~bars ~event_idx] evaluates volume confirmation at
    [event_idx] (a 0-based index into [bars]).

    Uses the [lookback_bars] bars immediately prior to [event_idx] as the
    baseline average.

    Returns [None] if there are fewer than [lookback_bars] bars before
    [event_idx], or if [event_idx] is out of range, or if baseline volume is
    zero.

    Pure function.

    Implementation note: this is a thin wrapper over
    {!analyze_breakout_with_callbacks}. It builds a {!callbacks} record via
    {!callbacks_from_bars} and delegates with
    [event_offset = bars_len - 1 - event_idx]. Behaviour is bit-identical to the
    callback API. *)

val analyze_breakout_with_callbacks :
  config:config -> callbacks:callbacks -> event_offset:int -> result option
(** [analyze_breakout_with_callbacks ~config ~callbacks ~event_offset] is the
    indicator-callback shape of {!analyze_breakout}.

    [event_offset] is the [week_offset] of the event bar (0 = newest bar). The
    [config.lookback_bars] bars immediately prior to the event bar are read at
    offsets [event_offset + 1], [event_offset + 2], …,
    [event_offset + lookback_bars]. Returns [None] if any prior offset returns
    [None] (not enough history), if the event bar's offset returns [None], or if
    the baseline average is zero.

    Pure function: same callback outputs always produce the same result. *)

(** Which of Weinstein's §4.2 branches confirmed a breakout bar — the {b named}
    form of {!confirms_breakout}'s boolean.

    Exists because the at-fill audit (plan
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] §4 PR-5) must be able to
    separate the two sanctioned confirmations from each other and from a
    measured non-confirmation. "Confirmed" alone cannot answer "did the build-up
    branch carry the arm", and a bare [false] cannot be told apart from the
    {i no-verdict} case ([classify_breakout] returning [None]), which is the
    population the F5 runner {b holds} rather than ejects.

    Each constructor carries the quantity that decided it, so the audit row
    records the measurement and not only the label. *)
type breakout_confirmation =
  | Spike of float
      (** Branch (a): the event bar's volume / prior-[lookback_bars] average,
          which reached [config.strong_threshold]. *)
  | Buildup of float
      (** Branch (b): the build-up window's average / the preceding equally
          sized window's average, which reached [config.strong_threshold] with
          some increase on the event bar. *)
  | Unconfirmed of {
      spike_ratio : float option;
      buildup_multiple : float option;
    }
      (** At least one branch was evaluable and none confirmed. Both measured
          quantities are carried (each [None] only when that branch had too
          little history), so the audit can rank near-misses rather than only
          count them. *)
[@@deriving show, eq]

val classify_breakout :
  config:config ->
  callbacks:callbacks ->
  event_offset:int ->
  breakout_confirmation option
(** [classify_breakout ~config ~callbacks ~event_offset] is {!confirms_breakout}
    with the deciding branch and its measurement retained.

    [None] means exactly what {!confirms_breakout}'s [None] means: {i neither}
    branch had enough history, so there is {b no verdict} — never a failed
    breakout. A [Spike]/[Buildup] maps to [Some true] and an [Unconfirmed] to
    [Some false], and {!confirms_breakout} is literally defined as that
    projection, so the two can never disagree.

    When both branches clear, the result is [Spike] (the book's headline case);
    the verdict is branch-agnostic, so the precedence only labels. Pure. *)

val confirms_breakout :
  config:config -> callbacks:callbacks -> event_offset:int -> bool option
(** [confirms_breakout ~config ~callbacks ~event_offset] is Weinstein's §4.2
    breakout-volume verdict at [event_offset] (0 = newest bar), implementing
    {b both} branches the book sanctions:

    - {b (a) spike}: the event bar's volume is >= [config.strong_threshold] (2x)
      the average of the prior [config.lookback_bars] bars.
    - {b (b) build-up}: the mean of the build-up window — the event bar plus the
      [lookback_bars - 1] bars before it (default 4 = the book's "3-4 weeks") —
      is >= [strong_threshold] x the mean of the equally-sized window before it
      (the book's "prior several weeks"), {i and} the event bar itself shows
      some increase over the bar before it.

    Either branch confirming yields [Some true]. Implementing (a) alone would
    eject book-valid breakouts whose volume arrived as a multi-week build-up
    rather than a single spike.

    Returns:
    - [Some true] — confirmed by at least one branch.
    - [Some false] — at least one branch could be evaluated and none confirmed.
    - [None] — {i neither} branch had enough history to judge. Callers must not
      read [None] as a failed breakout: it carries no verdict. (The F5
      volume-at-fill eject holds the position on [None] rather than ejecting on
      missing data.)

    Pure function. Consumed by the screen-time gate's sibling, the
    {!Weinstein_strategy.Volume_eject_runner} at-fill confirmation
    (`volume_confirm_at_fill`). *)

val is_pullback_confirmed :
  config:config -> breakout_volume:int -> pullback_volume:int -> bool
(** [is_pullback_confirmed ~config ~breakout_volume ~pullback_volume] checks
    whether a pullback shows the volume contraction Weinstein requires.

    A contracting pullback (volume drying up) is a bullish sign — it suggests
    distribution is absent and the move is likely to continue.

    Pure function. *)

val average_volume : bars:Daily_price.t list -> n:int -> float
(** [average_volume ~bars ~n] computes the average volume of the last [n] bars
    in [bars]. Returns 0.0 if [bars] is empty or [n] ≤ 0.

    Pure convenience function for computing baseline volumes. *)
