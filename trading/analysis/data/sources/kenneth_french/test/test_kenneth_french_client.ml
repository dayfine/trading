open Core
open OUnit2
open Matchers
open Kenneth_french.Kenneth_french_client

(* The pinned sample fixture mirrors the source-CSV's two-block structure:
   - 7-line preamble + blank lines.
   - "Average Value Weighted Returns -- Daily" block header + industry
     header + 4 data rows (1926-07-01, 1926-07-02, 2020-03-16 covid crash,
     2026-03-31).
   - blank separator + "Average Equal Weighted Returns -- Daily" block
     header + identical structure, but with one synthetic [-99.99] sentinel
     on the 2020-03-16 Consumer cell to exercise the sentinel→None path.
   - trailing copyright line.

   Small enough to keep in-repo + exercises every structural branch of
   {!parse}. *)
let _fixture_path = "./data/french_5industry_sample.csv"
let _read () = In_channel.read_all _fixture_path

let _parsed_or_fail body =
  match parse body with
  | Ok parsed -> parsed
  | Error err -> failwith ("Kenneth French parse failed: " ^ Status.show err)

let _date y m d = Date.create_exn ~y ~m ~d
let _expected_industries = [ "Cnsmr"; "Manuf"; "HiTec"; "Hlth"; "Other" ]

let test_parse_extracts_both_blocks _ =
  let parsed = _parsed_or_fail (_read ()) in
  assert_that parsed
    (all_of
       [
         field (fun p -> p.value_weighted.observations) (size_is 4);
         field (fun p -> p.equal_weighted.observations) (size_is 4);
       ])

let test_industries_pinned_in_source_order _ =
  let parsed = _parsed_or_fail (_read ()) in
  assert_that parsed
    (all_of
       [
         field
           (fun p -> p.value_weighted.industries)
           (equal_to _expected_industries);
         field
           (fun p -> p.equal_weighted.industries)
           (equal_to _expected_industries);
       ])

let test_vw_first_row_is_1926_07_01_with_pinned_values _ =
  let parsed = _parsed_or_fail (_read ()) in
  match parsed.value_weighted.observations with
  | first :: _ ->
      assert_that first
        (all_of
           [
             field (fun o -> o.date) (equal_to (_date 1926 Month.Jul 1));
             field
               (fun o -> o.industry_returns)
               (elements_are
                  [
                    equal_to ("Cnsmr", Some (-0.09));
                    equal_to ("Manuf", Some 0.22);
                    equal_to ("HiTec", Some (-0.11));
                    equal_to ("Hlth", Some 0.97);
                    equal_to ("Other", Some 0.20);
                  ]);
           ])
  | [] -> assert_failure "Expected non-empty VW observations"

let test_ew_first_row_distinct_values_from_vw _ =
  let parsed = _parsed_or_fail (_read ()) in
  match parsed.equal_weighted.observations with
  | first :: _ ->
      assert_that first
        (all_of
           [
             field (fun o -> o.date) (equal_to (_date 1926 Month.Jul 1));
             field
               (fun o -> o.industry_returns)
               (elements_are
                  [
                    equal_to ("Cnsmr", Some 0.14);
                    equal_to ("Manuf", Some 0.03);
                    equal_to ("HiTec", Some (-0.06));
                    equal_to ("Hlth", Some 1.43);
                    equal_to ("Other", Some 0.36);
                  ]);
           ])
  | [] -> assert_failure "Expected non-empty EW observations"

(* The covid-era 2020-03-16 row exercises a deeply-negative real value (no
   sentinel) on the VW side. Asserting Cnsmr at -12.38 guards against
   accidental sentinel widening that would silently drop genuine crash
   data. *)
let test_vw_covid_crash_negative_value_not_sentinelled _ =
  let parsed = _parsed_or_fail (_read ()) in
  let covid =
    List.find parsed.value_weighted.observations ~f:(fun o ->
        Date.equal o.date (_date 2020 Month.Mar 16))
  in
  assert_that covid
    (is_some_and
       (field
          (fun o -> o.industry_returns)
          (elements_are
             [
               equal_to ("Cnsmr", Some (-12.38));
               equal_to ("Manuf", Some (-11.45));
               equal_to ("HiTec", Some (-9.84));
               equal_to ("Hlth", Some (-10.43));
               equal_to ("Other", Some (-11.92));
             ])))

