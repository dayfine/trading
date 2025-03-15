let pp_date fmt d =
  Format.fprintf fmt "%04d-%02d-%02d"
    (d.Unix.tm_year + 1900)
    (d.Unix.tm_mon + 1)
    d.Unix.tm_mday

type date = Unix.tm

type price_data = {
  date : date;
  open_price : float;
  high : float;
  low : float;
  close : float;
  adjusted_close : float;
  volume : int;
} [@@deriving show]
