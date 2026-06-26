open Core

(** Dollar volume of a single bar: close price times share volume. *)
let _bar_dollar_volume (bar : Types.Daily_price.t) =
  bar.close_price *. Float.of_int bar.volume

let dollar_adv ~lookback_days (bars : Types.Daily_price.t list) =
  if lookback_days <= 0 then None
  else
    (* [bars] is oldest-first; take the trailing [lookback_days] bars. *)
    let n = List.length bars in
    let window =
      if n <= lookback_days then bars else List.drop bars (n - lookback_days)
    in
    match window with
    | [] -> None
    | _ ->
        let total =
          List.sum (module Float) window ~f:_bar_dollar_volume
        in
        Some (total /. Float.of_int (List.length window))
