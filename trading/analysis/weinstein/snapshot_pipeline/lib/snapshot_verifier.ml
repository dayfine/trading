open Core
module Snapshot_format = Data_panel_snapshot.Snapshot_format

type file_result = {
  symbol : string;
  path : string;
  status : (int, Status.t) Result.t;
}

type t = { total : int; passed : int; failed : int; results : file_result list }

let _verify_one ~(entry : Snapshot_manifest.file_metadata)
    ~(expected : Data_panel_snapshot.Snapshot_schema.t) : file_result =
  let status =
    match
      Snapshot_format.read_with_expected_schema ~path:entry.path ~expected
    with
    | Ok rows -> Ok (List.length rows)
    | Error err -> Error err
  in
  { symbol = entry.symbol; path = entry.path; status }

let _summarize results =
  let passed = List.count results ~f:(fun r -> Result.is_ok r.status) in
  let failed = List.length results - passed in
  { total = List.length results; passed; failed; results }

let verify_directory ~manifest_path =
  let open Result.Let_syntax in
  let%bind manifest = Snapshot_manifest.read ~path:manifest_path in
  let results =
    List.map manifest.entries ~f:(fun entry ->
        _verify_one ~entry ~expected:manifest.schema)
  in
  Ok (_summarize results)
