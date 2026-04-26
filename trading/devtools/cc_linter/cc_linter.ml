(* Cyclomatic complexity linter: computes CC per function and warns on CC > 10.
   Uses the OCaml AST via compiler-libs for accurate measurement.

   CC formula: 1 + number of decision points in the function body.
   Decision points counted:
   - Each if/then/else: +1
   - Each match arm beyond the first: +1 per extra arm
   - Each when guard: +1
   - Boolean operators && and ||: +1 each

   Usage: cc_linter <trading-root> [--out <output-json-path>]

   Scans all lib/*.ml and scripts/**/*.ml files under <trading-root>,
   excluding _build/ and ta_ocaml/ directories.

   Exits 0 always — CC is a quality signal, not a hard gate. Warnings are
   printed to stdout. If --out <path> is provided, per-function CC data is
   written there for trend analysis.

   NOTE: positional arguments after <trading-root> are ignored. JSON output
   must be requested explicitly with --out to avoid clobbering source files. *)

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

(* --- Cyclomatic complexity computation ------------------------------------- *)

(* Count decision points (branches) in an expression.
   CC = 1 + total decision points in function body. *)
let rec count_decisions expr =
  match expr.pexp_desc with
  | Pexp_ifthenelse (cond, then_e, else_opt) -> (
      (* +1 for the if branch itself *)
      let n = 1 + count_decisions cond + count_decisions then_e in
      match else_opt with None -> n | Some e -> n + count_decisions e)
  | Pexp_match (scrutinee, cases) ->
      (* A "flat mapping" match has no guards and no decisions in any RHS —
         it's an exhaustive enum conversion, not branching logic. Don't
         count the arms as decision points in that case. *)
      let is_flat_mapping =
        List.for_all
          (fun c -> c.pc_guard = None && count_decisions c.pc_rhs = 0)
          cases
      in
      if is_flat_mapping then count_decisions scrutinee
      else
        let extra_arms = max 0 (List.length cases - 1) in
        let guards =
          List.fold_left
            (fun acc c ->
              let guard_n =
                match c.pc_guard with
                | None -> 0
                | Some g -> 1 + count_decisions g
              in
              acc + guard_n + count_decisions c.pc_rhs)
            0 cases
        in
        extra_arms + guards + count_decisions scrutinee
  | Pexp_try (body, cases) ->
      (* Each with-arm is a branch point *)
      let extra_arms = max 0 (List.length cases - 1) in
      let guards =
        List.fold_left (fun acc c -> acc + count_decisions c.pc_rhs) 0 cases
      in
      extra_arms + guards + count_decisions body
  | Pexp_apply (fn, args) ->
      (* Check for boolean operators && and || *)
      let op_bonus =
        match fn.pexp_desc with
        | Pexp_ident { txt = Longident.Lident ("&&" | "||"); _ } -> 1
        | _ -> 0
      in
      let args_n =
        List.fold_left (fun acc (_, e) -> acc + count_decisions e) 0 args
      in
      op_bonus + count_decisions fn + args_n
  | Pexp_function (params, _, body) -> (
      let params_n =
        List.fold_left
          (fun acc p ->
            match p.pparam_desc with
            | Pparam_val _ -> acc
            | Pparam_newtype _ -> acc)
          0 params
      in
      match body with
      | Pfunction_body e -> params_n + count_decisions e
      | Pfunction_cases (cases, _, _) ->
          let is_flat_mapping =
            List.for_all
              (fun c -> c.pc_guard = None && count_decisions c.pc_rhs = 0)
              cases
          in
          if is_flat_mapping then params_n
          else
            let extra_arms = max 0 (List.length cases - 1) in
            let guards =
              List.fold_left
                (fun acc c ->
                  let guard_n =
                    match c.pc_guard with
                    | None -> 0
                    | Some g -> 1 + count_decisions g
                  in
                  acc + guard_n + count_decisions c.pc_rhs)
                0 cases
            in
            params_n + extra_arms + guards)
  | Pexp_let (_, bindings, body) ->
      let bindings_n =
        List.fold_left
          (fun acc vb -> acc + count_decisions vb.pvb_expr)
          0 bindings
      in
      bindings_n + count_decisions body
  | Pexp_sequence (e1, e2) -> count_decisions e1 + count_decisions e2
  | Pexp_constraint (e, _) -> count_decisions e
  | Pexp_tuple es -> List.fold_left (fun acc e -> acc + count_decisions e) 0 es
  | Pexp_construct (_, Some e) -> count_decisions e
  | Pexp_field (e, _) -> count_decisions e
  | Pexp_setfield (e1, _, e2) -> count_decisions e1 + count_decisions e2
  | Pexp_array es -> List.fold_left (fun acc e -> acc + count_decisions e) 0 es
  | Pexp_record (fields, base) ->
      let fields_n =
        List.fold_left (fun acc (_, e) -> acc + count_decisions e) 0 fields
      in
      let base_n = match base with None -> 0 | Some e -> count_decisions e in
      fields_n + base_n
  | Pexp_while (cond, body) -> 1 + count_decisions cond + count_decisions body
  | Pexp_for (_, lo, hi, _, body) ->
      1 + count_decisions lo + count_decisions hi + count_decisions body
  | _ -> 0

