(** Single-symbol monthly Weinstein-style reduction on the Shiller S&P composite
    series.

    Strategy:
    - Compute a 30-month moving average over [sp_price] (a coarse proxy for the
      canonical 30-week MA on weekly bars).
    - Long the index when current price > MA AND MA is rising (price[t] > ma[t]
      AND ma[t] > ma[t-1]). Cash otherwise. No shorts in this reduction.
    - Returns are computed on a monthly basis. The strategy participates in
      month t's return iff it was Long at the end of month t-1 (i.e. the
      Long-cash decision is applied with a one-month lag, matching the "decision
      at end-of-week, holds through next week" cadence the production strategy
      uses on weekly bars).

    Output: a decade-by-decade table (1870s through 2020s) with CAGR, Sharpe,
    MaxDD for both the strategy and a buy-and-hold benchmark, plus headline
    155-year totals.

    Limitations (per dev/plans/cross-cycle-weinstein-validation-2026-05-19.md):
    - Index-level only. No cross-sectional ranking, no sector rotation.
    - Monthly granularity. Can't measure intra-month stop performance.
    - 30-month MA is a coarse proxy for 30-week. This is fine for the "does the
      framework profit at all in 1929 / 1973 / 2000?" question. *)

open Core
module Client = Shiller.Shiller_client

(** Parser for the *derived* 6-column CSV emitted by [fetch_shiller_history.exe]
    (period,sp_price,dividend,earnings,cpi,long_rate), NOT the raw 10-column
    mirror format that [Shiller_client.parse] consumes. We do this here rather
    than going through [Client.parse] because the pinned fixture stores the
    derived form. *)
let _parse_derived_csv body : Client.series =
  let lines = String.split_lines body in
  let observations =
    List.filter_mapi lines ~f:(fun i line ->
        if i = 0 then None
        else if String.is_empty (String.strip line) then None
        else
          let cols = String.split line ~on:',' in
          match cols with
          | [ date_s; sp_s; div_s; earn_s; cpi_s; long_s ] ->
              let parse_opt s =
                if String.is_empty (String.strip s) then None
                else Some (Float.of_string s)
              in
              Some
                {
                  Client.period = Date.of_string date_s;
                  sp_price = Float.of_string sp_s;
                  dividend = parse_opt div_s;
                  earnings = parse_opt earn_s;
                  cpi = parse_opt cpi_s;
                  long_rate = parse_opt long_s;
                }
          | _ ->
              failwithf "shiller_weinstein_decades: malformed CSV line %d: %s" i
                line ())
  in
  { Client.observations }

(** Default MA window in months. The canonical Weinstein "30-week" applied to
    monthly data is ~7 months; the original M1 PR used 30 months, which we have
    since shown lags ~4× too slow. Operators override via [-ma-window]. *)
let _default_ma_window_months = 30

(** Risk-free rate proxy for Sharpe. We use a constant 0 for the cross-decade
    comparison; using the contemporaneous long-rate would bias toward
    inflationary decades. The Sharpe numbers reported are therefore "excess over
    cash" not "excess over treasury" — adequate for cross-regime rank
    comparison. *)
let _risk_free_monthly = 0.0

(* ────────────────────────────────────────────────────────────
   Pure compute helpers
   ──────────────────────────────────────────────────────────── *)

(** [moving_average prices ~window] returns an array of the same length as
    [prices], with the first [window-1] entries set to [Float.nan] and the rest
    set to the trailing simple average. *)
let _moving_average prices ~window =
  let n = Array.length prices in
  let out = Array.create ~len:n Float.nan in
  if n < window then out
  else begin
    let sum = ref 0.0 in
    for i = 0 to window - 1 do
      sum := !sum +. prices.(i)
    done;
    out.(window - 1) <- !sum /. Float.of_int window;
    for i = window to n - 1 do
      sum := !sum -. prices.(i - window) +. prices.(i);
      out.(i) <- !sum /. Float.of_int window
    done;
    out
  end

