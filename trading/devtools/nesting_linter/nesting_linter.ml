(* Nesting depth linter: enforces indentation depth and structural nesting limits.

   Uses the OCaml AST (via compiler-libs) for function boundaries, then measures
   per-line indentation of formatted source as a proxy for structural depth.
   Since ocamlformat enforces 2-space indentation, depth = leading_spaces / 2.

   Usage: nesting_linter <trading-root> [<exceptions-conf>]

   Scans all lib/*.ml and scripts/**/*.ml files under <trading-root>.

   Limits (hard):
   - Per-function avg depth  > 3.0   → FAIL
   - Per-function max depth  > 5     → FAIL
   - Per-file avg depth      > 2.5   → FAIL
   - Nested else             > 0     → FAIL  (see below)

   Nested-else rule:
   An "else" branch that is not a direct "else if" but contains a further
   conditional via intermediate let-bindings is flagged. This pattern always
   indicates the function should be split:

     if guard then None         ← ok: direct else-if chain
     else if guard2 then None   ← ok
     else                       ← VIOLATION: else → let → if
       let score = compute () in
       if score > t then None
       else Some result

   Exemptions:
   - Place (* @nesting-ok: <reason> *) on the line immediately before the
     "let" keyword to exempt one function from all nesting checks.
   - Add a "nesting <path-substring> <reason>" line to the exceptions conf
     to exclude a file from all nesting checks. *)

let fn_avg_limit = 3.0
let fn_max_limit = 5
let file_avg_limit = 2.5

(* --- Utility --------------------------------------------------------------- *)

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

(* --- Exceptions conf ------------------------------------------------------- *)

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
             | linter :: path :: _ when String.equal linter "nesting" ->
                 result := path :: !result
             | _ -> ()
         done
       with End_of_file -> ());
      close_in ic;
      !result

let is_excluded exceptions path =
  List.exists (fun sub -> contains_substring path sub) exceptions

(* --- File collection ------------------------------------------------------- *)

let is_excluded_dir entry =
  String.equal entry "_build"
  || String.equal entry "ta_ocaml"
  || String.equal entry ".claude"

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

(* --- AST helpers ----------------------------------------------------------- *)

open Parsetree

let rec is_function_expr expr =
  match expr.pexp_desc with
  | Pexp_function _ -> true
  | Pexp_constraint (e, _) -> is_function_expr e
  | _ -> false

let binding_name pvb_pat =
  match pvb_pat.ppat_desc with
  | Ppat_var { txt; _ } -> txt
  | Ppat_constraint ({ ppat_desc = Ppat_var { txt; _ }; _ }, _) -> txt
  | _ -> "<anonymous>"

let is_nesting_ok lines start_line =
  let check n =
    if n < 1 || n > Array.length lines then false
    else contains_substring lines.(n - 1) "@nesting-ok"
  in
  check (start_line - 1) || check (start_line - 2)

(* --- Nested-else detection ------------------------------------------------- *)

(* True if [expr] eventually reaches a conditional (Pexp_ifthenelse) by
   following only let-bindings and sequences — i.e., the conditional governs
   the overall result of this expression, not just an intermediate value.
   Stops at function boundaries and application arguments. *)
let rec has_nested_if expr =
  match expr.pexp_desc with
  | Pexp_ifthenelse _ -> true
  | Pexp_let (_, _, body) -> has_nested_if body
  | Pexp_sequence (_, e) -> has_nested_if e
  | Pexp_constraint (e, _) -> has_nested_if e
  | _ -> false

(* Count else-branches that are not direct else-if but contain a conditional
   via intermediate let bindings. Only walks the direct control flow of the
   function body — does not cross into closure arguments. *)
