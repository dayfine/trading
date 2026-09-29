open Core
module Suspend_mode = Weinstein_strategy.Entry_ticket_suspend_mode

(* The runner's base value of the knob, so a params.sexp with no override for it
   reads as whatever the strategy defaults to — not a hardcoded [Off]. *)
let _default_suspend () =
  (Weinstein_strategy.default_config ~universe:[] ~index_symbol:"")
    .entry_ticket_macro_suspend

(* The knob's value in one partial-config overlay, if the overlay sets it. It is
   a top-level field, so the runner's left-to-right deep merge makes the last
   overlay that names it win. *)
let _suspend_in_overlay = function
  | Sexp.List fields ->
      List.find_map fields ~f:(function
        | Sexp.List [ Sexp.Atom "entry_ticket_macro_suspend"; v ] -> Some v
        | _ -> None)
  | Sexp.Atom _ -> None

let _overrides_of_params = function
  | Sexp.List fields ->
      List.find_map fields ~f:(function
        | Sexp.List [ Sexp.Atom "overrides"; Sexp.List os ] -> Some os
        | _ -> None)
      |> Option.value ~default:[]
  | Sexp.Atom _ -> []

let macro_suspend_of_params params =
  match
    List.filter_map (_overrides_of_params params) ~f:_suspend_in_overlay
    |> List.last
  with
  | None -> Some (_default_suspend ())
  | Some v -> Option.try_with (fun () -> Suspend_mode.t_of_sexp v)

let load_macro_suspend path =
  if not (Sys_unix.file_exists_exn path) then None
  else
    match Sexp.load_sexp path with
    | sexp -> macro_suspend_of_params sexp
    | exception _ -> None
