open Core.Filename
open Core.Date

type t = { symbol : string; path : string }

let create symbol =
  let path = concat "data" (symbol ^ ".csv") in
  { symbol; path }

let create_with_path symbol path = { symbol; path }

let validate_prices prices =
  let rec check_sorted_and_unique prev = function
    | [] -> Ok ()
    | price :: rest ->
        if compare price.Types.Daily_price.date prev <= 0 then
          Error
            (Base.Errors.Error.create Invalid_argument
               "Prices must be sorted by date in ascending order and contain \
                no duplicates")
        else check_sorted_and_unique price.Types.Daily_price.date rest
  in
  match prices with
  | [] -> Ok ()
  | first :: rest -> check_sorted_and_unique first.Types.Daily_price.date rest

let save t ?(override = false) prices =
  match validate_prices prices with
  | Error error -> raise (Base.Errors.Error error)
  | Ok () ->
      (* TODO: Implement actual file writing *)
      ()

let get_prices t ?start_date ?end_date =
  (* TODO: Implement actual file reading and filtering *)
  []

let get_date_range t =
  (* TODO: Implement actual date range calculation *)
  None
