open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_format = Data_panel_snapshot.Snapshot_format
module Snapshot_columnar = Data_panel_snapshot.Snapshot_columnar
module Snapshot_columnar_codec = Data_panel_snapshot.Snapshot_columnar_codec
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Width of one Float64 cell — a [Decoded] row's per-field byte cost. *)
let _bytes_per_float = 8

(* Width of one int32 date cell — the only mapped block an [Mmap] backing's
   byte estimate counts (the float columns are OS-page-cache resident). *)
let _bytes_per_date = 4

(* Per-row OCaml-heap overhead for a [Decoded] row (record header + symbol
   string + array header) beyond the raw float bytes. *)
let _per_row_overhead_bytes = 64

(* Fixed per-backing constant folded into every estimate. *)
let _per_backing_overhead_bytes = 128

(* Fixed [Mmap] handle cost: the open fd, reader record, header, and column
   bigarray descriptors. The mapped cells are NOT counted (page-cache
   resident). *)
let _per_mmap_handle_bytes = 256

type t = Mmap of Snapshot_columnar.reader | Decoded of Snapshot.t array

let is_mmap = function Mmap _ -> true | Decoded _ -> false

(* --- format detection ------------------------------------------------- *)

let _read_magic_prefix ic =
  let magic_len = String.length Snapshot_columnar_codec.magic in
  let buf = Bytes.create magic_len in
  match In_channel.really_input ic ~buf ~pos:0 ~len:magic_len with
  | Some () -> Some (Bytes.to_string buf)
  | None -> None

let is_columnar_file path =
  try
    let prefix = In_channel.with_file path ~f:_read_magic_prefix in
    Option.value_map prefix ~default:false
      ~f:(String.equal Snapshot_columnar_codec.magic)
  with _ -> false

(* --- loading ---------------------------------------------------------- *)

let _schema_skew_error ~file_hash ~expected_hash ~path =
  let message =
    Printf.sprintf "Daily_panels: schema hash skew (file=%s expected=%s) for %s"
      file_hash expected_hash path
  in
  Error Status.{ code = Failed_precondition; message }

(* Open a v2 file, gating on the schema hash; close the reader on skew. *)
let _load_mmap ~path ~(expected : Snapshot_schema.t) : t Status.status_or =
  let open Result.Let_syntax in
  let%bind reader = Snapshot_columnar.open_reader ~path in
  let file_hash = Snapshot_columnar.schema_hash reader in
  if String.equal file_hash expected.schema_hash then Ok (Mmap reader)
  else (
    Snapshot_columnar.close reader;
    _schema_skew_error ~file_hash ~expected_hash:expected.schema_hash ~path)

let _sort_by_date (rows : Snapshot.t array) =
  Array.sort rows ~compare:(fun (a : Snapshot.t) b ->
      Date.compare a.date b.date)

(* Decode a v1 sexp file into a sorted [Decoded] array. *)
let _load_decoded ~path ~expected : t Status.status_or =
  Result.map (Snapshot_format.read_with_expected_schema ~path ~expected)
    ~f:(fun rows_list ->
      let rows = Array.of_list rows_list in
      _sort_by_date rows;
      Decoded rows)

let load ~path ~expected =
  if is_columnar_file path then _load_mmap ~path ~expected
  else _load_decoded ~path ~expected

(* --- byte estimation -------------------------------------------------- *)

let _decoded_bytes ~(schema : Snapshot_schema.t) (rows : Snapshot.t array) =
  let n_rows = Array.length rows in
  let row_value_bytes = Snapshot_schema.n_fields schema * _bytes_per_float in
  _per_backing_overhead_bytes
  + (n_rows * (row_value_bytes + _per_row_overhead_bytes))

let _mmap_bytes ~n_rows =
  _per_backing_overhead_bytes + _per_mmap_handle_bytes
  + (n_rows * _bytes_per_date)

let estimate_bytes ~schema = function
  | Decoded rows -> _decoded_bytes ~schema rows
  | Mmap reader -> _mmap_bytes ~n_rows:(Snapshot_columnar.n_rows reader)

(* --- reads ------------------------------------------------------------ *)

let _not_found ~symbol ~date =
  Status.error_not_found
    (Printf.sprintf "Daily_panels.read_today: %s has no row for %s" symbol
       (Date.to_string date))

(* Comparator shape Core's [Array.binary_search] expects. *)
let _compare_row_date (r : Snapshot.t) (d : Date.t) = Date.compare r.date d

let _decoded_read_today rows ~symbol ~date =
  match
    Array.binary_search rows ~compare:_compare_row_date `First_equal_to date
  with
  | Some i -> Ok rows.(i)
  | None -> _not_found ~symbol ~date

let _mmap_read_today reader ~symbol ~date =
  let open Result.Let_syntax in
  let%bind rows = Snapshot_columnar.read_range reader ~from:date ~until:date in
  match rows with row :: _ -> Ok row | [] -> _not_found ~symbol ~date

let read_today b ~symbol ~date =
  match b with
  | Decoded rows -> _decoded_read_today rows ~symbol ~date
  | Mmap reader -> _mmap_read_today reader ~symbol ~date

(* Half-open [lo, hi) index range of [rows] within [[from, until]], clamped. *)
let _decoded_range rows ~from ~until =
  let n = Array.length rows in
  let lo =
    Array.binary_search rows ~compare:_compare_row_date
      `First_greater_than_or_equal_to from
    |> Option.value ~default:n
  in
  let hi =
    Array.binary_search rows ~compare:_compare_row_date
      `First_strictly_greater_than until
    |> Option.value ~default:n
  in
  (lo, hi)

(* The rows in [[from, until]] as a chronological list ([Ok []] when the range
   selects nothing). Pulled out so [_decoded_read_history]'s guard has no
   nested else. *)
let _decoded_slice rows ~from ~until =
  let lo, hi = _decoded_range rows ~from ~until in
  if hi <= lo then Ok []
  else Ok (Array.to_list (Array.sub rows ~pos:lo ~len:(hi - lo)))

let _decoded_read_history rows ~from ~until =
  if Date.( > ) from until || Array.is_empty rows then Ok []
  else _decoded_slice rows ~from ~until

let read_history b ~from ~until =
  match b with
  | Decoded rows -> _decoded_read_history rows ~from ~until
  | Mmap reader -> Snapshot_columnar.read_range reader ~from ~until

let close = function
  | Decoded _ -> ()
  | Mmap reader -> Snapshot_columnar.close reader
