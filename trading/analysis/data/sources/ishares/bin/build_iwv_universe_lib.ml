open Core
module Client = Ishares.Ishares_holdings_client
module Replay = Ishares.Ishares_membership_replay

type cache_entry = { as_of : Date.t; csv_path : string } [@@deriving show, eq]

type filter_config = {
  require_equity_asset_class : bool;
  require_us_location : bool;
}
[@@deriving show, eq]

let default_filter_config =
  { require_equity_asset_class = true; require_us_location = true }

let _equity_asset_class = "Equity"
let _us_location = "United States"
let _csv_extension = ".csv"

(* [YYYY-MM-DD.csv] filename → Date.t. Returns [None] on any structural
   mismatch so the caller can skip non-matching entries (e.g. README files
   or sentinel markers) without aborting the scan. *)
let _date_of_basename basename =
  if not (String.is_suffix basename ~suffix:_csv_extension) then None
  else
    let stem = String.drop_suffix basename (String.length _csv_extension) in
    try Some (Date.of_string stem) with _ -> None

let _list_dir_entries dir =
  try Ok (Array.to_list (Sys_unix.readdir dir))
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to list cache directory %s: %s" dir msg)

let _entry_in_window ~from ~until (entry : cache_entry) =
  Date.( <= ) from entry.as_of && Date.( <= ) entry.as_of until

let list_cache_entries ~cache_dir ~from ~until =
  let%bind.Result names = _list_dir_entries cache_dir in
  let candidates =
    List.filter_map names ~f:(fun name ->
        match _date_of_basename name with
        | None -> None
        | Some as_of ->
            Some { as_of; csv_path = Filename.concat cache_dir name })
  in
  let in_window = List.filter candidates ~f:(_entry_in_window ~from ~until) in
  Ok (List.sort in_window ~compare:(fun a b -> Date.compare a.as_of b.as_of))

let _read_file path =
  try Ok (In_channel.read_all path)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read %s: %s" path msg)

(* Apply both row-level filters per the [filter_config]. Order doesn't matter
   for the [&&] composition but writing them as separate steps keeps the
   intent clear. *)
let _row_passes_filter ~(filter : filter_config) (h : Client.holding) =
  let asset_ok =
    (not filter.require_equity_asset_class)
    || String.equal h.asset_class _equity_asset_class
  in
  let location_ok =
    (not filter.require_us_location) || String.equal h.location _us_location
  in
  asset_ok && location_ok

let _filter_snapshot ~filter (snap : Client.snapshot) : Client.snapshot =
  {
    snap with
    holdings = List.filter snap.holdings ~f:(_row_passes_filter ~filter);
  }

(* Load one cache entry. Returns [Ok None] when the body parses to
   [No_data_sentinel] (skippable) or [Ok (Some (date, snap))] when it carries
   data. [Error] propagates structural parse failures. *)
let _load_one ~filter (entry : cache_entry) :
    (Date.t * Client.snapshot) option Status.status_or =
  let%bind.Result body = _read_file entry.csv_path in
  let%bind.Result outcome = Client.parse body in
  match outcome with
  | Client.No_data_sentinel -> Ok None
  | Client.Parsed snap -> Ok (Some (entry.as_of, _filter_snapshot ~filter snap))

let load_and_filter ~entries ~filter =
  let rec loop acc = function
    | [] -> Ok (List.rev acc)
    | entry :: rest -> (
        match _load_one ~filter entry with
        | Error _ as e -> e
        | Ok None -> loop acc rest
        | Ok (Some pair) -> loop (pair :: acc) rest)
  in
  loop [] entries

type outcome = {
  universe_sexp : Sexp.t;
  member_count : int;
  snapshot_count : int;
  removed_count : int;
}

let _active_on ~as_of (t : Replay.tenure_record) =
  Date.( <= ) t.first_seen as_of && Date.( <= ) as_of t.last_seen

let _tenure_to_sexp_pair (t : Replay.tenure_record) =
  Sexp.List
    [
      Sexp.List [ Sexp.Atom "symbol"; Sexp.Atom t.ticker ];
      Sexp.List [ Sexp.Atom "sector"; Sexp.Atom t.sector_at_first ];
    ]

let _to_universe_sexp (tenures : Replay.tenure_record list) =
  let sorted =
    List.sort tenures ~compare:(fun a b -> String.compare a.ticker b.ticker)
  in
  let entries = List.map sorted ~f:_tenure_to_sexp_pair in
  Sexp.List [ Sexp.Atom "Pinned"; Sexp.List entries ]

let build_universe ~snapshots ~threshold_consecutive_misses ~as_of =
  let snapshot_count = List.length snapshots in
  let tenures = Replay.replay ~threshold_consecutive_misses snapshots in
  let active = List.filter tenures ~f:(_active_on ~as_of) in
  let removed_count = List.length tenures - List.length active in
  let universe_sexp = _to_universe_sexp active in
  {
    universe_sexp;
    member_count = List.length active;
    snapshot_count;
    removed_count;
  }

let _header_comment ~as_of ~from ~until ~snapshot_count ~member_count
    ~removed_count =
  Printf.sprintf
    ";; Russell 3000 universe (IWV-derived) — build_iwv_universe.exe.\n\
     ;; as-of: %s | members: %d | snapshots replayed: %d | tenures removed in \
     window: %d\n\
     ;; window: %s .. %s\n\
     ;; Source: pinned iShares IWV holdings via fetch_iwv_history.exe;\n\
     ;; replay via Ishares_membership_replay.replay (3-snapshot threshold).\n\
     ;; Caveat: IWV is a sampled tracker of the Russell 3000 index;\n\
     ;; tracking error ~5-15 bps and membership lists are close-but-not-\n\
     ;; identical (plan §6 risk 1). See\n\
     ;; dev/plans/iwv-scraper-2026-05-16.md §PR-D.\n\
     ;;\n"
    (Date.to_string as_of) member_count snapshot_count removed_count
    (Date.to_string from) (Date.to_string until)

let _write_atomic ~path ~contents =
  let tmp = path ^ ".tmp" in
  try
    (try Core_unix.mkdir_p (Filename.dirname path) with _ -> ());
    Out_channel.with_file tmp ~f:(fun oc ->
        Out_channel.output_string oc contents);
    Core_unix.rename ~src:tmp ~dst:path;
    Ok ()
  with
  | Sys_error msg ->
      Status.error_internal (Printf.sprintf "write %s failed: %s" path msg)
  | Core_unix.Unix_error (err, _, _) ->
      Status.error_internal
        (Printf.sprintf "rename to %s failed: %s" path
           (Core_unix.Error.message err))

let write_outcome_to_file ~path ~as_of ~from ~until (outcome : outcome) =
  let header =
    _header_comment ~as_of ~from ~until ~snapshot_count:outcome.snapshot_count
      ~member_count:outcome.member_count ~removed_count:outcome.removed_count
  in
  let body = Sexp.to_string_hum outcome.universe_sexp ^ "\n" in
  _write_atomic ~path ~contents:(header ^ body)

let run ~cache_dir ~output ~from ~until ~as_of ~threshold_consecutive_misses
    ?(filter = default_filter_config) () =
  let%bind.Result entries = list_cache_entries ~cache_dir ~from ~until in
  let%bind.Result snapshots = load_and_filter ~entries ~filter in
  let outcome =
    build_universe ~snapshots ~threshold_consecutive_misses ~as_of
  in
  let%bind.Result () =
    write_outcome_to_file ~path:output ~as_of ~from ~until outcome
  in
  Ok outcome
