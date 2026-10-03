open Core

(* One pin: the first-qualifying [E] and the arm that anchored it (#3089). The
   arm is pinned with the level so the audit names the arm the resting ticket
   was actually priced at, not the current week's arm. *)
type pin = { entry : float; anchor : Screener.entry_anchor_kind }
type t = pin Hashtbl.M(String).t

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

(* The pin a first-qualifying candidate earns: its current [E] and arm. *)
let _pin_of (cand : Screener.scored_candidate) =
  { entry = cand.suggested_entry; anchor = Screener.entry_anchor_kind cand }

(* Reuse the pinned [E] if present (override [suggested_entry]); otherwise pin
   the current [E] together with its arm and pass the candidate through
   unchanged. *)
let _freeze_one ~pending (cand : Screener.scored_candidate) =
  match Hashtbl.find pending cand.ticker with
  | Some pin -> { cand with Screener.suggested_entry = pin.entry }
  | None ->
      Hashtbl.set pending ~key:cand.ticker ~data:(_pin_of cand);
      cand

let release pending ~symbol = Hashtbl.remove pending symbol

let anchor_kind pending (cand : Screener.scored_candidate) =
  match Hashtbl.find pending cand.ticker with
  | Some pin -> pin.anchor
  | None -> Screener.entry_anchor_kind cand

let apply ~enabled ~pending ~held_set ~candidates =
  if not enabled then candidates
  else
    let qualifying =
      List.map candidates ~f:(fun (c : Screener.scored_candidate) -> c.ticker)
      |> String.Set.of_list
    in
    _release_stale ~pending ~qualifying ~held_set;
    List.map candidates ~f:(_freeze_one ~pending)
