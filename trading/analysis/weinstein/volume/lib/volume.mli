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

val analyze_breakout :
  config:config -> bars:Daily_price.t list -> event_idx:int -> result option
(** [analyze_breakout ~config ~bars ~event_idx] evaluates volume confirmation at
    [event_idx] (a 0-based index into [bars]).

    Uses the [lookback_bars] bars immediately prior to [event_idx] as the
    baseline average.

    Returns [None] if there are fewer than [lookback_bars] bars before
    [event_idx], or if [event_idx] is out of range, or if baseline volume is
    zero.

    Pure function. *)

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
