type t = {
  date : Core.Date.t;
  open_price : float;
  high_price : float;
  low_price : float;
  close_price : float;
  volume : int;
  adjusted_close : float;
  active_through : Core.Date.t option;
      (** Last date on which the issue actively traded, when known. [None] means
          "still trading / unknown delisting status" — the default for bars
          sourced from feeds that do not carry a delisting marker. [Some d]
          indicates the symbol was delisted on or before [d]; callers (e.g. the
          screener point-in-time filter) may treat look-ups strictly after [d]
          as "bar missing because the issue is no longer listed" rather than as
          a data gap. *)
}
[@@deriving show, eq]

let make ~date ~open_price ~high_price ~low_price ~close_price ~volume
    ~adjusted_close ?active_through () =
  {
    date;
    open_price;
    high_price;
    low_price;
    close_price;
    volume;
    adjusted_close;
    active_through;
  }
