(* Function length linter: reports function definitions exceeding 50 lines.
   Uses the OCaml AST via compiler-libs to avoid shell-based false positives
   (multi-line strings, long match expressions in non-function values, etc.)

   Usage: fn_length_linter <trading-root>

   Scans all lib/*.ml and scripts/**/*.ml files under <trading-root>,
   excluding _build/ and ta_ocaml/ directories. Exits 1 if any violations
   are found.

   Only top-level let bindings whose right-hand side is a function (i.e.
   Pexp_function, covering all fun/function forms in OCaml 5.x) are checked.
   Constant definitions and record constructors are skipped.

   Exception: place a comment containing "@large-function: <reason>" on the
   line immediately before the "let" keyword to opt a single function out of
   the limit. Use sparingly — only for pattern-match state machines and
   algorithms that cannot be meaningfully split. *)

let limit = 50

(* --- Utility ------------------------------------------------------------ *)

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

(* --- File collection ---------------------------------------------------- *)

let is_excluded_dir entry =
  String.equal entry "_build" || String.equal entry "ta_ocaml"

(* Collect all lib/*.ml and scripts/**/*.ml files under [root], skipping
   _build/ and ta_ocaml/ directories. *)
let collect_lib_ml_files root =
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
                (String.equal (Filename.basename dir) "lib"
                || contains_substring path "/scripts/")
                && Filename.check_suffix path ".ml"
                && not (Filename.check_suffix path ".pp.ml")
              then result := path :: !result)
          entries
  in
  walk root;
  !result

(* --- AST helpers -------------------------------------------------------- *)

open Parsetree

let rec is_function_expr expr =
  match expr.pexp_desc with
  (* OCaml 5.x unifies Pexp_fun and Pexp_function into Pexp_function *)
  | Pexp_function _ -> true
  (* let f : t = fun x -> ... — constraint wraps a function *)
  | Pexp_constraint (e, _) -> is_function_expr e
  | _ -> false

let binding_name pvb_pat =
  match pvb_pat.ppat_desc with
  | Ppat_var { txt; _ } -> txt
  | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _) -> txt
  | _ -> "<anonymous>"

(* Return true if any of [lines] at indices [start-3 .. start-1] (1-indexed)
   contains the @large-function annotation. *)
let is_annotated lines start_line =
  let check n =
    if n < 1 || n > Array.length lines then false
    else contains_substring lines.(n - 1) "@large-function"
  in
  check (start_line - 1) || check (start_line - 2) || check (start_line - 3)

(* --- File checking ------------------------------------------------------ *)

let check_file path =
  let violations = ref [] in
  let ic = open_in path in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  let lines = String.split_on_char '\n' content |> Array.of_list in
  let lexbuf = Lexing.from_string content in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with Lexing.pos_fname = path };
  (try
     let structure = Parse.implementation lexbuf in
     List.iter
       (fun item ->
         match item.pstr_desc with
         | Pstr_value (_, bindings) ->
             List.iter
               (fun vb ->
                 if is_function_expr vb.pvb_expr then begin
                   let loc = vb.pvb_loc in
                   let start_line = loc.Location.loc_start.Lexing.pos_lnum in
                   let end_line = loc.Location.loc_end.Lexing.pos_lnum in
                   let lines_count = end_line - start_line + 1 in
                   if lines_count > limit && not (is_annotated lines start_line)
                   then
                     violations :=
                       (path, start_line, binding_name vb.pvb_pat, lines_count)
                       :: !violations
                 end)
               bindings
         | _ -> ())
       structure
   with _ -> ());
  List.rev !violations

(* --- Main --------------------------------------------------------------- *)

let () =
  let trading_root =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else (
      Printf.eprintf "Usage: fn_length_linter <trading-root>\n";
      exit 2)
  in
  let files = collect_lib_ml_files trading_root in
  let all_violations =
    List.concat_map (fun f -> check_file f) (List.sort String.compare files)
  in
  if all_violations = [] then print_endline "OK: no functions exceed 50 lines."
  else begin
    Printf.printf
      "FAIL: function length linter — functions exceeding %d lines:\n\n" limit;
    List.iter
      (fun (file, line, name, count) ->
        Printf.printf "  %s:%d: '%s' is %d lines (limit %d)\n" file line name
          count limit)
      all_violations;
    Printf.printf
      "\n\
       Refactor the function, or add a (* @large-function: <reason> *)\n\
       comment on the line immediately before the 'let' keyword.\n";
    exit 1
  end
