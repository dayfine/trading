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
  (* The whole file mapped as ONE [Bigstring] (one VMA). [read_range] /
     [read_all] read cells out by computed byte offset rather than holding ~14
     per-column [Bigarray] views; cells page in on access, so untouched columns
     never fault. One VMA per reader keeps the count bounded under a high handle
     cap — the per-column scheme exhausted the Rosetta x86-64 translator's
     mapping bookkeeping in forked children. [close] then GC unmaps the file. *)
  mutable map : Core.Bigstring.t option;
  dates_off : int;
  cols_off : int;
}

let _check_magic bs =
  if String.equal (Bigstring.To_string.sub bs ~pos:0 ~len:C.magic_len) C.magic
  then Ok ()
  else Status.error_internal "Snapshot_columnar: bad magic / not a v2 file"

(* Decodes the header block out of the whole-file mapping [bs], returning the
   [Header.t] and the byte offset where the date block begins. The leading
   [magic] is validated by {!_check_magic} before this is called. *)
let _decode_header bs : (Header.t * int) Status.status_or =
  let header_len =
    Int32.to_int_exn (Bigstring.get_int32_t_le bs ~pos:C.magic_len)
  in
  let hbuf =
    Bigstring.To_string.sub bs
      ~pos:(C.magic_len + C.int32_bytes)
      ~len:header_len
    |> Bytes.of_string
  in
  let header = Header.of_bytes hbuf in
  Ok (header, C.magic_len + C.int32_bytes + header_len)

let _check_version (header : Header.t) =
  if header.format_version <> C.format_version then
    Status.error_internal
      (Printf.sprintf "Snapshot_columnar: unsupported format_version %d"
         header.format_version)
  else Ok ()

(* Maps the whole file as one [Bigstring], or [Error Internal] if it is too
   short to even hold the magic + length prefix (so we never [map_file] a
   0-byte / truncated file). *)
let _map_whole_file fd : Core.Bigstring.t Status.status_or =
  let size = (Core_unix.fstat fd).st_size |> Int64.to_int_exn in
  if size < C.magic_len + C.int32_bytes then
    Status.error_internal "Snapshot_columnar: bad magic / file too short"
  else Ok (Bigstring_unix.map_file ~shared:false fd size)

let _build_reader fd (bs : Core.Bigstring.t) (header : Header.t) ~dates_off :
    reader =
  let n = header.n_rows in
  let cols_off = dates_off + (n * C.int32_bytes) in
  (* The header stores only [schema_hash] + [n_fields], not the ordered field
     list, so reconstruction uses the canonical [Snapshot_schema.default];
     [read_all] / [read_range] gate on [schema_hash = default.hash] first
     (see [_check_reconstructable]), so a foreign field order fails loudly. *)
  {
    fd = Some fd;
    header;
    schema = Snapshot_schema.default;
    map = Some bs;
    dates_off;
    cols_off;
  }

let open_reader ~path =
  let open Result.Let_syntax in
  try
    let fd = Core_unix.openfile path ~mode:[ Core_unix.O_RDONLY ] in
    match
      let%bind bs = _map_whole_file fd in
      let%bind () = _check_magic bs in
      let%bind header, dates_off = _decode_header bs in
      let%bind () = _check_version header in
      Ok (_build_reader fd bs header ~dates_off)
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
      (* Drop the whole-file mapping so the GC can unmap it; [None] keeps the
         field well-typed without holding any mapping. *)
      r.map <- None;
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

(* Reconstructs the single row at index [i] by reading each cell out of the
   whole-file mapping [bs] at its computed byte offset. *)
let _row_at (r : reader) bs ~n_fields ~n_rows i =
  let date = C.epoch_days_to_date (C.get_date bs ~dates_off:r.dates_off ~i) in
  let values =
    Array.init n_fields ~f:(fun col ->
        C.get_cell bs ~cols_off:r.cols_off ~n_rows ~col ~i)
  in
  Snapshot.create ~schema:r.schema ~symbol:r.header.symbol ~date ~values

(* The live whole-file mapping, or [Error Internal] if the reader is closed. *)
let _live_map (r : reader) : Core.Bigstring.t Status.status_or =
  match r.map with
  | Some bs -> Ok bs
  | None -> Status.error_internal "Snapshot_columnar: reader is closed"

(* Reconstructs the rows in [[lo, hi)] (0-based, half-open), chronological.
   Reads cells out of the single whole-file mapping — no per-call re-mapping. *)
let _reconstruct_rows (r : reader) ~lo ~hi : Snapshot.t list Status.status_or =
  let open Result.Let_syntax in
  let%bind bs = _live_map r in
  let n_fields = r.header.n_fields and n_rows = r.header.n_rows in
  List.init (hi - lo) ~f:(fun k -> _row_at r bs ~n_fields ~n_rows (lo + k))
  |> Result.all

let read_all r =
  let open Result.Let_syntax in
  let%bind () = _check_reconstructable r in
  _reconstruct_rows r ~lo:0 ~hi:r.header.n_rows

(* ----- range prune ------------------------------------------------------- *)

let read_range r ~from ~until =
  let open Result.Let_syntax in
  let%bind () = _check_reconstructable r in
  let%bind bs = _live_map r in
  let n = r.header.n_rows in
  let from_days = C.date_to_epoch_days from in
  let until_days = C.date_to_epoch_days until in
  if until_days < from_days then Ok []
  else
    let bound target = C.lower_bound bs ~dates_off:r.dates_off ~n ~target in
    let lo = bound from_days in
    (* exclusive upper bound = lower_bound of (until + 1) *)
    let hi = bound (until_days + 1) in
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
