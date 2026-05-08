(** List active linter exceptions from linter_exceptions.conf and inline
    [@large-module] / [@large-function] markers in .ml files.

    Usage: list_active_exceptions <trading-root>

    Output is a markdown report on stdout. Exits 0 always — passive linter. *)

(* --- Utilities -------------------------------------------------------------- *)

let contains_substring s sub =
  let n = String.length s and m = String.length sub in
  if m > n then false
  else
    let found = ref false in
    let i = ref 0 in
    while !i + m <= n && not !found do
      if String.sub s !i m = sub then found := true;
      incr i
    done;
    !found

(* Split a string on a delimiter character, returning all parts. *)
let split_on_char_custom c s =
  let parts = ref [] in
  let buf = Buffer.create 16 in
  String.iter
    (fun ch ->
      if Char.equal ch c then begin
        parts := Buffer.contents buf :: !parts;
        Buffer.clear buf
      end
      else Buffer.add_char buf ch)
    s;
  parts := Buffer.contents buf :: !parts;
  List.rev !parts

(* Strip leading and trailing whitespace. *)
let trim s =
  let n = String.length s in
  let i = ref 0 in
  while
    !i < n && (s.[!i] = ' ' || s.[!i] = '\t' || s.[!i] = '\n' || s.[!i] = '\r')
  do
    incr i
  done;
  let j = ref (n - 1) in
  while
    !j >= !i && (s.[!j] = ' ' || s.[!j] = '\t' || s.[!j] = '\n' || s.[!j] = '\r')
  do
    decr j
  done;
  if !j < !i then "" else String.sub s !i (!j - !i + 1)

(* --- Status computation ---------------------------------------------------- *)

