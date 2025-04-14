open Core
open OUnit2
open Trend_lib.Segmentation

let segment_equal a b =
  a.start_idx = b.start_idx && a.end_idx = b.end_idx
  && String.equal a.trend b.trend

let test_basic_segmentation _ =
  (* Test data with clear trends *)
  let data =
    [|
      1.0;
      2.0;
      3.0;
      4.0;
      5.0;
      (* increasing *)
      5.0;
      5.0;
      5.0;
      5.0;
      5.0;
      (* flat *)
      5.0;
      4.0;
      3.0;
      2.0;
      1.0 (* decreasing *);
    |]
  in

  let segments = segment_by_trends ~params:default_params data in
  let expected =
    [
      {
        start_idx = 0;
        end_idx = 6;
        trend = "increasing";
        r_squared = 0.909090953228;
        channel_width = 0.487949937588;
      };
      {
        start_idx = 7;
        end_idx = 14;
        trend = "decreasing";
        r_squared = 0.850340107509;
        channel_width = 0.611677835971;
      };
    ]
  in

  assert_equal
    ~printer:(fun l -> List.map ~f:show_segment l |> String.concat ~sep:"; ")
    ~cmp:(List.equal segment_equal) expected segments

let test_short_data _ =
  (* Test with data too short for segmentation *)
  let data = [| 1.0; 2.0; 3.0 |] in
  let segments = segment_by_trends ~params:default_params data in

  assert_equal segments
    [
      {
        start_idx = 0;
        end_idx = 2;
        trend = "unknown";
        r_squared = 0.0;
        channel_width = 0.0;
      };
    ]

let suite =
  "segmentation_test"
  >::: [
         "test_basic_segmentation" >:: test_basic_segmentation;
         "test_short_data" >:: test_short_data;
       ]

let () = run_test_tt_main suite
