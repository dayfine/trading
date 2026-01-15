open Core

type indicator_spec = {
  name : string;
  period : int;
  cadence : Time_series.cadence;
}
[@@deriving show, eq, hash, sexp, compare]

type cache_key = { symbol : string; spec : indicator_spec; date : Date.t }
[@@deriving hash, sexp, compare]

type cache_entry = { value : float option; is_provisional : bool }

type t = {
  price_cache : Price_cache.t;
  indicator_cache : (cache_key, cache_entry) Hashtbl.t;
}

let create ~price_cache =
  {
    price_cache;
    indicator_cache =
      Hashtbl.create
        (module struct
          type t = cache_key [@@deriving hash, sexp, compare]
        end);
  }

let _estimate_lookback_days ~period ~cadence =
  match cadence with
  | Time_series.Daily -> period + 10
  | Time_series.Weekly -> (period * 7) + 50
  | Time_series.Monthly -> (period * 30) + 100

let _is_provisional ~cadence ~date =
  not (Time_series.is_period_end ~cadence date)

let get_indicator t ~symbol ~spec ~date =
  let key = { symbol; spec; date } in
  match Hashtbl.find t.indicator_cache key with
  | Some entry -> Ok entry.value
  | None ->
      let lookback_days =
        _estimate_lookback_days ~period:spec.period ~cadence:spec.cadence
      in
      let start_date = Date.add_days date (-lookback_days) in
      let open Result.Let_syntax in
      let%bind prices =
        Price_cache.get_prices t.price_cache ~symbol ~start_date ~end_date:date
          ()
      in
      let as_of_date =
        if _is_provisional ~cadence:spec.cadence ~date then Some date else None
      in
      let%bind result =
        match spec.name with
        | "EMA" ->
            Indicator_computer.compute_ema ~symbol ~prices ~period:spec.period
              ~cadence:spec.cadence ?as_of_date ()
        | _ ->
            Error
              (Status.invalid_argument_error
                 (Printf.sprintf "Unknown indicator: %s" spec.name))
      in
      let value =
        List.last result.indicator_values
        |> Option.map ~f:(fun iv -> iv.Indicator_types.value)
      in
      let entry =
        { value; is_provisional = _is_provisional ~cadence:spec.cadence ~date }
      in
      Hashtbl.set t.indicator_cache ~key ~data:entry;
      Ok value

let finalize_period t ~cadence ~end_date =
  let keys_to_remove =
    Hashtbl.fold t.indicator_cache ~init:[] ~f:(fun ~key ~data acc ->
        if
          data.is_provisional
          && Time_series.equal_cadence key.spec.cadence cadence
          && Date.( <= ) key.date end_date
        then key :: acc
        else acc)
  in
  List.iter keys_to_remove ~f:(fun key -> Hashtbl.remove t.indicator_cache key)

let clear_cache t = Hashtbl.clear t.indicator_cache

let cache_stats t =
  let total = Hashtbl.length t.indicator_cache in
  let provisional =
    Hashtbl.count t.indicator_cache ~f:(fun entry -> entry.is_provisional)
  in
  (total, provisional)
