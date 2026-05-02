(** Per-day weekly aggregation for the Phase B snapshot pipeline.

    The Phase B writer needs, for each daily bar [bars[i]], the list that
    [Time_period.Conversion.daily_to_weekly ~include_partial_week:true
     bars[0..i]] would return. The prior pipeline rebuilt this list per-day via
    a fresh [daily_to_weekly] call (O(i) per call, O(N^2) per symbol). This
    module walks the daily series once and exposes the same prefix as a compact
    pair of [(finalized_count, partial_week_bar)] per daily index, sharing the
    [finalized] array across all indices.

    Bit-identity: the aggregation primitives are copied verbatim from
    [Time_period.Conversion._aggregate_week] / [Time_period.Week_bucketing] so
    the produced bars are identical to a fresh [daily_to_weekly] call.
    Out-of-order input still raises [Invalid_argument] with the same message. *)

type t = {
  finalized : Types.Daily_price.t array;
      (** All weeks that are complete by the end of [bars]. Chronological
          oldest-first. *)
  partial_per_day : Types.Daily_price.t array;
      (** [partial_per_day.(i)] is the partial-week aggregate of all daily bars
          in the same ISO week as [bars.(i)] up to and including day [i]. *)
  finalized_count_at_day : int array;
      (** [finalized_count_at_day.(i)] is the number of [finalized] entries
          chronologically before the week containing [bars.(i)]. The per-day
          weekly prefix is therefore
          [finalized.[0..finalized_count_at_day.(i) - 1] @
           [partial_per_day.(i)]]. *)
}
(** Compact representation of every per-day weekly prefix. The arrays are
    aligned to [bars.(i)] and share their backing storage across all days —
    there is no per-day list allocation in the tightest path. *)

val build : Types.Daily_price.t array -> t
(** [build bars_arr] computes the weekly aggregation in a single forward pass.

    @raise Invalid_argument
      if [bars_arr] is not strictly chronologically ordered (matches
      [Time_period.Week_bucketing]'s ordering check). *)

val window_for_day :
  t -> day_idx:int -> lookback:int -> Types.Daily_price.t list
(** [window_for_day t ~day_idx ~lookback] returns the chronological-oldest-first
    list of at most [lookback] weekly bars ending at the partial-week bar for
    daily index [day_idx]. Equal to taking the last [lookback] elements of the
    per-day prefix list. *)