(* --- File checking --------------------------------------------------------- *)

type fn_result = { path : string; start_line : int; name : string; cc : int }

let check_file path =
  let results = ref [] in
  let ic = open_in path in
  let content = really_input_string ic (in_channel_length ic) in
  close_in ic;
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
                   let decisions = count_decisions vb.pvb_expr in
                   let cc = 1 + decisions in
                   results :=
                     { path; start_line; name = binding_name vb.pvb_pat; cc }
                     :: !results
                 end)
               bindings
         | _ -> ())
       structure
   with _ -> ());
  List.rev !results

(* --- JSON output ----------------------------------------------------------- *)

let strip_prefix root path =
  if contains_substring path root then
    let len = String.length root in
    if len < String.length path && path.[len] = '/' then
      String.sub path (len + 1) (String.length path - len - 1)
    else path
  else path

let json_escape s =
  let buf = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\n' -> Buffer.add_string buf "\\n"
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let write_json path root date all_results =
  let oc = open_out path in
  Printf.fprintf oc "{\n";
  Printf.fprintf oc "  \"date\": \"%s\",\n" date;
  Printf.fprintf oc "  \"functions\": [\n";
  let first = ref true in
  List.iter
    (fun fn ->
      if not !first then Printf.fprintf oc ",\n";
      first := false;
      Printf.fprintf oc
        "    {\"file\": \"%s\", \"line\": %d, \"name\": \"%s\", \"cc\": %d}"
        (json_escape (strip_prefix root fn.path))
        fn.start_line (json_escape fn.name) fn.cc)
    all_results;
  Printf.fprintf oc "\n  ]\n";
  Printf.fprintf oc "}\n";
  close_out oc

(* --- Main ------------------------------------------------------------------ *)

let cc_warn_limit = 10

(* Parse CLI arguments: extract --out <path> flag and return (trading_root, json_out).
   All positional arguments beyond trading_root are silently ignored; JSON output
   must be requested with --out to prevent accidental source-file clobbering. *)
let _parse_args () =
  let args = Array.to_list (Array.sub Sys.argv 1 (Array.length Sys.argv - 1)) in
  let rec go remaining root json_out =
    match remaining with
    | [] -> (root, json_out)
    | "--out" :: path :: rest -> go rest root (Some path)
    | "--out" :: [] ->
        Printf.eprintf "cc_linter: --out requires a path argument\n";
        exit 2
    | arg :: rest -> (
        match root with
        | None -> go rest (Some arg) json_out
        | Some _ ->
            (* Additional positional args are ignored; do not write to them *)
            go rest root json_out)
  in
  match go args None None with
  | None, _ ->
      Printf.eprintf
        "Usage: cc_linter <trading-root> [--out <output-json-path>]\n";
      exit 2
  | Some root, json_out -> (root, json_out)

let () =
  let trading_root, json_output = _parse_args () in
  let files = collect_lib_ml_files trading_root |> List.sort String.compare in
  let all_results = List.concat_map (fun f -> check_file f) files in
  let warnings =
    List.filter (fun fn -> fn.cc > cc_warn_limit) all_results
    |> List.sort (fun a b -> Int.compare b.cc a.cc)
  in
  if warnings = [] then
    Printf.printf "OK: cc linter — all functions have CC <= %d.\n" cc_warn_limit
  else begin
    Printf.printf "WARNING: cc linter — %d function(s) with CC > %d:\n\n"
      (List.length warnings) cc_warn_limit;
    Printf.printf "  %-5s  %-50s  %s\n" "CC" "location" "function";
    Printf.printf "  %s\n" (String.make 80 '-');
    List.iter
      (fun fn ->
        Printf.printf "  %-5d  %-50s  %s\n" fn.cc
          (Printf.sprintf "%s:%d"
             (strip_prefix trading_root fn.path)
             fn.start_line)
          fn.name)
      warnings;
    Printf.printf
      "\nCC > %d is a quality signal — consider splitting these functions.\n"
      cc_warn_limit
  end;
  match json_output with
  | None -> ()
  | Some out_path ->
      (* Ensure parent directory exists *)
      let parent = Filename.dirname out_path in
      (if not (Sys.file_exists parent) then
         try Unix.mkdir parent 0o755 with _ -> ());
      let date =
        let t = Unix.localtime (Unix.time ()) in
        Printf.sprintf "%04d-%02d-%02d" (t.Unix.tm_year + 1900)
          (t.Unix.tm_mon + 1) t.Unix.tm_mday
      in
      write_json out_path trading_root date all_results;
      Printf.printf "CC data written to: %s\n" out_path
