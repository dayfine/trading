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
[@@deriving show, eq, sexp]

(** Relative strength trend vs benchmark. *)
type rs_trend =
  | Bullish_crossover
      (** RS just crossed from negative to positive territory — A+ bonus. *)
  | Positive_rising  (** RS positive and trending higher. *)
  | Positive_flat  (** RS positive but flat — hold, don't add. *)
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

(** Quality grade for candidates. Higher is better.

    [compare] gives [A_plus > A > B > C > D > F] ordering. *)
type grade = A_plus | A | B | C | D | F [@@deriving show, eq, ord, sexp]

val grade_to_string : grade -> string
(** Convert grade to a human-readable string (e.g. [A_plus] → ["A+"]). *)