let rec count_nested_else expr =
  match expr.pexp_desc with
  | Pexp_ifthenelse (_, then_e, else_opt) -> (
      let n = count_nested_else then_e in
      match else_opt with
      | None -> n
      | Some else_e ->
          let violation =
            match else_e.pexp_desc with
            | Pexp_ifthenelse _ -> 0 (* direct else-if chain: fine *)
            | _ -> if has_nested_if else_e then 1 else 0
          in
          n + violation + count_nested_else else_e)
  | Pexp_function (_, _, Pfunction_body body) -> count_nested_else body
  | Pexp_function (_, _, Pfunction_cases (cases, _, _)) ->
      List.fold_left (fun acc c -> acc + count_nested_else c.pc_rhs) 0 cases
  | Pexp_let (_, _, body) -> count_nested_else body
  | Pexp_sequence (e1, e2) -> count_nested_else e1 + count_nested_else e2
  | Pexp_match (_, cases) ->
      List.fold_left (fun acc c -> acc + count_nested_else c.pc_rhs) 0 cases
  | Pexp_constraint (e, _) -> count_nested_else e
  | Pexp_apply _ -> 0 (* stop at closure arguments *)
  | _ -> 0

(* --- Depth measurement ----------------------------------------------------- *)

let leading_spaces line =
  let n = String.length line in
  let i = ref 0 in
  while !i < n && line.[!i] = ' ' do
    incr i
  done;
  !i

let is_skip_line line =
  let t = String.trim line in
  String.length t = 0
  || (String.length t >= 2 && String.sub t 0 2 = "(*")
  || (String.length t >= 1 && t.[0] = '*')

let measure_fn_depths lines start_line end_line =
  let total = ref 0 in
  let count = ref 0 in
  let max_d = ref 0 in
  for i = start_line + 1 to end_line do
    if i <= Array.length lines then begin
      let line = lines.(i - 1) in
      if not (is_skip_line line) then begin
        let d = leading_spaces line / 2 in
        total := !total + d;
        incr count;
        if d > !max_d then max_d := d
      end
    end
  done;
  if !count = 0 then None
  else Some (float_of_int !total /. float_of_int !count, !max_d)

let measure_file_avg lines =
  let total = ref 0 in
  let count = ref 0 in
  Array.iter
    (fun line ->
      if not (is_skip_line line) then begin
        total := !total + (leading_spaces line / 2);
        incr count
      end)
    lines;
  if !count = 0 then 0.0 else float_of_int !total /. float_of_int !count

(* --- File checking --------------------------------------------------------- *)

type fn_violation = {
  avg : float;
  max_d : int;
  nested_else : int;
  path : string;
  start_line : int;
  name : string;
}

type file_result = {
  path : string;
  file_avg : float;
  fn_violations : fn_violation list;
  fn_count : int;
}

let check_file path =
  let ic = open_in path in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
  let lines = String.split_on_char '\n' content |> Array.of_list in
  let file_avg = measure_file_avg lines in
  let violations = ref [] in
  let fn_count = ref 0 in
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
                   incr fn_count;
                   let loc = vb.pvb_loc in
                   let start_line = loc.Location.loc_start.Lexing.pos_lnum in
                   let end_line = loc.Location.loc_end.Lexing.pos_lnum in
                   if not (is_nesting_ok lines start_line) then begin
                     let nested_else = count_nested_else vb.pvb_expr in
                     let depth_violation =
                       match measure_fn_depths lines start_line end_line with
                       | None -> false
                       | Some (avg, max_d) ->
                           if avg > fn_avg_limit || max_d > fn_max_limit then begin
                             violations :=
                               {
                                 avg;
                                 max_d;
                                 nested_else;
                                 path;
                                 start_line;
                                 name = binding_name vb.pvb_pat;
                               }
                               :: !violations;
                             true
                           end
                           else false
                     in
                     if (not depth_violation) && nested_else > 0 then
                       (* Report as depth-ok but nested-else violation *)
                       match measure_fn_depths lines start_line end_line with
                       | None -> ()
                       | Some (avg, max_d) ->
                           violations :=
                             {
                               avg;
                               max_d;
                               nested_else;
                               path;
                               start_line;
                               name = binding_name vb.pvb_pat;
                             }
                             :: !violations
                   end
                 end)
               bindings
         | _ -> ())
       structure
   with _ -> ());
  { path; file_avg; fn_violations = List.rev !violations; fn_count = !fn_count }

