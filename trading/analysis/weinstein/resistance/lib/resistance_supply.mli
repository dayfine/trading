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
  hist_bands : float array array;
      (** Age-banded histogram (lever f): [hist_bands.(b).(k)] counts weekly
          bars of age band [b] (0..{!n_age_bands}-1, youngest first —
          [0-26w / 26-78w / 78-130w / 130-520w]) whose mid-price lies in
          [anchor * 2^(k/n), anchor * 2^((k+1)/n)) where [n] is the per-band
          bucket count. {!analyze} collapses the bands into one effective
          histogram via the [config] band weights at score time. A v3 warehouse
          / age-blind histogram maps to the youngest band with the rest zero —
          see {!hist_bands_of_legacy}. *)
  anchor_close : float;
      (** The raw close the histogram was anchored at (the sketch row's own
          close). *)
}
(** One symbol-day's sketch cells, as stored in the warehouse columns. *)

val n_age_bands : int
(** [n_age_bands] is the number of {!sketch.hist_bands} age bands (4). Locked to
    [Snapshot_schema.n_age_bands] (the pure scoring layer cannot depend on the
    snapshot layer, so the two are pinned equal by test). *)

val hist_bands_of_legacy : float array -> float array array
(** [hist_bands_of_legacy flat] packs a legacy age-blind histogram (the v3
    warehouse / pre-lever-f 130-week shape) into the {!n_age_bands}-band layout:
    all mass in the youngest band, the remaining bands zero. Under
    {!default_config} band weights ([1;1;1;0]) the effective histogram
    {!analyze} collapses equals [flat] bit-for-bit, so a v3 warehouse scores
    identically to before lever f. *)

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
  band_weight_0_26w : float; [@sexp.default 1.0]
      (** Lever f: score-time weight for the 0-26w age band. Defaults to 1.0
          (the pre-lever-f no-op). *)
  band_weight_26_78w : float; [@sexp.default 1.0]
      (** Score-time weight for the 26-78w age band. Default 1.0. *)
  band_weight_78_130w : float; [@sexp.default 1.0]
      (** Score-time weight for the 78-130w age band. Default 1.0. *)
  band_weight_130_520w : float; [@sexp.default 0.0]
      (** Score-time weight for the 130-520w age band. Defaults to 0.0 so the
          band is inert; the three 0-130w bands at weight 1.0 reproduce the
          pre-lever-f age-blind 130w histogram exactly. Each band weight is an
          [Overlay_validator] axis (a real [config] sub-field), so the age decay
          is searchable without a warehouse rebuild (experiment-flag-discipline
          R1/R2). The four fields carry [@sexp.default]s so a config sexp
          written before lever f (without them) still round-trips. *)
}
[@@deriving sexp]
(** [@@deriving sexp] so this config can be nested (as an [option]) inside
    [Weinstein_strategy_config.config] and [Stock_analysis.config] and still
    round-trip through the backtest scenario / [Overlay_validator] sexp surface
    (PR-D wiring). *)

val default_config : config
(** Defaults: decay 0.7, saturation 8 bars, floors 0.0 / 0.0 / 0.0,
    [min_history_bars = 0], insufficient score 0.5, grade thresholds 8 / 3 (v1
    parity), age-band weights 1 / 1 / 1 / 0 (collapses to the pre-lever-f
    age-blind 130w histogram). All searchable; none hardcoded at use sites.

    The horizon floors are 0.0 as of the 2026-07-23 bundle promotion
    (user-approved, R3): the 07-19 floor-axis surface found the horizon-floor
    staircase (previously 0.4 / 0.25 / 0.1) was the redeemed-cohort tax — it
    priced a name whose recent histogram is empty but whose older max-high
    proves stale overhead, forfeiting the crash-recovery monster cohort. At
    zero, such a breakout scores 0 (same as virgin); in-band recent mass still
    scores via the saturation path. Ledger
    [2026-07-20-bundle-promotion-studies]. *)

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

    Score composition (plan §D5). The age bands are first collapsed into one
    effective per-bucket histogram by the [config] band weights
    ([effective.(k) = Σ_b w_b * hist_bands.(b).(k)]); the rest scores that
    effective histogram exactly as before lever f:
    - recent component: proximity-weighted effective-histogram mass at/above the
      breakout, saturated at [saturation_bars];
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

val is_clear_of_supply : sketch:sketch -> bool
(** [is_clear_of_supply ~sketch] is [true] iff the sketch is finite,
    [bars_seen > 0], and EVERY bin of the {b 0-130w age bands} (bands [0..2],
    which union to the trailing-130w window) is [0] — i.e. zero measured
    overhead mass: no prior (finalized) weekly bar in the trailing 130-week
    histogram window has a high above the current close whose mid-price
    ([(high + low) / 2]) falls at or above it. The 130-520w band is ignored so
    this predicate keeps its exact pre-lever-f 130w semantics (and a v3
    warehouse, whose mass all lands in band 0, gives the same answer);
    weight-independent by design. The histogram producer gates on
    [weekly_high > anchor] and buckets by the mid-price (see
    [Snapshot_pipeline.Resistance_sketch] and its .mli — the source of truth).
    This is exactly the recent-overhead mass {!analyze} scores as its histogram
    component, so a clear sketch has zero recent supply above the breakout
    (though {!analyze} may still return a nonzero score via a horizon floor
    whenever the breakout sits at or below a horizon max — [max_high_130w] /
    [max_high_260w] / [max_high_520w] — including recent within-130-week
    overhead the mid-price histogram does not count: a wick whose mid falls
    below the close, or a bar whose mid lands at or above [2 * close]. This
    predicate ignores those floors by design, asking only "is the recent
    overhead mass empty?"). It is therefore a mid-price mass measure, NOT a
    closing-price test: a wick (high above the close, close below it) IS counted
    when its mid sits at/above the close, and a prior weekly bar that closed
    above the current close is NOT counted when its mid falls below it.

    {b Why this exists alongside {!is_virgin}.} The sketch's [max_high_520w] is
    a per-day rolling max over the trailing window that INCLUDES the current
    week's own high. For a stock climbing into new high ground on a
    close-anchored breakout price, [close <= own weekly high <= max_high_520w],
    so [is_virgin] ([breakout >= max_high_520w]) is structurally unsatisfiable
    except on an exact tie at the weekly high tick. Concrete case — AXTI in its
    2025-26 redemption: on 2026-01-06 the close was 20.17, [max_high_520w] was
    20.345 (set by that very week's own high), and [res_hist_sum] was 0 (zero
    weekly bars above price in the whole window). [is_virgin] fails every week;
    [is_clear_of_supply] correctly reports new high ground. The re-admission
    lever ORs the two so the own-week-high artifact no longer suppresses genuine
    breakouts into clear space.

    [false] when any bin is non-zero (genuine overhead), when [bars_seen = 0],
    or when the sketch is non-finite — no fabrication from missing data. *)
