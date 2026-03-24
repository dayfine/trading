(** Shared domain types for the Weinstein analysis pipeline.

    All variant types are used throughout Stage, RS, Volume, Macro, and
    Screener modules. Centralised here to avoid circular dependencies. *)

(** Slope direction of a moving average. *)
type ma_slope = Rising | Flat | Declining [@@deriving show, eq]

(** Weinstein stage with metadata.

    Each stock is always in exactly one stage. The variant payload carries
    how many weeks the stock has been in that stage and, for Stage 2, whether
    late-stage deceleration has been detected. *)
type stage =
  | Stage1 of { weeks_in_base : int }
      (** Basing: MA flattening after decline; price oscillates around MA. *)
  | Stage2 of { weeks_advancing : int; late : bool }
      (** Advancing: MA rising; price consistently above MA. [late=true] means
          MA deceleration detected — still hold but no longer a new buy. *)
  | Stage3 of { weeks_topping : int }
      (** Topping: MA flattening after advance; price oscillates around MA.
          Distribution phase — exit with profits. *)
  | Stage4 of { weeks_declining : int }
      (** Declining: MA falling; price consistently below MA.
          Absolute rule: never buy or hold in Stage 4. *)
[@@deriving show, eq]

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
      (** Dense trading zone just above breakout. Stock will use up buying
          power working through this zone. *)
[@@deriving show, eq]

(** Relative strength trend vs benchmark. *)
type rs_trend =
  | Bullish_crossover
      (** RS just crossed from negative to positive territory — A+ bonus. *)
  | Positive_rising  (** RS positive and trending higher. *)
  | Positive_flat    (** RS positive but flat — hold, don't add. *)
  | Negative_improving
      (** RS still negative but improving — watch, not yet a buy. *)
  | Negative_declining  (** RS negative and falling — avoid or short. *)
  | Bearish_crossover
      (** RS just crossed from positive to negative — bearish warning. *)
[@@deriving show, eq]

(** Volume confirmation quality for a breakout or breakdown. *)
type volume_confirmation =
  | Strong of float
      (** Volume ≥ 2× recent average. [float] is the actual ratio.
          Required for high-quality long entries. *)
  | Adequate of float
      (** Volume 1.5–2× recent average. Acceptable but not ideal. *)
  | Weak of float
      (** Volume < 1.5× recent average. Treat breakout with suspicion. *)
[@@deriving show, eq]

(** Overall market trend from macro analysis. *)
type market_trend = Bullish | Bearish | Neutral [@@deriving show, eq]

(** Quality grade for candidates. Higher is better. [compare] gives
    A_plus > A > B > C > D > F ordering. *)
type grade = A_plus | A | B | C | D | F [@@deriving show, eq, ord]

(** Convert grade to a human-readable string. *)
val grade_to_string : grade -> string

(** [stage_number s] returns the integer stage number (1–4). Useful for
    logging and reporting. *)
val stage_number : stage -> int

(** [weeks_in_stage s] returns how many weeks the stock has been in its
    current stage. *)
val weeks_in_stage : stage -> int
