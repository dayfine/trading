type ma_slope = Rising | Flat | Declining [@@deriving show, eq]

type stage =
  | Stage1 of { weeks_in_base : int }
  | Stage2 of { weeks_advancing : int; late : bool }
  | Stage3 of { weeks_topping : int }
  | Stage4 of { weeks_declining : int }
[@@deriving show, eq]

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

let stage_number = function
  | Stage1 _ -> 1
  | Stage2 _ -> 2
  | Stage3 _ -> 3
  | Stage4 _ -> 4

let weeks_in_stage = function
  | Stage1 { weeks_in_base } -> weeks_in_base
  | Stage2 { weeks_advancing; _ } -> weeks_advancing
  | Stage3 { weeks_topping } -> weeks_topping
  | Stage4 { weeks_declining } -> weeks_declining

(* Suppress unused-opens warning for Core — used for Date in ppx-derived show *)
