type stage =
  | Stage1 of { weeks_in_base : int }
  | Stage2 of { weeks_advancing : int; late : bool }
  | Stage3 of { weeks_topping : int }
  | Stage4 of { weeks_declining : int }
[@@deriving show, eq]

type ma_direction = Rising | Flat | Declining [@@deriving show, eq]

type overhead_quality =
  | Virgin_territory
  | Clean
  | Moderate_resistance
  | Heavy_resistance
[@@deriving show, eq]

type rs_trend =
  | Bullish_crossover
  | Positive_rising
  | Positive_flat
  | Negative_improving
  | Negative_declining
  | Bearish_crossover
[@@deriving show, eq]

type volume_confirmation = Strong of float | Adequate of float | Weak of float
[@@deriving show, eq]

type market_trend = Bullish | Bearish | Neutral [@@deriving show, eq]
type grade = A_plus | A | B | C | D | F [@@deriving show, eq, ord]

let grade_to_string = function
  | A_plus -> "A+"
  | A -> "A"
  | B -> "B"
  | C -> "C"
  | D -> "D"
  | F -> "F"
