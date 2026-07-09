open Core
open Types

type exit_reason = Fast_crash | Slow_grind | Absolute_floor
[@@deriving show, eq, sexp]

type state =
  | In_market of { grind_streak : int }
  | Out_of_market of {
      exited_on : exit_reason;
      exit_date : Date.t;
      post_exit_low : float;
    }
[@@deriving show, eq, sexp]

type action = Hold | Exit of exit_reason | Re_enter
[@@deriving show, eq, sexp]

type config = {
  decline_config : Decline_character.config;
  fast_exit_rate_pct : float;
  fast_exit_lookback_bars : int;
  grind_confirm_weeks : int;
  floor_drop_pct : float;
  floor_peak_lookback_bars : int;
  fast_reentry_recover_pct : float;
  slow_reentry_ma_weeks : int;
  slow_reentry_ma_rising_lookback : int;
}
[@@deriving show, eq, sexp]

let default_config =
  {
    decline_config =
      { Decline_character.default_config with fast_v_ignores_ma_filter = true };
    fast_exit_rate_pct = 0.08;
    fast_exit_lookback_bars = 4;
    grind_confirm_weeks = 3;
    floor_drop_pct = 0.20;
    floor_peak_lookback_bars = 52;
    fast_reentry_recover_pct = 0.05;
    slow_reentry_ma_weeks = 30;
    slow_reentry_ma_rising_lookback = 4;
  }

let in_market = In_market { grind_streak = 0 }

(* The most recent index bar, or [None] when there are no bars. *)
let _current_bar (bars : Daily_price.t list) : Daily_price.t option =
  List.last bars

(* Positive drawdown [(reference - now) / reference]; [None] when [reference] is
   non-positive. A helper so callers avoid a nested [else]. *)
let _drawdown_fraction ~(reference : float) ~(now : float) : float option =
  if Float.( <= ) reference 0.0 then None
  else Some ((reference -. now) /. reference)

(* Trailing drawdown [(close[-1-lookback] - close[-1]) / close[-1-lookback]] as a
   positive fraction (negative if the index rose). [None] when there are too few
   bars or the reference close is non-positive. Reads only the last bar and the
   bar [lookback] bars earlier — lookahead-free. *)
let _trailing_drawdown (bars : Daily_price.t list) ~(lookback : int) :
    float option =
  let n = List.length bars in
  if n <= lookback || lookback < 0 then None
  else
    let arr = Array.of_list bars in
    _drawdown_fraction ~reference:arr.(n - 1 - lookback).Daily_price.close_price
      ~now:arr.(n - 1).Daily_price.close_price

(* Highest close over the trailing [lookback] window (current bar inclusive). A
   WINDOWED high that decays as bars scroll out — never a monotonic high-water
   mark (the GME lesson; see the .mli). *)
let _trailing_peak (bars : Daily_price.t list) ~(lookback : int) : float =
  let window = List.drop bars (Int.max 0 (List.length bars - lookback)) in
  List.fold window ~init:0.0 ~f:(fun acc b ->
      Float.max acc b.Daily_price.close_price)

(* Simple mean of [close_price] over the [period] bars ending at [end_idx]
   (inclusive, 0-based into [arr]). [None] when the window does not fit. *)
let _ma_ending (arr : Daily_price.t array) ~(period : int) ~(end_idx : int) :
    float option =
  if period <= 0 || end_idx < 0 || end_idx - period + 1 < 0 then None
  else
    let sum = ref 0.0 in
    for i = end_idx - period + 1 to end_idx do
      sum := !sum +. arr.(i).Daily_price.close_price
    done;
    Some (!sum /. Float.of_int period)

(* T1: a steep short-window drawdown with fast-V character (no A-D breadth lead,
   per {!Decline_character.classify}). *)
let _fast_crash (bars : Daily_price.t list) (character : Decline_character.t)
    ~(config : config) : bool =
  match character with
  | Decline_character.Fast_v ->
      _trailing_drawdown bars ~lookback:config.fast_exit_lookback_bars
      |> Option.exists ~f:(fun dd -> Float.( >= ) dd config.fast_exit_rate_pct)
  | Decline_character.Slow_grind | Decline_character.Not_declining -> false

(* T3: the index close is below [(1 - floor_drop_pct)] times the trailing-window
   high — the catastrophic backstop, keyed to a DECAYING windowed peak. *)
let _floor_breached (bars : Daily_price.t list) ~(config : config)
    ~(now : float) : bool =
  let peak = _trailing_peak bars ~lookback:config.floor_peak_lookback_bars in
  Float.( > ) peak 0.0
  && Float.( < ) now ((1.0 -. config.floor_drop_pct) *. peak)

(* Enter [Out_of_market] on [reason] at [current], seeding [post_exit_low] with
   the exit-bar close. *)
