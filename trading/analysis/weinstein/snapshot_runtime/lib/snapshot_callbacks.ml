open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

type t = {
  read_field :
    symbol:string ->
    date:Core.Date.t ->
    field:Snapshot_schema.field ->
    float Status.status_or;
  read_field_history :
    symbol:string ->
    from:Core.Date.t ->
    until:Core.Date.t ->
    field:Snapshot_schema.field ->
    (Core.Date.t * float) list Status.status_or;
}

let _missing_field_error (snapshot : Snapshot.t) ~field =
  let message =
    Printf.sprintf "Snapshot_callbacks: field %s not in schema (hash=%s)"
      (Snapshot_schema.field_name field)
      snapshot.schema.schema_hash
  in
  Error { Status.code = Failed_precondition; message }

let _field_value_or_error (snapshot : Snapshot.t) ~field =
  match Snapshot.get snapshot field with
  | Some v -> Ok v
  | None -> _missing_field_error snapshot ~field

let _make_read_field panels ~symbol ~date ~field =
  let open Result.Let_syntax in
  let%bind snapshot = Daily_panels.read_today panels ~symbol ~date in
  _field_value_or_error snapshot ~field

let _row_field_pair (snapshot : Snapshot.t) ~field =
  Result.map (_field_value_or_error snapshot ~field) ~f:(fun v ->
      (snapshot.date, v))

let _make_read_field_history panels ~symbol ~from ~until ~field =
  let open Result.Let_syntax in
  let%bind rows = Daily_panels.read_history panels ~symbol ~from ~until in
  List.map rows ~f:(fun row -> _row_field_pair row ~field) |> Result.all

let of_daily_panels panels =
  {
    read_field = _make_read_field panels;
    read_field_history = _make_read_field_history panels;
  }
