(** What the validator learns about the {b run's strategy config} from the run
    directory, so a check whose severity depends on a config knob can read it
    instead of guessing.

    The only source is the run's [params.sexp] (written beside [trades.csv] by
    [Backtest.Result_writer]), whose [overrides] field holds the partial-config
    overlays the runner deep-merged into its base config, in order. Today one
    knob is read: [entry_ticket_macro_suspend] (#2976), for V23. *)

val macro_suspend_of_params :
  Sexplib.Sexp.t -> Weinstein_strategy.Entry_ticket_suspend_mode.t option
(** The effective [entry_ticket_macro_suspend] of a parsed [params.sexp]:

    - the value of the {b last} overlay in [overrides] that sets the top-level
      field — the runner merges overlays left to right, so a later one wins;
    - the strategy's own default ([Weinstein_strategy.default_config]) when no
      overlay sets it, or [params.sexp] has no [overrides] at all;
    - [None] when the last overlay's value is not a valid mode — an unreadable
      config is reported as unknown, never guessed. *)

val load_macro_suspend :
  string -> Weinstein_strategy.Entry_ticket_suspend_mode.t option
(** [load_macro_suspend path] is {!macro_suspend_of_params} of the file at
    [path]; [None] when no file exists there or it is not a readable sexp. *)
