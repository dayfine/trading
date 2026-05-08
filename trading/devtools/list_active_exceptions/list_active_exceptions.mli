(** List active linter exceptions from two sources: 1.
    [trading/devtools/checks/linter_exceptions.conf] — explicit exception rows.
    2. All [*.ml] files under the trading root — scanned for [@large-module] and
    [@large-function] marker comments.

    Output is a markdown table on stdout, suitable for auditing active escape
    hatches.

    Usage: list_active_exceptions <trading-root>

    [status] values:
    - [active] — exception is present; review_at date/milestone not yet reached.
    - [expired] — review_at date (YYYY-MM-DD) is in the past.
    - [no-review-at] — marker is missing a [review_at:] annotation.

    Exits 0 always — this is a passive reporting tool, not a hard gate. *)
