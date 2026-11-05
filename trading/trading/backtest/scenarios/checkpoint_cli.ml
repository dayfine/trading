(** See [checkpoint_cli.mli]. *)

open Core

let request ~scenario_dir
    ({ every_n_fridays; resume; halt_after_checkpoints } :
      Cli_args.checkpoint_flags) =
  if Option.is_none every_n_fridays && Option.is_none resume then None
  else
    Some
      {
        Backtest.Backtest_checkpoint.scenario_dir;
        every_n_fridays = Option.value every_n_fridays ~default:Int.max_value;
        resume = Option.is_some resume;
        halt_after_checkpoints;
      }

let _scenario_dir_of path =
  if String.equal (Filename.basename path) Backtest.Backtest_checkpoint.dir_name
  then Filename.dirname path
  else path

let plan ~resume scenarios =
  match resume with
  | None ->
      ( scenarios,
        Output_root.make_timestamped_root ~repo_root:(Cli_args.repo_root ()) )
  | Some path -> (
      let dir = _scenario_dir_of path in
      let name = Filename.basename dir in
      match
        List.filter scenarios ~f:(fun (_, s) ->
            String.equal s.Scenario.name name)
      with
      | [ one ] -> ([ one ], Filename.dirname dir)
      | _ ->
          eprintf
            "--resume %s: expected exactly one scenario named %s in the \
             scenario directory\n"
            path name;
          Stdlib.exit 1)

let _header_date ~output_root (s : Scenario.t) =
  let path =
    String.concat ~sep:"/"
      [
        Output_root.scenario_dir ~output_root s;
        Backtest.Backtest_checkpoint.dir_name;
        "header.sexp";
      ]
  in
  try
    Some
      (Backtest.Backtest_checkpoint.header_of_sexp (Sexp.load_sexp path)).date
  with _ -> None

let print_halted_row ~output_root ~checkpoints (s : Scenario.t) =
  let n = Option.value_map checkpoints ~default:"?" ~f:Int.to_string in
  let date =
    Option.value_map
      (_header_date ~output_root s)
      ~default:"?" ~f:Date.to_string
  in
  printf "%-28s HALTED at checkpoint %s (%s)\n" s.name n date
