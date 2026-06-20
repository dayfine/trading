(** [stop_ma_split] — read-only screen: do 30-week-MA-rising stops behave like
    whipsaws (gave up upside) and MA-falling stops like real breakdowns (dodged
    a drop)?

    Motivation ([dev/experiments/p0-screens-2026-06-20/FINDINGS.md] P0b
    verdict): the vol-scaled and weekly-close stop dials both fail because their
    trigger cannot tell a Stage-2 pullback (dip-then-recover) from a Stage-3/4
    breakdown (dip-then-collapse). Weinstein's own discriminator is the 30-week
    MA slope. If {b MA-rising} stops carry the foregone-upside (whipsaw) and
    {b MA-falling} stops carry the disaster-dodged, an MA-gated stop is worth
    building. If not, the stop cost is irreducible.

    For every [stop_loss] round-trip in a scenario's [trades.csv] this computes:
    - the 30-week SMA slope at the exit week (rising / falling), from weekly
      closes read out of the snapshot warehouse, and
    - the post-exit continuation + favourable/adverse excursion at the grade
      horizon (the same {!Decision_grading.Post_exit} arithmetic the lens uses).

    It then buckets the stops by slope and emits a markdown comparison.
    Read-only: changes no strategy behaviour.

    Usage:
    {[
      stop_ma_split --scenario-dir <dir> --snapshot-dir <dir>
        [--grade-horizon 26] [--slope-lookback-weeks 4]
    ]} *)

open Core
module TAR = Trade_audit_report
module DG = Decision_grading
module Bar_reader = Weinstein_strategy.Bar_reader
module Daily_panels = Snapshot_runtime.Daily_panels
module Snapshot_callbacks = Snapshot_runtime.Snapshot_callbacks
module Snapshot_manifest = Snapshot_pipeline.Snapshot_manifest

let _ma_period = 30
let _default_grade_horizon = 26
let _default_slope_lookback = 4
let _days_per_week = 7
let _horizon_buffer_weeks = 3
let _pct_scale = 100.0
let _cache_mb = 512

let _usage () =
  eprintf
    "Usage: stop_ma_split --scenario-dir <dir> --snapshot-dir <dir> \
     [--grade-horizon 26] [--slope-lookback-weeks 4]\n";
  Stdlib.exit 1

type _acc = {
  mutable scenario_dir : string option;
  mutable snapshot_dir : string option;
  mutable grade_horizon : int;
  mutable slope_lookback : int;
}

let _parse args =
  let acc =
    {
      scenario_dir = None;
      snapshot_dir = None;
      grade_horizon = _default_grade_horizon;
      slope_lookback = _default_slope_lookback;
    }
  in
  let rec loop = function
    | [] -> acc
    | "--scenario-dir" :: p :: rest ->
        acc.scenario_dir <- Some p;
        loop rest
    | "--snapshot-dir" :: p :: rest ->
        acc.snapshot_dir <- Some p;
        loop rest
    | "--grade-horizon" :: s :: rest ->
        acc.grade_horizon <- Int.of_string s;
        loop rest
    | "--slope-lookback-weeks" :: s :: rest ->
        acc.slope_lookback <- Int.of_string s;
        loop rest
    | _ -> _usage ()
  in
  loop args

let _bar_reader_of_snapshot ~snapshot_dir =
  let manifest_path = Filename.concat snapshot_dir "manifest.sexp" in
  let manifest =
    match Snapshot_manifest.read ~path:manifest_path with
    | Ok m -> m
    | Error err ->
        eprintf "stop_ma_split: cannot read %s: %s\n" manifest_path
          (Status.show err);
        Stdlib.exit 1
  in
  let panels =
    match
      Daily_panels.create ~snapshot_dir ~manifest ~max_cache_mb:_cache_mb
    with
    | Ok p -> p
    | Error err ->
        eprintf "stop_ma_split: Daily_panels.create failed: %s\n"
          (Status.show err);
        Stdlib.exit 1
  in
  Bar_reader.of_snapshot_views (Snapshot_callbacks.of_daily_panels panels)

(* exit_trigger straight from trades.csv, keyed by (symbol, entry, exit) — same
   reason as decision_grading_bin: the audit-derived trigger is blank for some
   exit kinds, the CSV column is always populated. *)
let _exit_reason_lookup ~scenario_dir =
  let tbl = Hashtbl.Poly.create () in
  let path = Filename.concat scenario_dir "trades.csv" in
  let rows =
    In_channel.read_lines path
    |> List.filter ~f:(fun l -> not (String.is_empty l))
    |> List.map ~f:(fun l -> String.split l ~on:',')
  in
  (match rows with
  | header :: data ->
      let idx name =
        List.findi header ~f:(fun _ h -> String.equal h name)
        |> Option.map ~f:fst
      in
      let cs = idx "symbol" and ce = idx "entry_date" in
      let cx = idx "exit_date" and ct = idx "exit_trigger" in
      let get row i = Option.bind i ~f:(fun i -> List.nth row i) in
      List.iter data ~f:(fun row ->
          match (get row cs, get row ce, get row cx, get row ct) with
          | Some s, Some ed, Some xd, Some t ->
              Hashtbl.set tbl
                ~key:(s, Date.of_string ed, Date.of_string xd)
                ~data:t
          | _ -> ())
  | [] -> ());
  tbl

let _mean xs =
  if List.is_empty xs then 0.0
  else List.sum (module Float) xs ~f:Fn.id /. Float.of_int (List.length xs)

(* 30-week SMA structure at [exit_date]: slope sign (rising/falling) and whether
   the exit-week close sits above the SMA (Stage-2 structure intact). [None] when
   fewer than [period + lookback] weekly bars precede the exit. *)
