open OUnit2
open Matchers

let test_letters_uppercased _ =
  assert_that
    (List.map Csv.Symbol_shard.letters [ "COMP_old"; "AAPL"; "X"; "FB_old" ])
    (elements_are
       [
         equal_to ("C", "D");
         equal_to ("A", "L");
         equal_to ("X", "X");
         equal_to ("F", "D");
       ])

let test_dir_and_paths _ =
  let data_dir = Fpath.v "/data" in
  assert_that
    ( Csv.Symbol_shard.dir "COMP_old",
      Csv.Symbol_shard.dir "AAPL",
      Fpath.to_string (Csv.Csv_storage.symbol_data_dir ~data_dir "COMP_old"),
      Fpath.to_string (Csv.Csv_storage.shard_manifest_path ~data_dir "COMP_old"),
      Fpath.to_string
        (Csv.Csv_storage_manifest.shard_manifest_path ~data_dir "COMP_old") )
    (equal_to
       ( "C/D",
         "A/L",
         "/data/C/D/COMP_old",
         "/data/C/D/manifest.sexp",
         "/data/C/D/manifest.sexp" ))

let suite =
  "symbol_shard"
  >::: [
         "letters uppercased" >:: test_letters_uppercased;
         "dir and path builders" >:: test_dir_and_paths;
       ]

let () = run_test_tt_main suite