let _exit_to (reason : exit_reason) (current : Daily_price.t) : state =
  Out_of_market
    {
      exited_on = reason;
      exit_date = current.Daily_price.date;
      post_exit_low = current.Daily_price.close_price;
    }

(* The T1/T3 immediate exits (fast-crash, then absolute floor) as a direct
   else-if chain; [None] when neither fires. *)
let _immediate_exit ~(config : config) (character : Decline_character.t)
    (current : Daily_price.t) (index_bars : Daily_price.t list) :
    (state * action) option =
  if _fast_crash index_bars character ~config then
    Some (_exit_to Fast_crash current, Exit Fast_crash)
  else if
    _floor_breached index_bars ~config ~now:current.Daily_price.close_price
  then Some (_exit_to Absolute_floor current, Exit Absolute_floor)
  else None

(* Advance the grind streak (T2): count consecutive [Slow_grind] steps and fire
   the slow-grind exit once [grind_confirm_weeks] is reached, else hold. *)
let _grind_step ~(config : config) ~(grind_streak : int)
    (character : Decline_character.t) (current : Daily_price.t) : state * action
    =
  let streak =
    match character with
    | Decline_character.Slow_grind -> grind_streak + 1
    | Decline_character.Fast_v | Decline_character.Not_declining -> 0
  in
  if streak >= config.grind_confirm_weeks then
    (_exit_to Slow_grind current, Exit Slow_grind)
  else (In_market { grind_streak = streak }, Hold)

(* The [In_market] branch: T1/T3 immediate exits take precedence, else the
   confirmed-slow-grind (T2) / hold decision. *)
let _step_in_market ~(config : config) ~(grind_streak : int)
    ~(ad_macro : Macro.result) ~(index_bars : Daily_price.t list) :
    state * action =
  match _current_bar index_bars with
  | None -> (In_market { grind_streak }, Hold)
  | Some current -> (
      let character =
        Decline_character.classify ~config:config.decline_config ~macro:ad_macro
          ~index_bars
      in
      match _immediate_exit ~config character current index_bars with
      | Some result -> result
      | None -> _grind_step ~config ~grind_streak character current)

(* Weinstein-style slow re-entry: current close above a turning
   [slow_reentry_ma_weeks] MA (its value now above its value
   [slow_reentry_ma_rising_lookback] bars earlier). *)
let _slow_reentry (index_bars : Daily_price.t list) ~(config : config)
    ~(now : float) : bool =
  let arr = Array.of_list index_bars in
  let last = Array.length arr - 1 in
  let ma_now =
    _ma_ending arr ~period:config.slow_reentry_ma_weeks ~end_idx:last
  in
  let ma_prev =
    _ma_ending arr ~period:config.slow_reentry_ma_weeks
      ~end_idx:(last - config.slow_reentry_ma_rising_lookback)
  in
  match (ma_now, ma_prev) with
  | Some ma_now, Some ma_prev ->
      Float.( > ) now ma_now && Float.( > ) ma_now ma_prev
  | _ -> false

(* Re-entry signal, asymmetric by which trigger fired the exit. *)
let _reentry (index_bars : Daily_price.t list) ~(config : config)
    ~(exited_on : exit_reason) ~(low : float) ~(now : float) : bool =
  match exited_on with
  | Fast_crash | Absolute_floor ->
      Float.( >= ) now (low *. (1.0 +. config.fast_reentry_recover_pct))
  | Slow_grind -> _slow_reentry index_bars ~config ~now

(* The [Out_of_market] branch: lower [post_exit_low] to include the current
   close, then re-enter if the (asymmetric) re-entry rule fires. Self-contained —
   never waits on an external macro flip. *)
let _step_out_of_market ~(config : config) ~(exited_on : exit_reason)
    ~(exit_date : Date.t) ~(post_exit_low : float)
    ~(index_bars : Daily_price.t list) : state * action =
  match _current_bar index_bars with
  | None -> (Out_of_market { exited_on; exit_date; post_exit_low }, Hold)
  | Some current ->
      let now = current.Daily_price.close_price in
      let low = Float.min post_exit_low now in
      if _reentry index_bars ~config ~exited_on ~low ~now then
        (in_market, Re_enter)
      else (Out_of_market { exited_on; exit_date; post_exit_low = low }, Hold)

let step ~(config : config) ~(state : state) ~(index_bars : Daily_price.t list)
    ~(ad_macro : Macro.result) : state * action =
  match state with
  | In_market { grind_streak } ->
      _step_in_market ~config ~grind_streak ~ad_macro ~index_bars
  | Out_of_market { exited_on; exit_date; post_exit_low } ->
      _step_out_of_market ~config ~exited_on ~exit_date ~post_exit_low
        ~index_bars
