open Core

let filter ~min_entry_dollar_adv ~dollar_adv_for
    (candidates : Screener.scored_candidate list) =
  if Float.( <= ) min_entry_dollar_adv 0.0 then candidates
  else
    List.filter candidates ~f:(fun c ->
        match dollar_adv_for c.Screener.ticker with
        | None -> true (* No reading: never drop on missing data. *)
        | Some adv -> Float.( >= ) adv min_entry_dollar_adv)
