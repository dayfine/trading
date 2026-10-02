(* Carry-forward of untouched pre-run manifest entries on incremental builds,
   extracted from [build_runner.ml]. *)

open Core
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* A manifest written under a DIFFERENT schema carries another indicator set's
   column layout, so adopting its rows would advertise columns this build's
   readers cannot decode. Refusing across schemas mirrors
   {!Snapshot_manifest.update_for_symbol}, which rejects a cross-schema
   checkpoint for the same reason. Says so and carries nothing. *)
let _refuse_cross_schema_carry ~(m : Snapshot_manifest.t) ~schema =
  Printf.eprintf
    "incremental: existing manifest's schema_hash %s differs from this build's \
     %s; its %d entries are NOT carried forward\n\
     %!"
    m.schema_hash schema.Snapshot_schema.schema_hash (List.length m.entries);
  []

(* Entries of the pre-run manifest that are usable as carry-forward candidates:
   all of them when the schema matches, none when it does not. *)
let _carry_candidates ~existing ~schema =
  match existing with
  | None -> []
  | Some (m : Snapshot_manifest.t) ->
      if String.equal m.schema_hash schema.Snapshot_schema.schema_hash then
        m.entries
      else _refuse_cross_schema_carry ~m ~schema

(* Pre-run manifest entries for symbols this run did not produce (#2669).

   In incremental mode the run's symbol set may be a strict SUBSET of the
   warehouse's — a top-up that adds one benchmark symbol, or a cron window that
   resumes a partial rebuild with a different universe. The manifest is the
   warehouse's only index ({!Bar_source_resolver} enumerates symbols from it),
   so writing ONLY this run's entries deletes every other symbol from the
   warehouse while its [.snap] files sit untouched on disk — the observed
   failure was a 2,208-symbol warehouse reduced to one entry by a one-symbol
   top-up, and it read as empty to every runner.

   Carrying the untouched entries forward makes the final write agree with the
   per-symbol checkpoint, which already upserts rather than replaces
   ({!Snapshot_manifest.update_for_symbol}).

   Three candidates are dropped: one whose symbol this run produced (the fresh
   entry wins, so a rebuilt symbol is never duplicated or stale), one whose
   [.snap] file is gone (a stale index row would fail the closing verify), and
   one this run deliberately EXCLUDED — a twin leg the rename-twin pass dropped
   (#2730). Carrying an excluded symbol forward would silently reinstate the
   duplicate the pass exists to remove, and on an incremental rebuild that is
   exactly the shape that hides it: the pass reports the drop, the manifest
   keeps indexing it, and the backtest still holds both legs. *)
let carried_entries ~existing ~schema ~excluded entries =
  let produced =
    List.map entries ~f:(fun (e : Snapshot_manifest.file_metadata) -> e.symbol)
    |> Set.of_list (module String)
  in
  let skip symbol = Set.mem produced symbol || Set.mem excluded symbol in
  _carry_candidates ~existing ~schema
  |> List.filter ~f:(fun (e : Snapshot_manifest.file_metadata) ->
      (not (skip e.symbol)) && Stdlib.Sys.file_exists e.path)

(* A non-empty carry set means this run's universe was not a superset of the
   warehouse. That is legitimate (a top-up is exactly that shape), so it is a
   warning rather than a refusal — but the operator should see it, because it
   also flags the case where a resumed window was pointed at the wrong
   universe file. *)
let log_carry_forward carried =
  if not (List.is_empty carried) then
    Printf.printf
      "incremental: universe is not a superset of the existing manifest; \
       carrying %d untouched symbol(s) forward (#2669)\n\
       %!"
      (List.length carried)
