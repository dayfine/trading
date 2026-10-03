# trades.csv stop columns vs the stop machine (#3075), 2026-10-03

Diagnosis for issue #3075. Read-only on committed run artifacts; the code fix
that ships with it is reporting-only.

## Where the columns come from

`trades.csv` `entry_stop` / `exit_stop` / `max_stop` / `n_stop_raises` are all
`Backtest.Stop_log.stop_info` fields (`trades_stream.ml` `_stop_fields`,
`trade_context.ml` `_stop_ratchet_columns`). Before this change the log was fed
by three sources only:

1. `record_installed_stop`: the entry-decision audit's `installed_stop`,
   booked at the **decision** (#2974);
2. `UpdateRiskParams` transitions;
3. `record_stop_move`: silent `Entered_tightening` installs.

The stop machine itself lives in the strategy's `stop_states` map. Two things
move it with no transition:

- `Stops_split_runner.adjust` rescales the state of every position in the
  map, **including `Entering` positions whose ticket is still resting**;
- `Stop_move_capture.split_then_update` snapshots after the split on
  purpose, so a split is never reported as a move.

So any split between the decision and the exit leaves the log on the old basis.

## The AAON-wein-951 specimen

| | value |
|---|---|
| decision 2023-03-17 | close 89.33, `suggested_entry` 83.42, `installed_stop` 83.2129 |
| AAON 3:2 split | 2023 (while the ticket rested) |
| machine at fill 2024-02-15 | `stop_before` = 55.4753 = 83.2129 × 2/3 exactly |
| fill | 83.43, against the **unscaled** 83.42 trigger |
| `trades.csv` before | entry 83.21 / max 83.21 / exit 79.18 / 1 raise |
| `trades.csv` after this PR | entry 55.48 / max 79.18 / exit 79.18 / 2 raises |

The 55.475 is not a stale level. It is the decision stop correctly carried
through the split. What did not carry through is the **entry trigger**: the
simulator rescales only held positions (`Split_handler.detect_for_held_positions`),
never a resting order, so a pre-split trigger of 83.42 filled on post-split
prices, about 125 on the decision's basis. The stop then sat 34 % under a fill
that was itself about 40 % above the decided entry. MU-wein-76 is the same
shape: a 2:1 split in 2000, trigger 88.44 unscaled, filled 88.46, machine at
43.69 = 87.375 / 2.

So issue item (1) is real, but its cause is the trigger, not the stop.
Re-deriving the stop at the fill would hide the symptom and still buy at an
entry the screener never chose.

## Counts (join on `position_id` only)

`entry_stop` (trades.csv) against the first stop decision's `stop_before`,
which is the machine's level at the fill. Tolerance 0.006, because the CSV
rounds to cents. Built with a throwaway awk join over `trade_audit.sexp`
`stop_decisions` and `trades.csv`, not committed.

| run | trades | no decision | ≠ seed | age 0 | 1–4 | 5–26 | >26 |
|---|---:|---:|---:|---:|---:|---:|---:|
| inv26sc-investor-s0-v11 | 506 | 5 | 4 | 0/227 | 0/160 | 2/91 | 2/23 |
| inv26sc-investor-s1-v11 | 520 | 5 | 4 | 0/240 | 0/161 | 2/91 | 2/23 |
| inv26sc-investor-s2-v11 | 510 | 5 | 4 | 0/228 | 0/161 | 2/91 | 2/25 |
| f2-fills-faithful-s0-v11 | 724 | 724 | n/a | | | | |
| tp-t1-5r-s0-v11 (trader) | 196 | 0 | 0 | 0/56 | 0/53 | 0/45 | 0/42 |

The same four tickets mismatch in every investor salt: MU (×0.500, 14 weeks
rested), AAON (×0.667, 47), FUJIY (×0.944, 29) and DHLGY (×0.952, 9). Every
one is a split rescale between the decision and the fill, and none happens
with a ticket age of 0. FUJIY and DHLGY carry ratios of 17:18 and 20:21, which
are not obvious splits. Either they are stock dividends or the split detector
fired on a price gap. Check them before treating them as real splits.

The f2 record predates the `stop_decisions` audit (#2977), so it cannot be
measured. The issue's ask was "≠ the first event's `stop_after`". That reads
15 per investor salt, but 11 of those are a legitimate raise on the fill day
(the seed matches and the stop moved). `stop_before` is the right join.

The same artifacts also show `exit_stop` behind the machine on positions split
**while held**: 15 rows per salt where `exit_stop` is not the last decision
level. TRMB, TDG, NEOG, ENB, AVD, BCH and AAON-255 are pre-split levels that
`exit_stop` kept. NJDCY, DANOY, BSC_old, BRK-B and BKI_old are late-Stage-2
tightens: `exit_stop` is right there, and the audit's `stop_decisions` does not
record those moves (documented in `stop_decision.mli`).

## The trader specimens are a different class

JOE, CTO, EC, BOKF and AEG (`tp-t1-5r-s0-v11`) have `entry_stop` equal to the
machine seed, and the machine never moved. JOE's exit reads `Stop_loss
(stop_price 49.632) (actual_price 51.07)`, a stop-loss whose fill is above its
own stop. The trader preset arms `catastrophic_stop_pct 0.10`, and
`Stops_runner._catastrophic_exit` reuses `Stop_transitions.make_exit_transition`,
which stamps the **structural** level as `stop_price`. These are
fast-crash-stop exits (bar low ≤ trailing high × 0.90) labelled as structural
stop-losses. The columns report the structural stop correctly. What is wrong is
the exit label. That needs a follow-up: a distinct exit reason or `stop_price`
for the catastrophic path. It is not part of this PR.

## What changed (reporting only)

`Stop_log.record_stop_decision`, fed from `Trade_audit_recorder`'s
`record_stop_decision`:

- the first decision re-seeds `entry_stop`, the current level and `max_stop`
  from `stop_before`, the machine's level at the fill;
- a later decision whose `stop_before` is below the log's level is a split
  rescale, so `exit_stop` takes it and `max_stop` is rescaled by the same
  factor. Above the log's level is a move whose transition has not arrived
  yet, and it is installed once;
- `stop_after` is installed like an `UpdateRiskParams`.

No strategy or simulator code changed, so fills and P&L are bit-identical.
`stop_initial_distance_pct` and `stop_fill_distance_pct` still read the
decision-time `installed_stop`. That is deliberate: they measure what the
`Stop_too_wide` gate bounded at the decision (V12's basis).

## Behaviour fix (1): decision item, not implemented

Proposed flag: `rescale_resting_entry_on_split : bool [@sexp.default false]`
in `Weinstein_strategy.config`.

- **Hook.** `Stops_split_runner.adjust` already detects the split for an
  `Entering` position and rescales its stop. Under the flag, the same detection
  either rescales the resting ticket's trigger and limit by the factor
  (re-issue through `Entry_ticket_suspend`'s withdraw and re-issue path,
  #2989), or cancels the ticket with a new cancel reason `Split_while_resting`.
  Cancel is simpler and arguably more faithful: the base was read on a
  pre-split chart, and the next Friday's screen re-decides on the adjusted one.
- **Not proposed:** re-deriving the stop at the fill. That keeps the unscaled
  trigger, so the strategy still buys at a price the screener never chose.
- **Blast radius:** 4 trades per 26y investor salt (MU, AAON, FUJIY, DHLGY),
  0 in the trader 5y run. All are tickets that rested at least 9 weeks. Small
  in count, but the cost is per trade: AAON lost −5.2 % on a ~$727k position.
- Default-off, so it is an axis when it lands (`experiment-flag-discipline.md`).
  It needs the split-detector check on FUJIY and DHLGY first.
