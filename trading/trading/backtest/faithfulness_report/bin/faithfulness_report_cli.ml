(** CLI for the faithfulness / sensibility report.

    Profiles one run's [trades.csv] (whipsaw rate, hold-time, stop width per
    entry-year) and, given a second run, the per-year + per-symbol P&L
    divergence between the two arms. Writes the Markdown report to [-out] (or
    stdout). See [dev/plans/fill-model-faithfulness-2026-08-07.md]. *)

open Core

let _write ~out md =
  match out with
  | Some path -> Out_channel.write_all path ~data:md
  | None -> print_string md

let command =
  Command.basic ~summary:"Backtest trade faithfulness / sensibility report"
    (let%map_open.Command a_path =
       flag "-a" (required string) ~doc:"FILE arm-A trades.csv"
     and b_path =
       flag "-b" (optional string) ~doc:"FILE arm-B trades.csv (optional)"
     and a_label =
       flag "-a-label" (optional_with_default "A" string) ~doc:"STR arm-A label"
     and b_label =
       flag "-b-label" (optional_with_default "B" string) ~doc:"STR arm-B label"
     and whipsaw_days =
       flag "-whipsaw-days"
         (optional_with_default 3 int)
         ~doc:"N whipsaw threshold in days (default 3)"
     and hold_ge =
       flag "-hold-ge"
         (optional_with_default 200 int)
         ~doc:"N runner hold threshold in days (default 200)"
     and stop_gt =
       flag "-stop-gt"
         (optional_with_default 0.15 float)
         ~doc:"F stop-width threshold fraction (default 0.15)"
     and top_k =
       flag "-top-k"
         (optional_with_default 20 int)
         ~doc:"N symbol divergences to list (default 20)"
     and out =
       flag "-out" (optional string) ~doc:"FILE output .md (default stdout)"
     in
     fun () ->
       Faithfulness_report.run ?b_path ~a_label ~b_label ~whipsaw_days ~hold_ge
         ~stop_gt ~top_k ~a_path ()
       |> _write ~out)

let () = Command_unix.run command
