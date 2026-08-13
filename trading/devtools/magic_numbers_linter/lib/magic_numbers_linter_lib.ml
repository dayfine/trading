(* See magic_numbers_linter_lib.mli for the module-level rationale and the
   full exempt-surface documentation. This file mirrors the former
   [trading/devtools/checks/linter_magic_numbers.sh] (removed) line-by-line:
   same skip rules in the same order, same PCRE-alternation-with-backtracking
   semantics for numeric-token extraction, same unreadable-file diagnostics.

   Known cosmetic divergence from the shell version: the shell script's final
   report used [printf '%b' "$VIOLATIONS"], which re-interprets any
   backslash-escape-looking substring INSIDE a flagged source line (e.g. a
   literal "\n" appearing in an OCaml string literal on the flagged line) as
   an escape sequence in the diagnostic text. This version prints violation
   lines verbatim (no such re-interpretation). This never changes whether a
   line is flagged, the exit code, or the FAIL:/OK: line -- only the
   rendering of embedded backslash sequences in the detail text for a line
   that both (a) contains a magic number and (b) contains a literal
   backslash-escape-like substring. *)

(* Generic char-level string helpers (contains_substring, count_occurrences,
   ends_with, split_fields, find_substring, is_digit, is_word_or_dot,
   digit_run_end, lookahead_ok) live in String_utils; which files get
   scanned and which are excluded lives in File_discovery. Both extracted
   purely to keep this file under the file-length linter's limit -- see
   string_utils.mli / file_discovery.mli. *)
open String_utils

(* --- Per-line skip predicates (each mirrors one `case ... continue` guard
   in the shell script, in the same order). --- *)

let has_eq_digit_default line =
  let n = String.length line in
  let rec scan i =
    if i >= n then false
    else if
      i + 2 < n && line.[i] = '=' && line.[i + 1] = ' ' && is_digit line.[i + 2]
    then true
    else if
      i + 3 < n
      && line.[i] = '='
      && line.[i + 1] = ' '
      && line.[i + 2] = '-'
      && is_digit line.[i + 3]
    then true
    else scan (i + 1)
  in
  scan 0

let has_let_binding line =
  match find_substring line "let " ~from:0 with
  | None -> false
  | Some p1 -> begin
      let after = p1 + 4 in
      let has_eq_space =
        match find_substring line " = " ~from:after with
        | Some _ -> true
        | None -> false
      in
      if has_eq_space then true
      else begin
        let n = String.length line in
        let rec scan i =
          if i >= n - 1 then false
          else if line.[i] = '=' && is_digit line.[i + 1] then true
          else scan (i + 1)
        in
        scan after
      end
    end

let should_skip_line line =
  contains_substring line "(*"
  || contains_substring line "*)"
  || contains_substring line "e.g."
  || ends_with line "\\"
  || count_occurrences line "\"" mod 2 <> 0
  || has_eq_digit_default line || has_let_binding line
  || contains_substring line "config."
  || contains_substring line "->"
  || contains_substring line "~f:"
  || contains_substring line "~len:"
  || contains_substring line "~pos:"

(* --- Numeric-candidate extraction: mirrors
   grep -oP '(?<![a-zA-Z0-9_.])([0-9]+\.[0-9]+|[0-9]{2,})(?![a-zA-Z0-9_.])'
   including PCRE backtracking semantics on the digit-run lengths, scanning
   left to right for non-overlapping matches. --- *)

let try_match_at s i =
  let n = String.length s in
  let la_end = digit_run_end s i in
  let la_len = la_end - i in
  let float_match =
    if
      la_end < n
      && s.[la_end] = '.'
      && la_end + 1 < n
      && is_digit s.[la_end + 1]
    then begin
      let second_start = la_end + 1 in
      let second_max = digit_run_end s second_start - second_start in
      let rec try_len len =
        if len < 1 then None
        else
          let end_pos = second_start + len in
          if lookahead_ok s end_pos then Some end_pos else try_len (len - 1)
      in
      try_len second_max
    end
    else None
  in
  match float_match with
  | Some end_pos -> Some (String.sub s i (end_pos - i), end_pos)
  | None -> (
      if la_len < 2 then None
      else
        let rec try_len len =
          if len < 2 then None
          else
            let end_pos = i + len in
            if lookahead_ok s end_pos then Some end_pos else try_len (len - 1)
        in
        match try_len la_len with
        | Some end_pos -> Some (String.sub s i (end_pos - i), end_pos)
        | None -> None)

