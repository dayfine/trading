(* Offline, read-only scanner over a snapshot warehouse.

   Two modes, both pure functions of the warehouse:
   - default: emit every rule-visible Stage-2 breakout with its forward run
     (the "monster universe" for issue #2490's capture funnel);
   - --pairs: emit decision-time features at supplied (symbol, date) pairs
     (issue #2489's fill-week volume ratio + base length dimensions).

   No strategy config, no goldens, no writes outside --out. *)
open Core
module Analytics = Monster_scan_lib.Monster_scan_analytics
module Reader = Monster_scan_lib.Monster_scan_reader

let _progress_every = 250

let _fail ~what (e : Status.t) =
  eprintf "monster_scan: %s: %s\n%!" what (Status.show e);
  exit 1

let _f v = Printf.sprintf "%.6g" v
let _opt_f = function None -> "" | Some v -> _f v

let _breakout_row ~symbol (b : Analytics.breakout) =
  let f = b.features and fwd = b.forward in
  String.concat ~sep:","
    [
      symbol;
      Date.to_string b.week_date;
      _f b.close;
      _f f.prior_high;
      _f f.vol_ratio;
      _f f.ma30;
      Int.to_string f.base_weeks;
      _f fwd.fwd_max_close;
      _f fwd.fwd_run_pct;
      Int.to_string fwd.weeks_to_max;
    ]

let _breakout_header =
  "symbol,week_date,close,prior_high_26w,vol_ratio,ma30,base_weeks,fwd_max_close,fwd_run_pct,weeks_to_max"

let _pairs_header =
  "symbol,date,vol_ratio_at_date,base_weeks_at_date,stage_at_date"

let _selected_symbols ~snapshot_dir ~symbols =
  match symbols with
  | Some csv -> String.split csv ~on:',' |> List.map ~f:String.strip
  | None -> (
      match Reader.symbols ~snapshot_dir with
      | Ok syms -> syms
      | Error e -> _fail ~what:"listing warehouse symbols" e)

(* A missing or unreadable panel is expected across a broad warehouse (delisted
   stubs, partial rebuilds); it is reported once on stderr and skipped, never
   fatal. *)
let _weekly_bars_or_skip ~snapshot_dir ~symbol =
  match Reader.weekly_bars ~snapshot_dir ~symbol with
  | Ok bars -> Some bars
  | Error e ->
      eprintf "monster_scan: skipping %s: %s\n%!" symbol (Status.show e);
      None

let _in_window ~start ~end_ (d : Date.t) =
  Date.( >= ) d start && Date.( <= ) d end_

let _scan_symbol ~params ~stage_config ~snapshot_dir ~start ~end_ ~symbol =
  match _weekly_bars_or_skip ~snapshot_dir ~symbol with
  | None -> []
  | Some bars ->
      Analytics.scan ~params ~stage_config ~bars
      |> List.filter ~f:(fun (b : Analytics.breakout) ->
          _in_window ~start ~end_ b.week_date)
      |> List.map ~f:(_breakout_row ~symbol)

let _emit ~out ~header rows =
  let data = String.concat ~sep:"\n" (header :: rows) ^ "\n" in
  Out_channel.write_all out ~data;
  eprintf "monster_scan: wrote %d rows to %s\n%!" (List.length rows) out

let _run_scan ~params ~stage_config ~snapshot_dir ~start ~end_ ~symbols ~out =
  let syms = _selected_symbols ~snapshot_dir ~symbols in
  eprintf "monster_scan: scanning %d symbols\n%!" (List.length syms);
  let rows =
    List.concat_mapi syms ~f:(fun i symbol ->
        if i % _progress_every = 0 && i > 0 then
          eprintf "monster_scan: %d/%d symbols\n%!" i (List.length syms);
        _scan_symbol ~params ~stage_config ~snapshot_dir ~start ~end_ ~symbol)
  in
  _emit ~out ~header:_breakout_header rows

let _pair_row ~params ~stage_config ~snapshot_dir ~symbol ~date =
  let features =
    let%bind.Option bars = _weekly_bars_or_skip ~snapshot_dir ~symbol in
    let%bind.Option idx = Analytics.index_for_date ~bars ~date in
    Analytics.features_at ~params ~stage_config ~bars ~idx
  in
  String.concat ~sep:","
    [
      symbol;
      Date.to_string date;
      _opt_f (Option.map features ~f:(fun f -> f.Analytics.vol_ratio));
      Option.value_map features ~default:"" ~f:(fun f ->
          Int.to_string f.Analytics.base_weeks);
      Option.value_map features ~default:"" ~f:(fun f ->
          Analytics.stage_label f.Analytics.stage);
    ]

let _parse_pair line =
  match String.split line ~on:',' |> List.map ~f:String.strip with
  | [ symbol; date ] when not (String.is_empty symbol) ->
      Some (symbol, Date.of_string date)
  | _ -> None

let _run_pairs ~params ~stage_config ~snapshot_dir ~pairs ~out =
  let requested =
    In_channel.read_lines pairs
    |> List.filter ~f:(fun l -> not (String.is_empty (String.strip l)))
    |> List.filter_map ~f:_parse_pair
  in
  eprintf "monster_scan: %d pairs\n%!" (List.length requested);
  let rows =
    List.map requested ~f:(fun (symbol, date) ->
        _pair_row ~params ~stage_config ~snapshot_dir ~symbol ~date)
  in
  _emit ~out ~header:_pairs_header rows

let _dispatch ~params ~snapshot_dir ~start ~end_ ~symbols ~pairs ~out =
  let stage_config = Stage.default_config in
  match pairs with
  | Some pairs -> _run_pairs ~params ~stage_config ~snapshot_dir ~pairs ~out
  | None ->
      let start = Date.of_string start and end_ = Date.of_string end_ in
      _run_scan ~params ~stage_config ~snapshot_dir ~start ~end_ ~symbols ~out

let command =
  Command.basic
    ~summary:
      "Scan a snapshot warehouse for rule-visible Stage-2 breakouts and their \
       forward runs"
    ~readme:(fun () ->
      "Read-only. Loads each symbol's complete ISO weeks from <dir>/<SYM>.snap \
       on the split/dividend-adjusted basis; at each week computes, from data \
       at or before that week only, the trailing prior high, the volume ratio, \
       the base length and the production stage. A week is a breakout when \
       close exceeds the prior high, volume confirms, and the stage is Stage \
       2. The forward run (max close over --fwd-weeks) uses hindsight on \
       purpose: it defines the ex-post monster set and never feeds detection. \
       With --pairs FILE (headerless 'symbol,date' lines) it instead emits the \
       decision-time features at each requested week.")
    (let%map_open.Command snapshot_dir =
       flag "-snapshot-dir" (required string)
         ~doc:"DIR snapshot warehouse holding SYM.snap panels"
     and start =
       flag "-start"
         (optional_with_default "1990-01-01" string)
         ~doc:"DATE earliest breakout week to emit (ignored with -pairs)"
     and end_ =
       flag "-end"
         (optional_with_default "2100-01-01" string)
         ~doc:"DATE latest breakout week to emit (ignored with -pairs)"
     and out = flag "-out" (required string) ~doc:"FILE CSV output path"
     and pairs =
       flag "-pairs" (optional string)
         ~doc:"FILE headerless symbol,date lines; switches to features mode"
     and symbols =
       flag "-symbols" (optional string)
         ~doc:"SYM,SYM restrict the scan to these symbols (default: all)"
     and breakout_lookback_weeks =
       flag "-breakout-lookback-weeks"
         (optional_with_default Analytics.default_params.breakout_lookback_weeks
            int)
         ~doc:"N trailing weeks for the prior high and average volume"
     and min_vol_ratio =
       flag "-min-vol-ratio"
         (optional_with_default Analytics.default_params.min_vol_ratio float)
         ~doc:"X minimum volume ratio confirming a breakout"
     and base_band_pct =
       flag "-base-band-pct"
         (optional_with_default Analytics.default_params.base_band_pct float)
         ~doc:"P half-width in percent of the base band around the median close"
     and fwd_weeks =
       flag "-fwd-weeks"
         (optional_with_default Analytics.default_params.fwd_weeks int)
         ~doc:"N forward weeks over which the run is measured"
     in
     fun () ->
       let params =
         {
           Analytics.breakout_lookback_weeks;
           min_vol_ratio;
           base_band_pct;
           fwd_weeks;
         }
       in
       _dispatch ~params ~snapshot_dir ~start ~end_ ~symbols ~pairs ~out)

let () = Command_unix.run command
