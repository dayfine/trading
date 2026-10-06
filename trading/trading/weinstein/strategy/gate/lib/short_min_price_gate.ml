open Core

let suggested_entry_price (c : Screener.scored_candidate) = c.suggested_entry

let filter ?(price_of = suggested_entry_price) ~short_min_price
    (candidates : Screener.scored_candidate list) =
  if Float.( <= ) short_min_price 0.0 then candidates
  else
    List.filter candidates ~f:(fun c ->
        Float.( >= ) (price_of c) short_min_price)
