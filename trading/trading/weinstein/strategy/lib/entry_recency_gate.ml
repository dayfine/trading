(** The [entry_max_bar_age_days] entry-recency gate — see
    [entry_recency_gate.mli]. *)

open Core

(* A candidate is fresh when its latest bar is within [max_bar_age_days] of
   [current_date]. No reading -> fresh (a missing reading must never drop a
   candidate, matching [Short_borrow_gate._short_has_borrow]). *)
let _is_fresh ~max_bar_age_days ~current_date ~last_bar_date_for
    (c : Screener.scored_candidate) =
  match last_bar_date_for c.Screener.ticker with
  | None -> true
  | Some last_bar_date ->
      Date.diff current_date last_bar_date <= max_bar_age_days

let filter ~max_bar_age_days ~current_date ~last_bar_date_for
    (candidates : Screener.scored_candidate list) =
  if max_bar_age_days <= 0 then candidates
  else
    List.filter candidates
      ~f:(_is_fresh ~max_bar_age_days ~current_date ~last_bar_date_for)

let apply ~max_bar_age_days ~bar_reader ~current_date candidates =
  if max_bar_age_days <= 0 then candidates
  else
    let last_bar_date_for ticker =
      Bar_reader.daily_bars_for bar_reader ~symbol:ticker ~as_of:current_date
      |> List.last
      |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.date)
    in
    filter ~max_bar_age_days ~current_date ~last_bar_date_for candidates
