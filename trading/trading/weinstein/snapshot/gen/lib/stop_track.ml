open Core

type t = { state : Weinstein_stops.stop_state; updated : Date.t; raises : int }
[@@deriving sexp, eq, show]

let level t = Weinstein_stops.get_stop_level t.state

let state_name : Weinstein_stops.stop_state -> string = function
  | Initial _ -> "Initial"
  | Trailing _ -> "Trailing"
  | Tightened _ -> "Tightened"

let label t =
  sprintf "%s (%d raises, through %s)" (state_name t.state) t.raises
    (Date.to_string t.updated)

(* Rewrite the stop level inside whichever arm the state holds, leaving that
   arm's other bookkeeping untouched. The arms are matched explicitly rather
   than via a shared accessor: [stop_state]'s payloads are inline records, so
   there is no cross-arm field to update generically, and an exhaustive match
   means a future fourth arm is a compile error here rather than a silent
   no-op. *)
let _with_level (state : Weinstein_stops.stop_state) stop_level :
    Weinstein_stops.stop_state =
  match state with
  | Initial { reference_level; stop_level = _ } ->
      Initial { stop_level; reference_level }
  | Trailing
      {
        stop_level = _;
        last_correction_extreme;
        last_trend_extreme;
        ma_at_last_adjustment;
        correction_count;
        correction_observed_since_reset;
      } ->
      Trailing
        {
          stop_level;
          last_correction_extreme;
          last_trend_extreme;
          ma_at_last_adjustment;
          correction_count;
          correction_observed_since_reset;
        }
  | Tightened { stop_level = _; last_correction_extreme; reason } ->
      Tightened { stop_level; last_correction_extreme; reason }

let ratchet t ~to_ =
  if Float.( < ) to_ (level t) then None
  else Some { t with state = _with_level t.state to_ }
