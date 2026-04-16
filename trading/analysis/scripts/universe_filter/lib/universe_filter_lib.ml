open Core

type row = {
  symbol : string;
  sector : string;
  name : string;
  exchange : string;
}
[@@deriving sexp, equal]

type rule =
  | Symbol_pattern of { name : string; pattern : string }
  | Name_pattern of { name : string; pattern : string }
  | Exchange_equals of { name : string; exchange : string }
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

(* Internal representation: regexes compiled once up-front, allow-list flattened
   into a set. Each drop rule keeps a closure that decides whether [row] matches.
   Keeping the closure uniform across variants keeps the per-row loop simple. *)
type drop_rule_compiled = { name : string; matches : row -> bool }

type compiled = {
  drop_rules : drop_rule_compiled list;
  allowlist : String.Hash_set.t;
}

(* [Re.Perl] does not support inline flag groups like [(?i)…]. To keep the sexp
   syntax friendly (the docs-facing "perl regex" story), we hand-parse a
   leading [(?i)] flag group off the pattern and translate it to the
   [`Caseless] opt that [Re.Perl.re] does accept. More inline flags can be
   added here as needed; unknown flag groups fall through unchanged and will
   raise at compile time. *)
let _extract_inline_flags (pattern : string) : Re.Perl.opt list * string =
  match String.chop_prefix pattern ~prefix:"(?i)" with
  | Some rest -> ([ `Caseless ], rest)
  | None -> ([], pattern)

let _compile_pattern pattern =
  let opts, body = _extract_inline_flags pattern in
  Re.compile (Re.Perl.re ~opts body)

let _compile_drop_rule = function
  | Symbol_pattern { name; pattern } ->
      let re = _compile_pattern pattern in
      Some { name; matches = (fun row -> Re.execp re row.symbol) }
  | Name_pattern { name; pattern } ->
      let re = _compile_pattern pattern in
      Some { name; matches = (fun row -> Re.execp re row.name) }
  | Exchange_equals { name; exchange } ->
      Some { name; matches = (fun row -> String.equal row.exchange exchange) }
  | Keep_allowlist _ -> None

let _compile (cfg : config) : compiled =
  let drop_rules = List.filter_map cfg.rules ~f:_compile_drop_rule in
  let allowlist = String.Hash_set.create () in
  List.iter cfg.rules ~f:(function
    | Keep_allowlist { symbols; _ } ->
        List.iter symbols ~f:(fun s -> Hash_set.add allowlist s)
    | Symbol_pattern _ | Name_pattern _ | Exchange_equals _ -> ());
  { drop_rules; allowlist }

(* --- Core filter --------------------------------------------------------- *)

(* Returns the list of matched drop-rule names (possibly empty). Allow-list
   rescue is applied by the caller, so this helper stays pure and the per-rule
   drop stats remain raw match counts. *)
let _matches (c : compiled) (row : row) : string list =
  List.filter_map c.drop_rules ~f:(fun { name; matches } ->
      if matches row then Some name else None)

let _extract_drop_rule_name = function
  | Symbol_pattern { name; _ }
  | Name_pattern { name; _ }
  | Exchange_equals { name; _ } ->
      Some name
  | Keep_allowlist _ -> None

let filter (cfg : config) (rows : row list) : filter_result =
  let c = _compile cfg in
  let stats = String.Table.create () in
  let kept = ref [] in
  let dropped = ref [] in
  let rescued = ref 0 in
  List.iter rows ~f:(fun row ->
      let matched = _matches c row in
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
    (* Emit one stat per drop rule in declaration order — even if the drop
       count is zero, so the caller sees that the rule exists and fired
       nothing, rather than silently missing. *)
    List.filter_map cfg.rules ~f:(fun rule ->
        Option.map (_extract_drop_rule_name rule) ~f:(fun name ->
            let count = Hashtbl.find stats name |> Option.value ~default:0 in
            { rule_name = name; drop_count = count }))
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
                       rows :=
                         {
                           symbol = sym;
                           sector = sec;
                           name = "";
                           exchange = "";
                         }
                         :: !rows
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
    List.iter rows ~f:(fun { symbol; sector; _ } ->
        Stdlib.Out_channel.output_string oc (symbol ^ "," ^ sector ^ "\n"));
    Stdlib.Out_channel.close oc;
    Stdlib.Sys.rename tmp path;
    Ok ()
  with exn -> Error (Exn.to_string exn)

(* --- Universe sexp join --------------------------------------------------- *)

(* Shape expected per entry in universe.sexp:
     ((symbol X) (name Y) (sector S) (industry I) (market_cap M) (exchange E))
   Fields may appear in any order. We only need symbol, name, exchange —
   other fields are ignored. Parsing by hand (rather than by deriving a full
   Instrument_info type) keeps this library free of a cross-subproject
   dependency on [analysis/data/types]. *)

let _atom_to_string = function
  | Sexp.Atom s -> s
  | List _ -> (* fields we care about are always atoms *) ""

let _parse_universe_entry (sexp : Sexp.t) :
    (string * string * string) option (* (symbol, name, exchange) *) =
  match sexp with
  | List fields ->
      let sym = ref "" in
      let nm = ref "" in
      let ex = ref "" in
      List.iter fields ~f:(function
        | Sexp.List [ Atom key; v ] -> (
            match key with
            | "symbol" -> sym := _atom_to_string v
            | "name" -> nm := _atom_to_string v
            | "exchange" -> ex := _atom_to_string v
            | _ -> ())
        | _ -> ());
      if String.is_empty !sym then None else Some (!sym, !nm, !ex)
  | Atom _ -> None

let _load_universe_metadata path :
    (string, string * string) Hashtbl.t Or_error.t =
  try
    let sexp = Sexp.load_sexp path in
    match sexp with
    | List entries ->
        let tbl = String.Table.create () in
        List.iter entries ~f:(fun entry ->
            match _parse_universe_entry entry with
            | Some (sym, name, exchange) ->
                (* Last write wins; in practice symbols are unique in
                   universe.sexp so this is fine. *)
                Hashtbl.set tbl ~key:sym ~data:(name, exchange)
            | None -> ());
        Ok tbl
    | Atom _ ->
        Or_error.error_string
          (Printf.sprintf
             "universe.sexp at %s is a single atom, expected a list" path)
  with exn -> Or_error.of_exn exn

let load_rows_with_universe ~sectors_csv ~universe_sexp =
  match read_csv sectors_csv with
  | Error e -> Error e
  | Ok rows -> (
      match _load_universe_metadata universe_sexp with
      | Error err ->
          Error
            (Printf.sprintf "Cannot read universe at %s: %s" universe_sexp
               (Error.to_string_hum err))
      | Ok meta ->
          let enriched =
            List.map rows ~f:(fun row ->
                match Hashtbl.find meta row.symbol with
                | Some (name, exchange) -> { row with name; exchange }
                | None -> row (* name="", exchange="" from read_csv *))
          in
          Ok enriched)

(* --- Summaries ------------------------------------------------------------ *)

let sector_breakdown rows =
  let tbl = String.Table.create () in
  List.iter rows ~f:(fun { sector; _ } ->
      Hashtbl.update tbl sector ~f:(function None -> 1 | Some n -> n + 1));
  Hashtbl.to_alist tbl
  |> List.sort ~compare:(fun (_, a) (_, b) -> Int.descending a b)
