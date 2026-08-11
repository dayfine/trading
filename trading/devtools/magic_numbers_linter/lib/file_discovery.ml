(* See file_discovery.mli. Extracted from magic_numbers_linter_lib.ml purely
   to keep that file under the file-length linter's limit. *)
open String_utils

(* --- linter_exceptions.conf: magic_numbers path-substring exclusions --- *)

let read_magic_number_exclusions conf_path =
  if not (Sys.file_exists conf_path) then []
  else begin
    let ic = open_in conf_path in
    let excludes = ref [] in
    (try
       while true do
         let raw = input_line ic in
         if String.length raw > 0 && raw.[0] <> '#' then
           match split_fields raw with
           | linter :: path_substr :: _ when linter = "magic_numbers" ->
               excludes := path_substr :: !excludes
           | _ -> ()
       done
     with End_of_file -> ());
    close_in ic;
    List.rev !excludes
  end

let is_excluded excludes path =
  List.exists (fun sub -> contains_substring path sub) excludes

(* --- File discovery: mirrors
   find "$TRADING_DIR" \( -name '_build' -o -name '.formatted' \) -prune -o \
        -path "*/lib/*.ml" -not -name "*.pp.ml" -print
   -- prune _build/.formatted dirs at any depth; select files whose path
   contains "/lib/" and ends in ".ml" but not ".pp.ml". --- *)

let is_pruned_dir name = name = "_build" || name = ".formatted"

let matches_lib_ml_pattern path =
  ends_with path ".ml"
  && (not (ends_with path ".pp.ml"))
  && contains_substring path "/lib/"

let collect_lib_ml_files root =
  let result = ref [] in
  let rec walk dir =
    match Sys.readdir dir with
    | exception _ -> ()
    | entries ->
        Array.sort String.compare entries;
        Array.iter
          (fun entry ->
            if is_pruned_dir entry then ()
            else begin
              let path = Filename.concat dir entry in
              if matches_lib_ml_pattern path then result := path :: !result;
              match Sys.is_directory path with
              | true -> walk path
              | false -> ()
              | exception _ -> ()
            end)
          entries
  in
  walk root;
  List.rev !result