(** Per-month monthly return: [(p_t - p_{t-1}) / p_{t-1}]. Length = n - 1. *)
let _monthly_returns prices =
  let n = Array.length prices in
  Array.init (n - 1) ~f:(fun i -> (prices.(i + 1) -. prices.(i)) /. prices.(i))

(** Long-cash signal at the end of month t, indexed against the [prices] / [ma]
    arrays. [true] = Long for month t+1; [false] = Cash. *)
let _is_long ~prices ~ma t =
  if t = 0 then false
  else
    let p = prices.(t) in
    let m = ma.(t) in
    let m_prev = ma.(t - 1) in
    if Float.is_nan m || Float.is_nan m_prev then false
    else Float.(p > m) && Float.(m > m_prev)

(** Strategy returns: for each month t (where t >= 1), participate in the full
    underlying return iff [_is_long ~t:(t-1)] was true. Length = n - 1. *)
let _strategy_returns ~prices ~ma =
  let n = Array.length prices in
  Array.init (n - 1) ~f:(fun i ->
      let underlying = (prices.(i + 1) -. prices.(i)) /. prices.(i) in
      if _is_long ~prices ~ma i then underlying else _risk_free_monthly)

(* ────────────────────────────────────────────────────────────
   Metrics
   ──────────────────────────────────────────────────────────── *)

(** [cagr_from_returns rs ~periods_per_year] = annualised compound return. *)
let _cagr_from_returns rs ~periods_per_year =
  let n = Array.length rs in
  if n = 0 then 0.0
  else
    let cum = Array.fold rs ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r)) in
    let years = Float.of_int n /. periods_per_year in
    if Float.(years <= 0.0) then 0.0 else Float.((cum ** (1.0 / years)) - 1.0)

(** [sharpe rs ~periods_per_year] = annualised Sharpe ratio (excess over
    [_risk_free_monthly]). *)
let _sharpe rs ~periods_per_year =
  let n = Array.length rs in
  if n < 2 then 0.0
  else
    let mean = Array.fold rs ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let var =
      Array.fold rs ~init:0.0 ~f:(fun acc r -> acc +. ((r -. mean) ** 2.0))
      /. Float.of_int (n - 1)
    in
    if Float.(var <= 0.0) then 0.0
    else
      let excess = mean -. _risk_free_monthly in
      let std = Float.sqrt var in
      excess /. std *. Float.sqrt periods_per_year

(** [max_drawdown rs] = maximum peak-to-trough drawdown of the cumulative return
    curve, as a negative number (or 0.0 if no drawdown). *)
let _max_drawdown rs =
  let cum = ref 1.0 in
  let peak = ref 1.0 in
  let max_dd = ref 0.0 in
  Array.iter rs ~f:(fun r ->
      cum := !cum *. (1.0 +. r);
      peak := Float.max !peak !cum;
      let dd = (!cum /. !peak) -. 1.0 in
      max_dd := Float.min !max_dd dd);
  !max_dd

(** [cumulative_return rs] = end-state cumulative return as a multiplier (e.g.
    1.0 means flat, 2.0 means doubled). *)
let _cumulative_return rs =
  Array.fold rs ~init:1.0 ~f:(fun acc r -> acc *. (1.0 +. r))

(** [beta strategy_rs market_rs] = OLS regression slope of strategy returns
    against market (B&H) returns. β<1 means strategy moves less than market per
    unit market move — confirms lower-vol-not-higher-return regime. *)
let _beta strategy_rs market_rs =
  let n = Array.length market_rs in
  if n < 2 then 0.0
  else
    let mean_x = Array.fold market_rs ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let mean_y = Array.fold strategy_rs ~init:0.0 ~f:( +. ) /. Float.of_int n in
    let cov = ref 0.0 in
    let var_x = ref 0.0 in
    for i = 0 to n - 1 do
      let dx = market_rs.(i) -. mean_x in
      let dy = strategy_rs.(i) -. mean_y in
      cov := !cov +. (dx *. dy);
      var_x := !var_x +. (dx *. dx)
    done;
    if Float.(!var_x <= 0.0) then 0.0 else !cov /. !var_x

(* ────────────────────────────────────────────────────────────
   Stage 1-4 classification (Weinstein book canonical)
   ──────────────────────────────────────────────────────────── *)

