(** Magic-number linter: bare numeric literals in lib/*.ml files must be routed
    through a config record or a named constant.

    Rewrite of the former [trading/devtools/checks/linter_magic_numbers.sh]
    (removed). The shell version forked ~8-10 subprocesses PER SOURCE LINE
    (grep/wc/sed for comment-depth tracking, quote counting, and candidate
    extraction) -- roughly 460k-575k process spawns across the ~57k lines in
    ~445 lib/*.ml files, which under Docker-on-macOS took ~35 minutes. This
    version does the same per-line scanning in a single process with no forking:
    same algorithm, same exceptions, same output format, ~35min -> low seconds.

    Usage: magic_numbers_linter <trading-root> <exceptions-conf-path>

    Exit 0 with an "OK: ..." line if no violations are found. Exit 1 with a
    "FAIL: ..." line and per-violation detail otherwise.

    Known cosmetic divergence from the shell version: the shell script's final
    report used [printf '%b' "$VIOLATIONS"], which re-interprets any
    backslash-escape-looking substring INSIDE a flagged source line (e.g. a
    literal "\n" appearing in an OCaml string literal on the flagged line) as an
    escape sequence in the diagnostic text. This version prints violation lines
    verbatim (no such re-interpretation). This never changes whether a line is
    flagged, the exit code, or the FAIL:/OK: line -- only the rendering of
    embedded backslash sequences in the detail text for a line that both (a)
    contains a magic number and (b) contains a literal backslash-escape-like
    substring. *)

(* --- Small string utilities (mirrors devtools/list_active_exceptions.ml's
   style: no external string/regex library, plain char-level scanning). --- *)

let contains_substring s sub =
  let n = String.length s and m = String.length sub in
  if m > n then false
  else
    let found = ref false in
    let i = ref 0 in
    while (not !found) && !i + m <= n do
      if String.sub s !i m = sub then found := true;
      incr i
    done;
    !found

let count_occurrences s sub =
  let n = String.length s and m = String.length sub in
  if m = 0 || m > n then 0
  else begin
    let count = ref 0 in
    let i = ref 0 in
    while !i + m <= n do
      if String.sub s !i m = sub then begin
        incr count;
        i := !i + m
      end
      else incr i
    done;
    !count
  end

let count_char s c =
  let n = String.length s in
  let count = ref 0 in
  for i = 0 to n - 1 do
    if s.[i] = c then incr count
  done;
  !count

let ends_with s suffix =
  let n = String.length s and m = String.length suffix in
  m <= n && String.sub s (n - m) m = suffix

let trim s =
  let n = String.length s in
  let i = ref 0 in
  while !i < n && (s.[!i] = ' ' || s.[!i] = '\t') do
    incr i
  done;
  let j = ref (n - 1) in
  while !j >= !i && (s.[!j] = ' ' || s.[!j] = '\t' || s.[!j] = '\r') do
    decr j
  done;
  if !j < !i then "" else String.sub s !i (!j - !i + 1)

(* Split a string on runs of whitespace (spaces/tabs), like awk's default
   field splitting: leading/trailing whitespace ignored, empty fields
   collapsed. *)
let split_fields s =
  let n = String.length s in
  let fields = ref [] in
  let buf = Buffer.create 16 in
  let flush () =
    if Buffer.length buf > 0 then begin
      fields := Buffer.contents buf :: !fields;
      Buffer.clear buf
    end
  in
  for i = 0 to n - 1 do
    match s.[i] with ' ' | '\t' -> flush () | c -> Buffer.add_char buf c
  done;
  flush ();
  List.rev !fields

(* --- linter_exceptions.conf: magic_numbers path-substring exclusions --- *)

(* Format per non-comment/non-blank line: "<linter> <path-substring> <reason>
   [# review_at: ...]". We only need field 1 (linter) and field 2 (path
   substring) for the magic_numbers section; the reason/review_at trailer is
   irrelevant to this linter (that's list_active_exceptions.ml's job). *)
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

(* Mirrors `find "$root" \( -name '_build' -o -name '.formatted' \) -prune -o
   -path "*/lib/*.ml" -not -name "*.pp.ml" -print`: NO `-type f`, so an
   entry matching the path pattern is printed whether it's a regular file or
   a directory (e.g. the sete_diagnostics_check.sh fixture uses a directory
   named "unreadable_dir.ml" to deterministically fail a read). A matching
   directory is both printed AND still walked into (only _build/.formatted
   are pruned from descent). *)
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

(* --- Per-line skip predicates (each mirrors one `case ... continue` guard
   in the shell script, in the same order). --- *)

let is_digit c = c >= '0' && c <= '9'

let is_word_or_dot c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || is_digit c || c = '_' || c = '.'

(* "= <digit>" or "= -<digit>" anywhere in the line (record field default /
   negative default), e.g. "field = 42" or "x = -5". *)
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

(* first index of a substring, or None *)
let find_substring s sub ~from =
  let n = String.length s and m = String.length sub in
  if m = 0 then None
  else
    let rec scan i =
      if i + m > n then None
      else if String.sub s i m = sub then Some i
      else scan (i + 1)
    in
    scan from

(* "let <name> = <...>" or "let <name>=<digit>" -- named constant / binding
   lines. Mirrors the glob `*'let '*' = '* | *'let '*'='[0-9]*`: find the
   FIRST "let " occurrence, then check whether " = " (resp. "="+digit)
   occurs anywhere from its end onward. *)
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
  || count_char line '"' mod 2 <> 0
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

let digit_run_end s start =
  let n = String.length s in
  let j = ref start in
  while !j < n && is_digit s.[!j] do
    incr j
  done;
  !j

let lookahead_ok s pos = pos >= String.length s || not (is_word_or_dot s.[pos])

(* Try to match the alternation starting exactly at [i] (lookbehind already
   verified by the caller). Returns the matched substring and the index just
   past it, or None if neither alternative matches at this start. *)
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

(* Remove double-quoted segments (mirrors the shell version's sed global
   substitution that deletes each quote-delimited span). Only called on
   lines already known to have an even total count of double-quote
   characters. *)
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

(* Scan one file's lines, appending "path: num in: line" violation entries
   (without trailing newline; the caller joins with "\n"). *)
let scan_file_lines path lines violations =
  let comment_depth = ref 0 in
  List.iter
    (fun line ->
      let opens = count_occurrences line "(*" in
      let closes = count_occurrences line "*)" in
      let skip_this_line = !comment_depth > 0 in
      comment_depth := !comment_depth + opens - closes;
      if !comment_depth < 0 then comment_depth := 0;
      if not skip_this_line then
        if not (should_skip_line line) then begin
          let candidates = extract_candidates line in
          List.iter
            (fun num ->
              if not (is_exempt_literal num) then begin
                let stripped = strip_quoted_segments line in
                if contains_substring stripped num then
                  violations :=
                    Printf.sprintf "%s: %s in: %s" path num line :: !violations
              end)
            candidates
        end)
    lines

(* --- Unreadable-file handling: mirrors the shell script's TOCTOU-aware
   probe (H-CHECK-SETE-DIAGNOSTICS FINDING-1) -- a file that vanished between
   `find` and the scan is silently skipped; a file that still exists but
   cannot be read (permission, I/O, or "is actually a directory" as in the
   sete_diagnostics_check.sh fixture) is a hard violation, never a silent
   pass. --- *)
let scan_file path violations =
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
  | Ok lines -> scan_file_lines path lines violations
  | Error _ ->
      if Sys.file_exists path then
        violations :=
          Printf.sprintf
            "%s: could not read file to scan for magic numbers (exists but the \
             read failed -- permission, I/O, or type error; \
             H-CHECK-SETE-DIAGNOSTICS FINDING-1)"
            path
          :: !violations
(* else: vanished between discovery and scan -- skip, matches the
         shell script's TOCTOU guard. *)

let () =
  if Array.length Sys.argv < 3 then begin
    Printf.eprintf
      "Usage: magic_numbers_linter <trading-root> <exceptions-conf-path>\n";
    exit 2
  end;
  let trading_root = Sys.argv.(1) in
  let exceptions_conf = Sys.argv.(2) in
  let excludes = read_magic_number_exclusions exceptions_conf in
  let files =
    collect_lib_ml_files trading_root
    |> List.filter (fun f -> not (is_excluded excludes f))
  in
  let violations = ref [] in
  List.iter (fun f -> if Sys.file_exists f then scan_file f violations) files;
  let violations = List.rev !violations in
  if violations <> [] then begin
    print_string
      "FAIL: magic number linter \xe2\x80\x94 bare numeric literals in lib/ \
       files.\n";
    print_string
      "Route values through a config record, or add a path exception to \
       linter_exceptions.conf.\n";
    print_string "\n";
    List.iter
      (fun v ->
        print_string v;
        print_char '\n')
      violations;
    exit 1
  end
  else begin
    print_string "OK: no magic numbers found in lib/ files.\n";
    exit 0
  end
