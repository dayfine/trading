open OUnit2
open Core
open Matchers
module Output_root = Scenario_lib.Output_root

let _with_temp_dir f =
  let dir = Filename_unix.temp_dir "output_root_test" "" in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () -> ignore (Sys_unix.command (sprintf "rm -rf %s" dir)))

let _pid_suffixed base = sprintf "%s-%d" base (Pid.to_int (Core_unix.getpid ()))

let test_fresh_base _ =
  _with_temp_dir (fun dir ->
      let base = Filename.concat dir "scenarios-ts" in
      assert_that
        (Output_root.claim_output_root ~base)
        (all_of
           [
             equal_to base;
             field (fun p -> Sys_unix.is_directory_exn p) (equal_to true);
           ]))

let test_existing_base_falls_back_to_pid_sibling _ =
  _with_temp_dir (fun dir ->
      let base = Filename.concat dir "scenarios-ts" in
      Core_unix.mkdir base;
      let marker = Filename.concat base "marker.txt" in
      Out_channel.write_all marker ~data:"keep";
      assert_that
        (Output_root.claim_output_root ~base)
        (all_of
           [
             equal_to (_pid_suffixed base);
             field (fun p -> String.equal p base) (equal_to false);
             field (fun p -> Sys_unix.is_directory_exn p) (equal_to true);
             field (fun _ -> In_channel.read_all marker) (equal_to "keep");
           ]))

let test_non_eexist_error_propagates _ =
  _with_temp_dir (fun dir ->
      let blocker = Filename.concat dir "a_file" in
      Out_channel.write_all blocker ~data:"x";
      let base = Filename.concat blocker "scenarios-ts" in
      let raised_unix_error =
        match Output_root.claim_output_root ~base with
        | _ -> false
        | exception Core_unix.Unix_error _ -> true
      in
      assert_that raised_unix_error (equal_to true))

let suite =
  "output_root"
  >::: [
         "fresh base is claimed" >:: test_fresh_base;
         "existing base falls back to pid-suffixed sibling"
         >:: test_existing_base_falls_back_to_pid_sibling;
         "non-EEXIST error propagates" >:: test_non_eexist_error_propagates;
       ]

let () = run_test_tt_main suite
