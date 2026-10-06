(* Pins drift DETECTION itself (H-FLAG-DRIFT-REGION-PINS, #3161 review): the
   sibling self-tests cover scan / parse / walk failures but nothing proved
   the linter still flags a real [@sexp.default] mismatch. Fixtures:

   - a .ml/.mli pair whose field default differs (5 vs 6) -> exit 1 and the
     output names [t.x] (the #2384 shape);
   - a pair where the .mli says a literal and the .ml says a top-level
     constant with the same value -> exit 0 (constant resolution);
   - the drifting pair with a matching exceptions-conf entry -> exit 0.

   Each fixture is padded above the linter's 500-file scan floor so a result
   is attributable to drift detection, not the vacuous-scan guard. *)

let filler_count = 500

let linter_exe () =
  Filename.concat
    (Filename.dirname Sys.executable_name)
    "../sexp_default_drift_linter.exe"

let _contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let _write path content =
  let oc = open_out path in
  output_string oc content;
  close_out oc

let _fail fmt =
  Printf.ksprintf
    (fun s ->
      prerr_endline s;
      exit 1)
    fmt

(* Builds <root>/lib with filler modules plus a.ml / a.mli. *)
let _build_fixture ~tag ~ml ~mli =
  let root =
    Filename.concat
      (Filename.get_temp_dir_name ())
      (Printf.sprintf "sexp_drift_detect_%s.%d" tag (Unix.getpid ()))
  in
  let lib = Filename.concat root "lib" in
  ignore (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote root)));
  Unix.mkdir root 0o755;
  Unix.mkdir lib 0o755;
  for i = 1 to filler_count do
    _write
      (Filename.concat lib (Printf.sprintf "mod_%d.ml" i))
      (Printf.sprintf "let f_%d x = x + 1\n" i)
  done;
  _write (Filename.concat lib "a.ml") ml;
  _write (Filename.concat lib "a.mli") mli;
  at_exit (fun () ->
      ignore (Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote root))));
  root

let _run root args =
  let out_path = Filename.temp_file "sexp_drift_detect" ".out" in
  let code =
    Sys.command
      (Printf.sprintf "%s %s %s > %s 2>&1" (linter_exe ()) root args out_path)
  in
  let ic = open_in out_path in
  let out = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Sys.remove out_path;
  (code, out)

let _record ~x_default =
  Printf.sprintf
    "type t = { x : int [@sexp.default %s]; y : int [@sexp.default 1] }\n"
    x_default

let () =
  (* 1. Drift: 5 in the .ml, 6 in the .mli. *)
  let root =
    _build_fixture ~tag:"drift" ~ml:(_record ~x_default:"5")
      ~mli:(_record ~x_default:"6")
  in
  let code, out = _run root "" in
  if code <> 1 then _fail "FAIL: drifting pair exited %d, want 1\n%s" code out;
  if not (_contains out "t.x") then
    _fail "FAIL: drift output does not name t.x\n%s" out;
  (* 2. Exception entry silences exactly that field. *)
  let conf = Filename.concat root "exceptions.conf" in
  _write conf "sexp_default_drift t.x fixture  # review_at: never\n";
  let code, out = _run root (Filename.quote conf) in
  if code <> 0 then _fail "FAIL: excepted drift exited %d, want 0\n%s" code out;
  (* 3. Constant resolution: literal vs named constant of equal value. *)
  let root =
    _build_fixture ~tag:"const"
      ~ml:("let default_x = 5\n" ^ _record ~x_default:"default_x")
      ~mli:(_record ~x_default:"5")
  in
  let code, out = _run root "" in
  if code <> 0 then
    _fail "FAIL: resolved-constant pair exited %d, want 0\n%s" code out;
  print_endline
    "OK: sexp_default_drift_linter -- flags a real default mismatch (names the \
     field), honours an exception entry, resolves equal constants."
