(** Emit a fixture universe from an all-eligible capture.

    Usage:
    {v
      pick.exe --capture <trades.csv> [--capture <trades.csv> ...] \
               --data-dir <dir> --window <label> --min-grade <G> \
               [--default-sector <name>] [-o <out.sexp>]
    v}

    Reads the [symbol] column of each capture, unions
    {!Candidate_universe.required_context_symbols}, resolves sectors from
    [<data-dir>/sectors.csv], and writes a pinned universe file with a
    provenance header.

    This script is not run from CI or [dune runtest]; it produces a committed
    fixture, and the fixture is what tests consume. The emitted universe is a
    {b hypothesis} until the window is re-run against it and the trade list is
    diffed against the full-universe run — see the README. *)

open Core
module Universe_file = Scenario_lib.Universe_file

type args = {
  captures : string list;
  data_dir : string;
  from_universe : string option;
  window : string;
  min_grade : string;
  default_sector : string;
  out : string option;
}

let _usage () =
  eprintf
    "Usage: pick.exe --capture <trades.csv> [--capture ...] --data-dir <dir> \
     --window <label> --min-grade <G> [--default-sector <name>] [-o <path>]\n";
  Stdlib.exit 2

let _parse argv =
  let rec loop acc = function
    | [] -> acc
    | "--capture" :: v :: rest ->
        loop { acc with captures = v :: acc.captures } rest
    | "--data-dir" :: v :: rest -> loop { acc with data_dir = v } rest
    | "--from-universe" :: v :: rest ->
        loop { acc with from_universe = Some v } rest
    | "--window" :: v :: rest -> loop { acc with window = v } rest
    | "--min-grade" :: v :: rest -> loop { acc with min_grade = v } rest
    | "--default-sector" :: v :: rest ->
        loop { acc with default_sector = v } rest
    | "-o" :: v :: rest -> loop { acc with out = Some v } rest
    | flag :: _ ->
        eprintf "pick.exe: unrecognised or incomplete argument: %s\n" flag;
        _usage ()
  in
  let acc =
    loop
      {
        captures = [];
        data_dir = "data";
        from_universe = None;
        window = "";
        min_grade = "";
        default_sector = "Unknown";
        out = None;
      }
      (List.tl_exn (Array.to_list argv))
  in
  if List.is_empty acc.captures then (
    eprintf "pick.exe: at least one --capture is required\n";
    _usage ());
  if String.is_empty acc.window || String.is_empty acc.min_grade then (
    eprintf
      "pick.exe: --window and --min-grade are required — they are the \
       provenance a derived fixture cannot be verified without\n";
    _usage ());
  { acc with captures = List.rev acc.captures }

let () =
  let args = _parse (Sys.get_argv ()) in
  let symbols =
    List.fold args.captures ~init:String.Set.empty ~f:(fun acc path ->
        let contents = In_channel.read_all path in
        Set.union acc (Candidate_universe.symbols_of_all_eligible_csv ~contents))
  in
  let sectors = Sector_map.load ~data_dir:(Fpath.v args.data_dir) in
  (* Prefer the SOURCE universe's own sectors: it is what the full run used, so
     inheriting from it guarantees the fixture's sector assignments match the run
     being reproduced. sectors.csv is the fallback for symbols it lacks (the
     context ETFs) — relying on it alone resolved 297 of 304 symbols to the
     default on the first real run, which would have collapsed the sector
     filter. *)
  let from_universe =
    match args.from_universe with
    | None -> fun _ -> None
    | Some path ->
        Candidate_universe.sector_of_universe (Universe_file.load path)
  in
  let sector_of =
    Candidate_universe.first_available
      [ from_universe; (fun s -> Hashtbl.find sectors s) ]
  in
  let entries =
    Candidate_universe.build ~candidate_symbols:symbols ~sector_of
      ~default_sector:args.default_sector ()
  in
  let unresolved =
    Candidate_universe.unresolved_sectors ~candidate_symbols:symbols ~sector_of
      ()
  in
  let provenance =
    [
      "Fixture universe derived from an all-eligible capture — GENERATED, do \
       not hand-edit.";
      "";
      sprintf "window:      %s" args.window;
      sprintf "min_grade:   %s" args.min_grade;
      sprintf "captures:    %s" (String.concat ~sep:", " args.captures);
      sprintf "candidates:  %d symbols seen in the capture" (Set.length symbols);
      sprintf
        "context:     %d always-included instruments (macro index + sector \
         ETFs)"
        (List.length Candidate_universe.required_context_symbols);
      sprintf "total:       %d symbols" (List.length entries);
      sprintf "sectors:     inherited from %s, fallback %s/sectors.csv"
        (Option.value args.from_universe ~default:"(none)")
        args.data_dir;
      sprintf "unresolved:  %d symbols fell back to the default sector"
        (List.length unresolved);
      "";
      "Soundness: dropping a symbol that never became a candidate cannot change";
      "the run, PROVIDED the capture was taken at the lowest gate (min_grade F)";
      "so it is the superset over variants. This file is a hypothesis until the";
      "window is re-run against it and the trade list matches the full run.";
    ]
  in
  let text = Candidate_universe.render ~entries ~provenance in
  (match args.out with
  | Some path ->
      Out_channel.write_all path ~data:text;
      printf "pick.exe: wrote %d symbols to %s\n" (List.length entries) path
  | None -> print_string text);
  if not (List.is_empty unresolved) then
    eprintf "pick.exe: %d symbols had no sector and fell back to %S: %s\n"
      (List.length unresolved) args.default_sector
      (String.concat ~sep:" " (List.take unresolved 20))
