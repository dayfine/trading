open Core
open Weinstein_types

type config = {
  enabled : bool;
  weak_pct_above : float;
  falling_points : float;
  rising_points : float;
  new_lows_pct : float;
  lookback_weeks : int;
}
[@@deriving sexp]

let default_config =
  {
    enabled = false;
    weak_pct_above = 45.0;
    falling_points = 5.0;
    rising_points = 5.0;
    new_lows_pct = 8.0;
    lookback_weeks = 4;
  }

(* One breadth reading: the four samples, all present. [classify] resolves the
   option-quadruple into this once so the rule predicates below read as the
   plain arithmetic they are. *)
type reading = {
  pct_above : float;
  pct_above_prior : float;
  nl_pct : float;
  nl_pct_prior : float;
}

let _reading pct_above pct_above_prior nl_pct nl_pct_prior =
  match (pct_above, pct_above_prior, nl_pct, nl_pct_prior) with
  | Some pct_above, Some pct_above_prior, Some nl_pct, Some nl_pct_prior ->
      Some { pct_above; pct_above_prior; nl_pct; nl_pct_prior }
  | _ -> None

let _is_weak ~(config : config) r = Float.(r.pct_above < config.weak_pct_above)

(** Weak participation that fell by at least [falling_points] over the lookback.
*)
let _participation_falling ~(config : config) r =
  _is_weak ~config r
  && Float.(r.pct_above -. r.pct_above_prior <= -.config.falling_points)

(** Elevated new lows that are still expanding. Independent of where
    participation sits — a widening low list is its own deterioration signal. *)
let _new_lows_expanding ~(config : config) r =
  Float.(r.nl_pct > config.new_lows_pct) && Float.(r.nl_pct > r.nl_pct_prior)

(** Weak participation that rose by at least [rising_points] over the lookback.
*)
let _participation_rising ~(config : config) r =
  _is_weak ~config r
  && Float.(r.pct_above -. r.pct_above_prior >= config.rising_points)

(* Rule order is the contract — see the .mli. Deteriorating is tested before
   Recovering so it wins the tie at a turn. *)
let _classify_reading ~config ~trend r =
  match trend with
  | Bearish -> Bearish_breadth
  | Bullish | Neutral ->
      if _participation_falling ~config r || _new_lows_expanding ~config r then
        Deteriorating
      else if _participation_rising ~config r then Recovering
      else breadth_state_of_market_trend trend

let classify ~(config : config) ~trend ~pct_above ~pct_above_prior ~nl_pct
    ~nl_pct_prior =
  if not config.enabled then breadth_state_of_market_trend trend
  else
    match _reading pct_above pct_above_prior nl_pct nl_pct_prior with
    | None -> breadth_state_of_market_trend trend
    | Some r -> _classify_reading ~config ~trend r
