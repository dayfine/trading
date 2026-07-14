(** Low-level readers for the extra scenario-directory artefacts. See [.mli]. *)

open Core

let _read_lines path =
  if Sys_unix.file_exists_exn path then (
    let ic = In_channel.create path in
    let ls = In_channel.input_lines ic in
    In_channel.close ic;
    ls)
  else []

let _header_index hdr =
  String.split hdr ~on:','
  |> List.mapi ~f:(fun i n -> (String.strip n, i))
  |> Map.of_alist_reduce (module String) ~f:(fun a _ -> a)

let _cell idx cells name =
  Option.bind (Map.find idx name) ~f:(fun i -> List.nth cells i)

let read_equity_curve path =
  match _read_lines path with
  | [] | [ _ ] -> []
  | _hdr :: rows ->
      List.filter_map rows ~f:(fun line ->
          match String.split (String.strip line) ~on:',' with
          | d :: v :: _ when not (String.is_empty d) -> (
              try Some (Date.of_string d, Float.of_string v) with _ -> None)
          | _ -> None)

let read_final_prices path =
  match _read_lines path with
  | [] | [ _ ] -> []
  | _hdr :: rows ->
      List.filter_map rows ~f:(fun line ->
          match String.split (String.strip line) ~on:',' with
          | s :: p :: _ when not (String.is_empty s) -> (
              try Some (s, Float.of_string p) with _ -> None)
          | _ -> None)

let read_open_positions path =
  match _read_lines path with
  | [] | [ _ ] -> []
  | hdr :: rows ->
      let idx = _header_index hdr in
      List.filter_map rows ~f:(fun line ->
          if String.is_empty (String.strip line) then None
          else
            let cells = String.split line ~on:',' in
            let get = _cell idx cells in
            match
              (get "symbol", get "entry_date", get "entry_price", get "quantity")
            with
            | Some s, Some e, Some p, Some q -> (
                try
                  Some
                    ( s,
                      Option.value (get "side") ~default:"LONG",
                      Date.of_string e,
                      Float.of_string p,
                      Float.of_string q )
                with _ -> None)
            | _ -> None)

let key sym entry exit_ = String.concat ~sep:"|" [ sym; entry; exit_ ]

type trade_extra = {
  qty : float;
  stop_kind : string;
  entry_stop : float option;
  exit_stop : float option;
}

let read_trade_extras path =
  match _read_lines path with
  | [] | [ _ ] -> []
  | hdr :: rows ->
      let idx = _header_index hdr in
      List.filter_map rows ~f:(fun line ->
          if String.is_empty (String.strip line) then None
          else
            let cells = String.split line ~on:',' in
            let get = _cell idx cells in
            match (get "symbol", get "entry_date", get "exit_date") with
            | Some s, Some e, Some x ->
                let float_of name =
                  Option.bind (get name) ~f:(fun v ->
                      try Some (Float.of_string v) with _ -> None)
                in
                let qty = Option.value (float_of "quantity") ~default:0.0 in
                let sk = Option.value (get "stop_trigger_kind") ~default:"" in
                Some
                  ( key s e x,
                    {
                      qty;
                      stop_kind = sk;
                      entry_stop = float_of "entry_stop";
                      exit_stop = float_of "exit_stop";
                    } )
            | _ -> None)

type summary = {
  initial_cash : float option;
  final_portfolio_value : float option;
  metrics : (string * float) list;
  stale_held : string list;
}

let _float_atom = function
  | Sexp.Atom s -> ( try Some (Float.of_string s) with _ -> None)
  | _ -> None

let _summary_assoc path =
  if not (Sys_unix.file_exists_exn path) then []
  else
    try
      match Sexp.load_sexp path with
      | Sexp.List fields ->
          List.filter_map fields ~f:(function
            | Sexp.List [ Sexp.Atom k; v ] -> Some (k, v)
            | _ -> None)
      | _ -> []
    with _ -> []

let _find_float fields key =
  Option.bind (List.Assoc.find fields key ~equal:String.equal) ~f:_float_atom

let _metrics_assoc fields =
  match List.Assoc.find fields "metrics" ~equal:String.equal with
  | Some (Sexp.List pairs) ->
      List.filter_map pairs ~f:(function
        | Sexp.List [ Sexp.Atom name; v ] ->
            let suffix =
              String.rsplit2 name ~on:'.'
              |> Option.value_map ~default:name ~f:snd
            in
            Option.map (_float_atom v) ~f:(fun f -> (suffix, f))
        | _ -> None)
  | _ -> []

let _stale_held fields =
  match List.Assoc.find fields "stale_held_symbols" ~equal:String.equal with
  | Some (Sexp.List xs) ->
      List.filter_map xs ~f:(function Sexp.Atom s -> Some s | _ -> None)
  | _ -> []

let read_summary path =
  let fields = _summary_assoc path in
  {
    initial_cash = _find_float fields "initial_cash";
    final_portfolio_value = _find_float fields "final_portfolio_value";
    metrics = _metrics_assoc fields;
    stale_held = _stale_held fields;
  }
