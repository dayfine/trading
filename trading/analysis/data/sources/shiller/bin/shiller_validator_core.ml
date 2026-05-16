open! Core
module Client = Shiller.Shiller_client

type drift_row = {
  period : Date.t;
  shiller_sp_price : float;
  eodhd_monthly_adj_close : float;
  rel_diff : float;
}
[@@deriving show, eq]

type stats = {
  n_compared : int;
  n_flagged : int;
  mean_abs_rel_diff : float;
  stdev_abs_rel_diff : float;
  max_abs_rel_diff : float;
}
[@@deriving show, eq]

type report = {
  threshold : float;
  overlap_first : Date.t option;
  overlap_last : Date.t option;
  stats : stats;
  rows : drift_row list;
  top_drift : drift_row list;
}
[@@deriving show, eq]

(* The Shiller series is anchored on the first day of the month
   (1871-01-01 = "January 1871"). When we resample EODHD daily bars we
   collapse all bars whose calendar (year, month) matches to a single point
   anchored on the same first-of-month, using the LAST bar's adjusted-close
   (the natural month-end pairing). This is the canonical alignment for
   monthly-cadence cross-validation. *)
let _first_of_month (d : Date.t) : Date.t =
  Date.create_exn ~y:(Date.year d) ~m:(Date.month d) ~d:1

let _same_year_month (a : Date.t) (b : Date.t) : bool =
  Int.equal (Date.year a) (Date.year b)
  && Month.equal (Date.month a) (Date.month b)

