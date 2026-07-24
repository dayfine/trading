open Core
open Tax_lens

let run ~dir ~config_path ~out =
  let config =
    match config_path with
    | Some p -> Tax_config.load_exn p
    | None -> Tax_config.default
  in
  let rd : Tax_types.run_data = Loader.load_exn dir in
  let result = Tax_model.simulate config rd in
  let winners = Diagnostics.top_winners config rd.trades in
  let md = Report.render result winners in
  match out with
  | Some path -> Out_channel.write_all path ~data:md
  | None -> print_string md

let command =
  Command.basic
    ~summary:"After-tax performance lens over a scenario output directory"
    (let%map_open.Command dir =
       flag "--dir" (required string)
         ~doc:"DIR scenario output dir (trades.csv + equity_curve.csv)"
     and config_path =
       flag "--config" (optional string)
         ~doc:
           "FILE sexp Tax_config (default: realized_st_lt 0.35/0.238/365 \
            +carryforward)"
     and out =
       flag "--out" (optional string)
         ~doc:"FILE write markdown here (default: stdout)"
     in
     fun () -> run ~dir ~config_path ~out)

let () = Command_unix.run command
