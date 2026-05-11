(** generate_synth_v3 — emit a synthetic multi-symbol universe (Synth-v3).

    Pairs a [Synth_v2] market series (regime-switching HMM + GARCH) with the
    [Factor_model] cross-section to produce a deterministic OHLCV universe.
    Output: one CSV file per symbol under [-output-dir].

    Example:
    {v
      generate_synth_v3.exe \
        -n-symbols 500 -target-days 20000 -seed 42 \
        -start-date 1990-01-02 -start-price 100 \
        -output-dir dev/data/synthetic-v3-run-001/
    v}

    A universe at the M7.0 acceptance scale (500 symbols × 20_000 bars each) is
    multi-hundred-MB on disk and several seconds of generator work; CSV write
    dominates wall-clock. *)

open Core

let _emit_csv_header oc =
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume\n"

let _emit_csv_row oc (b : Types.Daily_price.t) =
  Out_channel.fprintf oc "%s,%.4f,%.4f,%.4f,%.4f,%.4f,%d\n"
    (Date.to_string b.date) b.open_price b.high_price b.low_price b.close_price
    b.adjusted_close b.volume

let _write_symbol_csv ~output_dir (name, bars) =
  let path = Filename.concat output_dir (name ^ ".csv") in
  Out_channel.with_file path ~f:(fun oc ->
      _emit_csv_header oc;
      List.iter bars ~f:(_emit_csv_row oc))

let _ensure_output_dir dir =
  if not (Sys_unix.is_directory_exn ~follow_symlinks:true dir) then
    Core_unix.mkdir_p dir

let _summarise_universe (u : Synthetic.Synth_v3.universe) =
  let n_syms = List.length u.symbols in
  let bars_per_symbol =
    List.hd u.symbols
    |> Option.value_map ~default:0 ~f:(fun (_, b) -> List.length b)
  in
  Printf.eprintf "Wrote %d symbols × %d bars to disk\n%!" n_syms bars_per_symbol

let main ~n_symbols ~target_days ~seed ~start_date ~start_price ~output_dir () =
  let cfg =
    Synthetic.Synth_v3.default_config ~n_symbols
      ~start_date:(Date.of_string start_date)
      ~start_price ~target_length_days:target_days ~seed
  in
  match Synthetic.Synth_v3.generate cfg with
  | Error e ->
      Printf.eprintf "Error generating synth_v3 universe: %s\n%!"
        (Status.show e);
      exit 1
  | Ok universe ->
      _ensure_output_dir output_dir;
      List.iter universe.symbols ~f:(_write_symbol_csv ~output_dir);
      _summarise_universe universe

let command =
  Command.basic
    ~summary:
      "Generate a multi-symbol synthetic universe via Synth-v2 market + \
       single-factor cross-section (Synth-v3)"
    (let%map_open.Command n_symbols =
       flag "n-symbols" (required int)
         ~doc:"N Number of symbols in the universe (must be > 0)"
     and target_days =
       flag "target-days" (required int) ~doc:"N Number of bars per symbol"
     and seed =
       flag "seed"
         (optional_with_default 42 int)
         ~doc:"N PRNG seed (default: 42)"
     and start_date =
       flag "start-date"
         (optional_with_default "1990-01-02" string)
         ~doc:"YYYY-MM-DD First bar date (default: 1990-01-02)"
     and start_price =
       flag "start-price"
         (optional_with_default 100.0 float)
         ~doc:"P First bar's close per symbol (default: 100.0)"
     and output_dir =
       flag "output-dir" (required string)
         ~doc:"DIR Target directory for per-symbol CSV files"
     in
     fun () ->
       main ~n_symbols ~target_days ~seed ~start_date ~start_price ~output_dir
         ())

let () = Command_unix.run command
