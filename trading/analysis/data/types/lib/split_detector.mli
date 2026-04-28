(** Detect stock-split events between consecutive {!Daily_price.t} bars.

    This is the broker-model {b detection} primitive. EODHD daily bars carry
    both a raw [close_price] (as printed on the day) and an [adjusted_close]
    that is back-rolled for every future corporate action (splits {e and}
    dividends). On any non-corporate-action day the ratio
    [adjusted_close /. close_price] is constant; on a split day it jumps by
    exactly [1 /. split_factor]. By comparing the day-over-day {b raw} return
    against the day-over-day {b adjusted} return we can recover [split_factor]
    without a second data feed.

    The detector discriminates splits from dividends using a tolerance band
    (dividends produce a small drift, splits produce a {e large} jump that snaps
    to a small rational [N/M] with [N, M ≤ max_denominator]).

    See [dev/plans/split-day-ohlc-redesign-2026-04-28.md] §Detection. *)

val detect_split :
  ?dividend_threshold:float ->
  ?rational_snap_tolerance:float ->
  ?max_denominator:int ->
  prev:Daily_price.t ->
  curr:Daily_price.t ->
  unit ->
  float option
(** Detect a split between two consecutive daily bars.

    Returns [Some factor] where [factor = new_shares /. old_shares] for forward
    splits ([factor > 1.0], e.g. [4.0] for a 4:1) and reverse splits
    ([factor < 1.0], e.g. [0.2] for a 1:5). Returns [None] when no split is
    detected — that includes pure-dividend days, no-corporate-action days, and
    any day where the implied ratio fails to snap to a small rational [N/M] with
    [N, M <= max_denominator].

    The caller is responsible for skipping the very first bar of a series (no
    prior bar to compare against).

    Optional parameters:
    - [dividend_threshold]: minimum [|split_factor -. 1.0|] required to even
      consider the day a split candidate. Below this we treat the deviation as a
      dividend or noise. Default [0.05] (5%).
    - [rational_snap_tolerance]: maximum absolute distance between the raw ratio
      and the candidate rational [N/M] for the snap to succeed. Default [1e-3].
    - [max_denominator]: largest denominator [M] considered when searching for
      [N/M] approximations. Default [20]. Splits in practice are tiny rationals
      (4:1, 1:5, 3:2, 2:3, 1:10, etc.). *)
