open Core

(* Read the leading [magic_len] bytes of [ic], or [None] when the channel holds
   fewer bytes than the magic (a short / empty file is not a v2 file). *)
let _read_magic_prefix ic =
  let buf = Bytes.create Snapshot_columnar_codec.magic_len in
  match
    In_channel.really_input ic ~buf ~pos:0
      ~len:Snapshot_columnar_codec.magic_len
  with
  | Some () -> Some (Bytes.to_string buf)
  | None -> None

let is_columnar_file path =
  try
    let prefix = In_channel.with_file path ~f:_read_magic_prefix in
    Option.value_map prefix ~default:false
      ~f:(String.equal Snapshot_columnar_codec.magic)
  with _ -> false

let read_with_expected_schema ~path ~expected =
  if is_columnar_file path then
    Snapshot_columnar.read_with_expected_schema ~path ~expected
  else Snapshot_format.read_with_expected_schema ~path ~expected
