(** generate_synth_v2 — emit a synthetic daily-price series via the regime-
    switching HMM + GARCH model (Synth-v2).

    Unlike Synth-v1 ([generate_synth]) this binary does NOT take a real source
    series; the HMM and per-regime GARCH params are hand-set defaults documented
    in [Synth_v2]. A follow-up PR will add fit-from-history.

    Output: CSV on stdout (or to [-output PATH]).

    Example:
    {v
      generate_synth_v2.exe -target-days 20000 -seed 42 \
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

let main ~target_days ~seed ~start_date ~start_price ~output () =
  let cfg =
    Synthetic.Synth_v2.default_config
      ~start_date:(Date.of_string start_date)
      ~start_price ~target_length_days:target_days ~seed
  in
  match Synthetic.Synth_v2.generate cfg with
  | Error e ->
      Printf.eprintf "Error generating synth: %s\n%!" (Status.show e);
      exit 1
  | Ok bars ->
      _write_bars ~output bars;
      Printf.eprintf "Wrote %d synthetic bars\n%!" (List.length bars)

let command =
  Command.basic
    ~summary:
      "Generate a synthetic daily-price series via 3-regime HMM + GARCH \
       (Synth-v2)"
    (let%map_open.Command target_days =
       flag "target-days" (required int)
         ~doc:"N Number of synthetic bars to emit"
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
     in
     fun () -> main ~target_days ~seed ~start_date ~start_price ~output ())

let () = Command_unix.run command
