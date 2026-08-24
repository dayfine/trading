open Core
module Bar = Types.Daily_price
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snap = Data_panel_snapshot.Snapshot

let _snap_ext = ".snap"
let _get row field = Option.value (Snap.get row field) ~default:Float.nan

(* Snap [Volume] cells are float64; [Daily_price.volume] is an int. Mirrors
   [Bar_source]'s / [Sidetable_migrator]'s volume handling. *)
let _volume_of v = if Float.is_nan v then 0 else Float.to_int v

let _bar_of_row (row : Snap.t) : Bar.t =
  Bar.make ~date:row.Snap.date
    ~open_price:(_get row Snapshot_schema.Open)
    ~high_price:(_get row Snapshot_schema.High)
    ~low_price:(_get row Snapshot_schema.Low)
    ~close_price:(_get row Snapshot_schema.Close)
    ~volume:(_volume_of (_get row Snapshot_schema.Volume))
    ~adjusted_close:(_get row Snapshot_schema.Adjusted_close)
    ()

let symbols ~snapshot_dir =
  match Stdlib.Sys.readdir snapshot_dir with
  | exception Sys_error msg ->
      Status.error_internal
        (Printf.sprintf "monster_scan: cannot list %s: %s" snapshot_dir msg)
  | entries ->
      Array.to_list entries
      |> List.filter_map ~f:(fun e -> Filename.chop_suffix_opt ~suffix:_snap_ext e)
      |> List.sort ~compare:String.compare
      |> Result.return

let _read_daily ~path =
  match Snapshot_columnar.with_reader ~path ~f:Snapshot_columnar.read_all with
  | Error e -> Error e
  | Ok rows -> Ok (List.map rows ~f:_bar_of_row)

let weekly_bars ~snapshot_dir ~symbol =
  let path = Filename.concat snapshot_dir (symbol ^ _snap_ext) in
  if not (Stdlib.Sys.file_exists path) then
    Status.error_not_found
      (Printf.sprintf "monster_scan: no snapshot panel at %s" path)
  else
    let open Result.Let_syntax in
    let%map daily = _read_daily ~path in
    if List.is_empty daily then [||]
    else
      List.map daily ~f:Snapshot_pipeline.Adjusted_basis.to_adjusted_basis
      |> Array.of_list
      |> Snapshot_pipeline.Weekly_prefix.build
      |> fun prefix -> prefix.Snapshot_pipeline.Weekly_prefix.finalized
