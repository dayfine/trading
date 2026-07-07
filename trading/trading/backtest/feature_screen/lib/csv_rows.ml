(** See [csv_rows.mli] for the API contract. *)

open Core

type row = {
  signal_date : Date.t;
  return_pct : float;
  cascade_score : int;
  passes_macro : bool;
  rs_value : float option;
  rs_trend : string option;
  volume_ratio : float option;
  weeks_advancing : int option;
  stage2_late : bool option;
  resistance_quality : string option;
}
[@@deriving sexp_of]

let expected_header =
  "signal_date,symbol,side,entry_price,exit_date,exit_reason,return_pct,hold_days,entry_dollars,shares,pnl_dollars,cascade_score,passes_macro,rs_value,rs_trend,volume_ratio,weeks_advancing,stage2_late,resistance_quality"

(* Optional-cell parsers: an empty string is the CSV rendering of [None]. *)
let _opt_float s = if String.is_empty s then None else Some (Float.of_string s)
let _opt_int s = if String.is_empty s then None else Some (Int.of_string s)
let _opt_bool s = if String.is_empty s then None else Some (Bool.of_string s)
let _opt_str s = if String.is_empty s then None else Some s

(* Destructure a split CSV line positionally by name into a [row]. The list
   pattern binds each column and validates the count in one step; a wrong-width
   line falls through to [None]. Field parse errors raise (caught by the
   caller's guard). *)
let _row_of_cells (cells : string list) : row option =
  match cells with
  | [
   signal_date;
   _symbol;
   _side;
   _entry_price;
   _exit_date;
   _exit_reason;
   return_pct;
   _hold_days;
   _entry_dollars;
   _shares;
   _pnl_dollars;
   cascade_score;
   passes_macro;
   rs_value;
   rs_trend;
   volume_ratio;
   weeks_advancing;
   stage2_late;
   resistance_quality;
  ] ->
      Some
        {
          signal_date = Date.of_string signal_date;
          return_pct = Float.of_string return_pct;
          cascade_score = Int.of_string cascade_score;
          passes_macro = Bool.of_string passes_macro;
          rs_value = _opt_float rs_value;
          rs_trend = _opt_str rs_trend;
          volume_ratio = _opt_float volume_ratio;
          weeks_advancing = _opt_int weeks_advancing;
          stage2_late = _opt_bool stage2_late;
          resistance_quality = _opt_str resistance_quality;
        }
  | _ -> None

let _parse_line ~line_no (line : string) : (row, string) result =
  let err () =
    Error (Printf.sprintf "row %d: bad or wrong-width row" line_no)
  in
  match try _row_of_cells (String.split line ~on:',') with _ -> None with
  | Some row -> Ok row
  | None -> err ()

let _parse_data_lines ~source lines : (row list, string) result =
  List.filter lines ~f:(fun l -> not (String.is_empty l))
  |> List.mapi ~f:(fun i l -> (i + 2, l))
  |> List.fold_result ~init:[] ~f:(fun acc (line_no, line) ->
      match _parse_line ~line_no line with
      | Ok r -> Ok (r :: acc)
      | Error m -> Error (Printf.sprintf "%s: %s" source m))
  |> Result.map ~f:List.rev

let _validate_and_parse ~source (lines : string list) :
    (row list, string) result =
  match lines with
  | [] -> Error (Printf.sprintf "%s: empty file (no header)" source)
  | header :: rest ->
      if String.( <> ) (String.strip header) expected_header then
        Error (Printf.sprintf "%s: header mismatch" source)
      else _parse_data_lines ~source rest

let parse_rows lines = _validate_and_parse ~source:"trades.csv" lines

let concat_files named_contents =
  List.fold_result named_contents ~init:[] ~f:(fun acc (source, lines) ->
      Result.map (_validate_and_parse ~source lines) ~f:(fun rows -> acc @ rows))
