open Core
module Bar_reader = Weinstein_strategy.Bar_reader

type verdict =
  | Clean
  | Data_suspect of {
      move_pct : float;
      threshold_pct : float;
      bar_date : Date.t;
    }
[@@deriving eq, show]

(* Absolute percentage move of [last] vs [prior]'s close. [None] when the prior
   close is 0.0 (undefined move) — the caller treats that as [Clean]. *)
let _move_pct ~(prior : Types.Daily_price.t) ~(last : Types.Daily_price.t) =
  if Float.equal prior.close_price 0.0 then None
  else
    Some
      (Float.abs (last.close_price -. prior.close_price)
      /. prior.close_price *. 100.0)

(* Verdict for the final (bar, prior-bar) pair of a resident series. Split out
   of [_check_armed] so the option chain stays flat (nesting linter). *)
let _verdict_of_pair ~threshold_pct ~prior ~(last : Types.Daily_price.t) =
  match _move_pct ~prior ~last with
  | Some move_pct when Float.(move_pct >= threshold_pct) ->
      Data_suspect { move_pct; threshold_pct; bar_date = last.date }
  | Some _ | None -> Clean

(* Armed path ([threshold_pct > 0.0]): read the series and compare its last two
   bars. Fewer than two bars -> [Clean] (nothing to compare; the sparse-tail
   gate owns the "not enough data" surface). *)
let _check_armed bar_reader ~symbol ~as_of ~threshold_pct =
  let bars = Bar_reader.daily_bars_for bar_reader ~symbol ~as_of in
  match List.rev bars with
  | last :: prior :: _ -> _verdict_of_pair ~threshold_pct ~prior ~last
  | [] | [ _ ] -> Clean

let check bar_reader ~symbol ~as_of ~threshold_pct =
  if Float.(threshold_pct <= 0.0) then Clean
  else _check_armed bar_reader ~symbol ~as_of ~threshold_pct

(* Message body for a [Data_suspect] verdict. Split out of [warning] so the
   match arm is a flat [Some (call)] (nesting linter). *)
let _message ~symbol ~move_pct ~threshold_pct ~bar_date =
  Printf.sprintf
    "%s: FLAGGED data-suspect (kept as a candidate) — last bar %s moved %.1f%% \
     vs the prior bar's close (threshold %.1f%%); the signal may rest on a \
     single anomalous print (see issue #2083)"
    symbol (Date.to_string bar_date) move_pct threshold_pct

let warning ~symbol = function
  | Clean -> None
  | Data_suspect { move_pct; threshold_pct; bar_date } ->
      Some (_message ~symbol ~move_pct ~threshold_pct ~bar_date)
