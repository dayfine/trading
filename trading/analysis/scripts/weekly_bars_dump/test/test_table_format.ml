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

(* Five distinct, non-symmetric OHLCV values -- deliberately NOT the [_bar]
   helper above, whose high/low are mirror images of open and would let a
   high/low transposition (or a close/adjusted_close mixup) pass unnoticed.
   [adjusted_close] is set to a sixth, distinct value so a regression that
   rendered it instead of [close_price] is also caught. *)
let _distinct_bar : Types.Daily_price.t =
  Types.Daily_price.make
    ~date:(Date.of_string "2024-01-05")
    ~open_price:10.0 ~high_price:14.0 ~low_price:9.0 ~close_price:11.0
    ~volume:12345 ~adjusted_close:999.0 ()

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

(* Pins the row's field ORDER and VALUES, not just the header/labels the
   other tests already cover. The expected substring is built independently
   from [_row_line]'s implementation, in the semantic order the header
   promises ("week open high low close volume") -- a regression that
   transposed [high_price]/[low_price], or substituted [adjusted_close] for
   [close_price], would leave the other three tests green but fail this one. *)
let test_render_row_preserves_field_order_and_values _ =
  let rendered =
    Table_format.render ~symbol_label:"SYM-ABCD" ~bars:[ _distinct_bar ]
      ~week_labels:[ "w1" ] ~ma_30w:None
  in
  assert_that rendered
    (contains_substring
       (Printf.sprintf "%-4s %10.2f %10.2f %10.2f %10.2f %12d" "w1" 10.0 14.0
          9.0 11.0 12345))

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
         "render_row_preserves_field_order_and_values"
         >:: test_render_row_preserves_field_order_and_values;
         "render_rejects_mismatched_label_length"
         >:: test_render_rejects_mismatched_label_length;
       ]

let () = run_test_tt_main suite
