open Core
open Async

type manifest = {
  fetched_at : string;
  source : string;
  row_count : int;
  rate_limit_rps : float;
  errors : string list;
}
[@@deriving sexp]

type fetch_result = {
  symbol : string;
  sector : string option;
  error : string option;
}

type fetch_fn = Uri.t -> string Status.status_or Deferred.t

(* --- HTML parsing -------------------------------------------------------- *)

(* Matches Finviz's current sector link: an anchor with the screener
   filter query f=sec_<slug>, whose inner text is the sector display
   name. Finviz's older snapshot-table layout with a td/b/a cell is
   gone post-refactor. *)
let _sector_re =
  Re.compile (Re.Perl.re ~opts:[ `Caseless ] {|f=sec_[a-z]+"[^>]*>([^<]+)<|})

let parse_sector html =
  match Re.exec_opt _sector_re html with
  | Some group ->
      let raw = String.strip (Re.Group.get group 1) in
      Some (Weinstein_types.normalize_sector_name raw)
  | None -> None

(* --- Universe filtering -------------------------------------------------- *)

let _is_likely_etf_or_index (info : Types.Instrument_info.t) =
  let sym = info.symbol in
  let exch = String.uppercase info.exchange in
  String.is_suffix sym ~suffix:".INDX"
  || String.is_prefix exch ~prefix:"INDEX"
  || String.is_suffix sym ~suffix:"W"
  || String.is_suffix sym ~suffix:"WS"
  || (String.is_substring sym ~substring:"-P" && String.length sym > 2)
  || String.is_suffix sym ~suffix:".U"

let filter_common_stocks instruments =
  List.filter_map instruments ~f:(fun (info : Types.Instrument_info.t) ->
      if _is_likely_etf_or_index info then None else Some info.symbol)

(* --- CSV / manifest I/O -------------------------------------------------- *)

let load_existing_sectors csv_path =
  let tbl = Hashtbl.create (module String) in
  (match Stdlib.In_channel.open_gen [ Open_rdonly ] 0 csv_path with
  | ic ->
      (match Stdlib.In_channel.input_line ic with
      | None -> ()
      | Some _header ->
          let rec loop () =
            match Stdlib.In_channel.input_line ic with
            | None -> ()
            | Some line ->
                (match String.split line ~on:',' with
                | symbol :: sector :: _ when String.length symbol > 0 ->
                    Hashtbl.set tbl ~key:(String.strip symbol)
                      ~data:(String.strip sector)
                | _ -> ());
                loop ()
          in
          loop ());
      Stdlib.In_channel.close ic
  | exception Sys_error _ -> ());
  tbl

let _sectors_csv_path data_dir = data_dir ^ "/sectors.csv"
let _manifest_path data_dir = data_dir ^ "/sectors.csv.manifest"

let write_sectors_csv ~data_dir rows =
  let csv_path = _sectors_csv_path data_dir in
  let tmp_path = csv_path ^ ".tmp" in
  try
    let oc = Stdlib.Out_channel.open_text tmp_path in
    Stdlib.Out_channel.output_string oc "symbol,sector\n";
    List.iter rows ~f:(fun (symbol, sector) ->
        Stdlib.Out_channel.output_string oc (symbol ^ "," ^ sector ^ "\n"));
    Stdlib.Out_channel.close oc;
    Stdlib.Sys.rename tmp_path csv_path;
    Ok ()
  with exn -> Error (Exn.to_string exn)

let load_manifest path =
  try
    let contents =
      Stdlib.In_channel.with_open_text path Stdlib.In_channel.input_all
    in
    let sexp = Sexp.of_string contents in
    Some (manifest_of_sexp sexp)
  with _ -> None

let save_manifest path m =
  let sexp = sexp_of_manifest m in
  let contents = Sexp.to_string_hum sexp in
  Stdlib.Out_channel.with_open_text path (fun oc ->
      Stdlib.Out_channel.output_string oc contents)

let manifest_is_fresh manifest ~max_age_days =
  try
    let fetched = Time_float_unix.of_string manifest.fetched_at in
    let now = Time_float_unix.now () in
    let age = Time_float.diff now fetched in
    Time_float.Span.( < ) age
      (Time_float.Span.of_day (Float.of_int max_age_days))
  with _ -> false

(* --- Fetching ------------------------------------------------------------ *)

let _finviz_uri symbol =
  Uri.make ~scheme:"https" ~host:"finviz.com" ~path:"/quote.ashx"
    ~query:[ ("t", [ symbol ]) ]
    ()

let _default_fetch uri =
  let headers =
    Cohttp.Header.of_list
      [
        ( "User-Agent",
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 \
           (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" );
      ]
  in
  Cohttp_async.Client.get ~headers uri >>= fun (resp, body) ->
  match Cohttp.Response.status resp with
  | `OK -> Cohttp_async.Body.to_string body >>| fun s -> Ok s
  | status ->
      Cohttp_async.Body.to_string body >>| fun _body_str ->
      Error
        (Status.internal_error ("HTTP " ^ Cohttp.Code.string_of_status status))

let fetch_one ~fetch ~rate_limit_rps symbol =
  let uri = _finviz_uri symbol in
  let delay =
    if Float.( > ) rate_limit_rps 0.0 then 1.0 /. rate_limit_rps else 0.0
  in
  fetch uri >>= fun result ->
  let fetch_result =
    match result with
    | Error e -> { symbol; sector = None; error = Some (Status.show e) }
    | Ok html -> (
        match parse_sector html with
        | Some sector -> { symbol; sector = Some sector; error = None }
        | None ->
            {
              symbol;
              sector = None;
              error = Some "Could not parse sector from HTML";
            })
  in
  (if Float.( > ) delay 0.0 then after (Time_float.Span.of_sec delay)
   else return ())
  >>| fun () -> fetch_result

(* --- Orchestration ------------------------------------------------------- *)

let run ~data_dir ~rate_limit_rps ~force ?(fetch = _default_fetch) ?symbols
    ?limit () =
  let%bind sym_list =
    match symbols with
    | Some s -> return s
    | None -> (
        Universe.get_deferred data_dir >>| fun result ->
        match result with
        | Error e ->
            eprintf "Error loading universe: %s\n%!" (Status.show e);
            []
        | Ok instruments -> filter_common_stocks instruments)
  in
  if List.is_empty sym_list then (
    eprintf "No symbols to fetch.\n%!";
    return ())
  else
    let csv_path = _sectors_csv_path data_dir in
    let manifest_file = _manifest_path data_dir in
    let existing = load_existing_sectors csv_path in
    (* The CSV is authoritative: always skip symbols that already have a
       sector row, unless --force. Manifest age is informational, not a
       gate on resume — a stale manifest with a valid CSV still means
       the sectors we scraped before are still usable. *)
    let to_fetch =
      let filtered =
        if force then sym_list
        else List.filter sym_list ~f:(fun sym -> not (Hashtbl.mem existing sym))
      in
      match limit with
      | Some n when n > 0 -> List.take filtered n
      | _ -> filtered
    in
    (match load_manifest manifest_file with
    | Some m when not (manifest_is_fresh m ~max_age_days:30) ->
        printf
          "Note: manifest is older than 30 days (fetched_at=%s). Existing rows \
           are still reused; pass --force to re-fetch everything.\n\
           %!"
          m.fetched_at
    | _ -> ());
    printf "Universe: %d symbols, already cached: %d, to fetch: %d\n%!"
      (List.length sym_list) (Hashtbl.length existing) (List.length to_fetch);
    if List.is_empty to_fetch then (
      printf "All symbols already cached. Use --force to re-fetch.\n%!";
      return ())
    else
      let errors = ref [] in
      let success_count = ref 0 in
      let total = List.length to_fetch in
      let checkpoint_interval = 100 in
      let write_checkpoint ~final () =
        let rows =
          Hashtbl.to_alist existing
          |> List.sort ~compare:(fun (a, _) (b, _) -> String.compare a b)
        in
        (match write_sectors_csv ~data_dir rows with
        | Ok () ->
            if final then
              printf "Wrote %d rows to %s\n%!" (List.length rows) csv_path
        | Error e -> eprintf "ERROR writing CSV: %s\n%!" e);
        let m =
          {
            fetched_at = Time_float_unix.to_string_utc (Time_float_unix.now ());
            source = "finviz";
            row_count = List.length rows;
            rate_limit_rps;
            errors = List.rev !errors;
          }
        in
        save_manifest manifest_file m
      in
      let%bind _results =
        Deferred.List.map ~how:`Sequential to_fetch ~f:(fun sym ->
            fetch_one ~fetch ~rate_limit_rps sym >>| fun r ->
            let idx = !success_count + List.length !errors + 1 in
            (match r.sector with
            | Some sector ->
                Hashtbl.set existing ~key:r.symbol ~data:sector;
                Int.incr success_count;
                printf "  [%d/%d] %s → %s\n%!" idx total sym sector
            | None ->
                errors := r.symbol :: !errors;
                let msg = Option.value r.error ~default:"unknown error" in
                eprintf "  [%d/%d] %s → WARN: %s\n%!" idx total sym msg);
            if idx % checkpoint_interval = 0 then
              write_checkpoint ~final:false ();
            r)
      in
      write_checkpoint ~final:true ();
      let err_count = List.length !errors in
      let ok_count = !success_count in
      let success_pct =
        if total > 0 then Float.of_int ok_count /. Float.of_int total *. 100.0
        else 100.0
      in
      printf "Done: %d/%d fetched (%.1f%%), %d errors, %d total rows.\n%!"
        ok_count total success_pct err_count (Hashtbl.length existing);
      if Float.( < ) success_pct 80.0 then
        eprintf "WARNING: Success rate %.1f%% is below 80%% threshold.\n%!"
          success_pct;
      return ()
