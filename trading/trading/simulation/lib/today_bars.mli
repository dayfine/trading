(** Today's engine price bars for the simulator's universe. *)

val get :
  adapter:Trading_simulation_data.Market_data_adapter.t ->
  symbols:string list ->
  date:Core.Date.t ->
  Trading_engine.Types.price_bar list
(** [get ~adapter ~symbols ~date] is one engine [price_bar] (open, high, low,
    close) per symbol in [symbols] that has a [Daily_price] on [date], in
    [symbols] order. Symbols without a bar that day are omitted. *)
