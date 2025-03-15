open Types

(* Create a date from year, month, day. Month is 1-12. *)
let create ~year ~month ~day : date =
  let t = Unix.localtime (Unix.time ()) in
  { t with tm_year = year - 1900; tm_mon = month - 1; tm_mday = day }

(* Parse a date from YYYY-MM-DD format *)
let parse str : date =
  try
    Scanf.sscanf str "%d-%d-%d" (fun year month day ->
      create ~year ~month ~day)
  with _ -> failwith "Invalid date format, expected YYYY-MM-DD"

(* Format a date as YYYY-MM-DD *)
let to_string (date : date) : string =
  Printf.sprintf "%04d-%02d-%02d"
    (date.tm_year + 1900)
    (date.tm_mon + 1)
    date.tm_mday

(* Compare two dates *)
let compare (d1 : date) (d2 : date) : int =
  let t1 = Unix.mktime d1 |> fst in
  let t2 = Unix.mktime d2 |> fst in
  compare t1 t2

(* Check if two dates are in the same week *)
let is_same_week (d1 : date) (d2 : date) : bool =
  let t1 = Unix.mktime d1 |> fst in
  let t2 = Unix.mktime d2 |> fst in
  let week1 = t1 /. (24. *. 3600. *. 7.) |> floor in
  let week2 = t2 /. (24. *. 3600. *. 7.) |> floor in
  week1 = week2

(* Get year as a normal year number (not Unix year) *)
let year (d : date) = d.tm_year + 1900

(* Get month as 1-12 (not Unix 0-11) *)
let month (d : date) = d.tm_mon + 1

(* Get day of month *)
let day (d : date) = d.tm_mday

let add_days date days =
  let time = Unix.mktime date in
  let new_time = fst time +. (float_of_int days) *. 24. *. 3600. in
  Unix.localtime new_time

let daily_to_weekly data =
  let rec aux acc curr_week = function
    | [] -> List.rev (match curr_week with [] -> acc | data :: _ -> data :: acc)
    | data :: rest ->
        match curr_week with
        | [] -> aux acc [data] rest
        | last :: _ ->
            if is_same_week last data then
              aux acc (data :: curr_week) rest
            else
              aux (last :: acc) [data] rest
  in
  aux [] [] data
