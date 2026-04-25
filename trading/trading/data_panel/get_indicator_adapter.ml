module BA2 = Bigarray.Array2

let make (panels : Indicator_panels.t) ~t :
    Trading_strategy.Strategy_interface.get_indicator_fn =
 fun symbol indicator_name period cadence ->
  let symbol_index = Indicator_panels.symbol_index panels in
  match Symbol_index.to_row symbol_index symbol with
  | None -> None
  | Some row -> (
      let spec : Indicator_spec.t =
        { name = indicator_name; period; cadence }
      in
      (* Lookup is O(1) via Hashtbl in [Indicator_panels]; raise inside [get]
         is converted to [None] here (None semantics: "indicator not
         available" — caller treats unknown spec the same as warmup NaN). *)
      match
        try Some (Indicator_panels.get panels spec) with Failure _ -> None
      with
      | None -> None
      | Some panel ->
          let v = BA2.unsafe_get panel row t in
          if Float.is_nan v then None else Some v)
