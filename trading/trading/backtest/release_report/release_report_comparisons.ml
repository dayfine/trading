open Core

(* --- All-eligible diagnostic section ---

   For each paired scenario where at least one side has [Some _] all-eligible
   artefacts, surface the headline aggregate (trade count, win rate, mean /
   median return, total P&L) for current vs prior side. The diagnostic
   measures opportunity cost: it sizes every cascade-admissible Stage-2
   breakout signal at a uniform fixed-dollar entry, bypassing every
   portfolio-level rejection (cash, exposure cap, sector concentration), and
   reports what each signal would have returned. A negative win rate / total
   P&L across the universe with a positive [actual] return implies the
   cascade is correctly keeping the average signal out; the inverse implies
   the cascade is leaving alpha on the table. Per-trade drill-down lives in
   the linked [trades.csv]. *)

type all_eligible_fields = {
  trade_count : int;
  winners : int;
  losers : int;
  win_rate_pct : float;
  mean_return_pct : float;
  median_return_pct : float;
  total_pnl_dollars : float;
  trades_csv_path : string;
}

type all_eligible_pair = {
  ae_name : string;
  ae_current : all_eligible_fields option;
  ae_prior : all_eligible_fields option;
}

let _fmt_optional_str = function Some s -> s | None -> "—"
let _fmt_pct_fraction_signed v = sprintf "%+.2f%%" (v *. 100.0)
let _fmt_pnl_dollars v = sprintf "%+.0f" v
let _fmt_int_signed v = sprintf "%d" v

let _alleli_row ~label ~cur_str ~prior_str =
  sprintf "| %s | %s | %s |" label cur_str prior_str

let _alleli_field_str (side : all_eligible_fields option)
    ~(fmt : float -> string) ~(get : all_eligible_fields -> float) =
  match side with None -> "—" | Some s -> fmt (get s)

let _alleli_int_field_str (side : all_eligible_fields option)
    ~(get : all_eligible_fields -> int) =
  match side with None -> "—" | Some s -> _fmt_int_signed (get s)

let _alleli_link_str (side : all_eligible_fields option) =
  Option.map side ~f:(fun s -> sprintf "[trades.csv](%s)" s.trades_csv_path)
  |> _fmt_optional_str

let _row_all_eligible_for_pair (p : all_eligible_pair) =
  [
    sprintf "### %s" p.ae_name;
    "";
    sprintf "Drill-down — Current: %s · Prior: %s"
      (_alleli_link_str p.ae_current)
      (_alleli_link_str p.ae_prior);
    "";
    "| Metric | Current | Prior |";
    "|---|---:|---:|";
    _alleli_row ~label:"Trades"
      ~cur_str:
        (_alleli_int_field_str p.ae_current ~get:(fun s -> s.trade_count))
      ~prior_str:
        (_alleli_int_field_str p.ae_prior ~get:(fun s -> s.trade_count));
    _alleli_row ~label:"Winners"
      ~cur_str:(_alleli_int_field_str p.ae_current ~get:(fun s -> s.winners))
      ~prior_str:(_alleli_int_field_str p.ae_prior ~get:(fun s -> s.winners));
    _alleli_row ~label:"Losers"
      ~cur_str:(_alleli_int_field_str p.ae_current ~get:(fun s -> s.losers))
      ~prior_str:(_alleli_int_field_str p.ae_prior ~get:(fun s -> s.losers));
    _alleli_row ~label:"Win rate"
      ~cur_str:
        (_alleli_field_str p.ae_current ~fmt:_fmt_pct_fraction_signed
           ~get:(fun s -> s.win_rate_pct))
      ~prior_str:
        (_alleli_field_str p.ae_prior ~fmt:_fmt_pct_fraction_signed
           ~get:(fun s -> s.win_rate_pct));
    _alleli_row ~label:"Mean return"
      ~cur_str:
        (_alleli_field_str p.ae_current ~fmt:_fmt_pct_fraction_signed
           ~get:(fun s -> s.mean_return_pct))
      ~prior_str:
        (_alleli_field_str p.ae_prior ~fmt:_fmt_pct_fraction_signed
           ~get:(fun s -> s.mean_return_pct));
    _alleli_row ~label:"Median return"
      ~cur_str:
        (_alleli_field_str p.ae_current ~fmt:_fmt_pct_fraction_signed
           ~get:(fun s -> s.median_return_pct))
      ~prior_str:
        (_alleli_field_str p.ae_prior ~fmt:_fmt_pct_fraction_signed
           ~get:(fun s -> s.median_return_pct));
    _alleli_row ~label:"Total P&L ($)"
      ~cur_str:
        (_alleli_field_str p.ae_current ~fmt:_fmt_pnl_dollars ~get:(fun s ->
             s.total_pnl_dollars))
      ~prior_str:
        (_alleli_field_str p.ae_prior ~fmt:_fmt_pnl_dollars ~get:(fun s ->
             s.total_pnl_dollars));
    "";
  ]

