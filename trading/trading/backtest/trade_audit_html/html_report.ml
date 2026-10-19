(** Self-contained interactive HTML report — public facade. See [.mli]. *)

open Core
module TAR = Trade_audit_report
include Html_data

let render = Html_render.render

(* Which close column a mark must be drawn from. The two series this module
   derives from marks need opposite bases, so the requirement travels with each
   request rather than being baked into the supplier. See the [.mli]. *)
type price_basis = Adjusted | Raw

(* Derived: open positions -------------------------------------------------- *)

let _open_position ~final_prices (sym, side_str, entry_date, entry_price, qty) :
    open_position =
  let mark =
    Option.value
      (List.Assoc.find final_prices sym ~equal:String.equal)
      ~default:0.0
  in
  let is_short = String.equal (String.uppercase side_str) "SHORT" in
  let value = mark *. qty in
  let unrealized =
    if is_short then (entry_price -. mark) *. qty
    else (mark -. entry_price) *. qty
  in
  let gain_pct =
    if Float.(entry_price <= 0.0) then 0.0
    else if is_short then (entry_price -. mark) /. entry_price *. 100.0
    else (mark -. entry_price) /. entry_price *. 100.0
  in
  {
    symbol = sym;
    entry_date;
    entry_price;
    quantity = qty;
    mark;
    value;
    unrealized;
    gain_pct;
  }

(* Derived: subtitle -------------------------------------------------------- *)

let _opt_date = function Some d -> Date.to_string d | None -> "?"

let _subtitle (report : TAR.t) =
  let h = report.header in
  sprintf "%s \xe2\x86\x92 %s \xc2\xb7 universe %s \xc2\xb7 %d round-trips"
    (_opt_date h.period_start) (_opt_date h.period_end)
    (Option.value_map h.universe_size ~default:"?" ~f:Int.to_string)
    h.total_round_trips

let _stage_label = function
  | None -> ""
  | Some (s : Weinstein_types.stage) -> (
      match s with
      | Stage1 _ -> "Stage1"
      | Stage2 _ -> "Stage2"
      | Stage3 _ -> "Stage3"
      | Stage4 _ -> "Stage4")

(* Per-trade quality: join the report's ratings to rows by symbol + nearest
   entry date, then fold through {!TAR.Trade_score.compute}. The rating carries
   the audit record's Friday DECISION date while the row carries the actual
   fill date, so the join needs the same date tolerance the report's own
   row/audit join uses. *)
let _audit_join_tolerance_days = 7

let _quality_map (report : TAR.t) =
  let ratings =
    Option.value_map report.analysis ~default:[] ~f:(fun a -> a.TAR.ratings)
  in
  List.map ratings ~f:(fun (rt : TAR.Trade_audit_ratings.rating) ->
      (rt.symbol, rt))
  |> Map.of_alist_multi (module String)

let _quality_of qmap ~sym ~entry ~pnl_percent =
  Map.find qmap sym
  |> Option.bind ~f:(fun rts ->
      List.filter_map rts ~f:(fun (rt : TAR.Trade_audit_ratings.rating) ->
          let gap = Int.abs (Date.diff rt.entry_date entry) in
          if gap <= _audit_join_tolerance_days then Some (gap, rt) else None)
      |> List.min_elt ~compare:(fun (a, _) (b, _) -> Int.compare a b)
      |> Option.map ~f:snd)
  |> Option.map ~f:(fun rating ->
      TAR.Trade_score.compute ~rating ~pnl_percent ())

let _trade_rows ?weekly_series (report : TAR.t) extras =
  let qmap = _quality_map report in
  List.map report.rows ~f:(fun (r : TAR.per_trade_row) ->
      let extra =
        Html_series.extra_of extras ~sym:r.symbol ~entry:r.entry_date
          ~exit_:r.exit_date
      in
      let series =
        Option.bind weekly_series ~f:(fun weekly_series ->
            Html_series.series ~weekly_series ~extra ~sym:r.symbol
              ~entry:r.entry_date ~exit_:r.exit_date)
      in
      ({
         symbol = r.symbol;
         entry_date = r.entry_date;
         exit_date = r.exit_date;
         days_held = r.days_held;
         entry_price = r.entry_price;
         exit_price = r.exit_price;
         quantity = extra.qty;
         pnl_dollars = r.pnl_dollars;
         pnl_percent = r.pnl_percent;
         exit_trigger = r.exit_trigger;
         stage = _stage_label r.entry_stage;
         stop_kind = extra.stop_kind;
         cascade_score = r.cascade_score;
         quality =
           _quality_of qmap ~sym:r.symbol ~entry:r.entry_date
             ~pnl_percent:r.pnl_percent;
         series;
       }
        : trade_row))

(* Load --------------------------------------------------------------------- *)

let _extras_map extras =
  Map.of_alist_reduce (module String) extras ~f:(fun a _ -> a)

let load ?bar_close ?weekly_series ?(benchmark_symbol = "SPY")
    ?(benchmark_label = "SPY TR") ~(report : TAR.t) ~scenario_dir () : data =
  let path f = Filename.concat scenario_dir f in
  let curve =
    Html_series.downsample ~every:5
      (Html_sources.read_equity_curve (path "equity_curve.csv"))
  in
  let dates = List.map curve ~f:fst in
  let final_prices = Html_sources.read_final_prices (path "final_prices.csv") in
  let opens =
    List.map
      (Html_sources.read_open_positions (path "open_positions.csv"))
      ~f:(_open_position ~final_prices)
  in
  let extras =
    _extras_map (Html_sources.read_trade_extras (path "trades.csv"))
  in
  let summary = Html_sources.read_summary (path "summary.sexp") in
  let initial_cash =
    match summary.initial_cash with
    | Some v -> v
    | None -> ( match curve with (_, v) :: _ -> v | [] -> 0.0)
  in
  let final_nav =
    match summary.final_portfolio_value with
    | Some v -> v
    | None -> ( match List.last curve with Some (_, v) -> v | None -> 0.0)
  in
  (* The one supplier, asked for each series' own basis. Partially applying
     [~basis] here is what keeps the choice with this module — the only place
     that knows which arithmetic each series performs. *)
  let benchmark =
    Option.bind bar_close ~f:(fun bar_close ->
        Html_series.benchmark
          ~adjusted_close:(bar_close ~basis:Adjusted)
          ~symbol:benchmark_symbol ~initial_cash ~dates)
  in
  let utilization =
    Option.map bar_close ~f:(fun bar_close ->
        Html_series.utilization ~position_mark:(bar_close ~basis:Raw)
          ~intervals:(Html_series.intervals report extras opens)
          ~curve)
  in
  {
    scenario_name = Option.value report.header.scenario_name ~default:"scenario";
    subtitle = _subtitle report;
    initial_cash;
    final_nav;
    curve;
    benchmark;
    benchmark_label;
    utilization;
    opens;
    stale_held = summary.stale_held;
    kpis =
      Html_kpis.of_run ~report ~metrics:summary.metrics ~initial_cash ~final_nav
        ~benchmark ~benchmark_label;
    analysis = report.analysis;
    trades = _trade_rows ?weekly_series report extras;
  }
