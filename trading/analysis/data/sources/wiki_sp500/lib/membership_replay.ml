open Core

type constituent = { symbol : string; security_name : string; sector : string }
[@@deriving show, eq]

(* --- CSV parsing -------------------------------------------------------- *)

(* Required header column names — match case-insensitively. We accept either
   ["GICS Sector"] (Wikipedia's actual column) or the simpler ["Sector"] for
   future-proofing. *)
let _symbol_header = "symbol"
let _security_header = "security"
let _sector_header_primary = "gics sector"
let _sector_header_alt = "sector"
let _unknown_sector = "Unknown"

(* Split a single CSV line, respecting double-quoted fields containing
   commas. Wikipedia's main constituents table uses this convention for
   headquarters fields like ["New York, NY"]. *)
let _split_csv_line line =
  let buf = Buffer.create 32 in
  let fields = ref [] in
  let in_quotes = ref false in
  String.iter line ~f:(fun c ->
      match c with
      | '"' -> in_quotes := not !in_quotes
      | ',' when not !in_quotes ->
          fields := Buffer.contents buf :: !fields;
          Buffer.clear buf
      | _ -> Buffer.add_char buf c);
  fields := Buffer.contents buf :: !fields;
  List.rev !fields

let _find_column_index headers name =
  List.findi headers ~f:(fun _ h ->
      String.equal (String.lowercase (String.strip h)) name)
  |> Option.map ~f:fst

let _resolve_column_indices headers =
  let symbol_idx = _find_column_index headers _symbol_header in
  let security_idx = _find_column_index headers _security_header in
  let sector_idx =
    match _find_column_index headers _sector_header_primary with
    | Some i -> Some i
    | None -> _find_column_index headers _sector_header_alt
  in
  match (symbol_idx, security_idx, sector_idx) with
  | Some s, Some sec, Some sector -> Ok (s, sec, sector)
  | _ ->
      Status.error_invalid_argument
        (Printf.sprintf
           "current-constituents CSV missing required header(s); need \
            Symbol/Security/Sector, got: %s"
           (String.concat ~sep:"," headers))

let _parse_data_row ~symbol_idx ~security_idx ~sector_idx ~row_num row =
  let cells = _split_csv_line row in
  let max_idx = max symbol_idx (max security_idx sector_idx) in
  if List.length cells <= max_idx then
    Status.error_invalid_argument
      (Printf.sprintf "row %d has %d cells; need at least %d" row_num
         (List.length cells) (max_idx + 1))
  else
    let cell i = String.strip (List.nth_exn cells i) in
    Ok
      {
        symbol = cell symbol_idx;
        security_name = cell security_idx;
        sector = cell sector_idx;
      }

let parse_current_csv csv_text =
  let lines =
    String.split_lines csv_text
    |> List.filter ~f:(fun l -> not (String.is_empty (String.strip l)))
  in
  match lines with
  | [] -> Status.error_invalid_argument "current-constituents CSV is empty"
  | header :: data_rows ->
      let headers = _split_csv_line header in
      let%bind.Result symbol_idx, security_idx, sector_idx =
        _resolve_column_indices headers
      in
      List.mapi data_rows ~f:(fun i row ->
          _parse_data_row ~symbol_idx ~security_idx ~sector_idx ~row_num:(i + 2)
            row)
      |> Result.all

(* --- Replay ------------------------------------------------------------- *)

(* The working set is keyed by symbol. We use a Hashtbl for O(1)
   add/drop/lookup over the ~341 events in the 2010+ window — a list-based
   implementation would be O(N*E) ≈ 170k ops which is fine but less
   pleasant when the changes input grows. *)
let _to_table cs =
  let table = Hashtbl.create (module String) in
  List.iter cs ~f:(fun c -> Hashtbl.set table ~key:c.symbol ~data:c);
  table

let _from_table table =
  Hashtbl.data table
  |> List.sort ~compare:(fun a b -> String.compare a.symbol b.symbol)

(* Apply the inverse of one change event: drop [added], restore [removed].
   Tolerant of [added] not being in the working set (see .mli docstring on
   why we choose silent-skip over hard error). *)
let _undo_event table (event : Changes_parser.change_event) =
  Option.iter event.added ~f:(fun a -> Hashtbl.remove table a.symbol);
  Option.iter event.removed ~f:(fun r ->
      Hashtbl.set table ~key:r.symbol
        ~data:
          {
            symbol = r.symbol;
            security_name = r.security_name;
            sector = _unknown_sector;
          })

let replay_back ~current ~changes ~as_of =
  let table = _to_table current in
  let events_to_undo =
    List.filter changes ~f:(fun (e : Changes_parser.change_event) ->
        Date.( > ) e.effective_date as_of)
  in
  List.iter events_to_undo ~f:(_undo_event table);
  Ok (_from_table table)

(* --- Sexp output ------------------------------------------------------- *)

let _constituent_to_sexp_pair c =
  Sexp.List
    [
      Sexp.List [ Sexp.Atom "symbol"; Sexp.Atom c.symbol ];
      Sexp.List [ Sexp.Atom "sector"; Sexp.Atom c.sector ];
    ]

let to_universe_sexp cs =
  let sorted =
    List.sort cs ~compare:(fun a b -> String.compare a.symbol b.symbol)
  in
  let entries = List.map sorted ~f:_constituent_to_sexp_pair in
  Sexp.List [ Sexp.Atom "Pinned"; Sexp.List entries ]

(* --- Dynamic universe (PR-D) ------------------------------------------- *)

type timeline_event = {
  date : Date.t;
  action : [ `Added | `Removed ];
  symbol : string;
  sector : string;
}

type timeline = {
  from : Date.t;
  until : Date.t;
  initial : constituent list;
      (* Membership at [from], sorted by [symbol] ascending. *)
  events : timeline_event list;
      (* Change events with [from < date <= until], sorted ascending by
         [(date, action)] where [`Added < `Removed] within a day. *)
}

let _action_rank = function `Added -> 0 | `Removed -> 1

let _compare_events a b =
  let date_cmp = Date.compare a.date b.date in
  if date_cmp <> 0 then date_cmp
  else
    let action_cmp =
      Int.compare (_action_rank a.action) (_action_rank b.action)
    in
    if action_cmp <> 0 then action_cmp else String.compare a.symbol b.symbol

(* Each Wikipedia change-event yields up to two timeline events: one
   [`Added] line for the new ticker and one [`Removed] line for the
   departing one. Sectors come from the snapshot for [`Added] (when we can
   find them via lookup of today's sector from current) — but during
   forward-replay through the window, post-[from] additions don't have a
   GICS sector available. We use ["Unknown"] there, matching the
   convention in [_undo_event]. *)
let _events_in_window ~current_sectors ~from ~until
    (changes : Changes_parser.change_event list) =
  List.concat_map changes ~f:(fun (e : Changes_parser.change_event) ->
      if Date.( <= ) e.effective_date from || Date.( > ) e.effective_date until
      then []
      else
        let added_evt =
          Option.map e.added ~f:(fun (a : Changes_parser.ticker_id) ->
              let sector =
                Option.value
                  (Hashtbl.find current_sectors a.symbol)
                  ~default:_unknown_sector
              in
              {
                date = e.effective_date;
                action = `Added;
                symbol = a.symbol;
                sector;
              })
        in
        let removed_evt =
          Option.map e.removed ~f:(fun (r : Changes_parser.ticker_id) ->
              {
                date = e.effective_date;
                action = `Removed;
                symbol = r.symbol;
                sector = _unknown_sector;
              })
        in
        List.filter_opt [ added_evt; removed_evt ])
  |> List.sort ~compare:_compare_events

let build_timeline ~current ~changes ~from ~until =
  if Date.( > ) from until then
    Status.error_invalid_argument
      (Printf.sprintf "build_timeline: from (%s) must be <= until (%s)"
         (Date.to_string from) (Date.to_string until))
  else
    let%bind.Result initial = replay_back ~current ~changes ~as_of:from in
    let initial =
      List.sort initial ~compare:(fun a b -> String.compare a.symbol b.symbol)
    in
    let current_sectors =
      let table = Hashtbl.create (module String) in
      List.iter current ~f:(fun c ->
          Hashtbl.set table ~key:c.symbol ~data:c.sector);
      table
    in
    let events = _events_in_window ~current_sectors ~from ~until changes in
    Ok { from; until; initial; events }

let is_member t ~symbol ~as_of =
  if Date.( < ) as_of t.from || Date.( > ) as_of t.until then false
  else
    let in_initial =
      List.exists t.initial ~f:(fun c -> String.equal c.symbol symbol)
    in
    (* Replay forward: apply every event with [date <= as_of] to the
       initial-state membership flag. *)
    List.fold t.events ~init:in_initial ~f:(fun is_in evt ->
        if Date.( > ) evt.date as_of then is_in
        else if not (String.equal evt.symbol symbol) then is_in
        else match evt.action with `Added -> true | `Removed -> false)

(* JSONL escape — only the [quote] and [backslash] characters need
   escaping for our finite domain (dates and ASCII tickers); we keep the
   encoder minimal rather than depending on yojson. *)
let _json_escape s =
  let buf = Buffer.create (String.length s + 4) in
  String.iter s ~f:(fun c ->
      match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | _ -> Buffer.add_char buf c);
  Buffer.contents buf

let _action_string = function `Added -> "added" | `Removed -> "removed"

let _emit_json_line ~date ~action ~symbol ~sector =
  Printf.sprintf {|{"date":"%s","action":"%s","symbol":"%s","sector":"%s"}|}
    (Date.to_string date) (_action_string action) (_json_escape symbol)
    (_json_escape sector)

let timeline_to_jsonl t =
  let initial_lines =
    List.map t.initial ~f:(fun c ->
        _emit_json_line ~date:t.from ~action:`Added ~symbol:c.symbol
          ~sector:c.sector)
  in
  let event_lines =
    List.map t.events ~f:(fun e ->
        _emit_json_line ~date:e.date ~action:e.action ~symbol:e.symbol
          ~sector:e.sector)
  in
  String.concat ~sep:"\n" (initial_lines @ event_lines) ^ "\n"
