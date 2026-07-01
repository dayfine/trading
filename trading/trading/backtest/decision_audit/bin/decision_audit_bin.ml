(** [decision_audit] — per-screen faithfulness audit of a backtest's entries.

    Reads a [trade_audit.sexp] (produced by {!Backtest.Result_writer.write}
    alongside [trades.csv]), groups the entry decisions by weekly screen date,
    and for each screen compares the {b funded} entries against the
    {b cash-rejected near-misses} on the captured decision-time features (score,
    grade, stage, weeks_advancing, rs_value, volume_ratio, sector).

    This is a read-only faithfulness lens — it changes no strategy behaviour and
    grades no picks by outcome. It answers: at each screen, do the funded names
    differ from the near-misses on any signal we capture? If none, the tie is
    uninformative and selection is faithful; if one does and we are not funding
    on it, that is a candidate lever. See
    [dev/plans/per-screen-decision-audit-2026-06-30.md].

    When [--snapshot-dir] is supplied, the Phase-2 forward-return counterfactual
    section is appended: the honest "usable signal left on the table" test —
    does the forward return of the cash-rejected near-misses differ from the
    funded names? Absent [--snapshot-dir], only the Phase-1 faithfulness report
    is emitted (no bar reads needed).

    Usage:
    {[
      decision_audit --audit <trade_audit.sexp> [--out report.md]
        [--snapshot-dir <warehouse>] [--horizon-weeks 12]
    ]}

    [--audit] is required. [--out], when given, writes the markdown there;
    otherwise it goes to stdout. [--snapshot-dir] points at the snapshot
    warehouse the run was produced against; when given, the counterfactual
    section is computed and appended. [--horizon-weeks] (default 12) is the
    forward horizon the counterfactual measures returns over. *)

open Core
module TA = Backtest.Trade_audit
module DA = Decision_audit
module Bar_reader = Weinstein_strategy.Bar_reader
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

(* Default forward horizon (weeks) for the Phase-2 counterfactual — one quarter,
   matching the [decision_grading] grade horizon. *)
let _default_horizon_weeks = 12

(* Daily_panels LRU cache budget for the forward-bar reads. Each candidate reads
   a handful of weeks, so a modest cap suffices — same value the
   [decision_grading] lens uses. *)
let _cache_mb = 512

let _usage () =
  eprintf
    "Usage: decision_audit --audit <trade_audit.sexp> [--out report.md] \
     [--snapshot-dir <warehouse>] [--horizon-weeks 12]\n";
  Stdlib.exit 1

type _parse_acc = {
  mutable audit_path : string option;
  mutable out_path : string option;
  mutable snapshot_dir : string option;
  mutable horizon_weeks : int option;
}

let _parse_horizon s =
  match Or_error.try_with (fun () -> Int.of_string (String.strip s)) with
  | Ok n when n > 0 -> n
  | _ ->
      eprintf "--horizon-weeks requires a positive int, got %S\n" s;
      Stdlib.exit 1

let _parse_flag args =
  let acc =
    {
      audit_path = None;
      out_path = None;
      snapshot_dir = None;
      horizon_weeks = None;
    }
  in
  let rec loop = function
    | [] -> acc
    | "--audit" :: p :: rest ->
        acc.audit_path <- Some p;
        loop rest
    | "--out" :: p :: rest ->
        acc.out_path <- Some p;
        loop rest
    | "--snapshot-dir" :: p :: rest ->
        acc.snapshot_dir <- Some p;
        loop rest
    | "--horizon-weeks" :: s :: rest ->
        acc.horizon_weeks <- Some (_parse_horizon s);
        loop rest
    | _ -> _usage ()
  in
  loop args

(** Load the audit records from [path]. Accepts both the combined
    {!TA.audit_blob} envelope and the bare {!TA.audit_records} list, matching
    the loader in [decision_grading_bin]. *)
let _load_audit_records ~path : TA.audit_record list =
  let sexp = Sexp.load_sexp path in
  try (TA.audit_blob_of_sexp sexp).audit_records
  with _ -> TA.audit_records_of_sexp sexp

(** Build a snapshot-backed {!Bar_reader.t} over [snapshot_dir]. Exits the
    process on a missing/corrupt manifest or panel-open failure (the "warehouse
    not built" failure mode surfaces immediately). Mirrors
    [decision_grading_bin._bar_reader_of_snapshot]. *)
let _bar_reader_of_snapshot ~snapshot_dir =
  let manifest_path = Filename.concat snapshot_dir "manifest.sexp" in
  let manifest =
    match Snapshot_manifest.read ~path:manifest_path with
    | Ok m -> m
    | Error err ->
        eprintf "decision_audit: cannot read %s: %s\n" manifest_path
          (Status.show err);
        Stdlib.exit 1
  in
  let panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb:_cache_mb
    with
    | Ok p -> p
    | Error err ->
        eprintf "decision_audit: Daily_panels.create failed: %s\n"
          (Status.show err);
        Stdlib.exit 1
  in
  Bar_reader.of_snapshot_views (Snapshot_callbacks.of_daily_panels panels)

(** The Phase-2 counterfactual section, or the empty string when no
    [--snapshot-dir] was supplied (Phase-1 only). *)
let _counterfactual_section ~snapshot_dir ~horizon_weeks screens : string =
  match snapshot_dir with
  | None -> ""
  | Some dir ->
      let bar_reader = _bar_reader_of_snapshot ~snapshot_dir:dir in
      let forwards =
        DA.Counterfactual.compute screens ~bar_reader ~horizon_weeks
      in
      eprintf
        "decision_audit: forward-return counterfactual over %dw for %d \
         candidates\n\
         %!"
        horizon_weeks (List.length forwards);
      "\n" ^ DA.Report.counterfactual_to_markdown forwards

let () =
  let acc = _parse_flag (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let audit_path =
    Option.value_or_thunk acc.audit_path ~default:(fun () ->
        eprintf "--audit is required\n";
        _usage ())
  in
  let horizon_weeks =
    Option.value acc.horizon_weeks ~default:_default_horizon_weeks
  in
  let records = _load_audit_records ~path:audit_path in
  let screens = DA.Screen_record.of_audit_records records in
  eprintf "decision_audit: %d entries across %d screens from %s\n%!"
    (List.length records) (List.length screens) audit_path;
  let markdown =
    DA.Report.to_markdown screens
    ^ _counterfactual_section ~snapshot_dir:acc.snapshot_dir ~horizon_weeks
        screens
  in
  match acc.out_path with
  | Some path ->
      Out_channel.write_all path ~data:markdown;
      eprintf "decision_audit: wrote %s\n%!" path
  | None -> print_string markdown
