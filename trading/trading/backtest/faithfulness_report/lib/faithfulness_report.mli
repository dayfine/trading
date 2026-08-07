(** Faithfulness / sensibility profiling of backtest trade logs.

    Systematizes the trade-by-trade evaluation from the 2026-08-07 fill-model
    deep dive (dev/notes/fill-model-fix-findings-2026-08-07.md): rather than
    judging a run by its topline return alone, profile HOW it trades — the
    whipsaw rate, hold-time distribution, stop-width distribution, and, given a
    second run, the per-year and per-symbol P&L divergence between the two arms.
    Pure functions over parsed [trades.csv] rows; testable without files.

    See dev/plans/fill-model-faithfulness-2026-08-07.md (workstream B). *)

type trade = {
  symbol : string;
  entry_year : int;
  days_held : int;
  pnl : float;
  stop_dist : float option;  (** [stop_initial_distance_pct] if present. *)
}

val parse_trades : string -> trade list
(** Parse a [trades.csv] at the given path; malformed rows are dropped. *)

(** {1 Single-arm sensibility profile} *)

type year_stat = {
  year : int;
  n : int;
  pnl : float;
  n_whipsaw : int;  (** entries with [days_held <= whipsaw_days]. *)
  n_runner : int;  (** entries with [days_held >= hold_ge]. *)
  avg_days : float;
}

val profile_by_year :
  trade list -> whipsaw_days:int -> hold_ge:int -> year_stat list
(** Per-entry-year counts, P&L, whipsaw / runner counts, and mean hold. The
    whipsaw rate (fraction stopped within [whipsaw_days]) is the fill-model
    signature: a tight-stop arm whipsaws 40-60%, a deep-stop arm 0-16%. *)

type stop_summary = { n : int; n_over : int; mean : float; max : float }

val stop_width_summary : trade list -> gt:float -> stop_summary
(** Distribution of [stop_initial_distance_pct]: how many entries carry a stop
    wider than [gt] (e.g. the strategy's 15% gate), plus mean and max. *)

(** {1 Two-arm divergence} *)

type year_div = {
  year : int;
  a_n : int;
  a_pnl : float;
  b_n : int;
  b_pnl : float;
}

val divergence_by_year : a:trade list -> b:trade list -> year_div list
(** Per-entry-year trade count and P&L for both arms, over the union of years.
*)

type sym_div = { symbol : string; a_pnl : float; b_pnl : float; delta : float }

val top_symbol_divergences :
  a:trade list -> b:trade list -> k:int -> sym_div list
(** The [k] symbols with the largest [|a_pnl - b_pnl|] — where the two arms most
    disagree on the same name (the AXTI / BFX / CFFN signature). *)

(** {1 Rendering} *)

val render_profile :
  label:string ->
  whipsaw_days:int ->
  hold_ge:int ->
  stop_gt:float ->
  year_stat list ->
  stop_summary ->
  string

val render_divergence :
  a_label:string -> b_label:string -> year_div list -> sym_div list -> string

val run :
  ?b_path:string ->
  ?a_label:string ->
  ?b_label:string ->
  ?whipsaw_days:int ->
  ?hold_ge:int ->
  ?stop_gt:float ->
  ?top_k:int ->
  a_path:string ->
  unit ->
  string
(** Read [a_path]'s [trades.csv] and render its single-arm profile; when
    [b_path] is given, also render the two-arm divergence. Returns the Markdown
    report. *)