let _ma_structure bar_reader ~symbol ~exit_date ~lookback =
  let need = _ma_period + lookback in
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol ~n:need ~as_of:exit_date
    |> List.sort ~compare:(fun (a : Types.Daily_price.t) b ->
        Date.compare a.date b.date)
  in
  if List.length bars < need then None
  else
    let closes =
      List.map bars ~f:(fun (b : Types.Daily_price.t) -> b.close_price)
    in
    let n = List.length closes in
    let sma lo = _mean (List.sub closes ~pos:lo ~len:_ma_period) in
    let sma_now = sma (n - _ma_period) in
    let sma_prev = sma (n - _ma_period - lookback) in
    let close_now = List.last_exn closes in
    Some (Float.(sma_now > sma_prev), Float.(close_now > sma_now))

type _stop = {
  rising : bool option;
  above_ma : bool option;
      (** exit-week close above the 30w SMA (Stage-2 intact?) *)
  continuation : float;
      (** post-exit move in trade direction; + = gave up upside *)
  favorable : float;
  adverse : float;  (** worst post-exit move against trade; the drop dodged *)
  realized : float;
}

let _grade_stop bar_reader ~grade_horizon ~lookback (row : TAR.per_trade_row) =
  let as_of = Date.add_days row.exit_date (grade_horizon * _days_per_week) in
  let bars =
    Bar_reader.weekly_bars_for bar_reader ~symbol:row.symbol
      ~n:(grade_horizon + _horizon_buffer_weeks)
      ~as_of
  in
  let post =
    DG.Post_exit.post_exit_metrics ~side:row.side ~exit_price:row.exit_price
      ~exit_date:row.exit_date ~bars ~horizons_weeks:[ grade_horizon ]
    |> List.hd
  in
  let field f = Option.value_map post ~default:0.0 ~f in
  let structure =
    _ma_structure bar_reader ~symbol:row.symbol ~exit_date:row.exit_date
      ~lookback
  in
  {
    rising = Option.map structure ~f:fst;
    above_ma = Option.map structure ~f:snd;
    continuation = field (fun h -> h.DG.Post_exit.continuation_pct);
    favorable = field (fun h -> h.DG.Post_exit.post_exit_max_favorable_pct);
    adverse = field (fun h -> h.DG.Post_exit.post_exit_max_adverse_pct);
    realized = row.pnl_percent /. _pct_scale;
  }

let _bucket_row label stops =
  let n = List.length stops in
  if n = 0 then Printf.sprintf "| %s | 0 | — | — | — | — |\n" label
  else
    Printf.sprintf "| %s | %d | %+.1f%% | %+.1f%% | %+.1f%% | %+.1f%% |\n" label
      n
      (_mean (List.map stops ~f:(fun s -> s.continuation)) *. 100.0)
      (_mean (List.map stops ~f:(fun s -> s.favorable)) *. 100.0)
      (_mean (List.map stops ~f:(fun s -> s.adverse)) *. 100.0)
      (_mean (List.map stops ~f:(fun s -> s.realized)) *. 100.0)

let () =
  let acc = _parse (List.tl_exn (Array.to_list (Sys.get_argv ()))) in
  let scenario_dir =
    Option.value_or_thunk acc.scenario_dir ~default:(fun () -> _usage ())
  in
  let snapshot_dir =
    Option.value_or_thunk acc.snapshot_dir ~default:(fun () -> _usage ())
  in
  let report = TAR.load ~scenario_dir in
  let reasons = _exit_reason_lookup ~scenario_dir in
  let bar_reader = _bar_reader_of_snapshot ~snapshot_dir in
  let is_stop (r : TAR.per_trade_row) =
    match Hashtbl.find reasons (r.symbol, r.entry_date, r.exit_date) with
    | Some t -> String.is_substring t ~substring:"stop_loss"
    | None -> false
  in
  let stops =
    List.filter report.rows ~f:is_stop
    |> List.map
         ~f:
           (_grade_stop bar_reader ~grade_horizon:acc.grade_horizon
              ~lookback:acc.slope_lookback)
  in
  eprintf "stop_ma_split: graded %d stop_loss exits\n%!" (List.length stops);
  let sel f v = List.filter stops ~f:(fun s -> Poly.equal (f s) (Some v)) in
  let insufficient = List.filter stops ~f:(fun s -> Option.is_none s.rising) in
  printf
    "# Stop MA-structure split — %s\n\n\
     30-week SMA at exit; %dw post-exit horizon. For a long, +continuation = \
     price kept rising after we sold (gave up upside / whipsaw); -adverse = \
     drop dodged. Per-decision value-add ~ realized - continuation (more \
     negative = worse exit).\n\n\
     ## By MA slope at exit\n\n\
     | MA slope | n | mean continuation | mean favorable | mean adverse | mean \
     realized |\n\
     |---|---|---|---|---|---|\n\
     %s%s\n\
     ## By price vs MA at exit (Stage-2 structure intact = close above MA)\n\n\
     | price vs MA | n | mean continuation | mean favorable | mean adverse | \
     mean realized |\n\
     |---|---|---|---|---|---|\n\
     %s%s%s\n"
    scenario_dir acc.grade_horizon
    (_bucket_row "rising" (sel (fun s -> s.rising) true))
    (_bucket_row "falling" (sel (fun s -> s.rising) false))
    (_bucket_row "above MA (whipsaw?)" (sel (fun s -> s.above_ma) true))
    (_bucket_row "below MA (breakdown?)" (sel (fun s -> s.above_ma) false))
    (_bucket_row "insufficient bars" insufficient)
