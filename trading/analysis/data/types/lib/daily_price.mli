type t = {
  date : Core.Date.t;
  open_price : float;
  high_price : float;
  low_price : float;
  close_price : float;
  volume : int;
  adjusted_close : float;
  active_through : Core.Date.t option;
      (** Last date on which the issue actively traded, when known. [None] is
          the default — "still trading / unknown delisting status". [Some d]
          means the symbol was delisted on or before [d]; consumers (screener
          point-in-time filter, bar loaders) may distinguish "bar missing after
          delisting" from "bar missing for plumbing reasons" using this field.
          CSV / EODHD JSON deserialization preserves [None] for legacy inputs
          that do not carry the column. *)
}
[@@deriving show, eq]

val make :
  date:Core.Date.t ->
  open_price:float ->
  high_price:float ->
  low_price:float ->
  close_price:float ->
  volume:int ->
  adjusted_close:float ->
  ?active_through:Core.Date.t ->
  unit ->
  t
(** Build a [t] from OHLCV fields with optional [active_through]. Defaults
    [active_through] to [None] — appropriate for any data source that does not
    carry a delisting marker. Provided so callers do not have to spell out
    [active_through = None] in every record literal. *)
