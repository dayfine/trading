open Core

type row = { symbol : string; sector : string } [@@deriving sexp, equal]

type rule =
  | Symbol_pattern of { name : string; pattern : string }
  | Keep_allowlist of { name : string; symbols : string list }
[@@deriving sexp]

type config = { rules : rule list } [@@deriving sexp]
type rule_stat = { rule_name : string; drop_count : int } [@@deriving sexp]

type filter_result = {
  kept : row list;
  dropped : row list;
  rule_stats : rule_stat list;
  rescued_by_allowlist : int;
}
[@@deriving sexp]

(* --- Compiled rule-set ---------------------------------------------------- *)

(* A separate internal representation so we compile regexes once, up-front,
   rather than per-row. *)
type compiled = {
  patterns : (string * Re.re) list; (* name, compiled regex *)
  allowlist : String.Hash_set.t;
}

let _compile (cfg : config) : compiled =
  let patterns =
    List.filter_map cfg.rules ~f:(function
      | Symbol_pattern { name; pattern } ->
          Some (name, Re.compile (Re.Perl.re pattern))
      | Keep_allowlist _ -> None)
  in
  let allowlist = String.Hash_set.create () in
  List.iter cfg.rules ~f:(function
    | Keep_allowlist { symbols; _ } ->
        List.iter symbols ~f:(fun s -> Hash_set.add allowlist s)
    | Symbol_pattern _ -> ());
  { patterns; allowlist }

(* --- Core filter --------------------------------------------------------- *)

(* Matches [row] against every compiled pattern. Returns the list of
   matched-pattern names (possibly empty). Allow-list rescue is applied
   later, so this helper stays pure and the per-rule drop stats remain a
   raw count of matches. *)
let _matches (c : compiled) (sym : string) : string list =
  List.filter_map c.patterns ~f:(fun (name, re) ->
      if Re.execp re sym then Some name else None)

let filter (cfg : config) (rows : row list) : filter_result =
  let c = _compile cfg in
  let stats = String.Table.create () in
  let kept = ref [] in
  let dropped = ref [] in
  let rescued = ref 0 in
  List.iter rows ~f:(fun row ->
      let matched = _matches c row.symbol in
      List.iter matched ~f:(fun name ->
          Hashtbl.update stats name ~f:(function None -> 1 | Some n -> n + 1));
      let would_drop = not (List.is_empty matched) in
      let on_allowlist = Hash_set.mem c.allowlist row.symbol in
      if would_drop && on_allowlist then (
        Int.incr rescued;
        kept := row :: !kept)
      else if would_drop then dropped := row :: !dropped
      else kept := row :: !kept);
  let rule_stats =
    (* Emit one stat per Symbol_pattern rule in declaration order — even if
       the drop count is zero, so the caller sees that the rule exists and
       fired nothing, rather than silently missing. *)
    List.filter_map cfg.rules ~f:(function
      | Symbol_pattern { name; _ } ->
          let count = Hashtbl.find stats name |> Option.value ~default:0 in
          Some { rule_name = name; drop_count = count }
      | Keep_allowlist _ -> None)
  in
  {
    kept = List.rev !kept;
    dropped = List.rev !dropped;
    rule_stats;
    rescued_by_allowlist = !rescued;
  }

(* --- Config I/O ----------------------------------------------------------- *)

let load_config path =
  match Sys_unix.file_exists path with
  | `No | `Unknown -> Error (Printf.sprintf "Config file not found: %s" path)
  | `Yes -> (
      try
        let contents =
          Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
        in
        let sexp = Sexp.of_string contents in
        try Ok (config_of_sexp sexp)
        with exn ->
          Error
            (Printf.sprintf "Malformed config at %s: %s" path
               (Exn.to_string exn))
      with exn ->
        Error
          (Printf.sprintf "Cannot read config at %s: %s" path
             (Exn.to_string exn)))

(* --- CSV I/O -------------------------------------------------------------- *)

let read_csv path =
  try
    let ic = Stdlib.In_channel.open_text path in
    let rows = ref [] in
    (match Stdlib.In_channel.input_line ic with
    | None -> ()
    | Some _header ->
        let rec loop () =
          match Stdlib.In_channel.input_line ic with
          | None -> ()
          | Some line ->
              let line = String.strip line in
              (if not (String.is_empty line) then
                 match String.split line ~on:',' with
                 | symbol :: sector :: _ ->
                     let sym = String.strip symbol in
                     let sec = String.strip sector in
                     if not (String.is_empty sym) then
                       rows := { symbol = sym; sector = sec } :: !rows
                 | _ -> ());
              loop ()
        in
        loop ());
    Stdlib.In_channel.close ic;
    Ok (List.rev !rows)
  with exn ->
    Error (Printf.sprintf "Cannot read CSV at %s: %s" path (Exn.to_string exn))

let write_csv path rows =
  let tmp = path ^ ".tmp" in
  try
    let oc = Stdlib.Out_channel.open_text tmp in
    Stdlib.Out_channel.output_string oc "symbol,sector\n";
    List.iter rows ~f:(fun { symbol; sector } ->
        Stdlib.Out_channel.output_string oc (symbol ^ "," ^ sector ^ "\n"));
    Stdlib.Out_channel.close oc;
    Stdlib.Sys.rename tmp path;
    Ok ()
  with exn -> Error (Exn.to_string exn)

(* --- Summaries ------------------------------------------------------------ *)

let sector_breakdown rows =
  let tbl = String.Table.create () in
  List.iter rows ~f:(fun { sector; _ } ->
      Hashtbl.update tbl sector ~f:(function None -> 1 | Some n -> n + 1));
  Hashtbl.to_alist tbl
  |> List.sort ~compare:(fun (_, a) (_, b) -> Int.descending a b)
