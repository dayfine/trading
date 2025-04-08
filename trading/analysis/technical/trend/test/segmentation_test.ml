open OUnit2
open Trend_lib.Segmentation

let float_equal ?(epsilon=0.0001) a b =
  abs_float (a -. b) < epsilon

let test_basic_segmentation _ =
  (* Test data with clear trends *)
  let data = [|
    1.0; 2.0; 3.0; 4.0; 5.0;  (* increasing *)
    5.0; 5.0; 5.0; 5.0; 5.0;  (* flat *)
    5.0; 4.0; 3.0; 2.0; 1.0   (* decreasing *)
  |] in

  let segments = segment_by_trends
    ~min_segment_length:3
    ~preferred_segment_length:5
    ~min_r_squared:0.6
    ~min_slope:0.1
    data in

  (* Should find 3 segments *)
  assert_bool "Should find 3 segments" (Array.length segments = 3);

  (* Check first segment (increasing) *)
  let seg1 = segments.(0) in
  assert_bool "First segment should be increasing" (seg1.trend = "increasing");
  assert_bool "First segment should start at 0" (seg1.start_idx = 0);
  assert_bool "First segment should end at 4" (seg1.end_idx = 4);
  assert_bool "First segment should have high R²" (float_equal seg1.r_squared 1.0);

  (* Check second segment (flat) *)
  let seg2 = segments.(1) in
  assert_bool "Second segment should be flat" (seg2.trend = "flat");
  assert_bool "Second segment should start at 5" (seg2.start_idx = 5);
  assert_bool "Second segment should end at 9" (seg2.end_idx = 9);
  assert_bool "Second segment should have high R²" (float_equal seg2.r_squared 1.0);

  (* Check third segment (decreasing) *)
  let seg3 = segments.(2) in
  assert_bool "Third segment should be decreasing" (seg3.trend = "decreasing");
  assert_bool "Third segment should start at 10" (seg3.start_idx = 10);
  assert_bool "Third segment should end at 14" (seg3.end_idx = 14);
  assert_bool "Third segment should have high R²" (float_equal seg3.r_squared 1.0)

let test_short_data _ =
  (* Test with data too short for segmentation *)
  let data = [|1.0; 2.0; 3.0|] in
  let segments = segment_by_trends
    ~min_segment_length:3
    ~preferred_segment_length:5
    data in

  assert_bool "Should return single segment for short data" (Array.length segments = 1);
  let seg = segments.(0) in
  assert_bool "Segment should span entire data" (seg.start_idx = 0 && seg.end_idx = 2);
  assert_bool "Trend should be unknown" (seg.trend = "unknown")

let suite =
  "segmentation_test" >::: [
    "test_basic_segmentation" >:: test_basic_segmentation;
    "test_short_data" >:: test_short_data;
  ]

let () = run_test_tt_main suite
