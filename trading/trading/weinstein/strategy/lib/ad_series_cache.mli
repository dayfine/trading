(** Precomputed A-D (advance/decline) breadth series for the strategy's per-tick
    macro path.

    The weekly A-D bar list threaded through the strategy is FIXED across the
    whole run (built once in {!Weinstein_strategy.make} from the daily A-D
    bars). The old per-tick macro path rebuilt the cumulative-A-D array and the
    momentum-MA scalar from scratch on every Friday tick — O(t) work over T
    ticks = O(n²). This cache precomputes the cumulative series ONCE and answers
    each tick's A-D queries in O(log n) (a binary search for the [as_of] cutoff
    plus O(1) array reads).

    The cache reproduces the OLD path bit-identically: the cumulative running
    sum is an [int] accumulator converted to [float] at the array boundary, and
    the momentum MA is an [int] sum of the last [min momentum_period k] A-D nets
    divided by a [float] period. A-D nets are small ints far below 2^53, so the
    telescoped int subtraction used here equals the old per-prefix int sum
    exactly. See {!Panel_callbacks._build_cumulative_ad_array} /
    {!Panel_callbacks._compute_momentum_ma_scalar} for the originals and
    [Test_ad_series_cache] for the parity proof. *)

type t

val of_weekly_ad_bars : momentum_period:int -> Macro.ad_bar list -> t
(** [of_weekly_ad_bars ~momentum_period ad_bars] precomputes the cumulative
    series from [ad_bars] (must be ascending by [date], as
    {!Ad_bars_aggregation.daily_to_weekly} produces). [momentum_period] is the
    momentum-MA window
    ([config.macro_config.indicator_thresholds.momentum_period]). An empty
    [ad_bars] yields an empty cache whose [callbacks_at] closures always return
    [None] — identical to the A-D-inert (empty-bars) behaviour. *)

val length : t -> int
(** Number of A-D bars held in the cache. *)

val callbacks_at :
  t ->
  as_of:Core.Date.t ->
  (week_offset:int -> float option) * (week_offset:int -> float option)
(** [callbacks_at t ~as_of] returns the
    [(get_cumulative_ad, get_ad_momentum_ma)] pair the macro callback bundle
    needs, computed over the prefix of bars with [date <= as_of].

    - [get_cumulative_ad ~week_offset]: cumulative A-D line value [week_offset]
      weeks back from the newest in-prefix bar (offset 0 = newest); [None] when
      the offset falls outside the prefix.
    - [get_ad_momentum_ma ~week_offset]: A-D momentum MA; only [week_offset:0]
      is meaningful (returns [None] otherwise, and [None] for an empty prefix).
*)

module Internal_for_test : sig
  val count_at_or_before : t -> as_of:Core.Date.t -> int
  (** Prefix length: count of bars with [date <= as_of]. Exposed for the parity
      test that pins it against {!Macro_inputs.ad_bars_at_or_before}. *)
end
