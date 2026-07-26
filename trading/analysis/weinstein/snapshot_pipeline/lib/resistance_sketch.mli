(** Per-day resistance sketch columns for the Phase B snapshot pipeline
    (resistance-v2, [dev/plans/resistance-v2-supply-sketches-2026-07-15.md]).

    For every daily index [i] this module computes weekly-cadence,
    point-in-time overhead-supply sketches from the same per-day weekly
    prefix the Stage/RS columns use ({!Weekly_prefix}): the weekly window at
    day [i] is the finalized weeks strictly before [i]'s week plus the
    partial week through day [i] — exactly the window the v1 resistance
    mapper sees at a Friday screening, so the sketch-derived virgin test
    [breakout >= max_high] is bit-equal to v1's [_is_virgin_territory] over
    the same span (v1: virgin iff no high STRICTLY exceeds the breakout, so
    the derived test must be [>=], preserving the [max_high = breakout]
    tie). Pinned against [Resistance.analyze] directly by the parity test in
    [test_resistance_sketch.ml].

    Field semantics (single source of truth is
    {!Data_panel_snapshot.Snapshot_schema}'s docstring):

    - [max_high_130w/260w/520w].(i): max raw weekly high over the trailing
      130/260/520 weekly bars ending at day [i] (partial week included).
    - [bars_seen].(i): true weekly-bar count available at day [i], capped at
      520 — the honest [Insufficient_history] input.
    - [hist].(cell).(i): {b age-banded} count at daily index [i]. The
      [Snapshot_schema.n_hist_cells] rows are band-major: cell
      [band * n_hist_buckets + bucket] holds age band [band] and price bucket
      [bucket]. The four age bands cover a weekly bar's age relative to day [i]
      (age 0 = the partial current week, age 1 = the most recent finalized
      week, ...): [0-26w / 26-78w / 78-130w / 130-520w] (half-open). Within a
      band, [bucket] counts weekly bars whose mid-price [(high + low) / 2] lies
      in the log band [C * 2^(bucket/20), C * 2^((bucket+1)/20)) above the day's
      raw close [C] and whose high exceeds [C]. Bucket indices past
      [Snapshot_schema.n_hist_buckets - 1] (supply more than 2x above [C]) are
      dropped. Summing the three 0-130w bands reproduces the pre-lever-f
      age-blind trailing-130w histogram exactly; the 130-520w band measures
      older supply the horizon max-highs previously only floored.

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
      (** [hist.(cell).(i)] = band-major cell [cell]'s count at daily index [i];
          the first dimension has
          {!Data_panel_snapshot.Snapshot_schema.n_hist_cells} rows (cell
          [band * n_hist_buckets + bucket]). *)
}
(** Per-day sketch arrays, each aligned to the daily bar array (index [i] = day
    [i]). *)

val compute :
  weekly_prefix:Weekly_prefix.t -> bars_arr:Types.Daily_price.t array -> t
(** [compute ~weekly_prefix ~bars_arr] computes every sketch column in one
    forward pass over the days. [weekly_prefix] must have been built from
    [bars_arr] (same indexing). Pure function. *)

val compute_windowed :
  deep_bars:Types.Daily_price.t array -> bars_arr:Types.Daily_price.t array -> t
(** [compute_windowed ~deep_bars ~bars_arr] computes the sketch for the days in
    [bars_arr] but lets the weekly prefix — rolling maxima, histogram window and
    [bars_seen] — also see [deep_bars], the earlier history lying strictly
    before [bars_arr]'s first day. This is the resistance-v2 §D4 false-virgin
    fix: without deep history a symbol that has traded for decades looks virgin
    at the scenario start because the warmup-windowed slice starves the sketch.

    The result arrays stay aligned to [bars_arr] indices. Internally the
    combined array [Array.append deep_bars bars_arr] is aggregated once and
    every sketch column is sliced to its trailing [Array.length bars_arr] days,
    so for every column [c] and window day [i]:
    {[
    (compute_windowed ~deep_bars ~bars_arr).c.(i)
    = (let full = Array.append deep_bars bars_arr in
       compute ~weekly_prefix:(Weekly_prefix.build full) ~bars_arr:full)
        .c.(i + Array.length deep_bars)
    ]}
    (split-parity, pinned in [test_resistance_sketch.ml]).

    [deep_bars = [||]] is bit-identical to
    [compute ~weekly_prefix:(Weekly_prefix.build bars_arr) ~bars_arr] — the
    no-deep-history default. The caller must supply [deep_bars] that precede
    [bars_arr] chronologically with no overlap; the combined aggregation raises
    [Invalid_argument] on out-of-order input (same contract as
    {!Weekly_prefix.build}). Pure function. *)
