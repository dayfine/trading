(** Inline module/function marker scanning for the exception reporter. *)

open Exception_entry

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