(* The EW 2020-03-16 row uses the [-99.99] missing-data sentinel on the
   Cnsmr cell. Parser must map it to [None]; other cells stay as [Some _]. *)
let test_ew_covid_sentinel_maps_to_none _ =
  let parsed = _parsed_or_fail (_read ()) in
  let covid =
    List.find parsed.equal_weighted.observations ~f:(fun o ->
        Date.equal o.date (_date 2020 Month.Mar 16))
  in
  assert_that covid
    (is_some_and
       (field
          (fun o -> o.industry_returns)
          (elements_are
             [
               equal_to ("Cnsmr", None);
               equal_to ("Manuf", Some (-8.50));
               equal_to ("HiTec", Some (-7.10));
               equal_to ("Hlth", Some (-8.20));
               equal_to ("Other", Some (-9.15));
             ])))

let test_vw_observations_in_source_order _ =
  let parsed = _parsed_or_fail (_read ()) in
  let dates =
    List.map parsed.value_weighted.observations ~f:(fun o -> o.date)
  in
  assert_that dates
    (elements_are
       [
         equal_to (_date 1926 Month.Jul 1);
         equal_to (_date 1926 Month.Jul 2);
         equal_to (_date 2020 Month.Mar 16);
         equal_to (_date 2026 Month.Mar 31);
       ])

let test_missing_vw_block_header_is_error _ =
  let body =
    "Just a preamble line\n\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,  -0.09,   0.22,  -0.11,   0.97,   0.20\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_missing_ew_block_header_is_error _ =
  let body =
    "  Average Value Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,  -0.09,   0.22,  -0.11,   0.97,   0.20\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_empty_body_is_error _ =
  assert_that (parse "") (is_error_with Status.Invalid_argument)

let test_whitespace_only_body_is_error _ =
  assert_that (parse "\n  \n\n") (is_error_with Status.Invalid_argument)

let test_unparseable_date_is_error _ =
  let body =
    "  Average Value Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     not-date,  -0.09,   0.22,  -0.11,   0.97,   0.20\n\n\
    \  Average Equal Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,   0.14,   0.03,  -0.06,   1.43,   0.36\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_wrong_column_count_is_error _ =
  let body =
    "  Average Value Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,  -0.09,   0.22\n\n\
    \  Average Equal Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,   0.14,   0.03,  -0.06,   1.43,   0.36\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

let test_unparseable_numeric_is_error _ =
  let body =
    "  Average Value Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,  NOT_A_NUMBER,   0.22,  -0.11,   0.97,   0.20\n\n\
    \  Average Equal Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,   0.14,   0.03,  -0.06,   1.43,   0.36\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

(* Industry mismatch between the two blocks is structurally impossible in
   the real CSV, but the parser explicitly checks it as a defensive
   contract. *)
let test_industry_mismatch_between_blocks_is_error _ =
  let body =
    "  Average Value Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,Other\n\
     19260701,  -0.09,   0.22,  -0.11,   0.97,   0.20\n\n\
    \  Average Equal Weighted Returns -- Daily\n\
     ,Cnsmr,Manuf,HiTec,Hlth,DIFFERENT\n\
     19260701,   0.14,   0.03,  -0.06,   1.43,   0.36\n"
  in
  assert_that (parse body) (is_error_with Status.Invalid_argument)

(* UTF-8 BOM tolerance — defensive guard against transcoding artifacts. *)
let test_utf8_bom_is_tolerated _ =
  let body = "\xEF\xBB\xBF" ^ _read () in
  let parsed = _parsed_or_fail body in
  assert_that parsed.value_weighted.observations (size_is 4)

(* CRLF line endings — the real upstream file uses CRLF. [String.split_lines]
   strips both \r\n and \n so this round-trips, but a regression test pins
   the contract. *)
let test_crlf_line_endings_are_tolerated _ =
  let body = String.substr_replace_all (_read ()) ~pattern:"\n" ~with_:"\r\n" in
  let parsed = _parsed_or_fail body in
  assert_that parsed
    (all_of
       [
         field (fun p -> p.value_weighted.observations) (size_is 4);
         field (fun p -> p.equal_weighted.observations) (size_is 4);
       ])

let test_source_uri_is_dartmouth_tuck_zip _ =
  let uri_str = Uri.to_string source_uri in
  assert_that uri_str
    (all_of
       [
         contains_substring "https://mba.tuck.dartmouth.edu/";
         contains_substring "ken.french";
         contains_substring "5_Industry_Portfolios_daily_CSV.zip";
       ])

