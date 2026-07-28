(** [validate_weekly_snapshot] CLI — run {!Snapshot_validator} over a pick file
    (issue #2122 v1).

    Usage:
    [validate_weekly_snapshot <pick-file> [-bars-snapshot-dir PATH]
     [-risk-budget N] [-through-band N] [-extension-max N]]

    Prints one line per finding ("ERROR SYM check: detail" / "WARN ...") or an
    explicit "OK: no findings". Exit 0 when no Error-level finding, 1 when any
    Error, 2 on usage errors. Threshold defaults mirror the live arming config
    (band 1.0 / max 15.0); pass the armed values explicitly when they change so
    the validator judges the artifact under the config that produced it.

    [-bars-snapshot-dir] enables the bar-dependent checks (chart coverage,
    split-in-window basis-suspect flags) from the same warehouse the report
    charts read. *)

open Core
open Weinstein_snapshot

type _flags = {
  bars_snapshot_dir : string option;
  risk_budget : float option;
  through_band_pct : float option;
  extension_max_pct : float option;
}

let _no_flags =
  {
    bars_snapshot_dir = None;
    risk_budget = None;
    through_band_pct = None;
    extension_max_pct = None;
  }

(* Same chart-history depth as render_weekly_report: ~2y window + 30w MA
   lookback + holiday slack. *)
let _bar_history_calendar_days = 1000

let _usage () =
  eprintf
    "Usage: validate_weekly_snapshot <pick-file> [-bars-snapshot-dir PATH] \
     [-risk-budget N] [-through-band N] [-extension-max N]\n";
  exit 2

let rec _parse_flags args (acc : _flags) =
  match args with
  | [] -> acc
  | "-bars-snapshot-dir" :: d :: rest ->
      _parse_flags rest { acc with bars_snapshot_dir = Some d }
  | "-risk-budget" :: n :: rest ->
      _parse_flags rest { acc with risk_budget = Some (Float.of_string n) }
  | "-through-band" :: n :: rest ->
      _parse_flags rest { acc with through_band_pct = Some (Float.of_string n) }
  | "-extension-max" :: n :: rest ->
      _parse_flags rest
        { acc with extension_max_pct = Some (Float.of_string n) }
  | _ -> _usage ()

let _read_snapshot path : Weekly_snapshot.t =
  match Snapshot_reader.read_from_file path with
  | Ok t -> t
  | Error err ->
      eprintf "Failed to read snapshot %s: %s\n" path (Status.show err);
      exit 1

let _bars_for ~warehouse_dir ~(as_of : Date.t) =
  let reader =
    Weinstein_snapshot_gen.Snapshot_warehouse_reader.build ~warehouse_dir ~as_of
      ~warmup_days:_bar_history_calendar_days ()
  in
  fun ~symbol ->
    Weinstein_strategy.Bar_reader.daily_bars_for reader ~symbol ~as_of

let () =
  match Sys.get_argv () |> Array.to_list with
  | _ :: pick_path :: flags ->
      let flags = _parse_flags flags _no_flags in
      let snap = _read_snapshot pick_path in
      let bars_for =
        Option.map flags.bars_snapshot_dir ~f:(fun warehouse_dir ->
            _bars_for ~warehouse_dir ~as_of:snap.Weekly_snapshot.date)
      in
      let findings =
        Snapshot_validator.validate ?through_band_pct:flags.through_band_pct
          ?extension_max_pct:flags.extension_max_pct
          ?risk_budget:flags.risk_budget ?bars_for snap
      in
      print_string (Snapshot_validator.to_report findings);
      if Snapshot_validator.has_errors findings then exit 1
  | _ -> _usage ()
