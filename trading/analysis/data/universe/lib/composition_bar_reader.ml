open Core

type bar = {
  date : Date.t;
  close : float;
  adjusted_close : float;
  volume : float;
}

(* Sharding rule matches [Csv_storage.symbol_data_dir]: first letter /
   last letter / <symbol>. Single-character symbols collapse to
   [<L>/<L>/<L>]. *)
let _shard_letters symbol =
  let l1 = String.prefix symbol 1 in
  let l2 =
    if String.length symbol >= 2 then
      String.sub symbol ~pos:(String.length symbol - 1) ~len:1
    else l1
  in
  (l1, l2)

let bars_path ~bars_root symbol =
  let l1, l2 = _shard_letters symbol in
  Filename.concat
    (Filename.concat (Filename.concat bars_root l1) l2)
    (Filename.concat symbol "data.csv")

let _bar_from_fields date_s close_s adj_close_s volume_s : bar option =
  try
    Some
      {
        date = Date.of_string date_s;
        close = Float.of_string close_s;
        adjusted_close = Float.of_string adj_close_s;
        volume = Float.of_string volume_s;
      }
  with _ -> None

let _parse_bar_line line : bar option =
  match String.split line ~on:',' with
  | date_s :: _ :: _ :: _ :: close_s :: adj_close_s :: volume_s :: _ ->
      _bar_from_fields date_s close_s adj_close_s volume_s
  | _ -> None

let _split_nonempty_lines body =
  String.split_lines body
  |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))

let _bars_from_body body =
  match _split_nonempty_lines body with
  | [] | [ _ ] -> None
  | _header :: rows -> Some (List.filter_map rows ~f:_parse_bar_line)

let read_bars ~bars_root symbol : bar list option =
  let path = bars_path ~bars_root symbol in
  match In_channel.read_all path with
  | exception Sys_error _ -> None
  | body -> _bars_from_body body
