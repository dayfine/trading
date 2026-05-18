open Core

type t =
  | Common_stock
  | Preferred_stock
  | ETF
  | Mutual_fund
  | Fund
  | ADR
  | GDR
  | Bond
  | Index
  | Currency
  | Commodity
  | Other of string
[@@deriving show, eq, sexp]

let of_eodhd_string raw =
  match String.strip raw with
  | "Common Stock" -> Common_stock
  | "Preferred Stock" -> Preferred_stock
  | "ETF" -> ETF
  | "Mutual Fund" -> Mutual_fund
  | "FUND" | "Fund" | "Closed-End Fund" -> Fund
  | "ADR" -> ADR
  | "GDR" -> GDR
  | "Bond" -> Bond
  | "INDEX" | "Index" -> Index
  | "Currency" | "CURRENCY" | "FOREX" -> Currency
  | "Commodity" | "COMMODITY" | "Future" -> Commodity
  | "" -> Other ""
  | other -> Other other

let to_string = function
  | Common_stock -> "Common Stock"
  | Preferred_stock -> "Preferred Stock"
  | ETF -> "ETF"
  | Mutual_fund -> "Mutual Fund"
  | Fund -> "Fund"
  | ADR -> "ADR"
  | GDR -> "GDR"
  | Bond -> "Bond"
  | Index -> "Index"
  | Currency -> "Currency"
  | Commodity -> "Commodity"
  | Other s -> s

let is_equity_like = function
  | Common_stock | Preferred_stock | ADR | GDR -> true
  | ETF | Mutual_fund | Fund | Bond | Index | Currency | Commodity | Other _ ->
      false
