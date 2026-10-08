(** Decade slicing and table/headline/stage-breakdown printers. *)

open Core
open Shiller_decades_metrics
open Shiller_decades_stage

let months_per_year = 12.0

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

let decade_of (d : Date.t) =
  let y = Date.year d in
  y / 10 * 10

(** Slice a returns array by decade boundary using [periods] (length n, aligned
    with [rs]; periods[i] is the END-OF-MONTH date for return rs[i]). *)
let slice_by_decade ~periods ~rs ~strategy_signal =
  let by_decade = Hashtbl.create (module Int) in
  Array.iteri rs ~f:(fun i r ->
      let dec = decade_of periods.(i) in
      let bucket =
        Hashtbl.find_or_add by_decade dec ~default:(fun () -> ([], [], [], 0))
      in
      let bh_rs, strat_rs, _, _ = bucket in
      let signal = strategy_signal.(i) in
      let dec_data =
        let bh_rs' = r :: bh_rs in
        let strat_rs' = (if signal then r else risk_free_monthly) :: strat_rs in
        let _, _, _, n_long = bucket in
        let n_long' = if signal then n_long + 1 else n_long in
        (bh_rs', strat_rs', [], n_long')
      in
      Hashtbl.set by_decade ~key:dec ~data:dec_data);
  by_decade

let decade_report ~decade ~bh_rs ~strat_rs ~n_long =
  let bh = Array.of_list_rev bh_rs in
  let strat = Array.of_list_rev strat_rs in
  let n = Array.length bh in
  {
    decade_label = sprintf "%ds" decade;
    n_months = n;
    strategy_cagr = cagr_from_returns strat ~periods_per_year:months_per_year;
    strategy_sharpe = sharpe strat ~periods_per_year:months_per_year;
    strategy_maxdd = max_drawdown strat;
    bh_cagr = cagr_from_returns bh ~periods_per_year:months_per_year;
    bh_sharpe = sharpe bh ~periods_per_year:months_per_year;
    bh_maxdd = max_drawdown bh;
    pct_months_long =
      (if n = 0 then 0.0 else 100.0 *. Float.of_int n_long /. Float.of_int n);
  }

(* ────────────────────────────────────────────────────────────
   Formatting
   ──────────────────────────────────────────────────────────── *)

let format_pct ?(decimals = 2) x = sprintf "%.*f%%" decimals (100.0 *. x)

let print_table (reports : decade_report list) =
  printf
    "\n\
     | Decade  | N mo | %% Long | Strat CAGR | Strat Sharpe | Strat MaxDD | \
     B&H CAGR  | B&H Sharpe | B&H MaxDD |\n\
     |---------|------|--------|------------|--------------|-------------|-----------|------------|-----------|\n";
  List.iter reports ~f:(fun r ->
      printf
        "| %-7s | %4d | %5.1f%% | %9s | %12.2f | %10s | %8s | %10.2f | %8s |\n"
        r.decade_label r.n_months r.pct_months_long
        (format_pct r.strategy_cagr)
        r.strategy_sharpe
        (format_pct r.strategy_maxdd)
        (format_pct r.bh_cagr) r.bh_sharpe (format_pct r.bh_maxdd))

(* ────────────────────────────────────────────────────────────
   Stage breakdown + ASCII chart
   ──────────────────────────────────────────────────────────── *)

let print_stage_breakdown ~stages ~dates =
  let buckets = Hashtbl.create (module Int) in
  Array.iteri stages ~f:(fun i s ->
      let dec = decade_of dates.(i) in
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

let count_transitions ~stages =
  let n = Array.length stages in
  let count = ref 0 in
  for i = 1 to n - 1 do
    let prev = stages.(i - 1) in
    let cur = stages.(i) in
    let prev_label = stage_label prev in
    let cur_label = stage_label cur in
    if not (String.equal prev_label cur_label) then incr count
  done;
  !count

let print_headline ~strat_rs ~bh_rs =
  let n = Array.length bh_rs in
  let strat_cum = cumulative_return strat_rs in
  let bh_cum = cumulative_return bh_rs in
  let strat_cagr =
    cagr_from_returns strat_rs ~periods_per_year:months_per_year
  in
  let bh_cagr = cagr_from_returns bh_rs ~periods_per_year:months_per_year in
  let strat_sharpe = sharpe strat_rs ~periods_per_year:months_per_year in
  let bh_sharpe = sharpe bh_rs ~periods_per_year:months_per_year in
  let strat_maxdd = max_drawdown strat_rs in
  let bh_maxdd = max_drawdown bh_rs in
  let years = Float.of_int n /. months_per_year in
  printf
    "\n\
     === Headline (%.1f years, %d months) ===\n\
     Strategy : CAGR %s, Sharpe %.2f, MaxDD %s, cumulative %.1fx\n\
     B&H      : CAGR %s, Sharpe %.2f, MaxDD %s, cumulative %.1fx\n"
    years n (format_pct strat_cagr) strat_sharpe (format_pct strat_maxdd)
    strat_cum (format_pct bh_cagr) bh_sharpe (format_pct bh_maxdd) bh_cum
