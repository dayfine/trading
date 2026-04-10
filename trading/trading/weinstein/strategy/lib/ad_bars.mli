(** Loader for NYSE advance/decline breadth data.

    Reads two CSV files — [nyse_advn.csv] and [nyse_decln.csv] — from
    [data_dir/breadth/], joins them on date, and returns a list of
    {!Macro.ad_bar} records sorted chronologically oldest-first.

    The CSV format is two columns, [YYYYMMDD,count], one row per NYSE trading
    day. The upstream source (unicorn.us.com) pads the tail of the file with
    [count=0] placeholder rows for dates where no fresh data was published; rows
    where {i both} advancing and declining are zero are filtered out.

    Missing files degrade gracefully to [[]] so that callers can treat this as
    an optional macro input (see {!Macro.analyze}'s [~ad_bars] argument). *)

val load : data_dir:string -> Macro.ad_bar list
(** [load ~data_dir] reads [data_dir/breadth/nyse_advn.csv] and
    [data_dir/breadth/nyse_decln.csv], joins them on date, filters out
    placeholder rows where both counts are zero, and returns the joined records
    sorted by date ascending.

    Returns [[]] if either CSV file is missing or unreadable. Malformed rows
    within a file are skipped silently. *)
