open Core
module Series_level = Snapshot_pipeline.Series_level

let report_name = "series_level.csv"

(* The sidecar goes beside the warehouse it describes, so an operator who copies
   an output directory out of the container carries the evidence with it. A
   write failure is logged, never fatal: the build's own output is the product,
   the report is the audit trail. Same contract as [Twin_pass._write_sidecar]
   and [Build_runner._write_tail_report]. *)
let _write_sidecar ~output_dir ~data =
  let path = Filename.concat output_dir report_name in
  try Out_channel.write_all path ~data
  with Sys_error msg ->
    Printf.eprintf "%s write failed: %s\n%!" report_name msg

(* Gated on the CONFIG, not on [findings] being empty. An armed pass that found
   nothing writes the header alone — positive evidence the scan ran — while an
   un-armed build leaves no file at all, so arming is visible in the output
   directory and not arming leaves it untouched. *)
let write_report (config : Series_level.Config.t) ~output_dir findings =
  if config.enabled then begin
    _write_sidecar ~output_dir ~data:(Series_level.to_csv findings);
    Printf.printf "%s\n%!" (Series_level.summary findings)
  end

(* Flag [~doc] strings are hoisted so the [Command.Param] block below stays flat
   — the same convention [Twin_pass] and [build_snapshots.ml] use. *)
let doc_detect =
  "Classify each stored series' price LEVEL (median close above the ceiling) \
   and write " ^ report_name
  ^ ". REPORT-ONLY: never drops, cuts or truncates a symbol. Default off."

let doc_median_max =
  "R Report a series whose median close is strictly above this (default \
   10000.0). The rule knowingly flags a legitimately expensive share class, so \
   raising it is the documented response to a real high-priced name."

let doc_min_bars =
  "N Skip a series with fewer than N finite closes (default 20): a median over \
   a handful of bars is not evidence the series is sane."

let params =
  let default = Series_level.Config.default in
  let%map_open.Command enabled =
    flag "detect-series-level" no_arg ~doc:doc_detect
  and median_close_max =
    flag "series-level-median-max"
      (optional_with_default default.median_close_max float)
      ~doc:doc_median_max
  and min_bars =
    flag "series-level-min-bars"
      (optional_with_default default.min_bars int)
      ~doc:doc_min_bars
  in
  { Series_level.Config.enabled; median_close_max; min_bars }
