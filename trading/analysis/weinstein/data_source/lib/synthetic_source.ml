open Async
open Core

type symbol_pattern =
  | Trending of { start_price : float; weekly_gain_pct : float; volume : int }
  | Basing of { base_price : float; noise_pct : float; volume : int }
  | Breakout of {
      base_price : float;
      base_weeks : int;
      weekly_gain_pct : float;
      breakout_volume_mult : float;
      base_volume : int;
    }
  | Declining of { start_price : float; weekly_loss_pct : float; volume : int }
[@@deriving show, eq]

type config = { start_date : Date.t; symbols : (string * symbol_pattern) list }
[@@deriving show, eq]

(* ------------------------------------------------------------------ *)
(* Bar generation constants                                             *)
(* ------------------------------------------------------------------ *)

(* Synthetic bar spread around close price.  Values are intentionally small so
   indicators that use OHLC ranges (e.g. stop checks) behave sensibly in tests
   without inflating volatility. *)
let _bar_open_factor = 0.995
let _bar_high_factor = 1.01
let _bar_low_factor = 0.99

(* Default basing noise for the [Breakout] pattern's pre-breakout phase.
   ±2% oscillation keeps bars well below the breakout price (base × 1.05). *)
let _breakout_basing_noise = 0.02

(* Post-breakout start price relative to the base.  5% above the base ensures
   the first trending bar is clearly above the prior range. *)
let _breakout_start_factor = 1.05

(* ------------------------------------------------------------------ *)
(* Bar generation                                                       *)
(* ------------------------------------------------------------------ *)

let _make_bar date close volume =
  {
    Types.Daily_price.date;
    open_price = close *. _bar_open_factor;
    high_price = close *. _bar_high_factor;
    low_price = close *. _bar_low_factor;
    close_price = close;
    adjusted_close = close;
    volume;
  }

(* @nesting-ok: structural weekend skip — match arms are flat transformations *)

(** Advance one calendar day, skipping weekends. *)
let _next_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat -> Date.add_days d 2
  | Day_of_week.Sun -> Date.add_days d 1
  | _ -> Date.add_days d 1

(** Skip forward to the first weekday on or after [d]. *)
let _first_weekday d =
  match Date.day_of_week d with
  | Day_of_week.Sat -> Date.add_days d 2
  | Day_of_week.Sun -> Date.add_days d 1
  | _ -> d

(** Generate weekday dates as an infinite sequence starting from [start_date]
    (inclusive). *)
let _weekdays_from start_date =
  Sequence.unfold ~init:(_first_weekday start_date) ~f:(fun d ->
      Some (d, _next_weekday d))

let _date_in_range ~(start_date : Date.t option) ~(end_date : Date.t option) d =
  let after_start =
    match start_date with None -> true | Some s -> Date.(d >= s)
  in
  let before_end =
    match end_date with None -> true | Some e -> Date.(d <= e)
  in
  after_start && before_end

let _clamp_dates ~(start_date : Date.t option) ~(end_date : Date.t option)
    (bars : Types.Daily_price.t list) =
  List.filter bars ~f:(fun b ->
      _date_in_range ~start_date ~end_date b.Types.Daily_price.date)

(** Generate [n] bars for [Trending] pattern starting at [start_date]. *)
let _gen_trending ~start_date ~start_price ~weekly_gain_pct ~volume ~n =
  let daily_gain = 1.0 +. (weekly_gain_pct /. 5.0) in
  let seq = Sequence.take (_weekdays_from start_date) n in
  List.rev
    (Sequence.foldi seq ~init:[] ~f:(fun i acc date ->
         let price = start_price *. (daily_gain ** Float.of_int i) in
         _make_bar date price volume :: acc))

let _basing_price base_price noise_pct i =
  let half_range = base_price *. noise_pct in
  let phase = Float.of_int (i mod 10) /. 10.0 in
  let offset = half_range *. Float.sin (phase *. 2.0 *. Float.pi) in
  base_price +. offset

let _gen_basing ~start_date ~base_price ~noise_pct ~volume ~n =
  let seq = Sequence.take (_weekdays_from start_date) n in
  List.rev
    (Sequence.foldi seq ~init:[] ~f:(fun i acc date ->
         let price = _basing_price base_price noise_pct i in
         _make_bar date price volume :: acc))

(** First weekday after the last bar in [bars], or [fallback] if [bars] is
    empty. *)
let _next_start_after bars fallback =
  match List.last bars with
  | Some b -> _next_weekday b.Types.Daily_price.date
  | None -> fallback

