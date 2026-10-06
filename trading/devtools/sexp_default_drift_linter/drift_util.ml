(* Shared string helpers for the sexp-default drift linter. *)

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

(* Collapse any run of whitespace to a single space and trim ends, so
   formatting differences (line breaks, extra indentation) between two
   copies of the same attribute don't register as a mismatch. *)
let normalize_ws s =
  let buf = Buffer.create (String.length s) in
  let in_ws = ref false in
  String.iter
    (fun c ->
      match c with
      | ' ' | '\t' | '\n' | '\r' ->
          if not !in_ws then Buffer.add_char buf ' ';
          in_ws := true
      | c ->
          Buffer.add_char buf c;
          in_ws := false)
    s;
  String.trim (Buffer.contents buf)