type stage = Stage1 | Stage2 | Stage3 | Stage4

let _stage_label = function
  | Stage1 -> "S1"
  | Stage2 -> "S2"
  | Stage3 -> "S3"
  | Stage4 -> "S4"

(** Slope of MA at index t: (ma[t] - ma[t-k]) / k, normalised by price level.
    [k] is the lookback for slope assessment. 6 months is the canonical
    Weinstein "MA is flat/rising/falling" lookback when applied to monthly data
    (= ~26 weeks ≈ 6 months). *)
let _ma_slope_pct ~ma ~prices ~k t =
  if t < k || Float.is_nan ma.(t) || Float.is_nan ma.(t - k) then Float.nan
  else (ma.(t) -. ma.(t - k)) /. prices.(t)

let _stage_slope_lookback = 6
let _stage_slope_threshold = 0.005

(** Classify Stage 1/2/3/4 at index t given price + MA. Canonical book rules:

    - Stage 2 (advancing): price > MA AND MA rising
    - Stage 4 (declining): price < MA AND MA falling
    - Stage 1 (basing): price ≈ MA, MA flat-or-rising
    - Stage 3 (topping): price ≈ MA, MA flat-or-falling

    Slope threshold ±0.5% of price per 6-month lookback distinguishes "flat"
    from "rising/falling". *)
let _classify_stage ~prices ~ma t =
  let p = prices.(t) in
  let m = ma.(t) in
  if Float.is_nan m then Stage1
  else
    let slope = _ma_slope_pct ~ma ~prices ~k:_stage_slope_lookback t in
    let rising = Float.(slope > _stage_slope_threshold) in
    let falling = Float.(slope < -._stage_slope_threshold) in
    let above = Float.(p > m) in
    let below = Float.(p < m) in
    match (above, below, rising, falling) with
    | true, _, true, _ -> Stage2
    | _, true, _, true -> Stage4
    | true, _, false, _ -> Stage3 (* above MA but MA flat/falling = topping *)
    | _, true, false, _ -> Stage1 (* below MA but MA flat/rising = basing *)
    | _ -> Stage1

(* ────────────────────────────────────────────────────────────
   Slicing + reporting
   ──────────────────────────────────────────────────────────── *)

let _months_per_year = 12.0

type decade_report = {
  decade_label : string;
  n_months : int;
  strategy_cagr : float;
  strategy_sharpe : float;
  strategy_maxdd : float;
  bh_cagr : float;
  bh_sharpe : float;
  bh_maxdd : float;
  pct_months_long : float;
}

let _decade_of (d : Date.t) =
  let y = Date.year d in
  y / 10 * 10

(** Slice a returns array by decade boundary using [periods] (length n, aligned
    with [rs]; periods[i] is the END-OF-MONTH date for return rs[i]). *)
