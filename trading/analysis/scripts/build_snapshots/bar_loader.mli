(** CSV bar loading and windowing for the snapshot build, extracted from
    {!Symbol_builder}. *)

val csv_mtime : data_dir:Fpath.t -> symbol:string -> float option
(** Modification time of the symbol's [data.csv]; [None] when absent. *)

val load_windowed_bars :
  data_dir:Fpath.t ->
  start_date:Core.Date.t option ->
  end_date:Core.Date.t option ->
  symbol:string ->
  Types.Daily_price.t list Status.status_or
(** Load a symbol's bars windowed to the inclusive [start_date, end_date]. *)

val load_split_bars :
  data_dir:Fpath.t ->
  start_date:Core.Date.t option ->
  end_date:Core.Date.t option ->
  sketch_deep_days:int ->
  symbol:string ->
  (Types.Daily_price.t list * Types.Daily_price.t list) Status.status_or
(** Load once, split into [(deep_bars, window_bars)]: rows are emitted for the
    window only; the deep slice (up to [sketch_deep_days] before the window
    start) widens the resistance sketch's weekly prefix. *)