(* --- Pretty printing ------------------------------------------------------- *)

let strip_prefix root path =
  if contains_substring path root then
    let len = String.length root in
    if len < String.length path && path.[len] = '/' then
      String.sub path (len + 1) (String.length path - len - 1)
    else path
  else path

let violation_tags v =
  let avg_fail = v.avg > fn_avg_limit in
  let max_fail = v.max_d > fn_max_limit in
  let else_fail = v.nested_else > 0 in
  let parts =
    (if avg_fail then [ "avg" ] else [])
    @ (if max_fail then [ "max" ] else [])
    @ if else_fail then [ "else" ] else []
  in
  String.concat "+" parts

(* --- Main ------------------------------------------------------------------ *)

let () =
  let trading_root =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else (
      Printf.eprintf
        "Usage: nesting_linter <trading-root> [<exceptions-conf>]\n";
      exit 2)
  in
  let exceptions =
    if Array.length Sys.argv > 2 then read_exceptions Sys.argv.(2) else []
  in
  let files =
    collect_lib_ml_files trading_root
    |> List.filter (fun f -> not (is_excluded exceptions f))
    |> List.sort String.compare
  in
  let results = List.map check_file files in
  let fn_violations =
    List.concat_map (fun r -> r.fn_violations) results
    |> List.sort (fun a b -> Float.compare b.avg a.avg)
  in
  let file_violations =
    List.filter (fun r -> r.file_avg > file_avg_limit) results
    |> List.sort (fun a b -> Float.compare b.file_avg a.file_avg)
  in
  let total_fns = List.fold_left (fun acc r -> acc + r.fn_count) 0 results in
  let fail = fn_violations <> [] || file_violations <> [] in
  if fn_violations <> [] then begin
    Printf.printf "FAIL: nesting linter — %d function(s) exceed limits:\n\n"
      (List.length fn_violations);
    Printf.printf "  %-6s %-4s %-4s %-9s  %-50s  %s\n" "avg" "max" "else" "why"
      "location" "function";
    Printf.printf "  %s\n" (String.make 88 '-');
    List.iter
      (fun v ->
        Printf.printf "  %-6.2f %-4d %-4d %-9s  %-50s  %s\n" v.avg v.max_d
          v.nested_else (violation_tags v)
          (Printf.sprintf "%s:%d"
             (strip_prefix trading_root v.path)
             v.start_line)
          v.name)
      fn_violations;
    Printf.printf
      "\n\
       Limits: avg > %.1f, max > %d, nested-else > 0.\n\
       Fix: refactor or add (* @nesting-ok: <reason> *) before the 'let'.\n\
       Nested-else: split the function at the else — the else body is a new \
       fn.\n\n"
      fn_avg_limit fn_max_limit
  end;
  if file_violations <> [] then begin
    Printf.printf
      "FAIL: nesting linter — %d file(s) exceed file avg > %.1f:\n\n"
      (List.length file_violations)
      file_avg_limit;
    List.iter
      (fun r ->
        Printf.printf "  %.2f  %s\n" r.file_avg
          (strip_prefix trading_root r.path))
      file_violations;
    Printf.printf
      "\nFix: refactor or add 'nesting <path> <reason>' to exceptions conf.\n\n"
  end;
  let total_avg =
    if results = [] then 0.0
    else
      List.fold_left (fun acc r -> acc +. r.file_avg) 0.0 results
      /. float_of_int (List.length results)
  in
  if not fail then
    Printf.printf "OK: nesting linter — all %d functions within limits.\n"
      total_fns;
  Printf.printf
    "Codebase avg nesting: %.2f  |  %d functions scanned  |  %d files\n"
    total_avg total_fns (List.length results);
  if fail then exit 1
