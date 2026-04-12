open Core

type stage =
  | Stage1 of { weeks_in_base : int }
  | Stage2 of { weeks_advancing : int; late : bool }
  | Stage3 of { weeks_topping : int }
  | Stage4 of { weeks_declining : int }
[@@deriving show, eq, sexp]

type ma_direction = Rising | Flat | Declining [@@deriving show, eq, sexp]

type overhead_quality =
  | Virgin_territory
  | Clean
  | Moderate_resistance
  | Heavy_resistance
[@@deriving show, eq, sexp]

type rs_trend =
  | Bullish_crossover
  | Positive_rising
  | Positive_flat
  | Negative_improving
  | Negative_declining
  | Bearish_crossover
[@@deriving show, eq, sexp]

type volume_confirmation = Strong of float | Adequate of float | Weak of float
[@@deriving show, eq, sexp]

type market_trend = Bullish | Bearish | Neutral [@@deriving show, eq, sexp]

(** The 11 GICS sectors used by S&P/MSCI classification. *)
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

let all_gics_sectors =
  [
    Information_technology;
    Financials;
    Health_care;
    Energy;
    Industrials;
    Consumer_staples;
    Consumer_discretionary;
    Utilities;
    Materials;
    Real_estate;
    Communication_services;
  ]

let gics_sector_to_string = function
  | Information_technology -> "Information Technology"
  | Financials -> "Financials"
  | Health_care -> "Health Care"
  | Energy -> "Energy"
  | Industrials -> "Industrials"
  | Consumer_staples -> "Consumer Staples"
  | Consumer_discretionary -> "Consumer Discretionary"
  | Utilities -> "Utilities"
  | Materials -> "Materials"
  | Real_estate -> "Real Estate"
  | Communication_services -> "Communication Services"

let gics_sector_of_string_opt s =
  match String.lowercase s with
  | "information technology" -> Some Information_technology
  | "financials" -> Some Financials
  | "health care" -> Some Health_care
  | "energy" -> Some Energy
  | "industrials" -> Some Industrials
  | "consumer staples" -> Some Consumer_staples
  | "consumer discretionary" -> Some Consumer_discretionary
  | "utilities" -> Some Utilities
  | "materials" -> Some Materials
  | "real estate" -> Some Real_estate
  | "communication services" -> Some Communication_services
  | _ -> None

type grade = A_plus | A | B | C | D | F [@@deriving show, eq, ord, sexp]

let grade_to_string = function
  | A_plus -> "A+"
  | A -> "A"
  | B -> "B"
  | C -> "C"
  | D -> "D"
  | F -> "F"
