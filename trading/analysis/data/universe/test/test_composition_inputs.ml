open Core
open OUnit2
open Matchers
open Universe
module CI = Composition_inputs

let _tmp suffix = Stdlib.Filename.temp_file "ci_test_" ("_" ^ suffix)

(* A symbol_types.sexp in the canonical Asset_type_enrichment shape, written by
   hand so the test does not cross dune-project boundaries. Unlike the runner
   test's helper, each entry's asset_type sexp is given verbatim so
   [Not_in_eodhd_listing] entries can be expressed alongside [Listed _] ones. *)
let _write_symbol_types_raw ~path entries =
  let body =
    List.map entries ~f:(fun (sym, at_sexp) ->
        Printf.sprintf "    ((symbol %s) (asset_type %s) (exchange \"\"))" sym
          at_sexp)
    |> String.concat ~sep:"\n"
  in
  Out_channel.write_all path
    ~data:
      ("((generated_at 2020-05-30)\n (source_endpoints ())\n (symbols (\n"
     ^ body ^ ")))\n")

let _lookup_exn path =
  match CI.load_asset_type_lookup path with
  | Ok tbl -> tbl
  | Error err -> assert_failure ("load_asset_type_lookup: " ^ Status.show err)

(* ---------------------------------------------------------------------- *)
(* load_asset_type_lookup — documented edge cases                          *)
(* ---------------------------------------------------------------------- *)

(* Only [Listed _] entries contribute; a [Not_in_eodhd_listing] symbol is
   omitted from the map entirely (downstream consumers default it). *)
let test_not_in_eodhd_listing_omitted _ =
  let path = _tmp "types.sexp" in
  _write_symbol_types_raw ~path
    [
      ("AAPL", "(Listed \"Common Stock\")");
      ("GONE", "Not_in_eodhd_listing");
      ("TSM", "(Listed ADR)");
    ];
  let tbl = _lookup_exn path in
  assert_that tbl
    (all_of
       [
         field Hashtbl.length (equal_to 2);
         field
           (fun t -> Hashtbl.find t "AAPL")
           (is_some_and (equal_to Eodhd.Asset_type.Common_stock));
         field
           (fun t -> Hashtbl.find t "TSM")
           (is_some_and (equal_to Eodhd.Asset_type.ADR));
         field (fun t -> Hashtbl.find t "GONE") is_none;
       ])

(* The first occurrence of a duplicated symbol wins; the later entry's asset
   type is ignored. *)
let test_duplicate_symbol_first_occurrence_wins _ =
  let path = _tmp "types.sexp" in
  _write_symbol_types_raw ~path
    [ ("DUP", "(Listed ADR)"); ("DUP", "(Listed \"Common Stock\")") ];
  let tbl = _lookup_exn path in
  assert_that tbl
    (all_of
       [
         field Hashtbl.length (equal_to 1);
         field
           (fun t -> Hashtbl.find t "DUP")
           (is_some_and (equal_to Eodhd.Asset_type.ADR));
       ])

let suite =
  "Composition_inputs"
  >::: [
         "test_not_in_eodhd_listing_omitted"
         >:: test_not_in_eodhd_listing_omitted;
         "test_duplicate_symbol_first_occurrence_wins"
         >:: test_duplicate_symbol_first_occurrence_wins;
       ]

let () = run_test_tt_main suite
