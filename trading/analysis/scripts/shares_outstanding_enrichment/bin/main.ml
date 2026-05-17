(** Bulk-enrich equity-like inventory symbols with shares-outstanding sourced
    from EODHD's [/api/fundamentals/{symbol}] endpoint.

    Reads [inventory.sexp] (one entry per cached symbol) and [symbol_types.sexp]
    (Q1 PR2 artifact), filters the inventory to equity-like instruments
    (Common_stock / Preferred_stock / ADR / GDR), calls EODHD fundamentals for
    each, and writes [shares_outstanding.sexp].

    Typical usage:
    {v
      shares_outstanding_enrichment.exe \
        --inventory-path  data/inventory.sexp \
        --symbol-types-path data/symbol_types.sexp \
        --output-path     data/shares_outstanding.sexp \
        --secrets-path    trading/analysis/data/sources/eodhd/secrets \
        --sleep-ms        200
    v}

    Token tier: the [/api/fundamentals/] endpoint requires an EODHD plan with
    the "Fundamentals API" add-on. Tokens without this add-on return HTTP 403
    even though [/api/eod] continues to work. When the run hits 403s for the
    first few symbols, it aborts early (no point burning the API quota on locked
    endpoints). *)

open Core
open Async

(* Per-call sleep between fetches. Even at the paid-plan rate limit
   (1200 req/min), a 200ms gap keeps us comfortably under the cap while
   leaving headroom for the bursty filter / parsing work inside [get_fundamentals]. *)
let _default_sleep_ms = 200
let _default_secrets_path = "trading/analysis/data/sources/eodhd/secrets"

(* Abort after this many consecutive auth failures — treat as token-tier
   gating, not transient. *)
let _max_consecutive_auth_failures = 5

let _read_token ~secrets_path =
  try Ok (In_channel.read_all secrets_path |> String.strip)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read secrets %s: %s" secrets_path msg)

let _load_inventory ~inventory_path =
  let path = Fpath.v inventory_path in
  File_sexp.Sexp.load
    (module struct
      type t = Inventory.t

      let sexp_of_t = Inventory.sexp_of_t
      let t_of_sexp = Inventory.t_of_sexp
    end)
    ~path

let _load_symbol_types ~symbol_types_path =
  Asset_type_enrichment_lib.load ~path:(Fpath.v symbol_types_path)

(* ---- Per-symbol fetch + classification ---- *)

(* The fetch result classes:
   - Got the data (possibly with shares = 0.0; downstream filters that out)
   - Auth-level failure: 403 from a gated tier — increments the auth-failure
     counter and may abort the run.
   - Other transient / not-found error: log + continue, do not abort. *)
type fetch_outcome =
  | Fetched of Eodhd.Fundamentals_endpoint.fundamentals
  | Auth_failed of string
  | Other_failed of string

let _is_auth_error_message msg =
  let lower = String.lowercase msg in
  String.is_substring lower ~substring:"403"
  || String.is_substring lower ~substring:"forbidden"

let _fetch_one ~token symbol =
  Eodhd.Fundamentals_endpoint.get_fundamentals ~token ~symbol () >>| function
  | Ok f -> Fetched f
  | Error status ->
      let msg = Status.show status in
      if _is_auth_error_message msg then Auth_failed msg else Other_failed msg

(* ---- Progress accumulator ---- *)

type progress = {
  attempted : int;
  fetched : int;
  with_positive_shares : int;
  consecutive_auth_failures : int;
  recent_fundamentals : Eodhd.Fundamentals_endpoint.fundamentals list;
      (* Accumulated in REVERSE order; reversed once at end of run. *)
}

let _initial_progress =
  {
    attempted = 0;
    fetched = 0;
    with_positive_shares = 0;
    consecutive_auth_failures = 0;
    recent_fundamentals = [];
  }

(* Single step: increment [attempted] and route per outcome. Inlined so the
   fetch loop body reads top-to-bottom without indirection. *)
let _step_progress progress outcome =
  let base = { progress with attempted = progress.attempted + 1 } in
  match outcome with
  | Fetched f ->
      let positive =
        Float.(f.Eodhd.Fundamentals_endpoint.shares_outstanding > 0.0)
      in
      {
        base with
        fetched = base.fetched + 1;
        with_positive_shares =
          (base.with_positive_shares + if positive then 1 else 0);
        consecutive_auth_failures = 0;
        recent_fundamentals = f :: base.recent_fundamentals;
      }
  | Auth_failed _ ->
      {
        base with
        consecutive_auth_failures = base.consecutive_auth_failures + 1;
      }
  | Other_failed _ -> { base with consecutive_auth_failures = 0 }

(* ---- Main fetch loop ---- *)

let _log_progress progress symbol = function
  | Fetched f ->
      Core.printf "[%d] %s -> %.0f shares\n%!" progress.attempted symbol
        f.Eodhd.Fundamentals_endpoint.shares_outstanding
  | Auth_failed msg ->
      Core.printf "[%d] %s -> AUTH FAIL: %s\n%!" progress.attempted symbol msg
  | Other_failed msg ->
      Core.printf "[%d] %s -> ERROR: %s\n%!" progress.attempted symbol msg

