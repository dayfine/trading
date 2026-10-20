open Core

let join_tolerance_days = 7

let _split_rows path =
  In_channel.read_lines path
  |> List.filter ~f:(fun l -> not (String.is_empty l))
  |> List.map ~f:(fun l -> String.split l ~on:',')

let _column_index header name =
  List.findi header ~f:(fun _ h -> String.equal h name) |> Option.map ~f:fst

(* [(key, trigger)] for one data row, or [None] when any column is absent. *)
let _entry_of_row ~cols row =
  let get i = Option.bind i ~f:(fun i -> List.nth row i) in
  let col_symbol, col_entry, col_exit, col_trigger = cols in
  match (get col_symbol, get col_entry, get col_exit, get col_trigger) with
  | Some sym, Some ed, Some xd, Some trig ->
      Some ((sym, Date.of_string ed, Date.of_string xd), trig)
  | _ -> None

let exit_reason_lookup ~scenario_dir =
  let tbl = Hashtbl.Poly.create () in
  let rows = _split_rows (Filename.concat scenario_dir "trades.csv") in
  let header, data = match rows with h :: d -> (h, d) | [] -> ([], []) in
  let cols =
    ( _column_index header "symbol",
      _column_index header "entry_date",
      _column_index header "exit_date",
      _column_index header "exit_trigger" )
  in
  List.filter_map data ~f:(_entry_of_row ~cols)
  |> List.iter ~f:(fun (key, data) -> Hashtbl.set tbl ~key ~data);
  tbl

type mfe_index = (Date.t * float) list String.Table.t

let build_mfe_index entries =
  let tbl = Hashtbl.create (module String) in
  List.iter entries ~f:(fun (symbol, date, mfe) ->
      Hashtbl.add_multi tbl ~key:symbol ~data:(date, mfe));
  tbl

let find_mfe mfe_index ~symbol ~entry_date =
  match Hashtbl.find mfe_index symbol with
  | None -> None
  | Some candidates ->
      List.filter_map candidates ~f:(fun (d, mfe) ->
          let gap = Int.abs (Date.diff d entry_date) in
          if gap <= join_tolerance_days then Some (gap, mfe) else None)
      |> List.min_elt ~compare:(fun (g1, _) (g2, _) -> Int.compare g1 g2)
      |> Option.map ~f:snd
