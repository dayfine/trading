open Core

(* Low-level byte/mmap layer for the columnar format. See the .mli + the
   Snapshot_columnar docstring for the on-disk layout. *)

let magic = "SNAPCOL1"
let magic_len = 8
let format_version = 1
let int32_bytes = 4
let float64_bytes = 8

(* The 1970-01-01 epoch the date column is measured against. *)
let epoch = Date.create_exn ~y:1970 ~m:Month.Jan ~d:1
let date_to_epoch_days d = Date.diff d epoch
let epoch_days_to_date days = Date.add_days epoch days

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

type dates_arr =
  (int32, Bigarray.int32_elt, Bigarray.c_layout) Bigarray.Array1.t

type col_arr =
  (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array1.t

let map_col fd ~byte_pos ~n_rows : col_arr =
  let g =
    Core_unix.map_file fd ~pos:(Int64.of_int byte_pos) Bigarray.float64
      Bigarray.c_layout ~shared:false [| n_rows |]
  in
  Bigarray.array1_of_genarray g

let map_dates fd ~byte_pos ~n_rows : dates_arr =
  let g =
    Core_unix.map_file fd ~pos:(Int64.of_int byte_pos) Bigarray.int32
      Bigarray.c_layout ~shared:false [| n_rows |]
  in
  Bigarray.array1_of_genarray g

let lower_bound (dates : dates_arr) ~n ~target =
  let lo = ref 0 and hi = ref n in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if Int32.to_int_exn dates.{mid} < target then lo := mid + 1 else hi := mid
  done;
  !lo
