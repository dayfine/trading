(** Markdown rendering for the per-screen decision-audit. See [report.mli]. *)

open Core
module SR = Screen_record
module TA = Backtest.Trade_audit

type feature_stat = {
  feature : string;
  funded_n : int;
  funded_mean : float option;
  near_miss_n : int;
  near_miss_mean : float option;
}
[@@deriving sexp]

(* Short one-letter stage label for the compact per-screen listing. *)
let _stage_label : Weinstein_types.stage -> string = function
  | Stage1 _ -> "S1"
  | Stage2 { late; _ } -> if late then "S2L" else "S2"
  | Stage3 _ -> "S3"
  | Stage4 _ -> "S4"

let _skip_reason_label (r : TA.skip_reason) : string =
  Sexp.to_string (TA.sexp_of_skip_reason r)

let _mean = function
  | [] -> None
  | xs ->
      Some (List.sum (module Float) xs ~f:Fn.id /. Float.of_int (List.length xs))

let _opt_float = Option.value_map ~default:"-" ~f:(Printf.sprintf "%.2f")

(* Pool a numeric feature across screens from both sides, dropping [None]s. *)
let _stat ~feature ~(funded : float list) ~(near_miss : float list) :
    feature_stat =
  {
    feature;
    funded_n = List.length funded;
    funded_mean = _mean funded;
    near_miss_n = List.length near_miss;
    near_miss_mean = _mean near_miss;
  }

let _collect_funded records ~f =
  List.concat_map records ~f:(fun (s : SR.t) -> List.filter_map s.funded ~f)

let _collect_near records ~f =
  List.concat_map records ~f:(fun (s : SR.t) ->
      List.filter_map s.near_misses ~f)

let feature_stats (records : SR.t list) : feature_stat list =
  let stat feature ~funded_f ~near_f =
    _stat ~feature
      ~funded:(_collect_funded records ~f:funded_f)
      ~near_miss:(_collect_near records ~f:near_f)
  in
  [
    stat "score"
      ~funded_f:(fun (e : SR.funded_entry) -> Some (Float.of_int e.score))
      ~near_f:(fun (n : SR.near_miss) -> Some (Float.of_int n.score));
    stat "rs_value"
      ~funded_f:(fun e -> e.rs_value)
      ~near_f:(fun n -> n.rs_value);
    stat "volume_ratio"
      ~funded_f:(fun e -> e.volume_ratio)
      ~near_f:(fun n -> n.volume_ratio);
    stat "weeks_advancing"
      ~funded_f:(fun e -> Option.map e.weeks_advancing ~f:Float.of_int)
      ~near_f:(fun n -> Option.map n.weeks_advancing ~f:Float.of_int);
  ]

let _feature_table (records : SR.t list) : string =
  let row (s : feature_stat) =
    Printf.sprintf "| %s | %s (n=%d) | %s (n=%d) |\n" s.feature
      (_opt_float s.funded_mean) s.funded_n
      (_opt_float s.near_miss_mean)
      s.near_miss_n
  in
  "| feature | funded mean | near-miss mean |\n|---|---|---|\n"
  ^ String.concat (List.map (feature_stats records) ~f:row)

(* Near-miss skip_reason breakdown: which constraint dropped the near-misses. *)
let _reason_breakdown (records : SR.t list) : string =
  let all =
    List.concat_map records ~f:(fun (s : SR.t) ->
        List.map s.near_misses ~f:(fun n -> _skip_reason_label n.reason_skipped))
  in
  let counts =
    List.map all ~f:(fun r -> (r, ()))
    |> Map.of_alist_multi (module String)
    |> Map.to_alist
    |> List.map ~f:(fun (r, hits) -> (r, List.length hits))
    |> List.sort ~compare:(fun (_, a) (_, b) -> Int.compare b a)
  in
  match counts with
  | [] -> ""
  | _ ->
      "\nNear-miss skip reasons: "
      ^ String.concat ~sep:", "
          (List.map counts ~f:(fun (r, c) -> Printf.sprintf "%s=%d" r c))
      ^ "\n"

let _header (records : SR.t list) : string =
  let n_screens = List.length records in
  let n_funded =
    List.sum (module Int) records ~f:(fun (s : SR.t) -> s.summary.n_funded)
  in
  let n_near =
    List.sum (module Int) records ~f:(fun (s : SR.t) -> s.summary.n_near_miss)
  in
  let n_inv = List.count records ~f:(fun (s : SR.t) -> s.summary.inversion) in
  Printf.sprintf
    "# Per-screen faithfulness audit\n\n\
     Screens: %d | funded: %d | near-misses: %d | screens with inversion: %d\n\n\
     Faithfulness question: does any captured feature separate the funded set \
     from the cash-rejected near-misses? Overlapping means = uninformative tie \
     (faithful/expected).\n\n\
     ## Funded vs near-miss on captured features\n\n\
     %s%s\n"
    n_screens n_funded n_near n_inv (_feature_table records)
    (_reason_breakdown records)

let _funded_line (e : SR.funded_entry) : string =
  Printf.sprintf "%s s%d %s %s" e.symbol e.score
    (Weinstein_types.grade_to_string e.grade)
    (_stage_label e.stage)

let _near_line (n : SR.near_miss) : string =
  Printf.sprintf "%s s%d %s %s [%s]" n.symbol n.score
    (Weinstein_types.grade_to_string n.grade)
    (_stage_label n.stage)
    (_skip_reason_label n.reason_skipped)

let _screen_section (s : SR.t) : string =
  let funded =
    if List.is_empty s.funded then "  (none)\n"
    else
      String.concat
        (List.map s.funded ~f:(fun e -> "  " ^ _funded_line e ^ "\n"))
  in
  let near =
    if List.is_empty s.near_misses then "  (none)\n"
    else
      String.concat
        (List.map s.near_misses ~f:(fun n -> "  " ^ _near_line n ^ "\n"))
  in
  Printf.sprintf
    "## %s  (funded %d, near-misses %d)\n\
     funded:\n\
     %snear-miss:\n\
     %sinversion: %b\n\n"
    (Date.to_string s.screen_date)
    s.summary.n_funded s.summary.n_near_miss funded near s.summary.inversion

let to_markdown (records : SR.t list) : string =
  match records with
  | [] -> "# Per-screen faithfulness audit\n\nNo entry decisions in audit.\n"
  | _ -> _header records ^ String.concat (List.map records ~f:_screen_section)