(** Apply the breakout volume multiplier to the first bar in [bars]. *)
let _mark_breakout_bar base_volume breakout_volume_mult bars =
  match bars with
  | [] -> []
  | first :: rest ->
      let vol =
        Float.to_int (Float.of_int base_volume *. breakout_volume_mult)
      in
      { first with Types.Daily_price.volume = vol } :: rest

let _gen_breakout ~start_date ~base_price ~base_weeks ~weekly_gain_pct
    ~breakout_volume_mult ~base_volume ~n =
  let base_days = base_weeks * 5 in
  let basing_bars =
    _gen_basing ~start_date ~base_price ~noise_pct:_breakout_basing_noise
      ~volume:base_volume ~n:(min n base_days)
  in
  let remaining = n - List.length basing_bars in
  if remaining <= 0 then basing_bars
  else
    let trending_start = _next_start_after basing_bars start_date in
    let trending_bars =
      _gen_trending ~start_date:trending_start
        ~start_price:(base_price *. _breakout_start_factor)
        ~weekly_gain_pct ~volume:base_volume ~n:remaining
      |> _mark_breakout_bar base_volume breakout_volume_mult
    in
    basing_bars @ trending_bars

let _gen_declining ~start_date ~start_price ~weekly_loss_pct ~volume ~n =
  let daily_loss = 1.0 -. (weekly_loss_pct /. 5.0) in
  let seq = Sequence.take (_weekdays_from start_date) n in
  List.rev
    (Sequence.foldi seq ~init:[] ~f:(fun i acc date ->
         let price = start_price *. (daily_loss ** Float.of_int i) in
         _make_bar date price volume :: acc))

(** Generate bars for one symbol pattern. [end_date] is applied after
    generation. *)
(* @nesting-ok: flat dispatch match — all arms are single function calls to named helpers; no nested control flow *)
let _gen_bars ~(start_date : Date.t) ~(end_date : Date.t option) pattern :
    Types.Daily_price.t list =
  let max_bars = 252 * 3 in
  let raw =
    match pattern with
    | Trending { start_price; weekly_gain_pct; volume } ->
        _gen_trending ~start_date ~start_price ~weekly_gain_pct ~volume
          ~n:max_bars
    | Basing { base_price; noise_pct; volume } ->
        _gen_basing ~start_date ~base_price ~noise_pct ~volume ~n:max_bars
    | Breakout
        {
          base_price;
          base_weeks;
          weekly_gain_pct;
          breakout_volume_mult;
          base_volume;
        } ->
        _gen_breakout ~start_date ~base_price ~base_weeks ~weekly_gain_pct
          ~breakout_volume_mult ~base_volume ~n:max_bars
    | Declining { start_price; weekly_loss_pct; volume } ->
        _gen_declining ~start_date ~start_price ~weekly_loss_pct ~volume
          ~n:max_bars
  in
  _clamp_dates ~start_date:None ~end_date raw

(* ------------------------------------------------------------------ *)
(* DATA_SOURCE implementation helpers                                   *)
(* ------------------------------------------------------------------ *)

let _not_found_error symbol =
  Error
    (Status.not_found_error
       (Printf.sprintf "Synthetic_source: unknown symbol %s" symbol))

let _get_bars_impl symbols_tbl start_date ~(query : Data_source.bar_query) () =
  match Hashtbl.find symbols_tbl query.symbol with
  | None -> return (_not_found_error query.symbol)
  | Some pattern ->
      let bars = _gen_bars ~start_date ~end_date:query.end_date pattern in
      let filtered =
        _clamp_dates ~start_date:query.start_date ~end_date:query.end_date bars
      in
      return (Ok filtered)

let _make_instrument symbol =
  {
    Types.Instrument_info.symbol;
    name = symbol;
    sector = "Synthetic";
    industry = "Synthetic";
    market_cap = 1_000_000_000.0;
    exchange = "SYN";
  }

let _get_universe_impl symbols =
  let instruments =
    List.map symbols ~f:(fun (symbol, _) -> _make_instrument symbol)
  in
  return (Ok instruments)

(* ------------------------------------------------------------------ *)
(* DATA_SOURCE implementation                                           *)
(* ------------------------------------------------------------------ *)

let make config =
  let symbols_tbl = Hashtbl.of_alist_exn (module String) config.symbols in
  let module S = struct
    let get_bars = _get_bars_impl symbols_tbl config.start_date
    let get_universe () = _get_universe_impl config.symbols
  end in
  (module S : Data_source.DATA_SOURCE)
