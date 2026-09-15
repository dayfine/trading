(** Dated point-in-time universe membership — see [universe_schedule.mli]. *)

open Core

type _entry = {
  date : Date.t;
  members : String.Set.t;
  sectors : (string * string) list;
}

type t = { entries : _entry list (* sorted by [date], non-empty *) }

let _error code message = Error Status.{ code; message }

let _duplicate_dates (sorted : (Date.t * string) list) =
  List.find_consecutive_duplicate sorted ~equal:(fun (a, _) (b, _) ->
      Date.equal a b)
  |> Option.map ~f:(fun ((d, _), _) -> d)

(* Load one [(date, path)] entry. Two shapes are rejected, both for the same
   reason — they name no members, so they cannot express "these symbols are
   members on this date":

   - [Full_sector_map], the [data/sectors.csv] sentinel; and
   - an EMPTY [Pinned] list. A truncated or empty vintage file would otherwise
     load fine and silently produce a zero-candidate window rather than a load
     error, which is exactly the failure a 27-entry schedule must not hide. *)
let _load_entry ~fixtures_root (date, path) =
  let resolved = Filename.concat fixtures_root path in
  match Universe_file.load resolved with
  | Universe_file.Full_sector_map ->
      _error Status.Failed_precondition
        (sprintf
           "Universe_schedule: %s (entry dated %s) is the Full_sector_map \
            sentinel; a dated schedule needs an explicit membership list."
           path (Date.to_string date))
  | Universe_file.Pinned [] ->
      _error Status.Invalid_argument
        (sprintf
           "Universe_schedule: %s (entry dated %s) lists no symbols; every \
            schedule entry needs a non-empty membership list."
           path (Date.to_string date))
  | Universe_file.Pinned pinned ->
      let sectors =
        List.map pinned ~f:(fun (e : Universe_file.pinned_entry) ->
            (e.symbol, e.sector))
      in
      Ok
        {
          date;
          members = String.Set.of_list (List.map sectors ~f:fst);
          sectors;
        }

let load ~fixtures_root schedule =
  let sorted =
    List.sort schedule ~compare:(fun (a, _) (b, _) -> Date.compare a b)
  in
  match (sorted, _duplicate_dates sorted) with
  | [], _ ->
      _error Status.Invalid_argument
        "Universe_schedule.load: empty schedule; pass a non-empty \
         universe_schedule or leave the field unset."
  | _, Some d ->
      _error Status.Invalid_argument
        (sprintf
           "Universe_schedule.load: duplicate universe_schedule entry dated \
            %s; each date may appear at most once."
           (Date.to_string d))
  | _, None ->
      Result.map
        (List.map sorted ~f:(_load_entry ~fixtures_root) |> Result.all)
        ~f:(fun entries -> { entries })

(* The governing entry for [d]: the last entry dated at or before [d], falling
   back to the first entry when [d] precedes every entry (D2 — the first list
   governs all earlier dates). [entries] is non-empty by construction. *)
let _entry_at t d =
  let governing =
    List.fold t.entries ~init:None ~f:(fun acc e ->
        if Date.( <= ) e.date d then Some e else acc)
  in
  match (governing, t.entries) with
  | Some e, _ -> e
  | None, first :: _ -> first
  | None, [] ->
      failwith "Universe_schedule: invariant violated — empty entry list"

let members_at t d = (_entry_at t d).members
let is_member t symbol d = Set.mem (members_at t d) symbol

let union_sector_map t =
  let tbl = Hashtbl.create (module String) in
  List.iter t.entries ~f:(fun e ->
      List.iter e.sectors ~f:(fun (symbol, sector) ->
          (* First occurrence in schedule order wins. *)
          ignore
            (Hashtbl.add tbl ~key:symbol ~data:sector : [ `Ok | `Duplicate ])));
  tbl

let reject_if_present ~runner_name = function
  | [] -> Ok ()
  | _ :: _ ->
      _error Status.Unimplemented
        (sprintf
           "%s does not implement universe_schedule (dated point-in-time \
            membership); it resolves the scenario's universe_path once for the \
            whole window. Run this scenario through scenario_runner, or drop \
            universe_schedule from the spec."
           runner_name)

let raise_if_present ~runner_name schedule =
  match reject_if_present ~runner_name schedule with
  | Ok () -> ()
  | Error err -> failwith (Status.show err)

let sector_map_of_unscheduled ~fixtures_root ~runner_name (s : Scenario.t) =
  raise_if_present ~runner_name s.universe_schedule;
  let resolved = Filename.concat fixtures_root s.universe_path in
  Universe_file.to_sector_map_override (Universe_file.load resolved)
