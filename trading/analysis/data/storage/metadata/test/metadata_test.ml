open Core
open OUnit2
open Metadata

let create_test_price_data ~start_date ~end_date ~prices ~volumes =
  let rec generate_dates current acc =
    if Date.compare current end_date > 0 then
      List.rev acc
    else
      generate_dates (Date.add_days current 1) (current :: acc)
  in
  let dates = generate_dates start_date [] in
  List.map2_exn dates (List.zip_exn prices volumes) ~f:(fun date (price, volume) ->
      Types.Daily_price.create ~date ~open_price:price ~high_price:price ~low_price:price
        ~close_price:price ~volume)

let test_normal_prices _ =
  let start_date = Date.of_string "2024-01-01" in
  let end_date = Date.of_string "2024-01-10" in
  let prices = List.init 10 ~f:(fun i -> Float.of_int (i + 100)) in
  let volumes = List.init 10 ~f:(fun _ -> 1000) in
  let price_data = create_test_price_data ~start_date ~end_date ~prices ~volumes in
  let metadata = generate_metadata ~price_data ~symbol:"TEST" () in
  let expected = {
    symbol = "TEST";
    last_verified = Date.today ~zone:Time_float.Zone.utc;
    verification_status = Verified;
    data_start_date = start_date;
    data_end_date = end_date;
    has_volume = true;
    last_n_prices_avg_below_10 = false;
    last_n_prices_avg_above_500 = false;
  } in
  assert_equal ~printer:show_t metadata expected

let test_low_prices _ =
  let start_date = Date.of_string "2024-01-01" in
  let end_date = Date.of_string "2024-01-10" in
  let prices = List.init 10 ~f:(fun i -> Float.of_int (i + 1)) in
  let volumes = List.init 10 ~f:(fun _ -> 1000) in
  let price_data = create_test_price_data ~start_date ~end_date ~prices ~volumes in
  let metadata = generate_metadata ~price_data ~symbol:"TEST" () in
  assert_bool "Should have average price below 10" metadata.last_n_prices_avg_below_10

let test_high_prices _ =
  let start_date = Date.of_string "2024-01-01" in
  let end_date = Date.of_string "2024-01-10" in
  let prices = List.init 10 ~f:(fun i -> Float.of_int (i + 500)) in
  let volumes = List.init 10 ~f:(fun _ -> 1000) in
  let price_data = create_test_price_data ~start_date ~end_date ~prices ~volumes in
  let metadata = generate_metadata ~price_data ~symbol:"TEST" () in
  assert_bool "Should have average price above 500" metadata.last_n_prices_avg_above_500

let test_no_volume _ =
  let start_date = Date.of_string "2024-01-01" in
  let end_date = Date.of_string "2024-01-10" in
  let prices = List.init 10 ~f:(fun i -> Float.of_int (i + 100)) in
  let volumes = List.init 10 ~f:(fun _ -> 0) in
  let price_data = create_test_price_data ~start_date ~end_date ~prices ~volumes in
  let metadata = generate_metadata ~price_data ~symbol:"TEST" () in
  assert_bool "Should not have volume" (not metadata.has_volume)

let test_custom_n _ =
  let start_date = Date.of_string "2024-01-01" in
  let end_date = Date.of_string "2024-01-30" in
  let prices = List.init 30 ~f:(fun i -> Float.of_int (i + 100)) in
  let volumes = List.init 30 ~f:(fun _ -> 1000) in
  let price_data = create_test_price_data ~start_date ~end_date ~prices ~volumes in
  let metadata = generate_metadata ~price_data ~symbol:"TEST" ~n:5 () in
  assert_equal ~printer:show_verification_status Verified metadata.verification_status

let suite =
  "metadata_test_suite" >::: [
    "test_normal_prices" >:: test_normal_prices;
    "test_low_prices" >:: test_low_prices;
    "test_high_prices" >:: test_high_prices;
    "test_no_volume" >:: test_no_volume;
    "test_custom_n" >:: test_custom_n;
  ]

let () = run_test_tt_main suite
