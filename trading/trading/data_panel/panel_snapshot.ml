open Core
module BA = Bigarray
module BA2 = Bigarray.Array2

type panel = (float, BA.float64_elt, BA.c_layout) BA2.t

(* On-disk header. Stored as ASCII sexp, prefixed by an int64 little-endian
   byte length. *)
module Header = struct
  type t = {
    n_rows : int;
    n_cols : int;
    symbols : string list;
    panel_names : string list;
    dtype : string;
  }
  [@@deriving sexp]
end

(* Page-align the body offset so [Caml_unix.map_file] doesn't have to fix up
   alignment on platforms that care. 4096 covers all common page sizes. *)
let _body_alignment = 4096

let _aligned_body_offset ~header_len_bytes =
  (* header_len_prefix is 8 bytes (int64 LE) + header bytes itself *)
  let raw = 8 + header_len_bytes in
  let rem = raw mod _body_alignment in
  if rem = 0 then raw else raw + (_body_alignment - rem)

let _write_int64_le oc (v : int64) =
  let b = Bytes.create 8 in
  for i = 0 to 7 do
    let shifted = Int64.shift_right_logical v (i * 8) in
    let byte = Int64.to_int_exn (Int64.bit_and shifted 0xFFL) in
    Bytes.set b i (Char.of_int_exn byte)
  done;
  Out_channel.output_bytes oc b

let _read_int64_le ic =
  let b = Bytes.create 8 in
  In_channel.really_input_exn ic ~buf:b ~pos:0 ~len:8;
  let v = ref 0L in
  for i = 7 downto 0 do
    let byte = Int64.of_int (Char.to_int (Bytes.get b i)) in
    v := Int64.bit_or (Int64.shift_left !v 8) byte
  done;
  !v

let _validate_panels_shape ~n_rows ~n_cols (panels : panel array) =
  Array.iteri panels ~f:(fun i p ->
      let r = BA2.dim1 p in
      let c = BA2.dim2 p in
      if r <> n_rows || c <> n_cols then
        invalid_arg
          (Printf.sprintf
             "Panel_snapshot.dump: panel %d shape %dx%d, expected %dx%d" i r c
             n_rows n_cols))

let _copy_panel_to_mmap ~(src : panel) ~(dst : panel) =
  (* Bigarray-to-Bigarray copy: BA2.blit handles the row-major iteration. *)
  BA2.blit src dst

let _write_header_and_preallocate ~path ~header_bytes ~body_offset
    ~total_body_bytes =
  Out_channel.with_file path ~f:(fun oc ->
      _write_int64_le oc (Int64.of_int (Bytes.length header_bytes));
      Out_channel.output_bytes oc header_bytes;
      let pad_len = body_offset - 8 - Bytes.length header_bytes in
      Out_channel.output_bytes oc (Bytes.make pad_len '\x00');
      let zero_chunk = Bytes.make 65536 '\x00' in
      let remaining = ref total_body_bytes in
      while !remaining > 0 do
        let chunk = Int.min !remaining (Bytes.length zero_chunk) in
        Out_channel.output_bytes oc (Bytes.sub zero_chunk ~pos:0 ~len:chunk);
        remaining := !remaining - chunk
      done)

let _mmap_and_copy_panels ~path ~body_offset ~panel_size_bytes ~n_rows ~n_cols
    panels =
  let fd = Core_unix.openfile ~mode:[ O_RDWR ] path in
  Exn.protect
    ~f:(fun () ->
      Array.iteri panels ~f:(fun i src ->
          let pos = Int64.of_int (body_offset + (i * panel_size_bytes)) in
          let mapped =
            Caml_unix.map_file fd ~pos BA.Float64 BA.C_layout true
              [| n_rows; n_cols |]
          in
          let dst : panel = BA.array2_of_genarray mapped in
          _copy_panel_to_mmap ~src ~dst))
    ~finally:(fun () -> Core_unix.close fd)

let dump ~path symbol_index ~panels ~panel_names =
  let n_panels = Array.length panels in
  if n_panels <> List.length panel_names then
    invalid_arg
      (Printf.sprintf "Panel_snapshot.dump: %d panels but %d names" n_panels
         (List.length panel_names));
  let n_rows = Symbol_index.n symbol_index in
  let n_cols = if n_panels = 0 then 0 else BA2.dim2 panels.(0) in
  _validate_panels_shape ~n_rows ~n_cols panels;
  let header : Header.t =
    {
      n_rows;
      n_cols;
      symbols = Symbol_index.symbols symbol_index;
      panel_names;
      dtype = "float64";
    }
  in
  let header_bytes =
    header |> Header.sexp_of_t |> Sexp.to_string |> Bytes.of_string
  in
  let body_offset =
    _aligned_body_offset ~header_len_bytes:(Bytes.length header_bytes)
  in
  let panel_size_bytes = n_rows * n_cols * 8 in
  _write_header_and_preallocate ~path ~header_bytes ~body_offset
    ~total_body_bytes:(n_panels * panel_size_bytes);
  _mmap_and_copy_panels ~path ~body_offset ~panel_size_bytes ~n_rows ~n_cols
    panels

let _decode_header ic =
  let header_len = _read_int64_le ic |> Int64.to_int_exn in
  let header_bytes = Bytes.create header_len in
  In_channel.really_input_exn ic ~buf:header_bytes ~pos:0 ~len:header_len;
  let sexp = Sexp.of_string (Bytes.to_string header_bytes) in
  let header = Header.t_of_sexp sexp in
  (header, header_len)

let load ~path =
  let header, header_len =
    In_channel.with_file path ~f:(fun ic -> _decode_header ic)
  in
  let body_offset = _aligned_body_offset ~header_len_bytes:header_len in
  let n_rows = header.n_rows in
  let n_cols = header.n_cols in
  let n_panels = List.length header.panel_names in
  let panel_size_bytes = n_rows * n_cols * 8 in
  let symbol_index =
    match Symbol_index.create ~universe:header.symbols with
    | Ok s -> s
    | Error err ->
        failwith
          (Printf.sprintf
             "Panel_snapshot.load: invalid symbol index in header: %s"
             err.Status.message)
  in
  let fd = Core_unix.openfile ~mode:[ O_RDONLY ] path in
  let panels =
    Exn.protect
      ~f:(fun () ->
        Array.init n_panels ~f:(fun i ->
            let pos = Int64.of_int (body_offset + (i * panel_size_bytes)) in
            let mapped =
              Caml_unix.map_file fd ~pos BA.Float64 BA.C_layout false
                [| n_rows; n_cols |]
            in
            BA.array2_of_genarray mapped))
      ~finally:(fun () -> Core_unix.close fd)
  in
  (symbol_index, panels, header.panel_names)
