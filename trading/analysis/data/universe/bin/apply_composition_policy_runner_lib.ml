open Core
module CP = Universe.Composition_policy
module CPR = Universe.Composition_policy_report
module CPT = Universe.Composition_policy_types
module CI = Universe.Composition_inputs
module Snapshot = Universe.Snapshot

type result = { input_count : int; kept_count : int; report_text : string }
[@@deriving show]

(* Project the policy's kept candidates back onto the snapshot, preserving the
   original entry records (weight / sector / synthetic) for the survivors and
   updating [size]. The candidate carries the symbol; we re-look-up the entry. *)
let _filtered_snapshot (snapshot : Snapshot.t) (kept : CPT.candidate list) :
    Snapshot.t =
  let by_symbol = Hashtbl.create (module String) in
  List.iter snapshot.entries ~f:(fun (e : Snapshot.entry) ->
      Hashtbl.set by_symbol ~key:e.symbol ~data:e);
  let entries =
    List.filter_map kept ~f:(fun c -> Hashtbl.find by_symbol c.CPT.symbol)
  in
  { snapshot with size = List.length entries; entries }

let _load_inputs ~snapshot_path ~symbol_types_path =
  let open Result.Let_syntax in
  let%bind snapshot = Snapshot.load ~path:snapshot_path in
  let%bind asset_type = CI.load_asset_type_lookup symbol_types_path in
  Ok (snapshot, asset_type)

let _write_outputs ~out_snapshot_path ~out_report_path ~filtered ~report_text =
  let open Result.Let_syntax in
  let%bind () = Snapshot.save filtered ~path:out_snapshot_path in
  match
    Or_error.try_with (fun () ->
        Out_channel.write_all out_report_path ~data:report_text)
  with
  | Ok () -> Ok ()
  | Error err ->
      Status.error_internal
        (Printf.sprintf "failed to write report %s: %s" out_report_path
           (Error.to_string_hum err))

let run ~snapshot_path ~symbol_types_path ~config ~out_snapshot_path
    ~out_report_path =
  let open Result.Let_syntax in
  let%bind snapshot, asset_type =
    _load_inputs ~snapshot_path ~symbol_types_path
  in
  let equity_like = Hashtbl.create (module String) in
  let candidates =
    CPR.candidates_of_snapshot snapshot ~equity_like ~asset_type ()
  in
  let policy_result = CP.apply ~config candidates in
  let filtered = _filtered_snapshot snapshot policy_result.kept in
  let report_text = CPR.render_reports policy_result in
  let%bind () =
    _write_outputs ~out_snapshot_path ~out_report_path ~filtered ~report_text
  in
  Ok
    {
      input_count = List.length snapshot.entries;
      kept_count = List.length filtered.entries;
      report_text;
    }
