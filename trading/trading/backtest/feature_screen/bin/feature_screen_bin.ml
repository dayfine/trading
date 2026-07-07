(** CLI for the multivariate feature screen.

    Reads one or more all-eligible [trades.csv] files, fits the full-sample and
    per-era OLS / logistic models over the selected feature subset, and writes a
    markdown report. Pooling several [--trades-csv] files concatenates their
    rows (e.g. grade-sweep cells). *)

open Core
module FS = Backtest_feature_screen

type args = {
  trades_csv : string list;
  out : string option;
  features : FS.Feature_matrix.feature list;
}

let _usage =
  String.concat ~sep:"\n"
    [
      "Usage: feature_screen_bin --trades-csv <path> [--trades-csv <path> ...] \
       [options]";
      "  --trades-csv <path>   All-eligible trades.csv (repeatable; rows \
       pooled).";
      "  --out <path>          Write the markdown report here (default: \
       stdout).";
      "  --features <csv>      Comma-separated feature subset (default: all). \
       Names: \
       cascade_score,rs_value,volume_ratio,weeks_advancing,passes_macro,stage2_late,rs_trend,resistance_quality.";
    ]

let _fail msg = failwith (msg ^ "\n" ^ _usage)

let _parse_features s : FS.Feature_matrix.feature list =
  String.split s ~on:',' |> List.map ~f:String.strip
  |> List.filter ~f:(fun t -> not (String.is_empty t))
  |> List.map ~f:(fun tok ->
      match FS.Feature_matrix.feature_of_string tok with
      | Some f -> f
      | None -> _fail (Printf.sprintf "unknown feature: %s" tok))

let _parse_argv argv : args =
  let rec loop acc = function
    | [] -> acc
    | "--trades-csv" :: v :: rest ->
        loop { acc with trades_csv = acc.trades_csv @ [ v ] } rest
    | "--out" :: v :: rest -> loop { acc with out = Some v } rest
    | "--features" :: v :: rest ->
        loop { acc with features = _parse_features v } rest
    | flag :: _ -> _fail (Printf.sprintf "unknown flag: %s" flag)
  in
  let init =
    { trades_csv = []; out = None; features = FS.Feature_matrix.all_features }
  in
  let parsed =
    loop init (Array.to_list argv |> List.tl |> Option.value ~default:[])
  in
  if List.is_empty parsed.trades_csv then
    _fail "at least one --trades-csv is required"
  else parsed

let _load_rows (paths : string list) : FS.Csv_rows.row list =
  let named = List.map paths ~f:(fun p -> (p, In_channel.read_lines p)) in
  match FS.Csv_rows.concat_files named with
  | Ok rows -> rows
  | Error m -> failwith m

let _run (args : args) : unit =
  let rows = _load_rows args.trades_csv in
  match FS.Feature_screen.screen ~rows ~features:args.features with
  | Error m -> failwith m
  | Ok t ->
      let md =
        FS.Report.render t ~title:"Feature screen — all-eligible trades"
      in
      (match args.out with
      | None -> print_string md
      | Some path -> Out_channel.write_all path ~data:md);
      eprintf "feature_screen: %d rows, %d complete-case; report %s\n%!"
        t.n_total t.n_complete
        (Option.value args.out ~default:"(stdout)")

let () = _run (_parse_argv (Sys.get_argv ()))
