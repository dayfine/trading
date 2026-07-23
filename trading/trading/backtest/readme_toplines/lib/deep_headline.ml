open Core

type record = {
  label : string;
  total_return_pct : float;
  max_drawdown_pct : float option; [@sexp.option]
  trades : int option; [@sexp.option]
  win_rate_pct : float option; [@sexp.option]
  period : string;
  scenario_path : string;
  basis_commit : string;
  date : string;
}
[@@deriving sexp]

let start_marker = "<!-- deep-headline:start -->"
let end_marker = "<!-- deep-headline:end -->"

let load path =
  if not (Stdlib.Sys.file_exists path) then None
  else
    match
      Or_error.try_with (fun () ->
          List.map (Sexp.load_sexps path) ~f:record_of_sexp)
    with
    | Ok records -> Some records
    | Error err ->
        failwithf "deep_headline: failed to parse %s: %s" path
          (Error.to_string_hum err) ()

(* ----- rendering ----- *)

let _missing = "—"

(* A large whole-percent total return, thousands-grouped with a leading sign,
   e.g. [8689.0 -> "+8,689%"]. *)
let _fmt_total_return_pct v =
  let rounded = Float.iround_nearest_exn v in
  let sign = if rounded >= 0 then "+" else "" in
  sprintf "%s%s%%" sign (Int.to_string_hum ~delimiter:',' rounded)

let _fmt_opt_pct = function None -> _missing | Some v -> sprintf "%.1f%%" v

let _fmt_opt_trades = function
  | None -> _missing
  | Some n -> Int.to_string_hum ~delimiter:',' n

let _header = "### Deep multi-decade headline (results-of-record)"

let _table_header =
  "| Result | Total return | Max DD | Trades | Win rate | Period |\n\
   |---|---|---|---|---|---|"

let _caveat =
  "_Basis: mark-to-market, including open-position marks on a few concentrated \
   fat-tail winners and (unless a liquidity overlay is armed) untradeable \
   illiquid names — NOT bankable as realized P&L. The honest read is vs the \
   index over the same window and realized-vs-MTM. Full pins + caveats: \
   [`dev/backtest/DEEP_RESULTS.md`](dev/backtest/DEEP_RESULTS.md)._"

let _render_row r =
  sprintf "| %s | %s | %s | %s | %s | %s |" r.label
    (_fmt_total_return_pct r.total_return_pct)
    (_fmt_opt_pct r.max_drawdown_pct)
    (_fmt_opt_trades r.trades)
    (_fmt_opt_pct r.win_rate_pct)
    r.period

let _render_citation r =
  sprintf "- **%s** — `%s` @ %s (%s)" r.label r.scenario_path r.basis_commit
    r.date

let render_markdown records =
  let rows = List.map records ~f:_render_row in
  let citations = List.map records ~f:_render_citation in
  String.concat ~sep:"\n"
    ([ _header; ""; _table_header ]
    @ rows
    @ [ ""; "Provenance (scenario / commit / date):" ]
    @ citations @ [ ""; _caveat ])

let render_block records =
  Readme_block.render_between ~start_marker ~end_marker
    (render_markdown records)
