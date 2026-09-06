(** Shared domain types for the Weinstein analysis pipeline.

    Used across the stage classifier, stop state machine, and screener.
    Centralised here to avoid circular dependencies. *)

(** Weinstein stage — the four-stage price cycle model. *)
type stage =
  | Stage1 of { weeks_in_base : int }
      (** Basing / accumulation: MA flattening after decline, price oscillating
          around MA. *)
  | Stage2 of {
      weeks_advancing : int;
      late : bool;
          (** MA deceleration detected — still hold, but no longer a new buy. *)
    }  (** Advancing / markup: MA rising, price consistently above MA. *)
  | Stage3 of { weeks_topping : int }
      (** Top / distribution: MA flattening after advance, price oscillating
          around MA. Exit with profits. *)
  | Stage4 of { weeks_declining : int }
      (** Declining / markdown: MA falling, price consistently below MA. Never
          buy or hold in Stage 4. *)
[@@deriving show, eq, sexp]

(** Direction of the 30-week moving average.

    Derived from the MA slope value; [Flat] means within the configured
    threshold. A [Rising] MA with price above is Stage 2 territory; [Declining]
    with price below is Stage 4. *)
type ma_direction = Rising | Flat | Declining [@@deriving show, eq, sexp]

(** Overhead resistance quality above a potential breakout level.

    Grades the risk that prior trading congestion will absorb buying power. *)
