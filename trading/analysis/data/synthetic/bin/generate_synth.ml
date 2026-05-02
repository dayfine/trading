(** generate_synth — emit a synthetic daily-price series via stationary block
    bootstrap.

    Source modes:
    - [-source-csv PATH]: load a daily-price CSV (header
      [date,open,high,low,close,adjusted_close,volume]).
    - default (no [-source-csv]): use the in-process [synthetic_spy_like]
      generator. Useful for smoke-testing the pipeline before real source data
      lands.

    Output: CSV on stdout (or to [-output PATH]) with the same header as the
    input CSV.

    Example:
    {v
      generate_synth.exe -target-days 8000 -mean-block-length 30 -seed 42 \
        -start-date 1990-01-02 -start-price 100
    v} *)

open Core

let _emit_csv_header oc =
  Out_channel.output_string oc
    "date,open,high,low,close,adjusted_close,volume\n"

let _emit_csv_row oc (b : Types.Daily_price.t) =
  Out_channel.fprintf oc "%s,%.4f,%.4f,%.4f,%.4f,%.4f,%d\n"
    (Date.to_string b.date) b.open_price b.high_price b.low_price b.close_price
    b.adjusted_close b.volume

let _write_bars ~output bars =
  let with_oc oc =
    _emit_csv_header oc;
    List.iter bars ~f:(_emit_csv_row oc)
  in
  match output with
  | None -> with_oc Out_channel.stdout
  | Some path -> Out_channel.with_file path ~f:with_oc

let _load_source ~source_csv ~synth_source_days ~synth_source_seed
    ~synth_source_start =
  match source_csv with
  | Some path -> Synthetic.Source_loader.load_csv ~path
  | None ->
      Ok
        (Synthetic.Source_loader.synthetic_spy_like
           ~start_date:(Date.of_string synth_source_start)
           ~n_days:synth_source_days ~seed:synth_source_seed)

let main ~source_csv ~target_days ~mean_block_length ~seed ~start_date
    ~start_price ~output ~synth_source_days ~synth_source_seed
    ~synth_source_start () =
  let source_result =
    _load_source ~source_csv ~synth_source_days ~synth_source_seed
      ~synth_source_start
  in
  match source_result with
  | Error e ->
      Printf.eprintf "Error loading source: %s\n%!" (Status.show e);
      exit 1
  | Ok source -> (
      let config : Synthetic.Block_bootstrap.config =
        {
          target_length_days = target_days;
          mean_block_length;
          seed;
          start_date = Date.of_string start_date;
          start_price;
        }
      in
      match Synthetic.Block_bootstrap.generate ~source ~config with
      | Error e ->
          Printf.eprintf "Error generating synth: %s\n%!" (Status.show e);
          exit 1
      | Ok bars ->
          _write_bars ~output bars;
          Printf.eprintf "Wrote %d synthetic bars\n%!" (List.length bars))

let command =
  Command.basic
    ~summary:
      "Generate a synthetic daily-price series via stationary block bootstrap"
    (let%map_open.Command source_csv =
       flag "source-csv" (optional string)
         ~doc:
           "PATH Daily-price CSV to bootstrap from. If omitted, an in-process \
            synthetic SPY-like series is used."
     and target_days =
       flag "target-days" (required int)
         ~doc:"N Number of synthetic bars to emit"
     and mean_block_length =
       flag "mean-block-length"
         (optional_with_default 30 int)
         ~doc:"L Mean block length in days (default: 30)"
     and seed =
       flag "seed"
         (optional_with_default 42 int)
         ~doc:"N PRNG seed (default: 42)"
     and start_date =
       flag "start-date"
         (optional_with_default "1990-01-02" string)
         ~doc:"YYYY-MM-DD First synthetic bar date (default: 1990-01-02)"
     and start_price =
       flag "start-price"
         (optional_with_default 100.0 float)
         ~doc:"P First synthetic bar's close (default: 100.0)"
     and output =
       flag "output" (optional string)
         ~doc:"PATH Write CSV to this file (default: stdout)"
     and synth_source_days =
       flag "synth-source-days"
         (optional_with_default 8000 int)
         ~doc:
           "N When -source-csv is omitted, length of the in-process synthetic \
            source (default: 8000)"
     and synth_source_seed =
       flag "synth-source-seed"
         (optional_with_default 42 int)
         ~doc:
           "N When -source-csv is omitted, seed for the in-process synthetic \
            source (default: 42)"
     and synth_source_start =
       flag "synth-source-start"
         (optional_with_default "1990-01-02" string)
         ~doc:
           "YYYY-MM-DD When -source-csv is omitted, start date for the \
            in-process source (default: 1990-01-02)"
     in
     fun () ->
       main ~source_csv ~target_days ~mean_block_length ~seed ~start_date
         ~start_price ~output ~synth_source_days ~synth_source_seed
         ~synth_source_start ())

let () = Command_unix.run command