let extract_candidates line =
  let n = String.length line in
  let results = ref [] in
  let i = ref 0 in
  while !i < n do
    if is_digit line.[!i] && (!i = 0 || not (is_word_or_dot line.[!i - 1])) then
      begin match try_match_at line !i with
      | Some (tok, next_i) ->
          results := tok :: !results;
          i := next_i
      | None -> incr i
      end
    else incr i
  done;
  List.rev !results

let is_exempt_literal = function
  | "0" | "1" | "0.0" | "1.0" | "2.0" | "0.5" | "100.0" -> true
  | _ -> false

let strip_quoted_segments line =
  let n = String.length line in
  let buf = Buffer.create n in
  let i = ref 0 in
  while !i < n do
    if line.[!i] = '"' then
      begin match find_substring line "\"" ~from:(!i + 1) with
      | Some j -> i := j + 1
      | None ->
          Buffer.add_substring buf line !i (n - !i);
          i := n
      end
    else begin
      Buffer.add_char buf line.[!i];
      incr i
    end
  done;
  Buffer.contents buf

(* --- Comment-depth tracking + per-line scan --- *)

(* Read lines the way `while IFS= read -r line; do ... done < file` does: a
   final line with no trailing newline is silently dropped (POSIX `read`
   returns non-zero on that partial read and the loop body never runs for
   it). Nearly all committed .ml files have a trailing newline (ocamlformat
   enforces it), so this only matters for pathological inputs. *)
let read_lines_like_shell_read ic =
  let lines = ref [] in
  let buf = Buffer.create 256 in
  (try
     while true do
       let c = input_char ic in
       if c = '\n' then begin
         lines := Buffer.contents buf :: !lines;
         Buffer.clear buf
       end
       else Buffer.add_char buf c
     done
   with End_of_file -> ());
  List.rev !lines

let scan_file_lines ~path lines =
  let comment_depth = ref 0 in
  List.concat_map
    (fun line ->
      let opens = count_occurrences line "(*" in
      let closes = count_occurrences line "*)" in
      let skip_this_line = !comment_depth > 0 in
      comment_depth := !comment_depth + opens - closes;
      if !comment_depth < 0 then comment_depth := 0;
      if skip_this_line || should_skip_line line then []
      else
        let stripped = lazy (strip_quoted_segments line) in
        extract_candidates line
        |> List.filter_map (fun num ->
            if is_exempt_literal num then None
            else if contains_substring (Lazy.force stripped) num then
              Some (Printf.sprintf "%s: %s in: %s" path num line)
            else None))
    lines

(* --- Unreadable-file handling: mirrors the shell script's TOCTOU-aware
   probe (H-CHECK-SETE-DIAGNOSTICS FINDING-1) -- a file that vanished between
   `find` and the scan is silently skipped; a file that still exists but
   cannot be read (permission, I/O, or "is actually a directory" as in the
   sete_diagnostics_check.sh fixture) is a hard violation, never a silent
   pass. --- *)
let scan_file path =
  (* On Linux, `open()` on a directory typically SUCCEEDS (returns a valid
     fd); the failure (EISDIR) only surfaces on the first read. So the
     Sys_error we need to catch can come from `open_in` OR from the first
     `input_char` inside `read_lines_like_shell_read` -- wrap the whole
     open+read sequence, not just the open. *)
  match
    try
      let ic = open_in path in
      let lines = read_lines_like_shell_read ic in
      close_in ic;
      Ok lines
    with Sys_error msg -> Error msg
  with
  | Ok lines -> scan_file_lines ~path lines
  | Error _ ->
      if Sys.file_exists path then
        [
          Printf.sprintf
            "%s: could not read file to scan for magic numbers (exists but the \
             read failed -- permission, I/O, or type error; \
             H-CHECK-SETE-DIAGNOSTICS FINDING-1)"
            path;
        ]
      else
        (* vanished between discovery and scan -- skip, matches the shell
           script's TOCTOU guard. *)
        []

let lint ~trading_root ~exceptions_conf =
  let excludes = File_discovery.read_magic_number_exclusions exceptions_conf in
  let files =
    File_discovery.collect_lib_ml_files trading_root
    |> List.filter (fun f -> not (File_discovery.is_excluded excludes f))
  in
  List.concat_map (fun f -> if Sys.file_exists f then scan_file f else []) files
