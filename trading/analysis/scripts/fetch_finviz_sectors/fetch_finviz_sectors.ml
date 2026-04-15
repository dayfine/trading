(** Fetch sector assignments from Finviz and write data/sectors.csv. *)

open Async

let _summary =
  "Fetch sector assignments from Finviz quote pages and write data/sectors.csv."

let _data_dir_default () = Data_path.default_data_dir () |> Fpath.to_string

let command =
  Command.async ~summary:_summary
    (let%map_open.Command symbols_flag =
       flag "symbols" (optional string)
         ~doc:
           "SYM1,SYM2,... Comma-separated list of symbols (default: all common \
            stocks from universe.sexp)"
     and data_dir =
       flag "data-dir"
         (optional_with_default (_data_dir_default ()) string)
         ~doc:"PATH Directory containing universe.sexp and sectors.csv"
     and rate_limit =
       flag "rate-limit"
         (optional_with_default 1.0 float)
         ~doc:"RPS Requests per second (default: 1.0)"
     and force =
       flag "force" no_arg
         ~doc:" Re-fetch all symbols even if manifest is fresh"
     in
     let symbols =
       match symbols_flag with
       | None -> None
       | Some s ->
           let parts = Core.String.split ~on:',' s in
           let stripped = Core.List.map parts ~f:Core.String.strip in
           Some
             (Core.List.filter stripped ~f:(fun s ->
                  not (Core.String.is_empty s)))
     in
     fun () ->
       Fetch_finviz_sectors_lib.run ~data_dir ~rate_limit_rps:rate_limit ~force
         ?symbols ())

let () = Command_unix.run command
