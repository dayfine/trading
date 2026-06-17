open Core
module C = Snapshot_columnar_codec
module Header = C.Header

(* Writer / reader / row-reconstruction for the columnar mmap format. The
   byte-encoding + mmap primitives live in {!Snapshot_columnar_codec}; see the
   .mli for the on-disk layout and the zero-copy range-prune rationale. *)

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

let _header_for ~(schema : Snapshot_schema.t) ~symbol ~n_rows : Header.t =
  {
    format_version = C.format_version;
    n_rows;
    n_fields = Snapshot_schema.n_fields schema;
    schema_hash = schema.schema_hash;
    symbol;
  }

let _header_of_rows (sorted : Snapshot.t list) : Header.t =
  let n_rows = List.length sorted in
  match sorted with
  | (first : Snapshot.t) :: _ ->
      _header_for ~schema:first.schema ~symbol:first.symbol ~n_rows
  | [] -> _header_for ~schema:Snapshot_schema.default ~symbol:"" ~n_rows:0

(* Encodes the sorted date column as raw int32-LE bytes. *)
let _dates_to_bytes (sorted : Snapshot.t list) : Bytes.t =
  let n = List.length sorted in
  let b = Stdlib.Bytes.create (n * C.int32_bytes) in
  List.iteri sorted ~f:(fun i (s : Snapshot.t) ->
      let days = Int32.of_int_exn (C.date_to_epoch_days s.date) in
      Stdlib.Bytes.set_int32_le b (i * C.int32_bytes) days);
  b

(* Encodes column [c] (one float64-LE block) across all rows. *)
let _column_to_bytes (rows : Snapshot.t array) ~col : Bytes.t =
  let n = Array.length rows in
  let b = Stdlib.Bytes.create (n * C.float64_bytes) in
  Array.iteri rows ~f:(fun i (s : Snapshot.t) ->
      let bits = Int64.bits_of_float s.values.(col) in
      Stdlib.Bytes.set_int64_le b (i * C.float64_bytes) bits);
  b

let _write_all_columns oc (rows : Snapshot.t array) ~n_fields =
  for col = 0 to n_fields - 1 do
    Out_channel.output_bytes oc (_column_to_bytes rows ~col)
  done

let _flush_file oc (sorted : Snapshot.t list) (header : Header.t) =
  let header_bytes = Header.to_bytes header in
  let len_prefix = Stdlib.Bytes.create C.int32_bytes in
  Stdlib.Bytes.set_int32_le len_prefix 0
    (Int32.of_int_exn (Bytes.length header_bytes));
  Out_channel.output_string oc C.magic;
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

let _by_date (a : Snapshot.t) (b : Snapshot.t) = Date.compare a.date b.date

let write ~path snapshots =
  match _validate snapshots with
  | Error _ as e -> e
  | Ok () ->
      let sorted = List.sort snapshots ~compare:_by_date in
      _try_write ~path sorted (_header_of_rows sorted)

(* ----- reader ----------------------------------------------------------- *)

type reader = {
  mutable fd : Core_unix.File_descr.t option;
  header : Header.t;
  schema : Snapshot_schema.t;
  dates : C.dates_arr;
  (* All [n_fields] float64 column blocks, mapped once at [open_reader] as
     zero-copy views. [read_range] / [read_all] slice these rather than
     re-mapping per call (which, under a high read rate, would create
     unbounded transient mappings). The OCaml-heap cost is one bigarray
     descriptor per column; the cells live in the OS page cache and only page
     in on access, so untouched columns never fault. Dropping the reader (via
     [close] then GC) unmaps them. *)
  mutable cols : C.col_arr array;
}

(* Reads exactly [len] bytes from [fd]; [Error Internal what] on a short read. *)
let _read_exact fd ~len ~what : Bytes.t Status.status_or =
  let buf = Stdlib.Bytes.create len in
  let n = Core_unix.read fd ~buf ~pos:0 ~len in
  if n < len then
    Status.error_internal (Printf.sprintf "Snapshot_columnar: %s" what)
  else Ok buf

let _check_magic prefix =
  if String.equal (Stdlib.Bytes.sub_string prefix 0 C.magic_len) C.magic then
    Ok ()
  else Status.error_internal "Snapshot_columnar: bad magic / not a v2 file"

(* Reads the [magic] + [header_len] prefix and the header block, returning the
   decoded [Header.t] and the byte offset where the date block begins. *)
