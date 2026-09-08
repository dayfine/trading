(** The simulator step's forced-exit phase — see [forced_exit_step.mli]. *)

open Core

(* Delisted exits, or the inputs unchanged when the caller supplies no
   delisting-marker lookup. *)
let _delisted ~adapter ~active_through_for ~commission ~date ~today_bars
    ~portfolio ~positions =
  match active_through_for with
  | None -> (portfolio, positions, [], [])
  | Some active_through_for ->
      Delisted_exit_runner.tick ~adapter ~active_through_for ~commission ~date
        ~today_bars ~portfolio ~positions ()

(* Resting-ticket cancels, or the inputs unchanged when the caller supplies no
   delisting-marker lookup. Deliberately NOT gated on [today_bars]: a resting
   order can fill on a bar-less day against the symbol's retained last bar, so
   waiting for bars would leave the hole open. See
   [delisted_ticket_cancel.mli]. *)
let _delisted_tickets ~order_manager ~active_through_for ~date ~positions =
  match active_through_for with
  | None -> (positions, [])
  | Some active_through_for ->
      Delisted_ticket_cancel.tick ~order_manager ~active_through_for ~date
        ~positions ()

let run ~adapter ~order_manager ~active_through_for ~stale_config ~commission
    ~date ~today_bars ~last_known_price ~on_transitions ~portfolio ~positions ()
    =
  (* MARKED delistings first, so a marked one never reaches the stale safety
     net and never counts as a data-quality flag. See the .mli. *)
  let portfolio, positions, delisted_trades, delisted_transitions =
    _delisted ~adapter ~active_through_for ~commission ~date ~today_bars
      ~portfolio ~positions
  in
  let portfolio, positions, stale_trades, stale_transitions =
    Stale_exit_runner.tick ~adapter ~config:stale_config ~commission ~date
      ~today_bars ~last_known_price ~portfolio ~positions ()
  in
  (* Entry side, last: it touches only wholly-unfilled tickets, which neither
     exit runner can select (both need a non-zero broker quantity), so it is
     disjoint from the ordering contract above. *)
  let positions, ticket_transitions =
    _delisted_tickets ~order_manager ~active_through_for ~date ~positions
  in
  let transitions =
    delisted_transitions @ stale_transitions @ ticket_transitions
  in
  if not (List.is_empty transitions) then
    Option.iter on_transitions ~f:(fun observe -> observe transitions);
  (portfolio, positions, delisted_trades @ stale_trades)