let test_source_uri_5industry_alias_matches_legacy _ =
  assert_that (Uri.equal source_uri source_uri_5industry) (equal_to true)

let test_source_uri_49industry_is_dartmouth_tuck_zip _ =
  let uri_str = Uri.to_string source_uri_49industry in
  assert_that uri_str
    (all_of
       [
         contains_substring "https://mba.tuck.dartmouth.edu/";
         contains_substring "ken.french";
         contains_substring "49_Industry_Portfolios_daily_CSV.zip";
       ])

(* ===========================================================================
   49-Industry daily dataset — same parser, wider column header.

   The pinned 49-Industry sample fixture mirrors the upstream layout
   verbatim: 7-line preamble, the VW block with 4 rows (1926-07-01,
   1926-07-02, 1929-10-28 Black Monday, 2026-03-31), a blank separator,
   the EW block with the same 4 dates, and a trailing copyright line.

   These tests pin: (a) the parser is column-count-agnostic — same code
   path, just 49 columns; (b) industry order in the header is preserved;
   (c) pinned spot-check values (Agric on 1929-10-28 = -5.80 VW / -5.25
   EW) detect any silent reorder; (d) sentinel mapping still fires for
   the many [-99.99] cells in the early 1926 rows (industries like
   Soda/Hlth/Rubbr/FabPr etc. did not exist in 1926). *)

let _fixture_path_49 = "./data/french_49industry_sample.csv"
let _read_49 () = In_channel.read_all _fixture_path_49

let _expected_industries_49 =
  [
    "Agric";
    "Food";
    "Soda";
    "Beer";
    "Smoke";
    "Toys";
    "Fun";
    "Books";
    "Hshld";
    "Clths";
    "Hlth";
    "MedEq";
    "Drugs";
    "Chems";
    "Rubbr";
    "Txtls";
    "BldMt";
    "Cnstr";
    "Steel";
    "FabPr";
    "Mach";
    "ElcEq";
    "Autos";
    "Aero";
    "Ships";
    "Guns";
    "Gold";
    "Mines";
    "Coal";
    "Oil";
    "Util";
    "Telcm";
    "PerSv";
    "BusSv";
    "Hardw";
    "Softw";
    "Chips";
    "LabEq";
    "Paper";
    "Boxes";
    "Trans";
    "Whlsl";
    "Rtail";
    "Meals";
    "Banks";
    "Insur";
    "RlEst";
    "Fin";
    "Other";
  ]

let test_49ind_parse_extracts_both_blocks _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  assert_that parsed
    (all_of
       [
         field (fun p -> p.value_weighted.observations) (size_is 4);
         field (fun p -> p.equal_weighted.observations) (size_is 4);
       ])

let test_49ind_industries_pinned_in_source_order _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  assert_that parsed
    (all_of
       [
         field
           (fun p -> p.value_weighted.industries)
           (equal_to _expected_industries_49);
         field
           (fun p -> p.equal_weighted.industries)
           (equal_to _expected_industries_49);
       ])

let test_49ind_industries_count_is_49 _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  assert_that parsed
    (all_of
       [
         field (fun p -> p.value_weighted.industries) (size_is 49);
         field (fun p -> p.equal_weighted.industries) (size_is 49);
       ])

(* Spot-check the first row of each block. Agric should be the first
   industry; the value pinned here is the verbatim upstream cell. If
   industry order silently shifts, these assertions would fire because
   the [(industry, return)] tuple equality includes the industry name. *)
let test_49ind_vw_first_row_agric_pinned _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  match parsed.value_weighted.observations with
  | first :: _ ->
      assert_that first
        (all_of
           [
             field (fun o -> o.date) (equal_to (_date 1926 Month.Jul 1));
             field
               (fun o -> List.hd_exn o.industry_returns)
               (equal_to ("Agric", Some 0.56));
             field
               (fun o -> List.last_exn o.industry_returns)
               (equal_to ("Other", Some (-1.66)));
             field (fun o -> o.industry_returns) (size_is 49);
           ])
  | [] -> assert_failure "Expected non-empty 49-industry VW observations"

