open Core

type per_friday = { date : Date.t; trend : Weinstein_types.market_trend }
[@@deriving sexp]

type t = per_friday list [@@deriving sexp]

let of_cascade_summaries (summaries : Trade_audit.cascade_summary list) : t =
  List.map summaries ~f:(fun (s : Trade_audit.cascade_summary) ->
      { date = s.date; trend = s.macro_trend })
  |> List.sort ~compare:(fun a b -> Date.compare a.date b.date)

let write ~output_dir (summaries : Trade_audit.cascade_summary list) =
  let entries = of_cascade_summaries summaries in
  Sexp.save_hum (output_dir ^ "/macro_trend.sexp") (sexp_of_t entries)