type overhead_quality =
  | Virgin_territory
      (** No prior trading above this price (new multi-year high). Most
          explosive potential — no trapped sellers wanting to break even. *)
  | Clean
      (** No significant resistance on the 2.5-year chart. Minor old resistance
          only. *)
  | Moderate_resistance
      (** Some resistance overhead but not dense. Stock can push through. *)
  | Heavy_resistance
      (** Dense trading zone just above breakout. Stock will use up buying power
          working through this zone. *)
  | Insufficient_history
      (** Not enough price history to map overhead resistance reliably. Emitted
          only when the mapper is armed with a positive minimum-history
          threshold and the available bars are fewer than that minimum. Distinct
          from {!Virgin_territory}: virgin territory is a positive claim ("no
          prior trading above this price over a deep lookback"), whereas
          insufficient-history is the absence of evidence — the window is too
          short to make any claim. Consumers must NOT treat this as virgin
          territory. *)
[@@deriving show, eq, sexp]

(** Relative strength trend vs benchmark. *)
type rs_trend =
  | Bullish_crossover
      (** RS just crossed from negative to positive territory — A+ bonus. *)
  | Positive_rising  (** RS positive and trending higher. *)
  | Positive_flat  (** RS positive but flat — hold, don't add. *)
  | Positive_declining
      (** RS still above the Mansfield zero line but {b falling} — the book's
          "inferior action in the RS line compared to the price performance"
          (Ch. 4, Chart 4-16: price range-bound while "the RS line is telling us
          to look out below ... trending lower"). Distinct from
          {!Positive_flat}: the level is the same side of the line, the
          {i direction} is not.

          {b Emitted only when armed.} {!Rs.config.enable_positive_declining}
          defaults to [false], under which {!Rs} folds this cohort back into
          {!Positive_flat} — so no existing run can observe this constructor
          until a spec arms the flag
          ([.claude/rules/experiment-flag-discipline.md] R1). Placed after
          {!Positive_flat} rather than at the end purely for reading order; the
          sexp encoding is by constructor name, so position carries no
          back-compat weight. *)
  | Negative_improving
      (** RS still negative but improving — watch, not yet a buy. *)
  | Negative_declining  (** RS negative and falling — avoid or short. *)
  | Bearish_crossover
      (** RS just crossed from positive to negative — bearish warning. *)
[@@deriving show, eq, sexp]

(** Volume confirmation quality for a breakout or breakdown. *)
type volume_confirmation =
  | Strong of float
      (** Volume ≥ 2× recent average. [float] is the actual ratio. Required for
          high-quality long entries. *)
  | Adequate of float
      (** Volume 1.5–2× recent average. Acceptable but not ideal. *)
  | Weak of float
      (** Volume < 1.5× recent average. Treat breakout with suspicion. *)
[@@deriving show, eq, sexp]

(** Overall market trend from macro analysis. *)
type market_trend = Bullish | Bearish | Neutral [@@deriving show, eq, sexp]

(** Macro trend refined by the DIRECTION of universe participation breadth
    (percent above the long MA, new 52-week lows) read as a rate of change
    rather than a level. Both inputs are adaptations — of the Ch. 3
    participation gauge and of the Ch. 8 new-highs-minus-new-lows net
    respectively; see [docs/design/weinstein-book-reference.md] §2.8 and §2.4,
    and {!Breadth_direction} for what each substitutes.

    A strict refinement of {!market_trend}: {!market_trend_of_breadth_state}
    projects it back, and every existing consumer keeps matching on
    [Macro.result.trend], which is unchanged. The two extra cases split what the
    three-state read calls Neutral — a tape that is Bullish-or-Neutral on the
    weighted indicators while breadth is collapsing is not the same regime as
    one where breadth is repairing, and the 27-year study measured the
    difference in realized P&L on entries made in each. *)
type breadth_state =
  | Bullish_breadth  (** Projects to [Bullish]. *)
  | Neutral_breadth
      (** Projects to [Neutral]; breadth is not moving decisively. *)
  | Deteriorating
      (** Participation is weak AND falling, or new lows are elevated AND
          rising. Projects to [Neutral] — it never blocks a side on its own. *)
  | Recovering
      (** Participation is still weak but rising off the low. Projects to
          [Neutral]. *)
  | Bearish_breadth  (** Projects to [Bearish]. *)
[@@deriving show, eq, sexp]

val market_trend_of_breadth_state : breadth_state -> market_trend
(** Project a [breadth_state] back onto the three-state read: [Bullish_breadth]
    and [Bearish_breadth] map 1:1; [Neutral_breadth], [Deteriorating] and
    [Recovering] all map to [Neutral].

    This is the compatibility contract for the whole feature — with the
    breadth-direction read disabled (the default), a macro result's
    [breadth_state] is exactly [breadth_state_of_market_trend result.trend], so
    the projection round-trips and no consumer of [trend] can observe a change.
*)

val breadth_state_of_market_trend : market_trend -> breadth_state
(** The right inverse of {!market_trend_of_breadth_state}: the state a
    three-state trend denotes when no breadth refinement is available.
    [market_trend_of_breadth_state (breadth_state_of_market_trend t) = t] for
    every [t]. *)

(** Quality grade for candidates. Higher is better.

    [compare] gives [A_plus > A > B > C > D > F] ordering. *)
type grade = A_plus | A | B | C | D | F [@@deriving show, eq, ord, sexp]

val grade_to_string : grade -> string
(** Convert grade to a human-readable string (e.g. [A_plus] → ["A+"]). *)

(** {1 GICS Sectors} *)

(** The 11 GICS (Global Industry Classification Standard) sectors used by
    S&P/MSCI. These are the canonical sector names used throughout the system —
    in [sectors.csv], in the SPDR sector ETF mapping, and in screener output. *)
type gics_sector =
  | Information_technology
  | Financials
  | Health_care
  | Energy
  | Industrials
  | Consumer_staples
  | Consumer_discretionary
  | Utilities
  | Materials
  | Real_estate
  | Communication_services
[@@deriving show, eq, ord, sexp]

val all_gics_sectors : gics_sector list
(** All 11 GICS sectors in standard order. *)

val gics_sector_to_string : gics_sector -> string
(** Canonical display name (e.g. [Information_technology] →
    ["Information Technology"]). *)

val gics_sector_of_string_opt : string -> gics_sector option
(** Parse a sector name (case-insensitive). Also accepts Finviz's labels
    ("Technology", "Financial", "Healthcare", "Basic Materials", "Consumer
    Cyclical", "Consumer Defensive") as aliases, mapping them to the
    corresponding GICS variant. Returns [None] for unrecognized names. *)

val normalize_sector_name : string -> string
(** Normalize [s] to the canonical GICS display spelling when recognized
    (including via Finviz aliases). Unknown names are returned unchanged so no
    data is dropped. Callers that need strictness should use
    {!gics_sector_of_string_opt} directly. *)
