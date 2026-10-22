(** Config-exception parsing and annotation helpers shared by the reporter. *)

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