let test_49ind_ew_first_row_agric_pinned _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  match parsed.equal_weighted.observations with
  | first :: _ ->
      assert_that first
        (all_of
           [
             field (fun o -> o.date) (equal_to (_date 1926 Month.Jul 1));
             field
               (fun o -> List.hd_exn o.industry_returns)
               (equal_to ("Agric", Some 0.63));
             field
               (fun o -> List.last_exn o.industry_returns)
               (equal_to ("Other", Some (-0.75)));
             field (fun o -> o.industry_returns) (size_is 49);
           ])
  | [] -> assert_failure "Expected non-empty 49-industry EW observations"

(* The 1929-10-28 Black Monday row pins a known historical event.
   Agric VW = -5.80, Agric EW = -5.25 per the Dartmouth/Tuck CSV. We
   spot-check Agric on both blocks plus a tail-industry (Other) to
   detect silent column-misalignment that would not surface on a single
   industry. *)
let test_49ind_vw_black_monday_1929_agric _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  let row =
    List.find parsed.value_weighted.observations ~f:(fun o ->
        Date.equal o.date (_date 1929 Month.Oct 28))
  in
  assert_that row
    (is_some_and
       (field
          (fun o ->
            List.find_exn o.industry_returns ~f:(fun (name, _) ->
                String.equal name "Agric"))
          (equal_to ("Agric", Some (-5.80)))))

let test_49ind_ew_black_monday_1929_agric _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  let row =
    List.find parsed.equal_weighted.observations ~f:(fun o ->
        Date.equal o.date (_date 1929 Month.Oct 28))
  in
  assert_that row
    (is_some_and
       (field
          (fun o ->
            List.find_exn o.industry_returns ~f:(fun (name, _) ->
                String.equal name "Agric"))
          (equal_to ("Agric", Some (-5.25)))))

(* Sentinels (-99.99) are dense in the early 1926 rows because many
   industries (Soda, Hlth, Rubbr, FabPr, Guns, Gold, Mines, PerSv,
   Softw, Boxes) didn't exist as separately-tracked SIC buckets in 1926.
   Pin one example per block to confirm the sentinel→None mapping
   survives the wider-column code path. *)
let test_49ind_vw_first_row_sentinel_industries_are_none _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  match parsed.value_weighted.observations with
  | first :: _ ->
      let soda =
        List.find_exn first.industry_returns ~f:(fun (name, _) ->
            String.equal name "Soda")
      in
      assert_that soda (equal_to ("Soda", None))
  | [] -> assert_failure "Expected non-empty 49-industry VW observations"

let test_49ind_ew_first_row_sentinel_industries_are_none _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  match parsed.equal_weighted.observations with
  | first :: _ ->
      let hlth =
        List.find_exn first.industry_returns ~f:(fun (name, _) ->
            String.equal name "Hlth")
      in
      assert_that hlth (equal_to ("Hlth", None))
  | [] -> assert_failure "Expected non-empty 49-industry EW observations"

let test_49ind_observations_in_source_order _ =
  let parsed = _parsed_or_fail (_read_49 ()) in
  let dates =
    List.map parsed.value_weighted.observations ~f:(fun o -> o.date)
  in
  assert_that dates
    (elements_are
       [
         equal_to (_date 1926 Month.Jul 1);
         equal_to (_date 1926 Month.Jul 2);
         equal_to (_date 1929 Month.Oct 28);
         equal_to (_date 2026 Month.Mar 31);
       ])

(* Defensive: the 49-Industry CSV is upstream-identical in shape to the
   5-Industry one, so industry-mismatch between blocks is structurally
   impossible. The contract still asserts it; pin a counterexample on
   the 49-wide axis so the test exercises the wide-column path. *)
let test_49ind_industry_mismatch_between_blocks_is_error _ =
  let body = _read_49 () in
  let corrupted =
    String.substr_replace_first body
      ~pattern:
        ",Agric,Food,Soda,Beer,Smoke,Toys,Fun,Books,Hshld,Clths,Hlth,MedEq,Drugs,Chems,Rubbr,Txtls,BldMt,Cnstr,Steel,FabPr,Mach,ElcEq,Autos,Aero,Ships,Guns,Gold,Mines,Coal,Oil,Util,Telcm,PerSv,BusSv,Hardw,Softw,Chips,LabEq,Paper,Boxes,Trans,Whlsl,Rtail,Meals,Banks,Insur,RlEst,Fin,Other\n\
         19260701,   0.63"
      ~with_:
        ",Agric,Food,Soda,Beer,Smoke,Toys,Fun,Books,Hshld,Clths,Hlth,MedEq,Drugs,Chems,Rubbr,Txtls,BldMt,Cnstr,Steel,FabPr,Mach,ElcEq,Autos,Aero,Ships,Guns,Gold,Mines,Coal,Oil,Util,Telcm,PerSv,BusSv,Hardw,Softw,Chips,LabEq,Paper,Boxes,Trans,Whlsl,Rtail,Meals,Banks,Insur,RlEst,Fin,DIFFERENT\n\
         19260701,   0.63"
  in
  assert_that (parse corrupted) (is_error_with Status.Invalid_argument)

