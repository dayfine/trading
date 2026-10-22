(** List active linter exceptions from linter_exceptions.conf and inline
    [@large-module] / [@large-function] markers in .ml files.

    Usage: list_active_exceptions <trading-root>

    Output is a markdown report on stdout. Exits 0 always — passive linter. *)

open Exception_entry
open Exception_marker

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
