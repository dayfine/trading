open Core

(* Default trailing window for the dollar-ADV average. Harmless positive value:
   only consulted when one of the thresholds below is positive, so it never
   changes baseline behaviour at the no-op default. *)
let default_adv_lookback_days = 20

type t = {
  adv_lookback_days : int;
  min_entry_dollar_adv : float;
  min_hold_dollar_adv : float;
}
[@@deriving sexp]

let default_config =
  {
    adv_lookback_days = default_adv_lookback_days;
    min_entry_dollar_adv = 0.0;
    min_hold_dollar_adv = 0.0;
  }
