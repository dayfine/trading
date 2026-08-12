(* See string_utils.mli. Extracted from magic_numbers_linter_lib.ml purely to
   keep that file under the file-length linter's limit -- these are generic
   char-level utilities, not magic-number-linter specific. *)

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

let ends_with s suffix =
  let n = String.length s and m = String.length suffix in
  m <= n && String.sub s (n - m) m = suffix

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

let is_digit c = c >= '0' && c <= '9'

let is_word_or_dot c =
  (c >= 'a' && c <= 'z')
  || (c >= 'A' && c <= 'Z')
  || is_digit c || c = '_' || c = '.'

let digit_run_end s start =
  let n = String.length s in
  let j = ref start in
  while !j < n && is_digit s.[!j] do
    incr j
  done;
  !j

let lookahead_ok s pos = pos >= String.length s || not (is_word_or_dot s.[pos])
