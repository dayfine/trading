open Core
open OUnit2
open Matchers
module Table_format = Weekly_bars_dump_lib.Table_format

let _bar ~date ~close : Types.Daily_price.t =
  Types.Daily_price.make ~date ~open_price:close ~high_price:(close +. 1.0)
    ~low_price:(close -. 1.0) ~close_price:close ~volume:1000
    ~adjusted_close:close ()

let _bars =
  [
    _bar ~date:(Date.of_string "2024-01-05") ~close:100.0;
    _bar ~date:(Date.of_string "2024-01-12") ~close:101.0;
  ]

let test_render_header_states_count_and_no_future_bars _ =
  let rendered =
    Table_format.render ~symbol_label:"SYM-ABCD" ~bars:_bars
      ~week_labels:[ "w1"; "w2" ] ~ma_30w:None
  in
  assert_that rendered
    (all_of
       [
         contains_substring "SYM-ABCD";
         contains_substring "n=2";
         contains_substring "no bars after it";
         contains_substring "w1";
         contains_substring "w2";
       ])

let test_render_omits_ma_footer_when_none _ =
  let rendered =
    Table_format.render ~symbol_label:"SYM-ABCD" ~bars:_bars
      ~week_labels:[ "w1"; "w2" ] ~ma_30w:None
  in
  assert_that rendered (not_ (contains_substring "30w MA"))

let test_render_appends_ma_footer_when_some _ =
  let rendered =
    Table_format.render ~symbol_label:"SYM-ABCD" ~bars:_bars
      ~week_labels:[ "w1"; "w2" ] ~ma_30w:(Some 123.45)
  in
  assert_that rendered (contains_substring "30w MA at decision week: 123.45")

let test_render_rejects_mismatched_label_length _ =
  assert_raises
    (Invalid_argument "Table_format.render: 2 bars but 1 week_labels")
    (fun () ->
      Table_format.render ~symbol_label:"SYM-ABCD" ~bars:_bars
        ~week_labels:[ "w1" ] ~ma_30w:None)

let suite =
  "Table_format"
  >::: [
         "render_header_states_count_and_no_future_bars"
         >:: test_render_header_states_count_and_no_future_bars;
         "render_omits_ma_footer_when_none"
         >:: test_render_omits_ma_footer_when_none;
         "render_appends_ma_footer_when_some"
         >:: test_render_appends_ma_footer_when_some;
         "render_rejects_mismatched_label_length"
         >:: test_render_rejects_mismatched_label_length;
       ]

let () = run_test_tt_main suite
