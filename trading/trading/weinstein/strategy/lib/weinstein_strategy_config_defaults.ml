(* Named no-op / promoted defaults for [Weinstein_strategy_config.config].
   Split out of [weinstein_strategy_config.ml] (file-length cap) and
   [include]d back there, so the [@sexp.default] attributes and the
   [default_config] literal keep reading one source of truth each. *)

(* No-op default for [macro_bearish_max_long_exposure_pct]: equals the normal
   long-exposure cap, so the trim never bites until a spec sets a tighter value. *)
let macro_bearish_no_op_cap = 0.70

(* No-op default for [fast_v_min_rate_pct]: equals [Decline_character]'s own
   [default_config.fast_v_min_rate_pct], so classification is bit-identical
   until a spec sets a different fast-V arming rate threshold. *)
let fast_v_min_rate_no_op = 0.08

(* Default bar-gap (calendar days) after which [stale_exit_after_days] force-
   sells a stale/delisted held position at its last close. Flipped None ->
   Some 5 on 2026-07-10 (user mandate) as a REALISM/faithfulness basis change:
   the simulator must not hold ghosts (IN1 marked at its 2005 close for 20 years
   inside NAV; 5 zombie positions in the deep run — issue #1484 / flag #1487). *)
let default_stale_exit_days = 5

(* Grid-robust continuous overhead-supply ranking weight, armed into the default
   screening weights by the 2026-07-23 bundle promotion (user-approved, R3).
   w=30 was robust across the 3-cell confirmation grid (ledger
   [2026-07-17-resistance-supply-confirmation-grid]) and the bundle studies
   (ledger [2026-07-20-bundle-promotion-studies]); it replaces the binary
   virgin/clean grade points when the continuous supply score is present. *)
let bundle_w_overhead_supply = 30

(* Default lagging dawn-label window (weeks) for [dawn_max_ma_flip_age_weeks]:
   78 weeks ~= 1.5y per the P1b memo
   ([dev/notes/regime-dependency-evaluation-2026-07-24.md]). Named so the sexp
   default and the [default_config] literal share one source of truth. *)
let default_dawn_max_flip_age_weeks = 78

(* Default do-not-chase cap (percentage points) for [entry_extension_max_pct]:
   2.0, the value live arms in [dev/weekly-picks/live-config-overrides.sexp]
   (user decision 2026-08-25, issue #2404) and the staged record-convention
   specs' corpus value; one source for the sexp default and [default_config]. *)
let default_entry_extension_max_pct = 2.0