(* Today's date as a YYYY-MM-DD string. *)
let today_str () =
  let t = Unix.gettimeofday () in
  let tm = Unix.gmtime t in
  Printf.sprintf "%04d-%02d-%02d" (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1)
    tm.Unix.tm_mday

(* Return true if [date_str] (YYYY-MM-DD) is strictly before [today]. *)
let date_is_past date_str today = String.compare date_str today < 0

(* Compute the status string for a given review_at annotation value. *)
let compute_status review_at_opt =
  let today = today_str () in
  match review_at_opt with
  | None -> "no-review-at"
  | Some v -> begin
      let v = trim v in
      if String.length v = 0 then "no-review-at"
      else begin
        (* Check for YYYY-MM-DD format *)
        let looks_like_date =
          String.length v = 10
          && v.[4] = '-'
          && v.[7] = '-'
          &&
          let digit c = c >= '0' && c <= '9' in
          digit v.[0]
          && digit v.[1]
          && digit v.[2]
          && digit v.[3]
          && digit v.[5]
          && digit v.[6]
          && digit v.[8]
          && digit v.[9]
        in
        if looks_like_date then
          if date_is_past v today then "expired" else "active"
        else if String.equal (String.lowercase_ascii v) "never" then "active"
        else "active"
      end
    end

(* Find "review_at:" in a string and return the text after it. *)
let extract_review_at s =
  let marker = "review_at:" in
  let mlen = String.length marker in
  let slen = String.length s in
  let rec search i =
    if i + mlen > slen then None
    else if String.sub s i mlen = marker then
      Some (trim (String.sub s (i + mlen) (slen - i - mlen)))
    else search (i + 1)
  in
  search 0

(* --- linter_exceptions.conf parsing ---------------------------------------- *)

type conf_entry = {
  linter : string;
  path_substr : string;
  reason : string;
  review_at : string option;
  status : string;
}

(* Parse a non-comment, non-blank line.
   Format: <linter> <path-substring> <reason>  # review_at: <value> *)
let parse_conf_line line =
  (* Split off the trailing # review_at: ... comment *)
  let review_at_opt, core =
    let rlen = String.length line in
    let found_at = ref None in
    for i = 0 to rlen - 1 do
      if
        line.[i] = '#'
        && contains_substring (String.sub line i (rlen - i)) "review_at:"
      then found_at := Some i
    done;
    match !found_at with
    | None -> (None, trim line)
    | Some i ->
        let comment = String.sub line (i + 1) (rlen - i - 1) in
        (extract_review_at comment, trim (String.sub line 0 i))
  in
  let tokens =
    split_on_char_custom ' ' core
    |> List.map trim
    |> List.filter (fun t -> String.length t > 0)
  in
  match tokens with
  | linter :: path_substr :: rest ->
      let reason = String.concat " " rest in
      let status = compute_status review_at_opt in
      Some { linter; path_substr; reason; review_at = review_at_opt; status }
  | _ -> None

let read_conf_entries conf_path =
  let ic = open_in conf_path in
  let entries = ref [] in
  (try
     while true do
       let line = trim (input_line ic) in
       if String.length line > 0 && line.[0] <> '#' then
         match parse_conf_line line with
         | Some e -> entries := e :: !entries
         | None -> ()
     done
   with End_of_file -> ());
  close_in ic;
  List.rev !entries

(* --- File collection ------------------------------------------------------- *)

let is_excluded_dir entry =
  String.equal entry "_build"
  || String.equal entry "ta_ocaml"
  || String.equal entry ".claude"
  || String.equal entry ".formatted"

let collect_all_ml_files root =
  let result = ref [] in
  let rec walk dir =
    match Sys.readdir dir with
    | exception _ -> ()
    | entries ->
        Array.iter
          (fun entry ->
            if is_excluded_dir entry then ()
            else
              let path = Filename.concat dir entry in
              if Sys.is_directory path then walk path
              else if
                Filename.check_suffix path ".ml"
                && not (Filename.check_suffix path ".pp.ml")
              then result := path :: !result)
          entries
  in
  walk root;
  !result

(* --- Inline marker scanning ------------------------------------------------ *)

type module_entry = {
  file : string;
  line_count : int;
  reason : string;
  review_at : string option;
  status : string;
}

type function_entry = {
  file_line : string;
  fn_name : string;
  fn_reason : string;
  fn_review_at : string option;
  fn_status : string;
}

(* Extract the reason text from a marker comment body.
   Strips a trailing "*)" if present, then splits off any "# review_at:" suffix. *)
let extract_marker_reason_and_reviewat text =
  let text =
    let n = String.length text in
    if n >= 2 && String.sub text (n - 2) 2 = "*)" then
      trim (String.sub text 0 (n - 2))
    else trim text
  in
  let review_at = extract_review_at text in
  let reason =
    match review_at with
    | None -> text
    | Some _ -> begin
        (* Strip from the '#' that introduces "review_at:" *)
        let marker = "review_at:" in
        let mlen = String.length marker in
        let slen = String.length text in
        let rec find_marker i =
          if i + mlen > slen then None
          else if String.sub text i mlen = marker then Some i
          else find_marker (i + 1)
        in
        match find_marker 0 with
        | None -> text
        | Some i ->
            let j = ref (i - 1) in
            while !j >= 0 && (text.[!j] = ' ' || text.[!j] = '\t') do
              decr j
            done;
            if !j >= 0 && text.[!j] = '#' then trim (String.sub text 0 !j)
            else trim (String.sub text 0 i)
      end
  in
  (trim reason, review_at)

(* Find the text after a marker keyword in a line. *)
let text_after_marker line marker =
  let mlen = String.length marker in
  let slen = String.length line in
  let rec find i =
    if i + mlen > slen then ""
    else if String.sub line i mlen = marker then
      String.sub line (i + mlen) (slen - i - mlen)
    else find (i + 1)
  in
  find 0

(* Try to extract a "let <name>" binding name from a line of source. *)
let find_let_name line =
  let tokens =
    split_on_char_custom ' ' (trim line)
    |> List.map trim
    |> List.filter (fun t -> String.length t > 0)
  in
  match tokens with
  | "let" :: name :: _ when not (String.equal name "rec") -> Some name
  | "let" :: "rec" :: name :: _ -> Some name
  | _ -> None

(* Count lines in a file (without storing them). *)
let count_lines path =
  let ic = open_in path in
  let n = ref 0 in
  (try
     while true do
       let _ = input_line ic in
       incr n
     done
   with End_of_file -> ());
  close_in ic;
  !n

(* Scan a single .ml file for @large-module and @large-function markers. *)
let scan_file path =
  let total_lines = count_lines path in
  let ic = open_in path in
  let lines = ref [] in
  (try
     while true do
       lines := input_line ic :: !lines
     done
   with End_of_file -> ());
  close_in ic;
  let lines = Array.of_list (List.rev !lines) in
  let mod_entries = ref [] in
  let fn_entries = ref [] in
  Array.iteri
    (fun i line ->
      (* @large-module — only detect genuine OCaml comment markers.
         Heuristic: the trimmed line must begin with "(*" (ruling out
         markers embedded inside string literals). *)
      if
        contains_substring line "@large-module:"
        &&
        let t = trim line in
        String.length t >= 2 && t.[0] = '(' && t.[1] = '*'
      then begin
        let after = text_after_marker line "@large-module:" in
        let reason, review_at = extract_marker_reason_and_reviewat after in
        let status = compute_status review_at in
        mod_entries :=
          { file = path; line_count = total_lines; reason; review_at; status }
          :: !mod_entries
      end;
      (* @large-function — only detect genuine OCaml comment markers. *)
      if
        contains_substring line "@large-function:"
        &&
        let t = trim line in
        String.length t >= 2 && t.[0] = '(' && t.[1] = '*'
      then begin
        let after = text_after_marker line "@large-function:" in
        let fn_reason, fn_review_at =
          extract_marker_reason_and_reviewat after
        in
        let fn_status = compute_status fn_review_at in
        (* Search this line and the next two for a "let" binding name *)
        let n = Array.length lines in
        let fn_name =
          let candidates =
            [
              line;
              (if i + 1 < n then lines.(i + 1) else "");
              (if i + 2 < n then lines.(i + 2) else "");
            ]
          in
          List.fold_left
            (fun acc s ->
              match acc with Some _ -> acc | None -> find_let_name s)
            None candidates
          |> Option.value ~default:"<unknown>"
        in
        fn_entries :=
          {
            file_line = Printf.sprintf "%s:%d" path (i + 1);
            fn_name;
            fn_reason;
            fn_review_at;
            fn_status;
          }
          :: !fn_entries
      end)
    lines;
  (List.rev !mod_entries, List.rev !fn_entries)

(* --- Markdown output ------------------------------------------------------- *)

let pad s width =
  let n = String.length s in
  if n >= width then s else s ^ String.make (width - n) ' '

let print_table headers rows =
  let ncols = List.length headers in
  let widths = Array.make ncols 0 in
  List.iteri (fun i h -> widths.(i) <- max widths.(i) (String.length h)) headers;
  List.iter
    (fun row ->
      List.iteri
        (fun i cell -> widths.(i) <- max widths.(i) (String.length cell))
        row)
    rows;
  (* Header row *)
  print_string "| ";
  List.iteri
    (fun i h ->
      print_string (pad h widths.(i));
      if i < ncols - 1 then print_string " | " else print_string " |\n")
    headers;
  (* Separator row *)
  print_string "|";
  Array.iter
    (fun w ->
      print_string (String.make (w + 2) '-');
      print_string "|")
    widths;
  print_char '\n';
  (* Data rows *)
  List.iter
    (fun row ->
      print_string "| ";
      let cells = Array.make ncols "" in
      List.iteri (fun i cell -> cells.(i) <- cell) row;
      Array.iteri
        (fun i cell ->
          print_string (pad cell widths.(i));
          if i < ncols - 1 then print_string " | " else print_string " |\n")
        cells)
    rows

let review_at_display = function None -> "(none)" | Some v -> v

(* --- Main ------------------------------------------------------------------ *)

let () =
  let trading_root =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else begin
      Printf.eprintf "Usage: list_active_exceptions <trading-root>\n";
      exit 2
    end
  in
  let conf_path =
    Filename.concat trading_root "devtools/checks/linter_exceptions.conf"
  in

  (* Section 1: linter_exceptions.conf entries *)
  let conf_entries =
    if Sys.file_exists conf_path then read_conf_entries conf_path else []
  in
  let n_conf = List.length conf_entries in
  Printf.printf "## linter_exceptions.conf entries (%d)\n\n" n_conf;
  if n_conf = 0 then print_endline "(none)\n"
  else begin
    let rows =
      List.map
        (fun e ->
          [
            e.linter;
            e.path_substr;
            e.reason;
            review_at_display e.review_at;
            e.status;
          ])
        conf_entries
    in
    print_table [ "linter"; "path"; "reason"; "review_at"; "status" ] rows;
    print_char '\n'
  end;

  (* Scan all .ml files for inline markers *)
  let ml_files =
    collect_all_ml_files trading_root |> List.sort String.compare
  in
  let all_mod_entries = ref [] in
  let all_fn_entries = ref [] in
  List.iter
    (fun path ->
      let mods, fns = scan_file path in
      all_mod_entries := !all_mod_entries @ mods;
      all_fn_entries := !all_fn_entries @ fns)
    ml_files;

  (* Section 2: @large-module markers *)
  let n_mod = List.length !all_mod_entries in
  Printf.printf "## @large-module markers (%d)\n\n" n_mod;
  if n_mod = 0 then print_endline "(none)\n"
  else begin
    let rows =
      List.map
        (fun e ->
          [
            e.file;
            string_of_int e.line_count;
            e.reason;
            review_at_display e.review_at;
            e.status;
          ])
        !all_mod_entries
    in
    print_table [ "file"; "line count"; "reason"; "review_at"; "status" ] rows;
    print_char '\n'
  end;

  (* Section 3: @large-function markers *)
  let n_fn = List.length !all_fn_entries in
  Printf.printf "## @large-function markers (%d)\n\n" n_fn;
  if n_fn = 0 then print_endline "(none)\n"
  else begin
    let rows =
      List.map
        (fun e ->
          [
            e.file_line;
            e.fn_name;
            e.fn_reason;
            review_at_display e.fn_review_at;
            e.fn_status;
          ])
        !all_fn_entries
    in
    print_table
      [ "file:line"; "function"; "reason"; "review_at"; "status" ]
      rows;
    print_char '\n'
  end
