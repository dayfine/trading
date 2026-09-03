---
name: project_top500_composition_golden_is_gme
description: "weinstein-2019-top-500 composition golden's 475% return was ONE trade (GME 2020-09→2021-08, +$4.76M); under the D1/D2 fixed basis it drops to 40.6% because GME was screened but never funded — treat that cell's level as a lottery ticket, never as evidence"
metadata: 
  node_type: memory
  type: project
  originSessionId: c7c971d0-92c7-4c65-a853-b1c877ee64fa
  modified: 2026-09-03T08:45:15.332Z
---

**Measured 2026-09-03** (`dev/experiments/exit-basis-flip-2026-09-03/README.md`
§Dissection): the `goldens-custom-universe-scenarios/weinstein-2019-top-500`
golden (top-500 PIT-2019 composition, 2019–2023) read 475.48% on the
pre-flip basis and **40.60%** with `sim_exit_fill_next_open` +
`stop_skip_entry_bar` on. The whole gap is GME 2020-09-12 → 2021-08-07,
32,098 sh @ 6.21 → 154.59 = +$4.76M in the old arm (the other 172 trades net
−$0.5M). In the new arm GME was screened six times (grade A) but the book
was 7 positions deep on 2020-09-11 (vs 6) and the ticket was never funded.
Entry cohorts diverge from 2019-07 (119 shared / 54 / 70 by
`symbol|entry_date`).

**Why:** a survivor-biased composition golden with one monster is a lottery
cell; any path change (here a corrected exit basis) reshuffles who holds
cash on the monster's breakout week. 1 monster ≈ the whole spread
([[project_funding_grid_monster_lottery]],
[[project_composition_golden_survivor_bias]]).

**How to apply:** never quote this cell's return level as evidence for or
against anything; its pin is a regression tripwire only. When a change moves
it by hundreds of pp, check for GME first before suspecting the mechanism.
Same shape as [[project_clock26_is_a_tail_lottery]].