let _read_header fd : (Header.t * int) Status.status_or =
  let open Result.Let_syntax in
  let prefix_len = C.magic_len + C.int32_bytes in
  let%bind prefix =
    _read_exact fd ~len:prefix_len ~what:"file too short for header"
  in
  let%bind () = _check_magic prefix in
  let header_len =
    Int32.to_int_exn (Stdlib.Bytes.get_int32_le prefix C.magic_len)
  in
  let%bind hbuf = _read_exact fd ~len:header_len ~what:"truncated header" in
  Ok (Header.of_bytes hbuf, prefix_len + header_len)

let _check_version (header : Header.t) =
  if header.format_version <> C.format_version then
    Status.error_internal
      (Printf.sprintf "Snapshot_columnar: unsupported format_version %d"
         header.format_version)
  else Ok ()

(* Maps all [n_fields] column blocks as zero-copy views, once at open time. *)
let _map_all_cols fd ~cols_byte_pos ~n ~n_fields : C.col_arr array =
  Array.init n_fields ~f:(fun c ->
      C.map_col fd
        ~byte_pos:(cols_byte_pos + (c * n * C.float64_bytes))
        ~n_rows:n)

let _build_reader fd (header : Header.t) ~dates_byte_pos : reader =
  let n = header.n_rows in
  let dates = C.map_dates fd ~byte_pos:dates_byte_pos ~n_rows:n in
  let cols_byte_pos = dates_byte_pos + (n * C.int32_bytes) in
  let cols = _map_all_cols fd ~cols_byte_pos ~n ~n_fields:header.n_fields in
  (* The header stores only [schema_hash] + [n_fields], not the ordered field
     list, so row reconstruction uses the canonical [Snapshot_schema.default].
     [read_all] / [read_range] gate on [header.schema_hash = default.hash]
     before reconstructing, so a file under any other field order fails loudly
     rather than reconstructing rows under the wrong schema. *)
  { fd = Some fd; header; schema = Snapshot_schema.default; dates; cols }

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
      (* Drop the mapped column views so the GC can unmap them; the empty array
         keeps the field well-typed without holding any mapping. *)
      r.cols <- [||];
      try Core_unix.close fd with _ -> ())

let with_reader ~path ~f =
  match open_reader ~path with
  | Error _ as e -> e
  | Ok r -> Exn.protect ~f:(fun () -> f r) ~finally:(fun () -> close r)

(* ----- header accessors ------------------------------------------------- *)

let schema_hash r = r.header.schema_hash
let symbol r = r.header.symbol
let n_rows r = r.header.n_rows

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

(* Reconstructs the single row at index [i] from the held mapped columns. *)
let _row_at (r : reader) ~n_fields i =
  let date = C.epoch_days_to_date (Int32.to_int_exn r.dates.{i}) in
  let values = Array.init n_fields ~f:(fun c -> r.cols.(c).{i}) in
  Snapshot.create ~schema:r.schema ~symbol:r.header.symbol ~date ~values

(* Reconstructs the rows in [[lo, hi)] (0-based, half-open), chronological.
   Slices the columns mapped once at [open_reader] — no per-call re-mapping. *)
let _reconstruct_rows (r : reader) ~lo ~hi : Snapshot.t list Status.status_or =
  match r.fd with
  | None -> Status.error_internal "Snapshot_columnar: reader is closed"
  | Some _ ->
      let n_fields = r.header.n_fields in
      List.init (hi - lo) ~f:(fun k -> _row_at r ~n_fields (lo + k))
      |> Result.all

let read_all r =
  let open Result.Let_syntax in
  let%bind () = _check_reconstructable r in
  _reconstruct_rows r ~lo:0 ~hi:r.header.n_rows

(* ----- range prune ------------------------------------------------------- *)

let read_range r ~from ~until =
  let open Result.Let_syntax in
  let%bind () = _check_reconstructable r in
  let n = r.header.n_rows in
  let from_days = C.date_to_epoch_days from in
  let until_days = C.date_to_epoch_days until in
  if until_days < from_days then Ok []
  else
    let lo = C.lower_bound r.dates ~n ~target:from_days in
    (* exclusive upper bound = lower_bound of (until + 1) *)
    let hi = C.lower_bound r.dates ~n ~target:(until_days + 1) in
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

let _read_checked r ~expected_hash =
  let open Result.Let_syntax in
  let%bind () =
    _check_schema_hash ~file_hash:r.header.schema_hash ~expected_hash
  in
  read_all r

let read_with_expected_schema ~path ~(expected : Snapshot_schema.t) =
  with_reader ~path ~f:(fun r ->
      _read_checked r ~expected_hash:expected.schema_hash)
