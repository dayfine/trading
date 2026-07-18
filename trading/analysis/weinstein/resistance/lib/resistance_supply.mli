(** Continuous overhead-supply score from precomputed resistance sketches
    (resistance-v2 PR-C, [dev/plans/resistance-v2-supply-sketches-2026-07-15.md]
    §D5).

    The v1 mapper ({!Resistance}) walks bars and emits a BINARY
    {!Weinstein_types.overhead_quality} grade. This module consumes the
    warehouse sketch columns instead (rolling max-high family + trailing
    close-anchored histogram — see the [Snapshot_schema] docstring) and produces
    a CONTINUOUS supply pressure in [0, 1], with the letter grade still
    derivable for display back-compat (the score/display split that resolves the
    live-arming tension of the 2026-07-14 armed run).

    Pure function of plain floats — no dependency on the snapshot layer; the
    caller extracts the sketch cells from wherever they live. *)

type sketch = {
  max_high_130w : float;  (** Max raw weekly high, trailing 130 weekly bars. *)
  max_high_260w : float;  (** Same, 260 weekly bars. *)
  max_high_520w : float;  (** Same, 520 weekly bars. *)
  bars_seen : float;  (** True weekly-bar count available (capped 520). *)
  hist : float array;
      (** Trailing-130w histogram: [hist.(k)] counts weekly bars whose
          mid-price lies in [anchor * 2^(k/n), anchor * 2^((k+1)/n)) where
          [n = Array.length hist] buckets span one doubling. *)
  anchor_close : float;
      (** The raw close the histogram was anchored at (the sketch row's own
          close). *)
}
(** One symbol-day's sketch cells, as stored in the warehouse columns. *)

type config = {
  proximity_decay : float;
      (** Multiplicative weight decay per bucket above the breakout: supply [j]
          buckets above the first relevant bucket contributes
          [count * proximity_decay^j]. *)
  saturation_bars : float;
      (** Proximity-weighted bar mass at which the recent-supply component
          saturates to 1.0 (default mirrors the v1 heavy-zone bar count). *)
  recent_far_floor : float;
      (** Score floor when overhead exists within 130 weeks but sits more than
          one doubling above the breakout (outside the histogram span). *)
  stale_mid_floor : float;
      (** Score floor when the nearest overhead is 130-260 weeks old. *)
  stale_old_floor : float;
      (** Score floor when the nearest overhead is 260-520 weeks old. *)
  min_history_bars : int;
      (** Below this many weekly bars the result degrades to
          [Insufficient_history]. 0 disables (v1-compatible default). *)
  insufficient_score : float;
      (** Score reported for [Insufficient_history] rows. Deliberately NOT 0:
          scoring unknown history as virgin would re-create the false-virgin
          defect at the score level. *)
  heavy_resistance_bars : int;
      (** Grade derivation: max single-bucket count at/above the breakout that
          classifies as [Heavy_resistance] (mirrors v1). *)
  moderate_resistance_bars : int;  (** Same for [Moderate_resistance]. *)
}
[@@deriving sexp]
(** [@@deriving sexp] so this config can be nested (as an [option]) inside
    [Weinstein_strategy_config.config] and [Stock_analysis.config] and still
    round-trip through the backtest scenario / [Overlay_validator] sexp surface
    (PR-D wiring). *)

val default_config : config
(** No-op-adjacent defaults: decay 0.7, saturation 8 bars, floors 0.4 / 0.25 /
    0.1, [min_history_bars = 0], insufficient score 0.5, grade thresholds 8 / 3
    (v1 parity). All searchable; none hardcoded at use sites. *)

type result = {
  score : float;
      (** Overhead-supply pressure in [0, 1]. 0 = virgin territory at the
          520-week horizon; 1 = heavy recent supply just above the breakout. *)
  recent_weighted_bars : float;
      (** The raw proximity-weighted bar mass from the histogram (before
          saturation) — diagnostic / report transparency. *)
  quality : Weinstein_types.overhead_quality;
      (** Letter grade derived from the same sketch, for display back-compat:
          virgin iff [breakout >= max_high_520w] (bit-equal to v1's test, which
          requires a high STRICTLY above the breakout to void virginity);
          Heavy/Moderate/Clean from the max bucket count at/above the breakout.
      *)
}

val analyze : config:config -> sketch:sketch -> breakout_price:float -> result
(** [analyze ~config ~sketch ~breakout_price] scores the overhead supply a
    breakout at [breakout_price] faces.

    Score composition (plan §D5):
    - recent component: proximity-weighted histogram mass at/above the breakout,
      saturated at [saturation_bars];
    - horizon floors: ONLY when the histogram holds no mass at/above the
      breakout but a max-high proves overhead exists, the score falls back to
      [recent_far_floor] / [stale_mid_floor] / [stale_old_floor] by the age of
      the nearest overhead (the 10y/5y/2.5y virgin gradient with magnitude
      discounting; in-band mass always speaks for itself);
    - virgin (breakout above [max_high_520w]): score 0.

    Degradations: any non-finite sketch cell, or [bars_seen] below
    [config.min_history_bars], yields [Insufficient_history] with
    [config.insufficient_score].

    When [breakout_price < anchor_close] the histogram cannot see supply between
    the two (its floor is the anchor); the max-high floors still apply. In
    practice the Friday breakout price and the row's close are the same bar, so
    the gap is at most one bucket.

    Pure function. *)

val is_virgin : sketch:sketch -> breakout_price:float -> bool
(** [is_virgin ~sketch ~breakout_price] is the v1 virgin-territory predicate in
    isolation: [true] iff the sketch cells are finite (positive anchor) and the
    breakout is at or above the 520-week max high
    ([breakout_price >= max_high_520w], ties inclusive — bit-equal to the
    [quality = Virgin_territory] branch of {!analyze} and to the v1
    {!Resistance} bar-walk, both of which void virginity only on a high STRICTLY
    above the breakout). Unlike {!analyze} it carries no scoring config and
    applies no insufficient-history degradation — it answers only "is this new
    high ground over the 520-week window?".

    [false] when the sketch cells are non-finite — no fabrication of virginity
    from missing data. Consumed by the virgin-crossing re-admission lever
    ({!Stock_analysis.is_breakout_candidate}, gated by
    [Weinstein_strategy_config.virgin_crossing_readmission]): a Stage-2 name
    that crosses into virgin territory on volume is a fresh admissible breakout
    even when the early-Stage2 window would otherwise mark it stale. *)
