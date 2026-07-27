(** Tests for {!Weinstein_snapshot_gen.Config_overrides_loader}: the file →
    overlay-list → [Overlay_validator.apply_overrides] path used by
    [generate_weekly_snapshot --config-overrides]. *)

open Core
open OUnit2
open Matchers

module Config_overrides_loader =
  Snapshot_config_overrides.Config_overrides_loader

let _base_config () =
  Weinstein_strategy.default_config ~universe:[ "AAPL"; "MSFT" ]
    ~index_symbol:"GSPC.INDX"

let _write_tmp_overrides contents =
  let path = Filename_unix.temp_file "config_overrides" ".sexp" in
  Out_channel.write_all path ~data:contents;
  path

let test_applies_overlays_from_file _ =
  let path =
    _write_tmp_overrides
      "((extension_stop_config ((trigger_ratio 2.0) (trail_pct 0.25))))\n\
       ((reject_declining_ma_long_entry true))\n"
  in
  let config =
    Config_overrides_loader.load_and_apply ~overrides_path:path
      (_base_config ())
  in
  assert_that config
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) ->
             c.extension_stop_config.trigger_ratio)
           (float_equal 2.0);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.extension_stop_config.trail_pct)
           (float_equal 0.25);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.reject_declining_ma_long_entry)
           (equal_to true);
       ])

(* Arming path for the sparse-tail eligibility gate (issue #2083 fix 1): the
   overlay resolves through the SAME [Config_overrides_loader] ->
   [Overlay_validator.apply_overrides] path as every other live-only knob
   (e.g. [resistance_lookback_bars], [screening_config.candidate_ranking]) —
   not a hand-constructed record. This is the mechanism
   [dev/weekly-picks/live-config-overrides.sexp] uses to arm it. *)
let test_applies_sparse_tail_gate_overlay _ =
  let path =
    _write_tmp_overrides
      "((sparse_tail_min_bars 10) (sparse_tail_window_trading_days 15))\n"
  in
  let config =
    Config_overrides_loader.load_and_apply ~overrides_path:path
      (_base_config ())
  in
  assert_that config
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) -> c.sparse_tail_min_bars)
           (equal_to 10);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.sparse_tail_window_trading_days)
           (equal_to 15);
       ])

(* Arming path for live rename detection (issue #2083 fix 2). Same requirement
   as the sparse-tail gate above: R2 (experiment-flag-discipline) says the knobs
   must be real config fields that resolve through the genuine loader /
   validator, which is also what makes them expressible as a [Variant_matrix]
   axis. A typo'd field name would raise here rather than silently no-op. *)
let test_applies_rename_detect_overlay _ =
  let path =
    _write_tmp_overrides
      "((rename_detect_min_overlap_days 5) (rename_detect_match_fraction 0.95))\n"
  in
  let config =
    Config_overrides_loader.load_and_apply ~overrides_path:path
      (_base_config ())
  in
  assert_that config
    (all_of
       [
         field
           (fun (c : Weinstein_strategy.config) ->
             c.rename_detect_min_overlap_days)
           (equal_to 5);
         field
           (fun (c : Weinstein_strategy.config) ->
             c.rename_detect_match_fraction)
           (float_equal 0.95);
       ])

let test_empty_file_is_identity _ =
  let path = _write_tmp_overrides "" in
  let base = _base_config () in
  let config =
    Config_overrides_loader.load_and_apply ~overrides_path:path base
  in
  assert_that config (equal_to (base : Weinstein_strategy.config))

let _raises_failure f =
  match f () with
  | (_ : Weinstein_strategy.config) -> false
  | exception Failure _ -> true

let test_unknown_key_raises _ =
  let path = _write_tmp_overrides "((no_such_config_field true))\n" in
  assert_that
    (_raises_failure (fun () ->
         Config_overrides_loader.load_and_apply ~overrides_path:path
           (_base_config ())))
    (equal_to true)

let test_missing_file_raises _ =
  assert_that
    (_raises_failure (fun () ->
         Config_overrides_loader.load_and_apply
           ~overrides_path:"/nonexistent/overrides.sexp" (_base_config ())))
    (equal_to true)

let suite =
  "config_overrides_loader"
  >::: [
         "applies overlays from file" >:: test_applies_overlays_from_file;
         "applies sparse-tail-gate overlay"
         >:: test_applies_sparse_tail_gate_overlay;
         "applies rename-detect overlay" >:: test_applies_rename_detect_overlay;
         "empty file is identity" >:: test_empty_file_is_identity;
         "unknown key raises" >:: test_unknown_key_raises;
         "missing file raises" >:: test_missing_file_raises;
       ]

let () = run_test_tt_main suite
