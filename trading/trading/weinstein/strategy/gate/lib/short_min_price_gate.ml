open Core

let filter ~short_min_price (candidates : Screener.scored_candidate list) =
  if Float.( <= ) short_min_price 0.0 then candidates
  else
    List.filter candidates ~f:(fun c ->
        Float.( >= ) c.Screener.suggested_entry short_min_price)