let suite =
  "kenneth_french_client"
  >::: [
         "test_parse_extracts_both_blocks" >:: test_parse_extracts_both_blocks;
         "test_industries_pinned_in_source_order"
         >:: test_industries_pinned_in_source_order;
         "test_vw_first_row_is_1926_07_01_with_pinned_values"
         >:: test_vw_first_row_is_1926_07_01_with_pinned_values;
         "test_ew_first_row_distinct_values_from_vw"
         >:: test_ew_first_row_distinct_values_from_vw;
         "test_vw_covid_crash_negative_value_not_sentinelled"
         >:: test_vw_covid_crash_negative_value_not_sentinelled;
         "test_ew_covid_sentinel_maps_to_none"
         >:: test_ew_covid_sentinel_maps_to_none;
         "test_vw_observations_in_source_order"
         >:: test_vw_observations_in_source_order;
         "test_missing_vw_block_header_is_error"
         >:: test_missing_vw_block_header_is_error;
         "test_missing_ew_block_header_is_error"
         >:: test_missing_ew_block_header_is_error;
         "test_empty_body_is_error" >:: test_empty_body_is_error;
         "test_whitespace_only_body_is_error"
         >:: test_whitespace_only_body_is_error;
         "test_unparseable_date_is_error" >:: test_unparseable_date_is_error;
         "test_wrong_column_count_is_error" >:: test_wrong_column_count_is_error;
         "test_unparseable_numeric_is_error"
         >:: test_unparseable_numeric_is_error;
         "test_industry_mismatch_between_blocks_is_error"
         >:: test_industry_mismatch_between_blocks_is_error;
         "test_utf8_bom_is_tolerated" >:: test_utf8_bom_is_tolerated;
         "test_crlf_line_endings_are_tolerated"
         >:: test_crlf_line_endings_are_tolerated;
         "test_source_uri_is_dartmouth_tuck_zip"
         >:: test_source_uri_is_dartmouth_tuck_zip;
         "test_source_uri_5industry_alias_matches_legacy"
         >:: test_source_uri_5industry_alias_matches_legacy;
         "test_source_uri_49industry_is_dartmouth_tuck_zip"
         >:: test_source_uri_49industry_is_dartmouth_tuck_zip;
         "test_49ind_parse_extracts_both_blocks"
         >:: test_49ind_parse_extracts_both_blocks;
         "test_49ind_industries_pinned_in_source_order"
         >:: test_49ind_industries_pinned_in_source_order;
         "test_49ind_industries_count_is_49"
         >:: test_49ind_industries_count_is_49;
         "test_49ind_vw_first_row_agric_pinned"
         >:: test_49ind_vw_first_row_agric_pinned;
         "test_49ind_ew_first_row_agric_pinned"
         >:: test_49ind_ew_first_row_agric_pinned;
         "test_49ind_vw_black_monday_1929_agric"
         >:: test_49ind_vw_black_monday_1929_agric;
         "test_49ind_ew_black_monday_1929_agric"
         >:: test_49ind_ew_black_monday_1929_agric;
         "test_49ind_vw_first_row_sentinel_industries_are_none"
         >:: test_49ind_vw_first_row_sentinel_industries_are_none;
         "test_49ind_ew_first_row_sentinel_industries_are_none"
         >:: test_49ind_ew_first_row_sentinel_industries_are_none;
         "test_49ind_observations_in_source_order"
         >:: test_49ind_observations_in_source_order;
         "test_49ind_industry_mismatch_between_blocks_is_error"
         >:: test_49ind_industry_mismatch_between_blocks_is_error;
       ]

let () = run_test_tt_main suite