(* Group consecutive bars by (year, month) and emit the last bar per group.
   We rely on the EODHD cache invariant: bars are sorted ascending by date.
   A single pass is sufficient; we don't need a Map. *)
let resample_daily_to_monthly (bars : Types.Daily_price.t list) :
    (Date.t * float) list =
  let groups =
    List.group bars ~break:(fun a b -> not (_same_year_month a.date b.date))
  in
  List.filter_map groups ~f:(fun group ->
      match List.last group with
      | None -> None
      | Some last_bar ->
          Some (_first_of_month last_bar.date, last_bar.adjusted_close))

(* Convert the Shiller observation list into a Date-keyed map; the period
   field is already first-of-month so it can serve directly as the join
   key. Duplicates in the input would be a parser bug; we keep the last
   one if encountered. *)
let _shiller_by_period (shiller : Client.monthly_observation list) :
    float Date.Map.t =
  List.fold shiller ~init:Date.Map.empty ~f:(fun acc o ->
      Map.set acc ~key:o.period ~data:o.sp_price)

let _rel_diff ~eodhd ~shiller =
  if Float.equal shiller 0.0 then 0.0 else (eodhd -. shiller) /. shiller

let build_drift_rows ~(shiller : Client.monthly_observation list)
    ~(eodhd_monthly : (Date.t * float) list) : drift_row list =
  let shiller_map = _shiller_by_period shiller in
  List.filter_map eodhd_monthly ~f:(fun (period, eodhd_adj) ->
      match Map.find shiller_map period with
      | None -> None
      | Some shiller_price ->
          Some
            {
              period;
              shiller_sp_price = shiller_price;
              eodhd_monthly_adj_close = eodhd_adj;
              rel_diff = _rel_diff ~eodhd:eodhd_adj ~shiller:shiller_price;
            })

let _abs_rel rows = List.map rows ~f:(fun r -> Float.abs r.rel_diff)

let _mean xs =
  match xs with
  | [] -> 0.0
  | _ -> List.sum (module Float) xs ~f:Fn.id /. Float.of_int (List.length xs)

(* Population stdev — matches what a Markdown summary reader expects when
   the report says "across all compared months". Falls back to 0.0 with a
   single sample to avoid a divide-by-zero. *)
let _stdev xs =
  match xs with
  | [] | [ _ ] -> 0.0
  | _ ->
      let m = _mean xs in
      let n = Float.of_int (List.length xs) in
      let sq_sum =
        List.sum (module Float) xs ~f:(fun x -> Float.square (x -. m))
      in
      Float.sqrt (sq_sum /. n)

let compute_stats ~threshold (rows : drift_row list) : stats =
  let abs_diffs = _abs_rel rows in
  let n_flagged =
    List.count rows ~f:(fun r -> Float.(abs r.rel_diff > threshold))
  in
  {
    n_compared = List.length rows;
    n_flagged;
    mean_abs_rel_diff = _mean abs_diffs;
    stdev_abs_rel_diff = _stdev abs_diffs;
    max_abs_rel_diff =
      List.fold abs_diffs ~init:0.0 ~f:(fun acc x -> Float.max acc x);
  }

let _first_period rows = Option.map (List.hd rows) ~f:(fun r -> r.period)
let _last_period rows = Option.map (List.last rows) ~f:(fun r -> r.period)

(* Top-N drift months by absolute relative diff, descending. We sort a
   shallow copy of the rows; the canonical [rows] list stays in ascending
   date order. *)
let _top_drift ~top_n rows =
  List.sort rows ~compare:(fun a b ->
      Float.compare (Float.abs b.rel_diff) (Float.abs a.rel_diff))
  |> fun sorted -> List.take sorted top_n

let build_report ~(shiller : Client.monthly_observation list)
    ~(eodhd_monthly : (Date.t * float) list) ~(threshold : float) ~(top_n : int)
    : report =
  let rows = build_drift_rows ~shiller ~eodhd_monthly in
  {
    threshold;
    overlap_first = _first_period rows;
    overlap_last = _last_period rows;
    stats = compute_stats ~threshold rows;
    rows;
    top_drift = _top_drift ~top_n rows;
  }

let _format_date_opt = function None -> "n/a" | Some d -> Date.to_string d
let _format_pct f = Printf.sprintf "%.4f%%" (f *. 100.0)

let _format_signed_pct f =
  let sign = if Float.(f >= 0.0) then "+" else "" in
  Printf.sprintf "%s%.4f%%" sign (f *. 100.0)

let _format_drift_row (r : drift_row) =
  Printf.sprintf "| %s | %.4f | %.4f | %s |" (Date.to_string r.period)
    r.shiller_sp_price r.eodhd_monthly_adj_close
    (_format_signed_pct r.rel_diff)

let _summary_section (r : report) =
  [
    "## Summary";
    "";
    Printf.sprintf "- Overlap window: **%s** through **%s**"
      (_format_date_opt r.overlap_first)
      (_format_date_opt r.overlap_last);
    Printf.sprintf "- Months compared: **%d**" r.stats.n_compared;
    Printf.sprintf "- Flag threshold: **%s**" (_format_pct r.threshold);
    Printf.sprintf "- Months flagged (|rel_diff| > threshold): **%d**"
      r.stats.n_flagged;
    Printf.sprintf "- Mean |rel_diff|: **%s**"
      (_format_pct r.stats.mean_abs_rel_diff);
    Printf.sprintf "- Stdev |rel_diff|: **%s**"
      (_format_pct r.stats.stdev_abs_rel_diff);
    Printf.sprintf "- Max |rel_diff|: **%s**"
      (_format_pct r.stats.max_abs_rel_diff);
  ]

let _top_section (r : report) =
  let header =
    [
      "";
      Printf.sprintf "## Top %d drift months (by |rel_diff|)"
        (List.length r.top_drift);
      "";
      "| Period | Shiller SP | EODHD monthly adj_close | rel_diff |";
      "|---|---|---|---|";
    ]
  in
  let body =
    match r.top_drift with
    | [] -> [ "| _no overlap_ | | | |" ]
    | _ -> List.map r.top_drift ~f:_format_drift_row
  in
  header @ body

let _alignment_caveat =
  [
    "";
    "## Alignment caveat";
    "";
    "Shiller's monthly price is the **monthly average of daily closing prices**";
    "(per Shiller's `ie_data` documentation). This validator pairs each Shiller";
    "month with the **last trading day** of that calendar month in the EODHD \
     cache.";
    "The two definitions diverge by 5-20% in high-volatility months (e.g. \
     1929-1940,";
    "1987-10, 2008-09, 2020-02) even when both sources are internally \
     consistent.";
    "";
    "What to look for:";
    "- **Recent months** with monotone drift → vendor split/dividend revision \
     (real signal).";
    "- **Large bidirectional drift in volatile historical months** → \
     average-vs-month-end";
    "  mismatch (structural, not a bug).";
  ]

let format_markdown_report (r : report) : string =
  let header = [ "# Shiller → EODHD adjusted-close cross-validation"; "" ] in
  let lines =
    header @ _summary_section r @ _top_section r @ _alignment_caveat @ [ "" ]
  in
  String.concat ~sep:"\n" lines

(* ---- derived-CSV parser (consumes fetch_shiller_history.exe output) ---- *)

let _expected_derived_header = "period,sp_price,dividend,earnings,cpi,long_rate"
let _expected_derived_column_count = 6

let _parse_optional_float ~column raw =
  let trimmed = String.strip raw in
  if String.is_empty trimmed then Ok None
  else
    match Float.of_string trimmed with
    | f -> Ok (Some f)
    | exception _ ->
        Status.error_invalid_argument
          (Printf.sprintf "shiller_validator: unparseable %s value %S" column
             trimmed)

let _parse_derived_row line_num raw_line :
    Client.monthly_observation Status.status_or =
  let open Result.Let_syntax in
  let fields = String.split raw_line ~on:',' in
  if List.length fields <> _expected_derived_column_count then
    Status.error_invalid_argument
      (Printf.sprintf "shiller_validator: line %d has %d columns (expected %d)"
         line_num (List.length fields) _expected_derived_column_count)
  else
    match fields with
    | [ date_s; price_s; div_s; earn_s; cpi_s; rate_s ] ->
        let%bind period =
          match Date.of_string date_s with
          | d -> Ok d
          | exception _ ->
              Status.error_invalid_argument
                (Printf.sprintf "shiller_validator: line %d: bad date %S"
                   line_num date_s)
        in
        let%bind sp_price =
          match Float.of_string (String.strip price_s) with
          | f -> Ok f
          | exception _ ->
              Status.error_invalid_argument
                (Printf.sprintf "shiller_validator: line %d: bad price %S"
                   line_num price_s)
        in
        let%bind dividend = _parse_optional_float ~column:"dividend" div_s in
        let%bind earnings = _parse_optional_float ~column:"earnings" earn_s in
        let%bind cpi = _parse_optional_float ~column:"cpi" cpi_s in
        let%bind long_rate = _parse_optional_float ~column:"long_rate" rate_s in
        Ok { Client.period; sp_price; dividend; earnings; cpi; long_rate }
    | _ ->
        Status.error_internal
          (Printf.sprintf
             "shiller_validator: unreachable destructure on line %d" line_num)

let parse_shiller_derived_csv body :
    Client.monthly_observation list Status.status_or =
  let lines =
    String.split_lines body
    |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))
  in
  match lines with
  | [] -> Status.error_invalid_argument "shiller_validator: empty CSV body"
  | header :: data_lines ->
      if not (String.equal (String.strip header) _expected_derived_header) then
        Status.error_invalid_argument
          (Printf.sprintf
             "shiller_validator: header drift — expected %S, got %S"
             _expected_derived_header header)
      else
        List.mapi data_lines ~f:(fun i line -> _parse_derived_row (i + 2) line)
        |> Result.all