let _sleep_seconds ~sleep_ms =
  Clock.after (Time_float.Span.of_sec (float_of_int sleep_ms /. 1_000.0))

(* True if we've hit the auth-failure threshold and should abort the run. *)
let _should_abort progress =
  progress.consecutive_auth_failures >= _max_consecutive_auth_failures

let _log_abort progress =
  Core.printf
    "Aborting: %d consecutive auth failures (token likely lacks Fundamentals \
     API access).\n\
     %!"
    progress.consecutive_auth_failures

(* Fetch a single symbol, update the progress accumulator, and log. Returns
   the updated progress; the caller decides whether to continue. *)
let _process_symbol ~token ~progress symbol =
  _fetch_one ~token symbol >>| fun outcome ->
  let progress' = _step_progress progress outcome in
  _log_progress progress' symbol outcome;
  progress'

(* Walks the symbol list, fetching one at a time with [sleep_ms] in between.
   Bails out on [_max_consecutive_auth_failures] sequential auth errors —
   continuing past that point only burns API quota on a locked endpoint. *)
let rec _fetch_loop ~token ~sleep_ms ~progress = function
  | [] -> return progress
  | symbol :: rest ->
      _process_symbol ~token ~progress symbol >>= fun progress' ->
      if _should_abort progress' then (
        _log_abort progress';
        return progress')
      else
        _sleep_seconds ~sleep_ms >>= fun () ->
        _fetch_loop ~token ~sleep_ms ~progress:progress' rest

let _equity_like_inventory ~inventory ~symbol_types =
  let inventory_symbols =
    List.map inventory.Inventory.symbols ~f:(fun e -> e.Inventory.symbol)
  in
  Asset_type_enrichment_lib.filter_equity_like_symbols ~symbol_types
    ~symbols:inventory_symbols

let _print_summary progress =
  Core.printf "\n---- Summary ----\n";
  Core.printf "Attempted:               %d\n" progress.attempted;
  Core.printf "Fetched successfully:    %d\n" progress.fetched;
  Core.printf "With shares > 0:         %d\n" progress.with_positive_shares;
  Core.printf "Consecutive auth fails:  %d\n%!"
    progress.consecutive_auth_failures

(* ---- Composition + writeout ---- *)

let _build_and_save ~output_path ~progress =
  let today = Date.today ~zone:Time_float.Zone.utc in
  let fundamentals = List.rev progress.recent_fundamentals in
  let enriched =
    Shares_outstanding_enrichment_lib.join ~fundamentals ~generated_at:today
      ~source_endpoints:
        [ ("/api/fundamentals/{symbol}?filter=General,SharesStats", today) ]
  in
  Shares_outstanding_enrichment_lib.save enriched ~path:(Fpath.v output_path)

let _run ~inventory_path ~symbol_types_path ~output_path ~secrets_path ~sleep_ms
    =
  let open Deferred.Result.Let_syntax in
  let%bind token = _read_token ~secrets_path |> Deferred.return in
  let%bind inventory = _load_inventory ~inventory_path |> Deferred.return in
  let%bind symbol_types =
    _load_symbol_types ~symbol_types_path |> Deferred.return
  in
  let equity_like = _equity_like_inventory ~inventory ~symbol_types in
  Core.printf "Inventory: %d symbols. Equity-like (post-filter): %d.\n%!"
    (List.length inventory.Inventory.symbols)
    (List.length equity_like);
  let%bind progress =
    _fetch_loop ~token ~sleep_ms ~progress:_initial_progress equity_like
    |> Deferred.map ~f:Result.return
  in
  _print_summary progress;
  let%bind () = _build_and_save ~output_path ~progress |> Deferred.return in
  Core.printf "Wrote %s\n%!" output_path;
  Deferred.Result.return ()

let _main ~inventory_path ~symbol_types_path ~output_path ~secrets_path
    ~sleep_ms () =
  _run ~inventory_path ~symbol_types_path ~output_path ~secrets_path ~sleep_ms
  >>= function
  | Ok () -> return ()
  | Error e ->
      Core.eprintf "Error: %s\n" (Status.show e);
      exit 1

let command =
  Command.async
    ~summary:
      "Bulk-enrich equity-like inventory symbols with EODHD shares-outstanding \
       (Q2-A PR1 of custom-universe-bidirectional)"
    (let%map_open.Command inventory_path =
       flag "inventory-path" (required string)
         ~doc:"PATH Path to inventory.sexp"
     and symbol_types_path =
       flag "symbol-types-path" (required string)
         ~doc:"PATH Path to symbol_types.sexp (Q1 PR2 output)"
     and output_path =
       flag "output-path" (required string)
         ~doc:"PATH Where to write shares_outstanding.sexp"
     and secrets_path =
       flag "secrets-path"
         (optional_with_default _default_secrets_path string)
         ~doc:"PATH EODHD API token file (default: repo-local secrets)"
     and sleep_ms =
       flag "sleep-ms"
         (optional_with_default _default_sleep_ms int)
         ~doc:"MS Sleep between per-symbol fetches (default: 200ms)"
     in
     _main ~inventory_path ~symbol_types_path ~output_path ~secrets_path
       ~sleep_ms)

let () = Command_unix.run command
