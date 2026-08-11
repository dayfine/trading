(** Magic-number linter CLI entry point: bare numeric literals in [lib/*.ml]
    files must be routed through a config record or a named constant.

    All detection logic lives in {!Magic_numbers_linter_lib} (see that
    module's [.mli] for the full exempt-surface rule enumeration and the
    pinned regression suite under [test/]); this file is just argv parsing
    and output formatting.

    Usage: magic_numbers_linter <trading-root> <exceptions-conf-path>

    Exit 0 with an "OK: ..." line if no violations are found. Exit 1 with a
    "FAIL: ..." line and per-violation detail otherwise. *)

let () =
  if Array.length Sys.argv < 3 then begin
    Printf.eprintf
      "Usage: magic_numbers_linter <trading-root> <exceptions-conf-path>\n";
    exit 2
  end;
  let trading_root = Sys.argv.(1) in
  let exceptions_conf = Sys.argv.(2) in
  let violations =
    Magic_numbers_linter_lib.lint ~trading_root ~exceptions_conf
  in
  if violations <> [] then begin
    print_string
      "FAIL: magic number linter \xe2\x80\x94 bare numeric literals in lib/ \
       files.\n";
    print_string
      "Route values through a config record, or add a path exception to \
       linter_exceptions.conf.\n";
    print_string "\n";
    List.iter
      (fun v ->
        print_string v;
        print_char '\n')
      violations;
    exit 1
  end
  else begin
    print_string "OK: no magic numbers found in lib/ files.\n";
    exit 0
  end
