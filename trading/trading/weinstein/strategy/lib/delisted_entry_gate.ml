(** Unconditional post-[active_through] entry exclusion — see
    [delisted_entry_gate.mli]. *)

open Core

(* Same predicate and same boundary as [Delisted_exit_runner._request_for_position]:
   [as_of <= active_through] is still tradeable. No marker -> tradeable (a
   warehouse built before #2691 carries none, which is what makes this a no-op
   there). *)
let _is_tradeable ~as_of ~active_through_for (c : Screener.scored_candidate) =
  match active_through_for c.Screener.ticker with
  | None -> true
  | Some active_through -> Date.( <= ) as_of active_through

let filter ~as_of ~active_through_for candidates =
  List.filter candidates ~f:(_is_tradeable ~as_of ~active_through_for)

let apply ~bar_reader ~current_date candidates =
  let cb = Bar_reader.snapshot_callbacks bar_reader in
  let active_through_for symbol =
    cb.Snapshot_runtime.Snapshot_callbacks.active_through_for ~symbol
  in
  filter ~as_of:current_date ~active_through_for candidates
