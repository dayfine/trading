type t = Unix.tm

(** Create a new date *)
val create : year:int -> month:int -> day:int -> t

(** Parse a date string in YYYY-MM-DD format *)
val parse : string -> t

(** Add days to a date *)
val add_days : t -> int -> t

(** Get the year from a date *)
val year : t -> int

(** Get the month from a date *)
val month : t -> int

(** Get the day from a date *)
val day : t -> int

(** Check if two dates are in the same week *)
val is_same_week : t -> t -> bool

(** Convert daily data to weekly by taking the last entry of each week
    @param data List of data points with dates in chronological order
*)
val daily_to_weekly : 'a Types.with_date list -> 'a Types.with_date list
