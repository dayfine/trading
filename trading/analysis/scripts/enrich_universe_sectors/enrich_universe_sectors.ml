(** Populate [Instrument_info.sector] on universe.sexp from [data/sectors.csv].

    Reads [data_dir/universe.sexp] (produced by {!fetch_universe} or
    {!bootstrap_universe}) and [data_dir/sectors.csv] (produced by
    {!fetch_sectors} — the Wikipedia scraper), then rewrites universe.sexp with
    [sector] populated for the covered subset. Symbols not in the sector CSV
    keep their existing [sector] value (typically the empty string left by
    [fetch_universe]).

    This is the glue between the Python sector scraper and the OCaml universe
    file. It is idempotent — running it repeatedly is a no-op once the CSV has
    been applied.

    Typical usage:
    {v
      enrich_universe_sectors.exe                       # use default data dir
      enrich_universe_sectors.exe -data-dir /my/data    # custom dir
    v} *)

open Core

(* Merge sector from [map] into [instr] when [map] has an entry for its
   symbol AND the existing sector is empty. Preserving a non-empty
   existing sector means this script never overwrites curated values,
   e.g. hand-edited overrides that outrank the Wikipedia scrape. *)
let _apply_sector map (instr : Types.Instrument_info.t) :
    Types.Instrument_info.t =
  if not (String.is_empty instr.sector) then instr
  else
    match Sector_map.find map instr.symbol with
    | None -> instr
    | Some sector -> { instr with sector }

let _count_populated (instruments : Types.Instrument_info.t list) =
  List.count instruments ~f:(fun i -> not (String.is_empty i.sector))

let _die fmt =
  Printf.ksprintf
    (fun s ->
      prerr_endline s;
      exit 1)
    fmt

let _load_sector_map ~data_dir =
  match Sector_map.load ~data_dir with
  | Ok m ->
      Printf.printf "Loaded sectors.csv: %d symbols\n%!" (Sector_map.size m);
      m
  | Error e -> _die "Error loading sectors.csv: %s" (Status.show e)

let _load_universe ~data_dir_str =
  let result =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Universe.get_deferred data_dir_str)
  in
  match result with
  | Ok [] ->
      _die
        "universe.sexp is empty — run fetch_universe.exe or \
         bootstrap_universe.exe first"
  | Ok instruments -> instruments
  | Error e -> _die "Error loading universe.sexp: %s" (Status.show e)

let _write_universe ~data_dir enriched =
  match Universe.save ~data_dir enriched with
  | Ok () -> Printf.printf "Wrote universe.sexp with enriched sectors.\n%!"
  | Error e -> _die "Error writing universe.sexp: %s" (Status.show e)

let main ~data_dir_str () =
  let data_dir = Fpath.v data_dir_str in
  let sector_map = _load_sector_map ~data_dir in
  let instruments = _load_universe ~data_dir_str in
  let before = _count_populated instruments in
  let enriched = List.map instruments ~f:(_apply_sector sector_map) in
  let after = _count_populated enriched in
  Printf.printf "Universe: %d instruments; sector populated: %d -> %d (+%d)\n%!"
    (List.length instruments) before after (after - before);
  _write_universe ~data_dir enriched

let command =
  Command.basic
    ~summary:
      "Populate Instrument_info.sector on universe.sexp from data/sectors.csv"
    (let%map_open.Command data_dir =
       flag "data-dir"
         (optional_with_default
            (Data_path.default_data_dir () |> Fpath.to_string)
            string)
         ~doc:"PATH Data directory containing universe.sexp and sectors.csv"
     in
     fun () -> main ~data_dir_str:data_dir ())

let () = Command_unix.run command
