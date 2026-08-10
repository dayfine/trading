open Core

type t = float Hashtbl.M(String).t

let create () : t = Hashtbl.create (module String)

(* Drop any pinned symbol that is neither a candidate this week nor currently
   held: the setup has ended (candidate dropped out, or the position round-tripped
   to [Closed] and the symbol has left the walk), so a later re-qualification must
   earn a fresh pin rather than reuse a stale [E]. *)
let _release_stale ~pending ~qualifying ~held_set =
  let stale =
    Hashtbl.keys pending
    |> List.filter ~f:(fun sym ->
        (not (Set.mem qualifying sym)) && not (Set.mem held_set sym))
  in
  List.iter stale ~f:(fun sym -> Hashtbl.remove pending sym)

(* Reuse the pinned [E] if present (override [suggested_entry]); otherwise pin
   the current [E] and pass the candidate through unchanged. *)
let _freeze_one ~pending (cand : Screener.scored_candidate) =
  match Hashtbl.find pending cand.ticker with
  | Some pinned -> { cand with Screener.suggested_entry = pinned }
  | None ->
      Hashtbl.set pending ~key:cand.ticker ~data:cand.suggested_entry;
      cand

let release pending ~symbol = Hashtbl.remove pending symbol

let apply ~enabled ~pending ~held_set ~candidates =
  if not enabled then candidates
  else
    let qualifying =
      List.map candidates ~f:(fun (c : Screener.scored_candidate) -> c.ticker)
      |> String.Set.of_list
    in
    _release_stale ~pending ~qualifying ~held_set;
    List.map candidates ~f:(_freeze_one ~pending)
