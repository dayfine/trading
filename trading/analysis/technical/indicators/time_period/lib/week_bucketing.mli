open Core

(** Generic ISO-week bucketing for date-stamped data.

    {!bucket_weekly} groups a chronologically ascending list of items into one
    bucket per ISO week, then collapses each bucket via a caller-supplied
    aggregator. It exists so that domain-specific cadence converters (price
    bars, A-D breadth bars, ...) can share the same week-boundary logic and
    chronological-ordering invariants without duplicating the fold.

    Two items are considered to be in the same week iff they agree on both
    {!Date.week_number} and {!Date.year} (so the ISO week number, scoped by
    year, is the bucket key). The first and last week of the input may be
    partial — both are emitted.

    All functions are pure. *)

val bucket_weekly :
  get_date:('a -> Date.t) -> aggregate:('a list -> 'a) -> 'a list -> 'a list
(** [bucket_weekly ~get_date ~aggregate items] groups [items] by ISO week and
    collapses each week into a single item.

    [get_date] extracts the date used for bucketing. [aggregate] receives the
    items belonging to one week in {b reverse chronological order} (most recent
    first) and is guaranteed to be called with a non-empty list. The result of
    [aggregate] is what appears in the output for that week.

    The output preserves chronological order: bucket [k] comes before bucket
    [k+1] iff the items in [k] are dated earlier than the items in [k+1].

    Partial head and tail weeks are emitted (i.e. a week with only Wed-Fri at
    the start, or only Mon-Wed at the end, still produces one bucket). Empty
    input produces empty output.

    @raise Invalid_argument
      if [items] is not strictly chronologically ascending (duplicate dates are
      also rejected). *)
