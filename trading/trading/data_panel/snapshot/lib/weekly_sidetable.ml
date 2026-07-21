open Core
module C = Snapshot_columnar_codec

(* Fixed-width little-endian binary codec for the sparse weekly side-table. See
   the .mli for the on-disk layout + semantics. Reuses the epoch-days + width
   constants from {!Snapshot_columnar_codec} so [.weekly] and [.snap] agree on
   how a [Date.t] and a [float64] serialize. *)

type entry = { week_end_date : Date.t; mid : float; high : float }
[@@deriving sexp, compare, equal]

let magic = "WKSIDE01"
let magic_len = 8
let format_version = 1

(* magic + format_version(int32) + count(int32). *)
let header_bytes = magic_len + C.int32_bytes + C.int32_bytes

(* week_end_date(int32) + mid(float64) + high(float64). *)
let entry_bytes = C.int32_bytes + C.float64_bytes + C.float64_bytes
let _count_off = magic_len + C.int32_bytes
let _mid_off = C.int32_bytes
let _high_off = C.int32_bytes + C.float64_bytes

let format_hash =
  Printf.sprintf "%s/v%d" magic format_version
  |> Stdlib.Digest.string |> Stdlib.Digest.to_hex

(* ----- byte helpers ----------------------------------------------------- *)

let _put_int32 b ~pos v = Stdlib.Bytes.set_int32_le b pos (Int32.of_int_exn v)

let _put_float64 b ~pos f =
  Stdlib.Bytes.set_int64_le b pos (Int64.bits_of_float f)

let _get_int32 b ~pos = Int32.to_int_exn (Stdlib.Bytes.get_int32_le b pos)
let _get_float64 b ~pos = Int64.float_of_bits (Stdlib.Bytes.get_int64_le b pos)

(* ----- encode ----------------------------------------------------------- *)

let _put_entry b ~i (e : entry) =
  let off = header_bytes + (i * entry_bytes) in
  _put_int32 b ~pos:off (C.date_to_epoch_days e.week_end_date);
  _put_float64 b ~pos:(off + _mid_off) e.mid;
  _put_float64 b ~pos:(off + _high_off) e.high

let encode (entries : entry list) : bytes =
  let n = List.length entries in
  let b = Stdlib.Bytes.create (header_bytes + (n * entry_bytes)) in
  Stdlib.Bytes.blit_string magic 0 b 0 magic_len;
  _put_int32 b ~pos:magic_len format_version;
  _put_int32 b ~pos:_count_off n;
  List.iteri entries ~f:(fun i e -> _put_entry b ~i e);
  b

(* ----- decode ----------------------------------------------------------- *)

let _check_magic b =
  if String.equal (Stdlib.Bytes.sub_string b 0 magic_len) magic then Ok ()
  else Status.error_internal "Weekly_sidetable.decode: bad magic"

let _check_version b =
  let v = _get_int32 b ~pos:magic_len in
  if v = format_version then Ok ()
  else
    Status.error_internal
      (Printf.sprintf "Weekly_sidetable.decode: unsupported format_version %d" v)

let _check_count count =
  if count >= 0 then Ok ()
  else
    Status.error_internal
      (Printf.sprintf "Weekly_sidetable.decode: negative count %d" count)

let _check_length b ~count =
  let expected = header_bytes + (count * entry_bytes) in
  if Bytes.length b = expected then Ok ()
  else
    Status.error_internal
      (Printf.sprintf
         "Weekly_sidetable.decode: length %d <> expected %d (count=%d)"
         (Bytes.length b) expected count)

let _decode_entry b i : entry =
  let off = header_bytes + (i * entry_bytes) in
  {
    week_end_date = C.epoch_days_to_date (_get_int32 b ~pos:off);
    mid = _get_float64 b ~pos:(off + _mid_off);
    high = _get_float64 b ~pos:(off + _high_off);
  }

let decode (b : bytes) : entry list Status.status_or =
  let open Result.Let_syntax in
  if Bytes.length b < header_bytes then
    Status.error_internal "Weekly_sidetable.decode: file shorter than header"
  else
    let%bind () = _check_magic b in
    let%bind () = _check_version b in
    let count = _get_int32 b ~pos:_count_off in
    let%bind () = _check_count count in
    let%bind () = _check_length b ~count in
    Ok (List.init count ~f:(_decode_entry b))

(* ----- file IO ---------------------------------------------------------- *)

let write_file ~path entries =
  try
    Out_channel.write_all path ~data:(Bytes.to_string (encode entries));
    Ok ()
  with Sys_error msg | Failure msg ->
    Status.error_internal (Printf.sprintf "Weekly_sidetable.write_file: %s" msg)

let read_file ~path =
  match
    try Ok (In_channel.read_all path)
    with Sys_error msg | Failure msg ->
      Status.error_internal
        (Printf.sprintf "Weekly_sidetable.read_file: %s" msg)
  with
  | Error _ as e -> e
  | Ok s -> decode (Bytes.of_string s)
