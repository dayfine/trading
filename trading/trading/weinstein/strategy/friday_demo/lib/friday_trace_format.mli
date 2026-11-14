(** Shared text helpers for the Friday trace printer. *)

val pct : float -> string
(** [pct 0.153] is ["15.3%"]. *)

val signed_pct : float -> string
(** [signed_pct 0.0071] is ["+0.71%"]. *)

val money : float -> string
(** [money 1234.5] is ["$1,234.50"]. *)

val opt : ('a -> string) -> 'a option -> string
(** [opt f x] is [f v] for [Some v], ["-"] for [None]. *)

val unqualified : string -> string
(** Drop the module path a derived [show] puts in front of a constructor:
    ["Weinstein_types.Bullish"] becomes ["Bullish"]. *)

val stage_name : Weinstein_types.stage -> string
(** ["Stage 2 (wk 3)"], with [late] spelled out for a late Stage 2. *)

val stage_number : Weinstein_types.stage -> int
(** The stage's number, 1 to 4. *)

val side_name : Trading_base.Types.position_side -> string
(** ["long"] or ["short"]. *)

val header :
  Buffer.t ->
  n:int ->
  title:string ->
  does:string list ->
  input:string ->
  output:string ->
  unit
(** Print a stage's banner and its "Does / In / Out" lines. *)

val row : Buffer.t -> ('a, unit, string, unit) format4 -> 'a
(** Print one indented table row. *)
