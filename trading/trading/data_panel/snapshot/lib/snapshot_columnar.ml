open Core

(* Little-endian columnar mmap format. See the .mli for the on-disk layout and
   the rationale (zero-copy range/column prune via [Core_unix.map_file]). *)

let magic = "SNAPCOL1"
let magic_len = 8
let format_version = 1
let int32_bytes = 4
let float64_bytes = 8

(* The 1970-01-01 epoch the date column is measured against. A [Core.Date.t] is
   stored as [int32] days since this epoch; both [Date.diff]/[Date.add_days] are
   exact pure-day arithmetic, so the round-trip is exact. *)
let epoch = Date.create_exn ~y:1970 ~m:Month.Jan ~d:1
let date_to_epoch_days d = Date.diff d epoch
let epoch_days_to_date days = Date.add_days epoch days

(* Header written after the [magic] + [header_len] prefix, kept separate from
   the raw column blocks so the payload stays mmap-able. Encoded with a small
   hand-rolled little-endian scheme (no [bin_prot] ppx dependency): three int32
   scalars followed by two length-prefixed strings. *)
module Header = struct
  type t = {
    format_version : int;
    n_rows : int;
    n_fields : int;
    schema_hash : string;
    symbol : string;
  }

  (* Appends a 4-byte LE length prefix + the raw string bytes to [buf]. *)
  let _add_string buf s =
    let len_b = Stdlib.Bytes.create int32_bytes in
    Stdlib.Bytes.set_int32_le len_b 0 (Int32.of_int_exn (String.length s));
    Buffer.add_bytes buf len_b;
    Buffer.add_string buf s

  let _add_int32 buf v =
    let b = Stdlib.Bytes.create int32_bytes in
    Stdlib.Bytes.set_int32_le b 0 (Int32.of_int_exn v);
    Buffer.add_bytes buf b

  let to_bytes (t : t) : Bytes.t =
    let buf = Buffer.create 64 in
    _add_int32 buf t.format_version;
    _add_int32 buf t.n_rows;
    _add_int32 buf t.n_fields;
    _add_string buf t.schema_hash;
    _add_string buf t.symbol;
    Buffer.contents buf |> Bytes.of_string

  (* A cursor over [b]; each [_take_*] advances [pos]. *)
  let _take_int32 b pos =
    let v = Int32.to_int_exn (Stdlib.Bytes.get_int32_le b !pos) in
    pos := !pos + int32_bytes;
    v

  let _take_string b pos =
    let len = _take_int32 b pos in
    let s = Stdlib.Bytes.sub_string b !pos len in
    pos := !pos + len;
    s

  let of_bytes (b : Bytes.t) : t =
    let pos = ref 0 in
    let format_version = _take_int32 b pos in
    let n_rows = _take_int32 b pos in
    let n_fields = _take_int32 b pos in
    let schema_hash = _take_string b pos in
    let symbol = _take_string b pos in
    { format_version; n_rows; n_fields; schema_hash; symbol }
end

(* ----- writer ----------------------------------------------------------- *)

