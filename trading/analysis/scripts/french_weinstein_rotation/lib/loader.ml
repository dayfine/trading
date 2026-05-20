open Core

type block = VW | EW [@@deriving show, eq]

type daily_row = { date : Date.t; industry_returns : float option array }
[@@deriving show, eq]

type parsed_series = {
  block : block;
  industries : string list;
  rows : daily_row array;
}
[@@deriving show, eq]

(* Decompress via system [gunzip]. Single one-shot read at script startup
   avoids taking a camlzip opam dep. *)
let _gunzip_to_string ~csv_gz_path : string =
  let cmd = Printf.sprintf "gunzip -c %s" (Filename.quote csv_gz_path) in
  let ic = Core_unix.open_process_in cmd in
  let body = In_channel.input_all ic in
  match Core_unix.close_process_in ic with
  | Ok () -> body
  | Error _ ->
      failwithf "french_weinstein_rotation: gunzip failed for %s" csv_gz_path ()

let _parse_block_label raw =
  match String.strip raw with
  | "VW" -> VW
  | "EW" -> EW
  | other -> failwithf "french_weinstein_rotation: unknown block %S" other ()

let _parse_cell raw =
  let s = String.strip raw in
  if String.is_empty s then None else Some (Float.of_string s)

let _expect_header header_line =
  let cols = String.split header_line ~on:',' |> List.map ~f:String.strip in
  match cols with
  | "block" :: "date" :: industry_cols -> industry_cols
  | _ ->
      failwithf "french_weinstein_rotation: unexpected fixture header %S"
        header_line ()

let _parse_date date_s line_num =
  try Date.of_string (String.strip date_s)
  with _ ->
    failwithf "french_weinstein_rotation: bad date %S on line %d" date_s
      line_num ()

let _parse_row_fields ~line_num fields =
  match fields with
  | blk_s :: date_s :: cells ->
      let block = _parse_block_label blk_s in
      let date = _parse_date date_s line_num in
      let industry_returns = Array.of_list (List.map cells ~f:_parse_cell) in
      (block, { date; industry_returns })
  | _ -> failwithf "french_weinstein_rotation: empty row on line %d" line_num ()

let _parse_row ~industries_count ~line_num raw_line =
  let fields = String.split raw_line ~on:',' in
  let expected = 2 + industries_count in
  let got = List.length fields in
  if got <> expected then
    failwithf "french_weinstein_rotation: line %d has %d cols (expected %d): %S"
      line_num got expected raw_line ()
  else _parse_row_fields ~line_num fields

let _maybe_for_block ~block (blk, row) =
  if equal_block blk block then Some row else None

let _parse_data_line ~industries_count ~block ~line_num line =
  match String.strip line with
  | "" -> None
  | _ -> _parse_row ~industries_count ~line_num line |> _maybe_for_block ~block

let _split_header_and_data body =
  let lines = String.split_lines body in
  match lines with
  | [] | [ _ ] ->
      failwith "french_weinstein_rotation: fixture too short (no data rows)"
  | header :: data_lines -> (header, data_lines)

let load_block ~csv_gz_path ~block =
  let body = _gunzip_to_string ~csv_gz_path in
  let header, data_lines = _split_header_and_data body in
  let industry_cols = _expect_header header in
  let industries_count = List.length industry_cols in
  let parsed =
    List.filter_mapi data_lines ~f:(fun i line ->
        _parse_data_line ~industries_count ~block ~line_num:(i + 2) line)
  in
  { block; industries = industry_cols; rows = Array.of_list parsed }
