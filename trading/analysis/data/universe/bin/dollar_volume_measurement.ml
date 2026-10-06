(** CLI: measure what the true-dollar volume basis (issue #3136) would move.

    Scans every equity-like symbol in the store once (activity is read from the
    bars: the committed [inventory.sexp] lags the store), ranks each
    reconstitution year on the stored [close * volume] basis and on true
    dollars, and diffs both against the committed PIT lists. Also counts the
    entry liquidity gate decisions that flip, on week-end bars of committed
    top-N members. Writes a Markdown report and a CSV of the rejected
    (implausible) bars. Read-only on the store and the committed lists.

    {v
      dune exec analysis/data/universe/bin/dollar_volume_measurement.exe -- \
        --bars-root /workspaces/trading-1/data \
        --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
        --lists-dir test_data/goldens-custom-universe/composition \
        --out-report /tmp/dv-report.md --out-rejected /tmp/dv-rejected.csv
    v} *)

open! Core
module CI = Universe.Composition_inputs
module DVB = Universe.Dollar_volume_basis
module BR = Universe.Composition_bar_reader
module Scan = Dollar_volume_measurement_lib.Dollar_volume_scan
module Report = Dollar_volume_measurement_lib.Dollar_volume_report

let _die msg =
  Stdlib.Printf.eprintf "dollar_volume_measurement: %s\n" msg;
  Stdlib.exit 1

let _ok_or_die = function Ok v -> v | Error e -> _die (Status.show e)

(* Builder defaults (Build_from_individuals.default_config) and strategy
   liquidity defaults (Liquidity_config.default_config). *)
let _trailing_window_days = 60
let _min_window_bars = 30
let _liquidity_floor = 1_000_000.0
let _liquidity_lookback_bars = 20
let _true_top_k = 5

let _specimens =
  [ ("AMZN", Date.of_string "2018-06-14"); ("C", Date.of_string "2010-06-14") ]

let _list_date year = Date.create_exn ~y:year ~m:Month.May ~d:31

(* Raises on a directory still unreadable after retries: a silently skipped
   shard would drop its symbols from every list. *)
let _ls dir =
  match
    Scan.retry_read (fun () ->
        Option.try_with (fun () -> Stdlib.Sys.readdir dir))
  with
  | Some names -> Array.to_list names |> List.sort ~compare:String.compare
  | None -> _die ("unreadable store directory " ^ dir)

(* Every [<L1>/<L2>/<SYM>/data.csv] in the store (shard dirs are one char). *)
let _store_symbols bars_root =
  let one_char = List.filter ~f:(fun s -> String.length s = 1) in
  List.concat_map
    (one_char (_ls bars_root))
    ~f:(fun l1 ->
      let d1 = Filename.concat bars_root l1 in
      List.concat_map
        (one_char (_ls d1))
        ~f:(fun l2 ->
          let d2 = Filename.concat d1 l2 in
          List.filter (_ls d2) ~f:(fun sym ->
              Stdlib.Sys.file_exists
                (Filename.concat (Filename.concat d2 sym) "data.csv"))))
  |> List.dedup_and_sort ~compare:String.compare

let _load_list ~lists_dir ~size year =
  let path = Filename.concat lists_dir (sprintf "top-%d-%d.sexp" size year) in
  match Universe.Snapshot.load ~path with
  | Error _ -> None
  | Ok snap ->
      Some (List.map snap.entries ~f:(fun e -> e.symbol) |> String.Set.of_list)

let _committed ~lists_dir ~years ~sizes =
  let table = Hashtbl.Poly.create () in
  List.iter years ~f:(fun year ->
      List.iter sizes ~f:(fun size ->
          Option.iter (_load_list ~lists_dir ~size year) ~f:(fun set ->
              Hashtbl.set table ~key:(year, size) ~data:set)));
  table

let _params ~years : Scan.params =
  {
    years;
    trailing_window_days = _trailing_window_days;
    min_window_bars = _min_window_bars;
    basis = DVB.true_dollars_config;
    liquidity_floor = _liquidity_floor;
    liquidity_lookback_bars = _liquidity_lookback_bars;
  }

let _scan_all ~params ~bars_root ~committed ~member_size entries =
  let total = List.length entries in
  let scans =
    List.filter_mapi entries ~f:(fun i symbol ->
        if i % 1000 = 0 then Stdlib.Printf.eprintf "scan %d/%d\n%!" i total;
        let is_member year =
          match Hashtbl.find committed (year, member_size) with
          | Some set -> Set.mem set symbol
          | None -> false
        in
        Scan.scan params ~bars_root ~is_member symbol)
  in
  Stdlib.Printf.eprintf "scanned %d of %d candidates (unreadable: %d)\n%!"
    (List.length scans) total
    (total - List.length scans);
  scans

let _specimen_rows ~bars_root scans =
  List.filter_map _specimens ~f:(fun (sym, date) ->
      let open Option.Let_syntax in
      let%bind scan =
        List.find scans ~f:(fun (s : Scan.t) -> String.equal s.symbol sym)
      in
      let%bind bars = BR.read_bars ~bars_root sym in
      let%map bar =
        List.find bars ~f:(fun (b : BR.bar) -> Date.equal b.date date)
      in
      ( sym,
        date,
        DVB.bar_dollar_volume DVB.Close_times_volume ~splits:[] bar,
        DVB.bar_dollar_volume DVB.True_dollars ~splits:scan.applied bar ))

let _candidates ~bars_root ~symbol_types_path =
  let equity = _ok_or_die (CI.load_equity_like_lookup symbol_types_path) in
  List.filter (_store_symbols bars_root) ~f:(fun s ->
      Option.value (Hashtbl.find equity s) ~default:false)

let _run ~bars_root ~symbol_types_path ~lists_dir ~out_report ~out_rejected
    ~years ~sizes ~movers_k =
  let committed = _committed ~lists_dir ~years ~sizes in
  let member_size = List.fold sizes ~init:0 ~f:Int.max in
  let candidates = _candidates ~bars_root ~symbol_types_path in
  let scans =
    _scan_all ~params:(_params ~years) ~bars_root ~committed ~member_size
      candidates
  in
  let rows =
    List.concat_map years ~f:(fun year ->
        List.map sizes ~f:(fun size ->
            Report.membership_row
              ~committed:(Hashtbl.find committed (year, size))
              ~size ~top_k:_true_top_k scans year))
  in
  Out_channel.write_all out_report
    ~data:
      (Report.render ~liquidity_floor:_liquidity_floor ~rows
         ~movers_size:member_size ~movers_k ~scans
         ~specimens:(_specimen_rows ~bars_root scans));
  Out_channel.write_all out_rejected ~data:(Report.rejected_csv scans)

let _int_list raw =
  String.split raw ~on:','
  |> List.map ~f:(fun s -> Int.of_string (String.strip s))

let command =
  Command.basic ~summary:"Measure the #3136 true-dollar volume basis change."
    (let%map_open.Command bars_root =
       flag "--bars-root" (required string) ~doc:"PATH bar store"
     and symbol_types_path =
       flag "--symbol-types" (required string) ~doc:"PATH symbol_types.sexp"
     and lists_dir =
       flag "--lists-dir" (required string)
         ~doc:"DIR committed top-N-YYYY.sexp lists"
     and out_report =
       flag "--out-report" (required string) ~doc:"PATH Markdown report"
     and out_rejected =
       flag "--out-rejected" (required string) ~doc:"PATH rejected-bars CSV"
     and start_year =
       flag "--start-year"
         (optional_with_default 1998 int)
         ~doc:"YEAR first list year"
     and end_year =
       flag "--end-year"
         (optional_with_default 2025 int)
         ~doc:"YEAR last list year"
     and sizes =
       flag "--sizes"
         (optional_with_default "1000,3000" string)
         ~doc:"LIST top-N sizes"
     and movers_k =
       flag "--movers"
         (optional_with_default 20 int)
         ~doc:"K movers listed each way"
     in
     fun () ->
       let years = List.range start_year (end_year + 1) in
       _run ~bars_root ~symbol_types_path ~lists_dir ~out_report ~out_rejected
         ~years ~sizes:(_int_list sizes) ~movers_k)

let () = Command_unix.run command
