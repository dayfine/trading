(* Sexp-default drift linter: catches a record type that is declared more
   than once (an .mli redeclaring another module's record via [include], or
   the ordinary .ml/.mli pair) where the SAME field carries a DIFFERENT
   [@sexp.default ...] attribute across the declarations.

   Why this needs its own check: [@sexp.default e] attributes do not
   participate in OCaml signature matching. Two record type declarations can
   be structurally identical (same field names/types/order -- required for
   the build to typecheck) while disagreeing on what a field's attribute
   says its default is. The compiler is silent; only the reader who happens
   to compare both copies by eye catches it. This bit the repo twice:
   entry_order_max_rest_weeks (#2384, promoted 0->26 in the .ml, .mli left
   at 0) and stale_exit_after_days (#2388, .mli says [@sexp.default None],
   the other two copies say [@sexp.default Some default_stale_exit_days]).

   Usage: sexp_default_drift_linter <trading-root> [<exceptions-conf>]

   Scans all lib/*.ml and lib/*.mli files under <trading-root>. For each
   record type declaration (Ptype_record) found, groups declarations by
   (type name, ordered field-name list) -- this pair is exactly what the
   compiler already forces to be identical whenever two declarations are
   linked by [include] + independent redeclaration, or by a module's own
   .ml/.mli pair. A group with more than one declaring file is therefore a
   *bona fide* duplicate of one logical record, not a coincidence.

   No group-size floor is applied (a prior revision filtered out groups
   below 6 fields; removed 2026-08-20 rework of PR #2430). Measured on the
   shipped tree: of 909 record declarations, a 6-field floor silently
   dropped 614 (67.5%) before grouping and cut multi-file duplicate-group
   coverage from 402 groups (no floor) to 134 (floor 6) -- yet running with
   no floor at all produces the SAME zero live findings as the floor did,
   because the (type_name, field-list) grouping key plus the opted-in
   filter below are already what makes a match non-coincidental: a false
   positive would require two UNRELATED types to share an exact type name,
   an exact ordered field-name list, [@sexp.default] on the same field in
   both, AND different literal values -- and even then it is a one-line
   [linter_exceptions.conf] entry, not a correctness bug. A field-count
   floor bought no precision and cost most of the check's coverage; see
   dev/status/harness.md's H-SEXP-DEFAULT-DRIFT-LINTER entry for the fuller
   writeup.

   For each field in such a group, compares the [@sexp.default ...]
   attribute payload (its source text) across all declaring files, after:
     - collapsing whitespace runs (so multi-line vs single-line attributes
       compare equal), and
     - resolving simple top-level [let name = <literal>] constants defined
       in any scanned .ml file, so `[@sexp.default 5]` and
       `[@sexp.default default_stale_exit_days]` (where
       [let default_stale_exit_days = 5]) compare EQUAL rather than
       producing a textual false positive.
   A field missing the attribute in one declaration but carrying one in
   another is also a mismatch (the #2384 shape if the attribute had been
   dropped rather than changed, per the task write-up).

   A group/field pair may be exempted via a
   "sexp_default_drift <type_name>.<field_name> <reason>  # review_at: ..."
   line in the exceptions conf (same file/format as the other linters'
   sections; see linter_exceptions.conf header). *)

open Drift_scan
open Drift_parse
open Drift_compare

(* --- Main ---------------------------------------------------------------------- *)

(* Fails loudly (never a silent "OK") whenever the scan itself looks broken --
   see [validate_root_readable] and [min_expected_lib_files] above. This is
   what turns "an empty root, a moved trading/ dir, or a wrong-cwd invocation"
   from an indistinguishable clean-tree pass into an explicit FAIL. *)
let _check_scan_integrity trading_root files =
  match validate_root_readable trading_root with
  | Some msg ->
      Printf.printf "FAIL: sexp_default_drift linter -- %s\n" msg;
      exit 1
  | None ->
      let n = List.length files in
      if n < min_expected_lib_files then begin
        Printf.printf
          "FAIL: sexp_default_drift linter -- scanned only %d lib/*.ml + \
           lib/*.mli file(s) under %s, below the expected floor of %d. This \
           usually means the trading-root argument is wrong or moved, not that \
           the tree genuinely shrank this much.\n"
          n trading_root min_expected_lib_files;
        exit 1
      end

(* Fails loudly on any subdirectory whose [Sys.readdir] failed mid-walk,
   rather than silently omitting whatever was under it from the scan. This
   is the fix for the residual defect found in review of
   H-SEXP-DRIFT-VACUOUS-PASS: with only [_check_scan_integrity]'s floor
   guarding the total, a partial loss up to (scanned - min_expected_lib_files)
   files passed silently -- e.g. an 820-file tree losing a 300-file subtree
   to a permission error still reported "OK: ... (scanned 520 files)". Every
   walk failure is now named explicitly, independent of how large the loss
   under it turns out to be. *)
let _check_walk_failures failed_dirs =
  if failed_dirs <> [] then begin
    Printf.printf
      "FAIL: sexp_default_drift linter -- %d director%s could not be read and \
       were excluded from the scan (any [@sexp.default] drift inside them \
       would have gone undetected):\n\n"
      (List.length failed_dirs)
      (if List.length failed_dirs = 1 then "y" else "ies");
    List.iter
      (fun (dir, msg) -> Printf.printf "  %s: %s\n" dir msg)
      (List.rev failed_dirs);
    exit 1
  end

(* Fails loudly on any unparseable scanned file rather than silently
   dropping its records (the pre-fix behavior: [parse_ml]/[parse_mli] caught
   every exception and returned empty results, so a live drift bug hiding in
   an unparseable file was indistinguishable from a clean scan). See the
   [parse_outcome] docstring for why "unreachable in practice" argues for
   loud, not tolerated. *)
let _check_parse_failures parsed =
  let failures =
    List.filter_map
      (fun (f, (po : parse_outcome)) ->
        Option.map (fun msg -> (f, msg)) po.parse_error)
      parsed
  in
  if failures <> [] then begin
    Printf.printf
      "FAIL: sexp_default_drift linter -- %d file(s) failed to parse and were \
       excluded from the scan (any [@sexp.default] drift inside them would \
       have gone undetected):\n\n"
      (List.length failures);
    List.iter (fun (f, msg) -> Printf.printf "  %s: %s\n" f msg) failures;
    Printf.printf
      "\n\
       This linter only parses source the compiler has already accepted (every \
       file above is a workspace lib/*.ml or lib/*.mli), so a parse failure \
       here means the linter's own compiler-libs parser is out of step with \
       the toolchain -- fix the linter, do not add an exception for it.\n";
    exit 1
  end

let () =
  let trading_root =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else begin
      Printf.eprintf
        "Usage: sexp_default_drift_linter <trading-root> [<exceptions-conf>]\n";
      exit 2
    end
  in
  let exceptions =
    if Array.length Sys.argv > 2 then read_exceptions Sys.argv.(2) else []
  in
  let collected_files, failed_dirs = collect_lib_files trading_root in
  let files = List.sort String.compare collected_files in
  _check_scan_integrity trading_root files;
  _check_walk_failures failed_dirs;
  let parsed = List.map (fun f -> (f, parse_file f)) files in
  _check_parse_failures parsed;
  let records =
    List.concat_map (fun (_, (po : parse_outcome)) -> po.records) parsed
  in
  let constants =
    List.concat_map (fun (_, (po : parse_outcome)) -> po.constants) parsed
  in
  let table = build_constant_table constants in
  let groups = group_records records in
  let all_violations = List.concat_map (check_group table) groups in
  let live_violations =
    List.filter
      (fun v -> not (List.mem (exception_key v) exceptions))
      all_violations
  in
  if live_violations = [] then
    Printf.printf
      "OK: no sexp.default drift across duplicated record declarations \
       (scanned %d files).\n"
      (List.length files)
  else begin
    Printf.printf
      "FAIL: sexp_default_drift linter -- %d field(s) with a [@sexp.default \
       ...] mismatch across duplicate record declarations:\n\n"
      (List.length live_violations);
    List.iter (fun v -> print_endline (format_violation v)) live_violations;
    Printf.printf
      "\n\
       Fix by making every declaration agree on the same default (do not just \
       add a linter_exceptions.conf entry). If this is a pre-existing \
       divergence too risky to fix in this change (a behaviour-changing \
       default flip -- see .claude/rules/experiment-flag-discipline.md R1), \
       add a\n\
      \  sexp_default_drift <type>.<field> <reason>  # review_at: <trigger>\n\
       line to devtools/checks/linter_exceptions.conf instead, with a real \
       tracked follow-up.\n";
    exit 1
  end