let render_all_eligible pairs =
  let with_alleli =
    List.filter pairs ~f:(fun p ->
        Option.is_some p.ae_current || Option.is_some p.ae_prior)
  in
  if List.is_empty with_alleli then []
  else
    let header =
      [
        "## All-eligible diagnostic";
        "";
        "Fixed-dollar opportunity-cost diagnostic — every cascade-admissible \
         Stage-2 breakout signal is sized at a uniform entry and tracked to \
         its natural exit, bypassing portfolio-level rejections \
         (`all_eligible/grade-C/summary.sexp` required). Compare against \
         actual trading metrics: negative aggregate P&L with a positive actual \
         return means the cascade is correctly keeping the average signal out; \
         the inverse means signal alpha is being left on the table. Per-trade \
         drill-down lives in the linked `trades.csv`.";
        "";
      ]
    in
    let body = List.concat_map with_alleli ~f:_row_all_eligible_for_pair in
    header @ body

(* --- Benchmark-relative section ---

   For each paired scenario where at least one side has [Some _]
   benchmark-relative artefacts (i.e. all five PR #1021 metrics were emitted
   in [summary.sexp]'s metrics block), surface α, β, IR, TE, and Pearson
   correlation side-by-side. The five metrics together pin how much of the
   strategy's return is benchmark-explained vs. residual: a strategy with
   β ≈ 1, corr ≈ 1, α ≈ 0 is replicating the benchmark; β < 1 with positive
   α and low correlation indicates a genuinely independent return stream.

   Δ is rendered as (current - prior) in absolute units for β, IR, and corr
   (which are unitless ratios) and in percentage points (pp) for α and TE
   (which are already in %/yr). Rendered only when at least one side has
   [Some _]; missing sides print "—". *)

type benchmark_relative_fields = {
  alpha_pct_annualized : float;
  beta : float;
  information_ratio : float;
  tracking_error_pct_annualized : float;
  correlation : float;
}

type benchmark_relative_pair = {
  br_name : string;
  br_current : benchmark_relative_fields option;
  br_prior : benchmark_relative_fields option;
}

let _br_field_str (side : benchmark_relative_fields option)
    ~(fmt : float -> string) ~(get : benchmark_relative_fields -> float) =
  match side with None -> "—" | Some b -> fmt (get b)

let _br_delta_str ~(fmt : float -> string)
    ~(get : benchmark_relative_fields -> float) cur prior =
  match (cur, prior) with Some c, Some p -> fmt (get c -. get p) | _ -> "—"

let _fmt_signed_3 v = sprintf "%+.3f" v
let _fmt_signed_pp_2 v = sprintf "%+.2f pp" v
let _fmt_signed_pct_2 v = sprintf "%+.2f%%" v

let _br_row ~label ~cur_str ~prior_str ~delta_str =
  sprintf "| %s | %s | %s | %s |" label cur_str prior_str delta_str

let _br_value_row (cur, prior) ~label ~fmt_val ~fmt_delta ~get =
  _br_row ~label
    ~cur_str:(_br_field_str cur ~fmt:fmt_val ~get)
    ~prior_str:(_br_field_str prior ~fmt:fmt_val ~get)
    ~delta_str:(_br_delta_str ~fmt:fmt_delta ~get cur prior)

let _row_benchmark_relative_for_pair (p : benchmark_relative_pair) =
  [
    sprintf "### %s" p.br_name;
    "";
    "| Metric | Current | Prior | \xce\x94 |";
    "|---|---:|---:|---:|";
    _br_value_row (p.br_current, p.br_prior) ~label:"Alpha (%/yr)"
      ~fmt_val:_fmt_signed_pct_2 ~fmt_delta:_fmt_signed_pp_2 ~get:(fun b ->
        b.alpha_pct_annualized);
    _br_value_row (p.br_current, p.br_prior) ~label:"Beta"
      ~fmt_val:_fmt_signed_3 ~fmt_delta:_fmt_signed_3 ~get:(fun b -> b.beta);
    _br_value_row (p.br_current, p.br_prior) ~label:"Information ratio"
      ~fmt_val:_fmt_signed_3 ~fmt_delta:_fmt_signed_3 ~get:(fun b ->
        b.information_ratio);
    _br_value_row (p.br_current, p.br_prior) ~label:"Tracking error (%/yr)"
      ~fmt_val:_fmt_signed_pct_2 ~fmt_delta:_fmt_signed_pp_2 ~get:(fun b ->
        b.tracking_error_pct_annualized);
    _br_value_row (p.br_current, p.br_prior) ~label:"Correlation"
      ~fmt_val:_fmt_signed_3 ~fmt_delta:_fmt_signed_3 ~get:(fun b ->
        b.correlation);
    "";
  ]

let render_benchmark_relative pairs =
  let with_br =
    List.filter pairs ~f:(fun p ->
        Option.is_some p.br_current || Option.is_some p.br_prior)
  in
  if List.is_empty with_br then []
  else
    let header =
      [
        "## Benchmark-relative";
        "";
        "CAPM-style residual-return diagnostics from PR #1021: α (annualised \
         intercept of [r_strat = α + β · r_bench]), β (slope), Information \
         Ratio (α / TE), Tracking Error (annualised stdev of the active-return \
         series), and Pearson correlation. Δ is current minus prior — α / TE \
         in percentage points, β / IR / correlation in absolute units. \
         Rendered only for scenarios whose [summary.sexp] metrics block \
         carries all five labels.";
        "";
      ]
    in
    let body = List.concat_map with_br ~f:_row_benchmark_relative_for_pair in
    header @ body
