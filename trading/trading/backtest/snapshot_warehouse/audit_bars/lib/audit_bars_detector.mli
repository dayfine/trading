(** Pure detector for MSZ-class corrupt bars: one-day close spikes that revert
    the next day, seen in raw EODHD data for delisted sub-$5 micro-caps.

    Motivating artifact (see [dev/notes/deep-remeasure-364-2026-07-09.md]
    §"MaxDD 59.4% is an artifact"): MSZ 2014-08-15 has close 1.90 -> 25.36 ->
    1.93 the next day. A single such bar produced a phantom +$3.3M NAV spike and
    a fake 59.4% MaxDD in a deep re-baseline. This detector flags those bars so
    a warehouse can be data-audited before a re-measure trusts it.

    The detector is a pure function over a symbol's close series — no I/O — so
    it is unit-testable in isolation. The [bin/] executable wraps it with
    {!Snapshot_columnar} reads over a warehouse directory. *)

type params = {
  spike_mult : float;
      (** A bar's close must be at least [spike_mult] times the surrounding
          median close to be a spike candidate. *)
  median_window : int;
      (** Half-width [k] of the surrounding window: the median is taken over the
          [±k] bars around [t], excluding [t] itself. Must be [>= 1]. *)
  revert_frac : float;
      (** The next bar's close must be at most [revert_frac] times the spike
          close for the spike to count as reverting. *)
  price_ceiling : float;
      (** Only flag when the surrounding median close is below [price_ceiling] —
          the artifact class lives in sub-$5 names, so higher-priced series with
          a legitimate large move are not flagged. *)
}
[@@deriving sexp_of]

val default_params : params
(** Defaults tuned to the MSZ artifact class: [spike_mult = 5.0],
    [median_window = 5], [revert_frac = 0.5], [price_ceiling = 5.0]. *)

type bar = {
  date : Core.Date.t;  (** The trading day of this close. *)
  close : float;  (** Raw (unadjusted) daily close. *)
}
[@@deriving sexp_of]

type hit = {
  date : Core.Date.t;  (** Date of the spike bar [t]. *)
  prev_close : float;
      (** Close of bar [t-1], or [Float.nan] when [t] is the first bar. *)
  spike_close : float;  (** Close of the spike bar [t]. *)
  next_close : float;  (** Close of bar [t+1] (the reverting bar). *)
  ratio : float;
      (** [spike_close /. surrounding_median] — how large the spike is. *)
}
[@@deriving sexp_of, equal]

val detect : params:params -> bar array -> hit list
(** [detect ~params bars] returns every spike-revert candidate in [bars], in
    ascending date order.

    A bar [t] is a candidate when all hold:
    - the median close over the surrounding [±median_window] bars (excluding
      [t]) is below [params.price_ceiling];
    - [close_t >= params.spike_mult *. surrounding_median];
    - [close_{t+1} <= params.revert_frac *. close_t].

    The last bar is never a candidate (no [t+1] to check the revert). Near the
    start/end of the series the surrounding window is clamped to the available
    bars — the median is taken over whatever neighbours exist (at least one is
    required). [bars] is assumed sorted by date ascending, as
    {!Snapshot_columnar} delivers it. *)
