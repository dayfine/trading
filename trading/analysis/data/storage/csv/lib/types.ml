let pp_date fmt d =
  let timestamp = Unix.mktime d |> fst in
  let iso_string = ISO8601.Permissive.string_of_time timestamp in
  Format.fprintf fmt "%s" iso_string

type date = Unix.tm

type price_data = {
  date : date;
  open_ : float;
  high : float;
  low : float;
  close : float;
  adjusted_close : float;
  volume : int;
}
[@@deriving show]

type error =
  | Invalid_csv_format of string
  | Invalid_date of string
  | Invalid_number of string
  | Invalid_volume of string
[@@deriving show]

type result = (price_data, error) Result.t

type t = {
  date: date;
  open_price: float;
  high_price: float;
  low_price: float;
  close_price: float;
  volume: int;
  adjusted_close: float;
}
[@@deriving show]
