type t = {
  date : Core.Date.t;
  open_price : float;
  high_price : float;
  low_price : float;
  close_price : float;
  volume : int;
  adjusted_close : float;
}
[@@deriving show, eq]
