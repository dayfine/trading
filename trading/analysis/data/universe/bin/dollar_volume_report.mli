(** Aggregates {!Dollar_volume_scan} results into the issue #3136 measurement
    tables and renders them as Markdown.

    Three lists are compared per reconstitution year and size:
    - [C], the committed PIT list ([top-<N>-<year>.sexp]);
    - [L], the same ranking rebuilt from the current store on the stored
      [close * volume] basis (isolates store drift since [C] was built);
    - [T], the ranking on the true-dollar basis.

    [L] vs [T] isolates the basis change; [C] vs [T] is what a rebuild would
    move relative to what backtests read today. *)

open Core

type mover = {
  symbol : string;
  legacy_rank : int option;  (** Rank on the stored basis; [None]: unscored. *)
  true_rank : int option;  (** Rank on the true basis; [None]: unscored. *)
  ratio : float option;  (** True score over stored score. *)
  splits : Corporate_actions.split list;  (** Applied splits after the date. *)
}
(** One symbol entering or leaving the true-basis list. *)

type row = {
  year : int;
  size : int;
  committed : int;  (** [|C|]; [0] when no committed list exists. *)
  entered : mover list;  (** [T \ L], largest true/stored ratio first. *)
  left : mover list;  (** [L \ T], smallest ratio first. *)
  committed_out : int;  (** [|C \ T|]. *)
  drift_out : int;  (** [|C \ L|]: store drift, independent of the basis. *)
  true_top : (string * float) list;  (** Head of [T], for the eye check. *)
}
(** Membership change for one [(year, size)]. *)

val membership_row :
  committed:String.Set.t option ->
  size:int ->
  top_k:int ->
  Dollar_volume_scan.t list ->
  int ->
  row
(** [membership_row ~committed ~size ~top_k scans year] ranks [scans] on both
    bases at [year] (descending score, symbol as tie-break) and diffs the top
    [size]. [true_top] holds the first [top_k] of [T]. *)

val render :
  liquidity_floor:float ->
  rows:row list ->
  movers_size:int ->
  movers_k:int ->
  scans:Dollar_volume_scan.t list ->
  specimens:(string * Date.t * float * float) list ->
  string
(** [render ~liquidity_floor ~rows ~movers_size ~movers_k ~scans ~specimens] is
    the report: store split diagnostics, the specimen check
    [(symbol, date, stored, true)], the headline membership table, the rejected
    bars, the entry-gate flip table (at [liquidity_floor], for the heading), and
    the top [movers_k] movers each way for lists of [movers_size]. *)

val rejected_csv : Dollar_volume_scan.t list -> string
(** [rejected_csv scans] lists every rejected bar as
    [symbol,date,close,volume,true_dollar_volume]. *)
