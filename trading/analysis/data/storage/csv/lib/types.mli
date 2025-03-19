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
