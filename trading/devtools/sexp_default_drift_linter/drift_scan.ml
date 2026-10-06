(* Exceptions-conf reading and lib/*.ml{,i} file collection. *)

let read_exceptions conf_path =
  match open_in conf_path with
  | exception Sys_error _ -> []
  | ic ->
      let result = ref [] in
      (try
         while true do
           let line = input_line ic in
           let t = String.trim line in
           if String.length t = 0 || t.[0] = '#' then ()
           else
             match
               List.filter
                 (fun s -> String.length s > 0)
                 (String.split_on_char ' ' t)
             with
             | linter :: key :: _ when String.equal linter "sexp_default_drift"
               ->
                 result := key :: !result
             | _ -> ()
         done
       with End_of_file -> ());
      close_in ic;
      !result

(* --- File collection -------------------------------------------------------- *)

let is_excluded_dir entry =
  String.equal entry "_build"
  || String.equal entry "ta_ocaml"
  || String.equal entry ".claude"

(* Below this many scanned lib/*.ml + lib/*.mli files, the scan is treated as
   implausible rather than "a clean tree happens to be small". Measured on
   the shipped tree (2026-08-21): 862 files match the collection filter
   below. 500 leaves >40% headroom for ordinary file deletions/refactors
   while still catching the failure modes this guards against -- an empty or
   absent [trading-root] argument, a moved trading/ dir, or a wrong-cwd
   invocation, all of which collapse the count to 0 or near it. This is a
   floor, not a target: it only needs to sit comfortably below "normal" and
   comfortably above "the scan found basically nothing".

   What this floor does NOT do on its own: catch an arbitrary partial loss.
   A subtree lost because a directory failed to read is now caught
   separately and unconditionally by [_check_walk_failures] below (loud
   regardless of how many files were under it -- see [collect_lib_files]).
   A partial loss from some OTHER cause that never raises inside [walk] is
   only caught here, and only once it is large enough to push the total
   below this floor -- e.g. against the 862-file tree, roughly 362 files
   would have to vanish silently and by some path other than a walk failure
   before this floor alone would notice. Nothing currently re-measures 500
   as the tree grows; if the real count drifts far out of step with it
   (`find trading -path '*/lib/*.ml' -o -path '*/lib/*.mli' | wc -l`),
   tighten the constant. *)
let min_expected_lib_files = 500

(* [Sys.readdir] on a subdirectory discovered mid-walk can fail for benign
   reasons (a symlink race, a directory removed between listing and
   recursing, or unreadable permissions). These are no longer swallowed:
   [collect_lib_files] records each one and [_check_walk_failures] reports
   it by name and exits 1 regardless of how many files were lost under it --
   partial loss from a walk failure is loud by construction, not merely
   caught when it happens to breach [min_expected_lib_files]. What remains
   here is the separate top-level case: the [trading-root] argument itself
   missing, not-a-directory, or unreadable, which needs its own specific
   message because [collect_lib_files] never gets to walk anything. *)
let validate_root_readable root =
  if not (Sys.file_exists root) then
    Some (Printf.sprintf "trading-root does not exist: %s" root)
  else if not (Sys.is_directory root) then
    Some (Printf.sprintf "trading-root is not a directory: %s" root)
  else
    match Sys.readdir root with
    | exception Sys_error msg ->
        Some (Printf.sprintf "trading-root is not readable: %s (%s)" root msg)
    | _ -> None

(* [lib/*.ml] and [lib/*.mli] under [root] -- exactly the surface every
   known instance of this defect class lives on (record types with
   [@@deriving sexp] and .mli companions), and matches the scope other
   dune-wired structural linters in this repo use (linter_file_length.sh,
   linter_mli_coverage.sh).

   Both [.pp.ml] and [.pp.mli] are excluded: these are ppx-preprocessed
   build byproducts (post-rewrite output of a .ml/.mli that carries a ppx
   deriver), not source. They only appear on disk under [_build/], but this
   linter runs as a dune rule whose sandbox mirrors the relevant slice of
   [_build/default/] -- so when [root] resolves to that sandbox, plain
   [lib/*.mli] globbing picks up ppx output sitting alongside the real
   source in the same [lib/] directory. Discovered via
   H-SEXP-DRIFT-SILENT-PARSE-SKIP: before that fix, [.pp.mli] files (the
   [.ml] half was already excluded, but [.mli] was not) silently failed to
   parse and were dropped with no signal; making parse failures loud
   surfaced this as a real, reproducible FAIL on every `dune runtest`
   invocation of this rule, which is what motivated excluding them here
   rather than merely reporting on them. *)
(* Returns the collected files alongside every directory [Sys.readdir]
   failed on during the walk, paired with the raw error message -- see the
   docstring above [min_expected_lib_files] for why this must be surfaced
   rather than swallowed. *)
let collect_lib_files root =
  let result = ref [] in
  let failed_dirs = ref [] in
  let rec walk dir =
    match Sys.readdir dir with
    | exception Sys_error msg -> failed_dirs := (dir, msg) :: !failed_dirs
    | entries ->
        Array.iter
          (fun entry ->
            if is_excluded_dir entry then ()
            else
              let path = Filename.concat dir entry in
              if Sys.is_directory path then walk path
              else if
                String.equal (Filename.basename dir) "lib"
                && (Filename.check_suffix path ".ml"
                   || Filename.check_suffix path ".mli")
                && (not (Filename.check_suffix path ".pp.ml"))
                && not (Filename.check_suffix path ".pp.mli")
              then result := path :: !result)
          entries
  in
  walk root;
  (!result, !failed_dirs)

let read_file path =
  let ic = open_in path in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  content
