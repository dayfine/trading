(** Price-free public summary of one weekly snapshot.

    The full weekly record prints closes, entries, stops and order tickets, so
    under the EODHD terms (user decision 2026-11-14) it lives only in the
    private [dayfine/trading-results] repo. This repo keeps one
    [<date>-picks.md] per Friday: the macro reading, the strong and weak
    sectors, and for each candidate list the rank, symbol, grade, score and
    sector. It replaces the perl helper used for the 2026-11 backfill
    ([89a08b1fe/<date>-picks.md]).

    Only {!Weekly_snapshot.t}'s [system_version], [date], [macro],
    [sectors_strong], [sectors_weak], the two candidate lists (symbol, grade,
    score, sector) and the two [*_eligible_beyond_cap] counts are read. Entry,
    stop, sizing, rationale, held positions and warnings are never touched, so
    no price-bearing value can reach the output. *)

val default_config_path : string
(** The overrides file the weekly record is generated with:
    ["dev/weekly-picks/record-config-overrides.sexp"]. *)

val render : ?config_path:string -> Weekly_snapshot.t -> string
(** [render ?config_path snapshot] is the Markdown summary, ending in a newline.

    Layout: a title line, a header paragraph naming the system version and
    [config_path] (default {!default_config_path}), then [## Macro],
    [## Strong sectors], [## Weak sectors],
    [## Long candidates (N, M more eligible beyond the cap)] and
    [## Short candidates (...)]. An empty sector or candidate list prints
    [(none)]. A candidate list is a [| Rank | Symbol | Grade | Score | Sector |]
    table in snapshot order, ranks from 1. Scores print as the sexp prints them
    ([100], [87.5]). The short heading gains
    ["; the rendered report shows the top K"] when the list is longer than
    {!Report_renderer.default_short_display_limit}. A line saying shorts are
    report-only follows the short table when it is non-empty; it describes the
    record config, which sets [enable_short_side false].

    The header says the full record is in the private repo "under the same path"
    and carries no trading-results commit: the summary is written before that
    commit exists. Pure function; no I/O, no exceptions. *)
