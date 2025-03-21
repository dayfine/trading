open Core

(* Check if two dates are in the same week *)
let is_same_week (d1 : Date.t) (d2 : Date.t) : bool =
  Date.week_number d1 = Date.week_number d2 && Date.year d1 = Date.year d2

let daily_to_weekly data =
  let rec aux acc curr_week = function
    | [] -> (
        match curr_week with
        | [] -> List.rev acc
        | data :: _ -> List.rev (data :: acc))
    | data :: rest -> (
        match curr_week with
        | [] -> aux acc [ data ] rest
        | last :: _ ->
            if is_same_week last.Types.Daily_price.date data.Types.Daily_price.date then
              aux acc (data :: curr_week) rest
            else aux (last :: acc) [ data ] rest)
  in
  aux [] [] (List.sort data ~compare:(fun a b ->
    Date.compare a.Types.Daily_price.date b.Types.Daily_price.date))
