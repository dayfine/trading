open Types

val daily_to_weekly :
  ?weekdays_only:bool ->
  ?include_partial_week:bool ->
  Daily_price.t list ->
  Daily_price.t list
(** Convert daily data to weekly by taking the last entry of each week.

    @param weekdays_only
      If true, fails if weekend dates are present (default: false)
    @param include_partial_week
      If true, includes incomplete weeks at the end (default: true for backward compatibility).
      Set to false to only return complete weeks ending on Friday.
      Use true for provisional values (intra-week computation).
    @param data List of data points with dates in chronological order
    @raise Invalid_argument if data is not sorted chronologically
    @raise Invalid_argument
      if weekdays_only is true and weekend dates are present

    Examples:
    - [Mon, Tue, Wed] with include_partial_week=true → [Wed] (provisional)
    - [Mon, Tue, Wed] with include_partial_week=false → [] (no complete week)
    - [Mon-Fri, Mon-Wed] with include_partial_week=true → [Fri, Wed]
    - [Mon-Fri, Mon-Wed] with include_partial_week=false → [Fri] (only complete week)
*)
