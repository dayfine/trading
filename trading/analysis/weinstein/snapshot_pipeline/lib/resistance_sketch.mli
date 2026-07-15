(** Per-day resistance sketch columns for the Phase B snapshot pipeline
    (resistance-v2, [dev/plans/resistance-v2-supply-sketches-2026-07-15.md]).

    For every daily index [i] this module computes weekly-cadence,
    point-in-time overhead-supply sketches from the same per-day weekly
    prefix the Stage/RS columns use ({!Weekly_prefix}): the weekly window at
    day [i] is the finalized weeks strictly before [i]'s week plus the
    partial week through day [i] — exactly the window the v1 resistance
    mapper sees at a Friday screening, so the sketch-derived virgin test
    ([breakout > max_high]) is bit-equal to v1's [_is_virgin_territory]
    over the same span.

    Field semantics (single source of truth is
    {!Data_panel_snapshot.Snapshot_schema}'s docstring):

    - [max_high_130w/260w/520w].(i): max raw weekly high over the trailing
      130/260/520 weekly bars ending at day [i] (partial week included).
    - [bars_seen].(i): true weekly-bar count available at day [i], capped at
      520 — the honest [Insufficient_history] input.
    - [hist].(k).(i): count of weekly bars among the trailing 130 whose
      mid-price [(high + low) / 2] lies in the log band
      [C * 2^(k/20), C * 2^((k+1)/20)) above the day's raw close [C], and
      whose high exceeds [C]. Buckets past
      [Snapshot_schema.n_hist_buckets - 1] (supply more than 2x above [C])
      are dropped.

    Corrupt-bar guard: when day [i]'s raw close is non-positive or
    non-finite, every sketch cell at [i] is [Float.nan].

    Cost: O(chart window) per day for the histogram (the anchor [C] moves
    daily, so the bucketing cannot be shared across days) and amortized O(1)
    per day for the rolling maxima (monotonic-deque sliding max over the
    finalized weekly highs). *)

type t = {
  max_high_130w : float array;
  max_high_260w : float array;
  max_high_520w : float array;
  bars_seen : float array;
  hist : float array array;
      (** [hist.(k).(i)] = bucket [k]'s count at daily index [i]; the first
          dimension has {!Data_panel_snapshot.Snapshot_schema.n_hist_buckets}
          rows. *)
}
(** Per-day sketch arrays, each aligned to the daily bar array (index [i] = day
    [i]). *)

val compute :
  weekly_prefix:Weekly_prefix.t -> bars_arr:Types.Daily_price.t array -> t
(** [compute ~weekly_prefix ~bars_arr] computes every sketch column in one
    forward pass over the days. [weekly_prefix] must have been built from
    [bars_arr] (same indexing). Pure function. *)