let _slice_by_decade ~periods ~rs ~strategy_signal =
  let by_decade = Hashtbl.create (module Int) in
  Array.iteri rs ~f:(fun i r ->
      let dec = _decade_of periods.(i) in
      let bucket =
        Hashtbl.find_or_add by_decade dec ~default:(fun () -> ([], [], [], 0))
      in
      let bh_rs, strat_rs, _, _ = bucket in
      let signal = strategy_signal.(i) in
      let dec_data =
        let bh_rs' = r :: bh_rs in
        let strat_rs' =
          (if signal then r else _risk_free_monthly) :: strat_rs
        in
        let _, _, _, n_long = bucket in
        let n_long' = if signal then n_long + 1 else n_long in
        (bh_rs', strat_rs', [], n_long')
      in
      Hashtbl.set by_decade ~key:dec ~data:dec_data);
  by_decade

let _decade_report ~decade ~bh_rs ~strat_rs ~n_long =
  let bh = Array.of_list_rev bh_rs in
  let strat = Array.of_list_rev strat_rs in
  let n = Array.length bh in
  {
    decade_label = sprintf "%ds" decade;
    n_months = n;
    strategy_cagr = _cagr_from_returns strat ~periods_per_year:_months_per_year;
    strategy_sharpe = _sharpe strat ~periods_per_year:_months_per_year;
    strategy_maxdd = _max_drawdown strat;
    bh_cagr = _cagr_from_returns bh ~periods_per_year:_months_per_year;
    bh_sharpe = _sharpe bh ~periods_per_year:_months_per_year;
    bh_maxdd = _max_drawdown bh;
    pct_months_long =
      (if n = 0 then 0.0 else 100.0 *. Float.of_int n_long /. Float.of_int n);
  }

(* ────────────────────────────────────────────────────────────
   Formatting
   ──────────────────────────────────────────────────────────── *)

let _format_pct ?(decimals = 2) x = sprintf "%.*f%%" decimals (100.0 *. x)

let _print_table (reports : decade_report list) =
  printf
    "\n\
     | Decade  | N mo | %% Long | Strat CAGR | Strat Sharpe | Strat MaxDD | \
     B&H CAGR  | B&H Sharpe | B&H MaxDD |\n\
     |---------|------|--------|------------|--------------|-------------|-----------|------------|-----------|\n";
  List.iter reports ~f:(fun r ->
      printf
        "| %-7s | %4d | %5.1f%% | %9s | %12.2f | %10s | %8s | %10.2f | %8s |\n"
        r.decade_label r.n_months r.pct_months_long
        (_format_pct r.strategy_cagr)
        r.strategy_sharpe
        (_format_pct r.strategy_maxdd)
        (_format_pct r.bh_cagr) r.bh_sharpe (_format_pct r.bh_maxdd))

(* ────────────────────────────────────────────────────────────
   Stage breakdown + ASCII chart
   ──────────────────────────────────────────────────────────── *)

let _print_stage_breakdown ~stages ~dates =
  let buckets = Hashtbl.create (module Int) in
  Array.iteri stages ~f:(fun i s ->
      let dec = _decade_of dates.(i) in
      let cur =
        Hashtbl.find buckets dec |> Option.value ~default:(0, 0, 0, 0)
      in
      let s1, s2, s3, s4 = cur in
      let next =
        match s with
        | Stage1 -> (s1 + 1, s2, s3, s4)
        | Stage2 -> (s1, s2 + 1, s3, s4)
        | Stage3 -> (s1, s2, s3 + 1, s4)
        | Stage4 -> (s1, s2, s3, s4 + 1)
      in
      Hashtbl.set buckets ~key:dec ~data:next);
  printf "\n=== Stage breakdown (%% of months in each stage) ===\n";
  printf "| Decade  | Stage 1 | Stage 2 | Stage 3 | Stage 4 |\n";
  printf "|---------|--------:|--------:|--------:|--------:|\n";
  let decs = Hashtbl.keys buckets |> List.sort ~compare:Int.compare in
  List.iter decs ~f:(fun dec ->
      let s1, s2, s3, s4 = Hashtbl.find_exn buckets dec in
      let total = s1 + s2 + s3 + s4 in
      let pct x = 100.0 *. Float.of_int x /. Float.of_int total in
      printf "| %-7s | %6.1f%% | %6.1f%% | %6.1f%% | %6.1f%% |\n"
        (sprintf "%ds" dec) (pct s1) (pct s2) (pct s3) (pct s4))

let _count_transitions ~stages =
  let n = Array.length stages in
  let count = ref 0 in
  for i = 1 to n - 1 do
    let prev = stages.(i - 1) in
    let cur = stages.(i) in
    let prev_label = _stage_label prev in
    let cur_label = _stage_label cur in
    if not (String.equal prev_label cur_label) then incr count
  done;
  !count

(** ASCII chart of price (log scale) vs MA for a date range, with a stage strip
    underneath. Width is fixed at 80 chars. Useful for eyeballing whether stage
    transitions align with intuitive regime shifts. *)
let _chart_width = 80

let _chart_height = 12

(* @large-function: ASCII chart renderer; range scan + canvas plot + stage strip in one place is simplest *)
let _ascii_chart ~prices ~ma ~stages ~dates ~from_idx ~to_idx ~title =
  let n = to_idx - from_idx + 1 in
  if n <= 0 then ()
  else
    let step = Float.of_int n /. Float.of_int _chart_width in
    let log_prices = Array.map prices ~f:Float.log in
    let lo = ref Float.infinity in
    let hi = ref Float.neg_infinity in
    for i = from_idx to to_idx do
      lo := Float.min !lo log_prices.(i);
      hi := Float.min Float.infinity (Float.max !hi log_prices.(i));
      if not (Float.is_nan ma.(i)) then begin
        lo := Float.min !lo (Float.log ma.(i));
        hi := Float.max !hi (Float.log ma.(i))
      end
    done;
    let range = !hi -. !lo in
    let row_of v =
      if Float.is_nan v then -1
      else
        let frac = (v -. !lo) /. range in
        _chart_height - 1
        - Int.of_float (frac *. Float.of_int (_chart_height - 1))
    in
    let canvas = Array.make_matrix ~dimx:_chart_height ~dimy:_chart_width ' ' in
    for col = 0 to _chart_width - 1 do
      let idx = from_idx + Int.of_float (Float.of_int col *. step) in
      if idx <= to_idx then begin
        let pr = row_of log_prices.(idx) in
        let mr =
          row_of
            (if Float.is_nan ma.(idx) then Float.nan else Float.log ma.(idx))
        in
        if pr >= 0 && pr < _chart_height then canvas.(pr).(col) <- '*';
        if mr >= 0 && mr < _chart_height then
          canvas.(mr).(col) <-
            (if Char.equal canvas.(mr).(col) '*' then '#' else '-')
      end
    done;
    printf "\n=== %s ===\n" title;
    printf "(* = price, - = 30mo MA, # = both; log y-axis)\n";
    for row = 0 to _chart_height - 1 do
      printf "  %s\n" (String.of_array canvas.(row))
    done;
    (* Stage strip underneath *)
    let stage_strip = Bytes.make _chart_width ' ' in
    for col = 0 to _chart_width - 1 do
      let idx = from_idx + Int.of_float (Float.of_int col *. step) in
      if idx <= to_idx then begin
        let ch =
          match stages.(idx) with
          | Stage1 -> '.'
          | Stage2 -> '#'
          | Stage3 -> ':'
          | Stage4 -> 'v'
        in
        Bytes.set stage_strip col ch
      end
    done;
    printf "  %s\n" (Bytes.to_string stage_strip);
    printf "  (S1=. S2=# S3=: S4=v)\n";
    let d_lo = dates.(from_idx) in
    let d_hi = dates.(to_idx) in
    printf "  range: %s ... %s\n" (Date.to_string d_lo) (Date.to_string d_hi)

let _print_headline ~strat_rs ~bh_rs =
  let n = Array.length bh_rs in
  let strat_cum = _cumulative_return strat_rs in
  let bh_cum = _cumulative_return bh_rs in
  let strat_cagr =
    _cagr_from_returns strat_rs ~periods_per_year:_months_per_year
  in
  let bh_cagr = _cagr_from_returns bh_rs ~periods_per_year:_months_per_year in
  let strat_sharpe = _sharpe strat_rs ~periods_per_year:_months_per_year in
  let bh_sharpe = _sharpe bh_rs ~periods_per_year:_months_per_year in
  let strat_maxdd = _max_drawdown strat_rs in
  let bh_maxdd = _max_drawdown bh_rs in
  let years = Float.of_int n /. _months_per_year in
  printf
    "\n\
     === Headline (%.1f years, %d months) ===\n\
     Strategy : CAGR %s, Sharpe %.2f, MaxDD %s, cumulative %.1fx\n\
     B&H      : CAGR %s, Sharpe %.2f, MaxDD %s, cumulative %.1fx\n"
    years n (_format_pct strat_cagr) strat_sharpe (_format_pct strat_maxdd)
    strat_cum (_format_pct bh_cagr) bh_sharpe (_format_pct bh_maxdd) bh_cum

(* ────────────────────────────────────────────────────────────
   Main
   ──────────────────────────────────────────────────────────── *)

let _load_series ~csv_path =
  let body = In_channel.read_all csv_path in
  _parse_derived_csv body

let _maybe_chart_decades ~chart_decades ~prices ~ma ~stages ~obs =
  let stage_dates = Array.map obs ~f:(fun o -> o.Client.period) in
  let n = Array.length prices in
  List.iter chart_decades ~f:(fun dec ->
      let from_idx = ref None in
      let to_idx = ref None in
      for i = 0 to n - 1 do
        let y = Date.year stage_dates.(i) in
        let target_dec = y / 10 * 10 in
        if target_dec = dec then begin
          if Option.is_none !from_idx then from_idx := Some i;
          to_idx := Some i
        end
      done;
      match (!from_idx, !to_idx) with
      | Some f, Some t ->
          _ascii_chart ~prices ~ma ~stages ~dates:stage_dates ~from_idx:f
            ~to_idx:t ~title:(sprintf "%ds chart" dec)
      | _ -> ())

let _run ~csv_path ~chart_decades ~ma_window =
  let series = _load_series ~csv_path in
  let obs = Array.of_list series.observations in
  let prices = Array.map obs ~f:(fun o -> o.Client.sp_price) in
  let dates =
    Array.map obs ~f:(fun o -> o.Client.period) |> fun arr ->
    Array.sub arr ~pos:1 ~len:(Array.length arr - 1)
  in
  printf "MA window: %d months\n" ma_window;
  let ma = _moving_average prices ~window:ma_window in
  let bh_rs = _monthly_returns prices in
  let strat_rs = _strategy_returns ~prices ~ma in
  let strategy_signal =
    Array.init (Array.length bh_rs) ~f:(fun i -> _is_long ~prices ~ma i)
  in
  let by_decade = _slice_by_decade ~periods:dates ~rs:bh_rs ~strategy_signal in
  let decs = Hashtbl.keys by_decade |> List.sort ~compare:Int.compare in
  let reports =
    List.map decs ~f:(fun decade ->
        let bh_rs_d, strat_rs_d, _, n_long =
          Hashtbl.find_exn by_decade decade
        in
        _decade_report ~decade ~bh_rs:bh_rs_d ~strat_rs:strat_rs_d ~n_long)
  in
  _print_table reports;
  _print_headline ~strat_rs ~bh_rs;
  let stages =
    Array.init (Array.length prices) ~f:(fun t -> _classify_stage ~prices ~ma t)
  in
  let stage_dates = Array.map obs ~f:(fun o -> o.Client.period) in
  _print_stage_breakdown ~stages ~dates:stage_dates;
  let transitions = _count_transitions ~stages in
  let beta = _beta strat_rs bh_rs in
  printf
    "\n\
     === Diagnostics ===\n\
     β (strat vs B&H): %.3f (β<1 = lower-vol regime)\n\
     Stage transitions (whipsaw count): %d over %d months (%.1f per decade)\n"
    beta transitions (Array.length stages)
    (Float.of_int transitions /. Float.of_int (Array.length stages) *. 120.0);
  _maybe_chart_decades ~chart_decades ~prices ~ma ~stages ~obs

let command =
  Command.basic
    ~summary:"single-symbol monthly Weinstein reduction on Shiller S&P"
    (let%map_open.Command csv_path =
       flag "-csv" (required string)
         ~doc:
           "PATH parsed Shiller monthly CSV (output of fetch_shiller_history)"
     and chart_decades_str =
       flag "-chart-decades"
         (optional_with_default "" string)
         ~doc:
           "CSV comma-separated decade starts to chart, e.g. '1920,1970,2000'"
     and ma_window =
       flag "-ma-window"
         (optional_with_default _default_ma_window_months int)
         ~doc:
           "INT moving-average window in months (default 30 = ~7y; try 7 for \
            Weinstein-canonical 30-week cadence)"
     in
     fun () ->
       let chart_decades =
         if String.is_empty chart_decades_str then []
         else
           String.split chart_decades_str ~on:','
           |> List.map ~f:String.strip
           |> List.filter ~f:(fun s -> not (String.is_empty s))
           |> List.map ~f:Int.of_string
       in
       _run ~csv_path ~chart_decades ~ma_window)

let () = Command_unix.run command
