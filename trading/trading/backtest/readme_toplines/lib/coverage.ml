open Core

type coverage = { symbol : string; first_bar : Date.t; last_bar : Date.t }
[@@deriving sexp, eq]

let period_intersection coverages =
  match coverages with
  | [] -> None
  | _ -> (
      let latest_first =
        List.map coverages ~f:(fun c -> c.first_bar)
        |> List.max_elt ~compare:Date.compare
      in
      let earliest_last =
        List.map coverages ~f:(fun c -> c.last_bar)
        |> List.min_elt ~compare:Date.compare
      in
      match (latest_first, earliest_last) with
      | Some start_date, Some end_date when Date.( <= ) start_date end_date ->
          Some (start_date, end_date)
      | _ -> None)

let total_return_pct ~initial ~final =
  if Float.( <= ) initial 0.0 then Float.nan
  else (final -. initial) /. initial *. 100.0

let bah_total_return_pct ~start_date ~end_date ~close_series =
  let entry =
    List.filter close_series ~f:(fun (d, _) -> Date.( >= ) d start_date)
    |> List.min_elt ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
  in
  let exit_ =
    List.filter close_series ~f:(fun (d, _) -> Date.( <= ) d end_date)
    |> List.max_elt ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
  in
  match (entry, exit_) with
  | Some (entry_date, entry_close), Some (exit_date, exit_close)
    when Date.( < ) entry_date exit_date && Float.( > ) entry_close 0.0 ->
      (* Require entry strictly before exit: a window spanning a single bar
         (entry_date = exit_date) has zero holding span and is unpriceable. *)
      total_return_pct ~initial:entry_close ~final:exit_close
  | _ -> Float.nan

let inclusive_days ~start_date ~end_date =
  if Date.( < ) end_date start_date then 0
  else Date.diff end_date start_date + 1