(* [Error Invalid_argument] if any row's schema hash differs from [h]. *)
let _check_all_hashes_equal h (rest : Snapshot.t list) =
  match
    List.find rest ~f:(fun s -> not (String.equal s.schema.schema_hash h))
  with
  | None -> Ok ()
  | Some bad ->
      Status.error_invalid_argument
        (Printf.sprintf
           "Snapshot_columnar.write: mixed schema hashes (%s vs %s)" h
           bad.schema.schema_hash)

(* [Error Invalid_argument] if any row's symbol differs from [sym]. *)
let _check_all_symbols_equal sym (rest : Snapshot.t list) =
  match List.find rest ~f:(fun s -> not (String.equal s.symbol sym)) with
  | None -> Ok ()
  | Some bad ->
      Status.error_invalid_argument
        (Printf.sprintf "Snapshot_columnar.write: mixed symbols (%s vs %s)" sym
           bad.symbol)

let _validate (snapshots : Snapshot.t list) =
  match snapshots with
  | [] -> Ok ()
  | first :: rest ->
      let open Result.Let_syntax in
      let%bind () = _check_all_hashes_equal first.schema.schema_hash rest in
      _check_all_symbols_equal first.symbol rest

let _header_of_rows (sorted : Snapshot.t list) : Header.t =
  match sorted with
  | (first : Snapshot.t) :: _ ->
      {
        format_version;
        n_rows = List.length sorted;
        n_fields = Snapshot_schema.n_fields first.schema;
        schema_hash = first.schema.schema_hash;
        symbol = first.symbol;
      }
  | [] ->
      {
        format_version;
        n_rows = 0;
        n_fields = Snapshot_schema.n_fields Snapshot_schema.default;
        schema_hash = Snapshot_schema.default.schema_hash;
        symbol = "";
      }

(* Encodes the sorted date column as raw int32-LE bytes. *)
let _dates_to_bytes (sorted : Snapshot.t list) : Bytes.t =
  let n = List.length sorted in
  let b = Stdlib.Bytes.create (n * int32_bytes) in
  List.iteri sorted ~f:(fun i (s : Snapshot.t) ->
      let days = Int32.of_int_exn (date_to_epoch_days s.date) in
      Stdlib.Bytes.set_int32_le b (i * int32_bytes) days);
  b

(* Encodes column [c] (one float64-LE block) across all rows. *)
let _column_to_bytes (rows : Snapshot.t array) ~col : Bytes.t =
  let n = Array.length rows in
  let b = Stdlib.Bytes.create (n * float64_bytes) in
  Array.iteri rows ~f:(fun i (s : Snapshot.t) ->
      let bits = Int64.bits_of_float s.values.(col) in
      Stdlib.Bytes.set_int64_le b (i * float64_bytes) bits);
  b

let _write_all_columns oc (rows : Snapshot.t array) ~n_fields =
  for col = 0 to n_fields - 1 do
    Out_channel.output_bytes oc (_column_to_bytes rows ~col)
  done

let _flush_file oc (sorted : Snapshot.t list) (header : Header.t) =
  let header_bytes = Header.to_bytes header in
  let len_prefix = Stdlib.Bytes.create int32_bytes in
  Stdlib.Bytes.set_int32_le len_prefix 0
    (Int32.of_int_exn (Bytes.length header_bytes));
  Out_channel.output_string oc magic;
  Out_channel.output_bytes oc len_prefix;
  Out_channel.output_bytes oc header_bytes;
  Out_channel.output_bytes oc (_dates_to_bytes sorted);
  _write_all_columns oc (Array.of_list sorted) ~n_fields:header.n_fields

let _try_write ~path sorted header =
  try
    Out_channel.with_file path ~f:(fun oc -> _flush_file oc sorted header);
    Ok ()
  with Sys_error msg | Failure msg ->
    Status.error_internal (Printf.sprintf "Snapshot_columnar.write: %s" msg)

let write ~path snapshots =
  match _validate snapshots with
  | Error _ as e -> e
  | Ok () ->
      let sorted =
        List.sort snapshots ~compare:(fun (a : Snapshot.t) (b : Snapshot.t) ->
            Date.compare a.date b.date)
      in
      _try_write ~path sorted (_header_of_rows sorted)

(* ----- reader ----------------------------------------------------------- *)

type dates_arr =
  (int32, Bigarray.int32_elt, Bigarray.c_layout) Bigarray.Array1.t

type col_arr =
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t

type reader = {
  mutable fd : Core_unix.File_descr.t option;
  header : Header.t;
  schema : Snapshot_schema.t;
  dates : dates_arr;
  (* Byte offset of [col_0] (the first float64 column block) in the file. *)
  cols_byte_pos : int;
}

(* Maps a float64 column block of [n_rows] at [byte_pos]. *)
let _map_col fd ~byte_pos ~n_rows : col_arr =
  let g =
    Core_unix.map_file fd ~pos:(Int64.of_int byte_pos) Bigarray.float64
      Bigarray.c_layout ~shared:false [| n_rows |]
  in
  Bigarray.array1_of_genarray g

let _map_dates fd ~byte_pos ~n_rows : dates_arr =
  let g =
    Core_unix.map_file fd ~pos:(Int64.of_int byte_pos) Bigarray.int32
      Bigarray.c_layout ~shared:false [| n_rows |]
  in
  Bigarray.array1_of_genarray g

(* Reads the [magic] + [header_len] prefix and the header block, returning the
   decoded [Header.t] and the byte offset where the date block begins. *)
let _read_header fd : (Header.t * int) Status.status_or =
  let prefix_len = magic_len + int32_bytes in
  let prefix = Stdlib.Bytes.create prefix_len in
  let n = Core_unix.read fd ~buf:prefix ~pos:0 ~len:prefix_len in
  if n < prefix_len then
    Status.error_internal "Snapshot_columnar: file too short for header"
  else if not (String.equal (Stdlib.Bytes.sub_string prefix 0 magic_len) magic)
  then Status.error_internal "Snapshot_columnar: bad magic / not a v2 file"
  else
    let header_len =
      Int32.to_int_exn (Stdlib.Bytes.get_int32_le prefix magic_len)
    in
    let hbuf = Stdlib.Bytes.create header_len in
    let hn = Core_unix.read fd ~buf:hbuf ~pos:0 ~len:header_len in
    if hn < header_len then
      Status.error_internal "Snapshot_columnar: truncated header"
    else Ok (Header.of_bytes hbuf, prefix_len + header_len)

let _check_version (header : Header.t) =
  if header.format_version <> format_version then
    Status.error_internal
      (Printf.sprintf "Snapshot_columnar: unsupported format_version %d"
         header.format_version)
  else Ok ()

let _build_reader fd (header : Header.t) ~dates_byte_pos : reader =
  let n = header.n_rows in
  let dates = _map_dates fd ~byte_pos:dates_byte_pos ~n_rows:n in
  let cols_byte_pos = dates_byte_pos + (n * int32_bytes) in
  (* The header stores only [schema_hash] + [n_fields], not the ordered field
     list, so row reconstruction uses the canonical [Snapshot_schema.default].
     [read_all] / [read_range] gate on [header.schema_hash = default.hash]
     before reconstructing, so a file under any other field order fails loudly
     rather than reconstructing rows under the wrong schema. *)
  {
    fd = Some fd;
    header;
    schema = Snapshot_schema.default;
    dates;
    cols_byte_pos;
  }

let open_reader ~path =
  let open Result.Let_syntax in
  try
    let fd = Core_unix.openfile path ~mode:[ Core_unix.O_RDONLY ] in
    match
      let%bind header, dates_byte_pos = _read_header fd in
      let%bind () = _check_version header in
      Ok (_build_reader fd header ~dates_byte_pos)
    with
    | Ok r -> Ok r
    | Error _ as e ->
        (try Core_unix.close fd with _ -> ());
        e
  with exn ->
    Status.error_internal
      (Printf.sprintf "Snapshot_columnar.open_reader: %s" (Exn.to_string exn))

let close r =
  match r.fd with
  | None -> ()
  | Some fd -> (
      r.fd <- None;
      try Core_unix.close fd with _ -> ())

let with_reader ~path ~f =
  match open_reader ~path with
  | Error _ as e -> e
  | Ok r -> Exn.protect ~f:(fun () -> f r) ~finally:(fun () -> close r)

(* ----- row reconstruction ----------------------------------------------- *)

(* [Error Internal] unless the file's schema hash is the canonical default — the
   only field order [_reconstruct_rows] knows how to rebuild. *)
let _check_reconstructable (r : reader) =
  if String.equal r.header.schema_hash Snapshot_schema.default.schema_hash then
    Ok ()
  else
    Status.error_internal
      (Printf.sprintf
         "Snapshot_columnar: file schema hash %s is not the canonical default \
          %s; cannot reconstruct rows"
         r.header.schema_hash Snapshot_schema.default.schema_hash)

(* Maps every column block and reconstructs the rows in [[lo, hi)] (0-based,
   half-open) into [Snapshot.t list], chronological. *)
let _reconstruct_rows (r : reader) ~lo ~hi : Snapshot.t list Status.status_or =
  match r.fd with
  | None -> Status.error_internal "Snapshot_columnar: reader is closed"
  | Some fd ->
      let n = r.header.n_rows in
      let n_fields = r.header.n_fields in
      let cols =
        Array.init n_fields ~f:(fun c ->
            _map_col fd
              ~byte_pos:(r.cols_byte_pos + (c * n * float64_bytes))
              ~n_rows:n)
      in
      let rows =
        List.init (hi - lo) ~f:(fun k ->
            let i = lo + k in
            let date = epoch_days_to_date (Int32.to_int_exn r.dates.{i}) in
            let values = Array.init n_fields ~f:(fun c -> cols.(c).{i}) in
            Snapshot.create ~schema:r.schema ~symbol:r.header.symbol ~date
              ~values)
      in
      Result.all rows

let read_all r =
  let open Result.Let_syntax in
  let%bind () = _check_reconstructable r in
  _reconstruct_rows r ~lo:0 ~hi:r.header.n_rows

(* ----- range prune ------------------------------------------------------- *)

(* First index [i] in the sorted date column with [dates.{i} >= target], in
   [[0, n]]. Standard lower-bound binary search. *)
let _lower_bound (dates : dates_arr) ~n ~target =
  let lo = ref 0 and hi = ref n in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if Int32.to_int_exn dates.{mid} < target then lo := mid + 1 else hi := mid
  done;
  !lo

let read_range r ~from ~until =
  let open Result.Let_syntax in
  let%bind () = _check_reconstructable r in
  let n = r.header.n_rows in
  let from_days = date_to_epoch_days from in
  let until_days = date_to_epoch_days until in
  if until_days < from_days then Ok []
  else
    let lo = _lower_bound r.dates ~n ~target:from_days in
    (* exclusive upper bound = lower_bound of (until + 1) *)
    let hi = _lower_bound r.dates ~n ~target:(until_days + 1) in
    if lo >= hi then Ok [] else _reconstruct_rows r ~lo ~hi

(* ----- schema-gated whole-file read ------------------------------------- *)

let _check_schema_hash ~file_hash ~expected_hash =
  if String.equal file_hash expected_hash then Ok ()
  else
    let msg =
      Printf.sprintf
        "Snapshot_columnar.read_with_expected_schema: schema hash skew \
         (file=%s expected=%s)"
        file_hash expected_hash
    in
    Error Status.{ code = Failed_precondition; message = msg }

let read_with_expected_schema ~path ~(expected : Snapshot_schema.t) =
  with_reader ~path ~f:(fun r ->
      let open Result.Let_syntax in
      let%bind () =
        _check_schema_hash ~file_hash:r.header.schema_hash
          ~expected_hash:expected.schema_hash
      in
      read_all r)
