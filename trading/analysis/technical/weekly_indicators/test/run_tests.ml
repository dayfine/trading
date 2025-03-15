open OUnit2

let suite = "All tests" >::: [
  Test_date.suite;
  Test_csv_parser.suite;
  Test_ema.suite;
]

let () = run_test_tt_main suite
