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
   arm's other bookkeeping untouched. [stop_state]'s payloads are inline
   records, so there is no cross-arm field to update generically; each arm is
   named, which also means a future fourth arm is a compile error here rather
   than a silent no-op. Private: [ratchet] is the only way to move a stop
   level, so it is the only place the never-lower rule can be bypassed. *)
let _with_level (state : Weinstein_stops.stop_state) stop_level :
    Weinstein_stops.stop_state =
  match state with
  | Initial r -> Initial { r with stop_level }
  | Trailing r -> Trailing { r with stop_level }
  | Tightened r -> Tightened { r with stop_level }

let ratchet t ~to_ =
  if Float.( < ) to_ (level t) then None
  else Some { t with state = _with_level t.state to_ }
