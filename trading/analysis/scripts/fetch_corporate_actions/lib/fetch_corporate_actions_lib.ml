open Async
open Core

let _us_exchange = "US"

(* A one-letter suffix is a US share class (BRK.B), which EODHD addresses as
   BRK-B.US; a longer suffix is an exchange (GSPC.INDX, ISF.LSE). *)
let _share_class_suffix_len = 1

let eodhd_ticker symbol =
  match String.rsplit2 symbol ~on:'.' with
  | Some (code, suffix)
    when (not (String.is_empty code))
         && String.length suffix = _share_class_suffix_len ->
      (code ^ "-" ^ suffix, _us_exchange)
  | Some (code, exchange)
    when (not (String.is_empty code)) && not (String.is_empty exchange) ->
      (code, exchange)
  | _ -> (symbol, _us_exchange)

type outcome =
  | Fetched of { dividends : int; splits : int }
  | Empty
  | Failed of string
  | Skipped
[@@deriving show, eq]

let _to_dividend (d : Eodhd.Dividends_endpoint.dividend) :
    Corporate_actions.dividend =
  {
    ex_date = d.date;
    unadjusted_amount = d.unadjusted_amount;
    adjusted_amount = d.amount;
  }

let _to_split (s : Eodhd.Splits_endpoint.split) : Corporate_actions.split =
  { date = s.date; factor = s.factor }

(** Write both files; the outcome reflects the event counts. *)
let _write_both ~data_dir symbol divs splits =
  let open Result.Let_syntax in
  let divs = List.map divs ~f:_to_dividend in
  let splits = List.map splits ~f:_to_split in
  let%bind () = Corporate_actions.write_dividends ~data_dir symbol divs in
  let%map () = Corporate_actions.write_splits ~data_dir symbol splits in
  match (divs, splits) with
  | [], [] -> Empty
  | _ -> Fetched { dividends = List.length divs; splits = List.length splits }

let _failed what err = Failed (what ^ ": " ^ Status.show err)

let fetch_symbol ?fetch ~token ~data_dir symbol =
  let code, exchange = eodhd_ticker symbol in
  let%bind divs =
    Eodhd.Dividends_endpoint.get_dividends ~token ~symbol:code ~exchange ?fetch
      ()
  in
  let%map splits =
    Eodhd.Splits_endpoint.get_splits ~token ~symbol:code ~exchange ?fetch ()
  in
  match (divs, splits) with
  | Error e, _ -> _failed "dividends" e
  | _, Error e -> _failed "splits" e
  | Ok divs, Ok splits -> (
      match _write_both ~data_dir symbol divs splits with
      | Ok outcome -> outcome
      | Error e -> _failed "write" e)

type config = {
  data_dir : Fpath.t;
  refresh : bool;
  sleep_ms : int;
  parallel : int;
}

type summary = { ok : int; empty : int; error : int; skipped : int }
[@@deriving show, eq]

let _empty_summary = { ok = 0; empty = 0; error = 0; skipped = 0 }

let _count summary = function
  | Fetched _ -> { summary with ok = summary.ok + 1 }
  | Empty -> { summary with empty = summary.empty + 1 }
  | Failed _ -> { summary with error = summary.error + 1 }
  | Skipped -> { summary with skipped = summary.skipped + 1 }

let _describe = function
  | Fetched { dividends; splits } ->
      sprintf "OK (%d dividends, %d splits)" dividends splits
  | Empty -> "EMPTY"
  | Failed msg -> "ERROR " ^ msg
  | Skipped -> "SKIP (already fetched)"

let _pause ms =
  if ms > 0 then Clock.after (Time_float.Span.of_ms (Float.of_int ms))
  else return ()

(** One symbol: skip if already fetched, else fetch, log, and pause. *)
let _step ?fetch ~log ~token ~config ~total idx symbol =
  let%map outcome =
    if
      (not config.refresh)
      && Corporate_actions.has_both_files ~data_dir:config.data_dir symbol
    then return Skipped
    else
      let%bind outcome =
        fetch_symbol ?fetch ~token ~data_dir:config.data_dir symbol
      in
      let%map () = _pause config.sleep_ms in
      outcome
  in
  log (sprintf "[%d/%d] %s %s" (idx + 1) total symbol (_describe outcome));
  outcome

let run ?fetch ?(log = fun line -> printf "%s\n%!" line) ~token config symbols =
  let total = List.length symbols in
  let how =
    if config.parallel <= 1 then `Sequential
    else `Max_concurrent_jobs config.parallel
  in
  let%map outcomes =
    Deferred.List.mapi ~how symbols ~f:(_step ?fetch ~log ~token ~config ~total)
  in
  List.fold outcomes ~init:_empty_summary ~f:_count

let render_summary s =
  String.concat ~sep:"\n"
    [
      "Corporate-action fetch summary:";
      sprintf "  ok (events)     : %d" s.ok;
      sprintf "  empty (none)    : %d" s.empty;
      sprintf "  error           : %d" s.error;
      sprintf "  skipped (cached): %d" s.skipped;
      sprintf "  total           : %d" (s.ok + s.empty + s.error + s.skipped);
    ]

let parse_symbols contents =
  String.split_lines contents
  |> List.map ~f:String.strip
  |> List.filter ~f:(fun l ->
      (not (String.is_empty l)) && not (String.is_prefix l ~prefix:"#"))

let _dir_entry path name =
  let p = Fpath.(path / name) in
  match Sys_unix.is_directory (Fpath.to_string p) with
  | `Yes -> Some (name, p)
  | `No | `Unknown -> None

let _subdirs path =
  match Sys_unix.readdir (Fpath.to_string path) with
  | entries -> Array.to_list entries |> List.filter_map ~f:(_dir_entry path)
  | exception _ -> []

let symbols_in_data_dir data_dir =
  let has_bars p = Stdlib.Sys.file_exists Fpath.(to_string (p / "data.csv")) in
  _subdirs data_dir
  |> List.concat_map ~f:(fun (_, l1) -> _subdirs l1)
  |> List.concat_map ~f:(fun (_, l2) -> _subdirs l2)
  |> List.filter_map ~f:(fun (name, p) ->
      if has_bars p then Some name else None)
  |> List.sort ~compare:String.compare
