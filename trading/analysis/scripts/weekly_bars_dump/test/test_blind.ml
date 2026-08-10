open Core
open OUnit2
open Matchers
module Blind = Weekly_bars_dump_lib.Blind
module Table_format = Weekly_bars_dump_lib.Table_format

let test_pseudonym_stable _ =
  (* Same symbol -> same pseudonym across independent calls. Repeated
     queries about one symbol must read self-consistently to the judge. *)
  assert_that
    (Blind.pseudonym_of_symbol "AAPL")
    (equal_to (Blind.pseudonym_of_symbol "AAPL"))

let test_pseudonym_format _ =
  assert_that
    (Blind.pseudonym_of_symbol "AAPL")
    (all_of
       [
         field String.length (equal_to 8);
         field (fun p -> String.prefix p 4) (equal_to "SYM-");
       ])

let test_week_labels _ =
  assert_that (Blind.week_labels 3)
    (elements_are [ equal_to "w1"; equal_to "w2"; equal_to "w3" ])

let test_week_labels_empty_for_nonpositive _ =
  assert_that (Blind.week_labels 0) is_empty

let _bar ~date ~close : Types.Daily_price.t =
  Types.Daily_price.make ~date ~open_price:close ~high_price:(close +. 1.0)
    ~low_price:(close -. 1.0) ~close_price:close ~volume:1000
    ~adjusted_close:close ()

(* The property that matters operationally: the rendered, judge-facing
   table text must never contain the real symbol -- reversing the
   pseudonym back to the symbol is only possible via the CLI's separate
   [--mapping-out] artifact (weekly_bars_dump.ml's [_emit_mapping]), which
   this library-level test does not exercise (it is pure I/O plumbing).
   This test pins the guarantee that actually protects the judge: nothing
   in [Table_format.render]'s output leaks the symbol when the caller
   passes blinded labels through. *)
let test_blinded_table_never_leaks_symbol _ =
  let symbol = "ZZZZTEST" in
  let bars =
    [
      _bar ~date:(Date.of_string "2024-01-05") ~close:100.0;
      _bar ~date:(Date.of_string "2024-01-12") ~close:101.0;
    ]
  in
  let pseudonym = Blind.pseudonym_of_symbol symbol in
  let rendered =
    Table_format.render ~symbol_label:pseudonym ~bars
      ~week_labels:(Blind.week_labels (List.length bars))
      ~ma_30w:None
  in
  assert_that rendered (not_ (contains_substring symbol))

let suite =
  "Blind"
  >::: [
         "pseudonym_stable" >:: test_pseudonym_stable;
         "pseudonym_format" >:: test_pseudonym_format;
         "week_labels" >:: test_week_labels;
         "week_labels_empty_for_nonpositive"
         >:: test_week_labels_empty_for_nonpositive;
         "blinded_table_never_leaks_symbol"
         >:: test_blinded_table_never_leaks_symbol;
       ]

let () = run_test_tt_main suite
