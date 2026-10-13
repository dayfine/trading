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
  ?raw_confirm_min_share:float ->
  ?frozen_adjusted_min_deviation:float ->
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
      (4:1, 1:5, 3:2, 2:3, 1:10, etc.).
    - [raw_confirm_min_share]: when given, a snapped factor is kept only if the
      {b raw} close gap confirms it — i.e. [log (1 /. raw_ratio) /. log factor]
      (the share of the factor's log-magnitude carried by the raw close move) is
      at least this value. A real split moves the raw close by about
      [1 /. factor] (share near [1.0]); a dividend-driven jump in
      [adjusted_close] leaves the raw close flat or moving the wrong way (share
      near [0] or negative). Omitted (the default) = no check, the pre-#3104
      behaviour. Issue #3104: FUJIY 2020-09-28 (raw +2 %, factor 1.059 snapped
      to 18/17) is rejected at [0.5]. A dividend whose raw drop happens to match
      the factor (DHLGY 2025-05-06, 21/20) is not — raise [dividend_threshold]
      to [0.10] for that. See
      [dev/notes/split-detector-dividend-misfire-2026-10-03.md] for the
      bar-store counts.

    With [raw_confirm_min_share] given, a {b frozen-adjusted} day
    ([curr.adjusted_close = prev.adjusted_close] exactly) is also rejected when
    [|factor -. 1.0| < frozen_adjusted_min_deviation]: the adjusted series did
    not move, so the factor is only the raw move snapped to a rational (issue
    #3109; 55 % of the 0.05-0.10 band, 46 % of the 0.10-0.25 band). The raw-gap
    check cannot catch these, because the raw close did move.
    - [frozen_adjusted_min_deviation]: the smallest [|factor -. 1.0|] kept on a
      frozen-adjusted day. Default [0.25]: real splits (2:1, 3:2, 1:5 ...) on a
      flat adjusted close exist (2 % of the [>= 0.25] band) and are kept.
      Ignored when [raw_confirm_min_share] is omitted, so the default path is
      unchanged.

    Adjusted-only steps with no raw gap (AABA 2000-02-14, KKD 2001-06-15: the
    adjusted close steps by the split factor on a day the raw close does not)
    have a raw-gap share near [0] and are rejected by [raw_confirm_min_share].
    Dividend-shaped misfires whose raw drop matches the factor (WING 2018-02-08
    15/14, EC 2022-04-19 13/12) pass both checks; see the issue #3109 10-05
    comment. *)
