open Core
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Snap = Data_panel_snapshot.Snapshot

let _get row field = Option.value (Snap.get row field) ~default:Float.nan

(* Snap [Volume] cells are float64; [Daily_price.volume] is an int. Mirrors
   [Sidetable_migrator]'s [_volume_of]. *)
let _volume_of v = if Float.is_nan v then 0 else Float.to_int v

let _bar_of_row (row : Snap.t) : Types.Daily_price.t =
  Types.Daily_price.make ~date:row.Snap.date
    ~open_price:(_get row Snapshot_schema.Open)
    ~high_price:(_get row Snapshot_schema.High)
    ~low_price:(_get row Snapshot_schema.Low)
    ~close_price:(_get row Snapshot_schema.Close)
    ~volume:(_volume_of (_get row Snapshot_schema.Volume))
    ~adjusted_close:(_get row Snapshot_schema.Adjusted_close)
    ()

let _snap_path ~dir ~symbol = Filename.concat dir (symbol ^ ".snap")

let _load_from_warehouse ~symbol ~dir : Types.Daily_price.t list option =
  let path = _snap_path ~dir ~symbol in
  if not (Stdlib.Sys.file_exists path) then None
  else
    match Snapshot_columnar.with_reader ~path ~f:Snapshot_columnar.read_all with
    | Error _ -> None
    | Ok rows -> Some (List.map rows ~f:_bar_of_row)

let _load_from_csv ~symbol ~dir : Types.Daily_price.t list option =
  match Csv.Csv_storage.create ~data_dir:(Fpath.v dir) symbol with
  | Error _ -> None
  | Ok storage -> (
      match Csv.Csv_storage.get storage () with
      | Error _ -> None
      | Ok bars -> Some bars)

type source = Warehouse | Csv

(* [None] on an absent source, an unreadable one, or one that decoded to an
   empty bar list -- all three should fall through to the next source. *)
let _nonempty = function
  | Some bars when not (List.is_empty bars) -> Some bars
  | _ -> None

let load_daily ~symbol ~warehouse_dir ~csv_data_dir :
    (Types.Daily_price.t list * source) Status.status_or =
  let from_warehouse =
    Option.bind warehouse_dir ~f:(fun dir -> _load_from_warehouse ~symbol ~dir)
    |> _nonempty
    |> Option.map ~f:(fun bars -> (bars, Warehouse))
  in
  let from_csv () =
    Option.bind csv_data_dir ~f:(fun dir -> _load_from_csv ~symbol ~dir)
    |> _nonempty
    |> Option.map ~f:(fun bars -> (bars, Csv))
  in
  match Option.first_some from_warehouse (from_csv ()) with
  | Some result -> Ok result
  | None ->
      Status.error_not_found
        (Printf.sprintf "no daily bars for %s in warehouse or CSV store" symbol)

let load_weekly ~symbol ~warehouse_dir ~csv_data_dir :
    (Types.Daily_price.t list * source) Status.status_or =
  let open Result.Let_syntax in
  let%map daily, source = load_daily ~symbol ~warehouse_dir ~csv_data_dir in
  ( Time_period.Conversion.daily_to_weekly ~include_partial_week:true daily,
    source )
