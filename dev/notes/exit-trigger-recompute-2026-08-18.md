# Exit-trigger groupings, recomputed from `trades.csv` (join-immune)

Closes the priorities-doc item *"recompute async `exit_trigger` groupings
post-fix"* for the ladder-v4 family, and states why the recompute did not need to
wait for a post-#2317 run.

## The defect, and what it does and does not touch

`project_audit_join_date_proximity`: before #2317 (merged 2026-08-14) the audit
joined trades to entry records by **date proximity within 7 days**, so an
`exit_trigger` copied through that join could be attached to the wrong entry.
Any grouping built from the *audit's* copy is suspect.

`trades.csv` carries `exit_trigger` as its own column, written by the simulator
at exit time — **no join is involved**. Grouping the CSV by that column is
therefore valid on pre-fix artifacts too, which is what is done below.

The same artifacts are *not* usable for anything keyed on the join: their
`ticket_age_weeks_at_fill` takes only the values 0 and 1 (1,105 / 132 in cell 16,
rest unset), the exact signature of a 7-day reach-back. Any "how long did tickets
rest before filling" or "how many placed tickets ever resolved" number from a
pre-08-14 artifact is measuring the join window.

## Cell 00 (26y, top-3000, ladder-v4 core)

| exit_trigger | n | P&L \$ | per trade | win% |
|---|---|---|---|---|
| `laggard_rotation` | 349 | **+5,870,237** | +16,820 | 59% |
| `stage3_force_exit` | 5 | +251,280 | +50,256 | 80% |
| `extension_stop` | 1 | +88,344 | +88,344 | 100% |
| `liquidity_exit` | 5 | +60,025 | +12,005 | 80% |
| `stop_loss` | 722 | **−4,437,915** | −6,147 | 20% |

## Across all 19 arms with a `trades.csv` — the two structural facts

The 19 arms enumerated below are every ladder-v4 arm directory carrying a
`trades.csv` (`v4-00` … `v4-18`). The stderr-side cohort in
`dev/experiments/ticket-funding-cohort-2026-08-18/README.md` counts **20** arm
blocks in the shared `ladder-v4.log`. **The two populations were never
reconciled**, and with the artifacts off disk they cannot be: it is not
determined whether one arm produced no `trades.csv`, or whether the log carries
a 20th block that is a re-run of an arm already listed. What *is* determined is
that no arm was excluded here for its result — the 19 are every directory that
had the file. Every "19 arms" figure below is over `trades.csv`; every "20 arms"
figure there is over the log; neither is a subset claim about the other.

```
arm                                trades   total P&L | laggard n /      P&L | stop n /       P&L | lag share
v4-00-core-w4                        1082    1831972  |     349 /  5870237  |  722 / -4437915  |  32%
v4-01-anchor-w8                      1044    2979288  |     298 /  8113131  |  734 / -5557108  |  29%
v4-02-fresh-rangetop                 1064    2523328  |     381 /  6650816  |  676 / -4310472  |  36%
v4-03-ttl4                           1023    1934733  |     294 /  6188905  |  720 / -4621865  |  29%
v4-04-ttl8                           1031    1487244  |     286 /  5227330  |  738 / -4088761  |  28%
v4-05-maxstop25                      1202    3155285  |     564 /  5021612  |  619 / -2250394  |  47%
v4-06-maxstop35-diag                 1255    2485719  |     581 /  5965447  |  649 / -3527990  |  46%
v4-07-maxstop50-diag                 1325    6631350  |     635 /  9674077  |  653 / -4050100  |  48%
v4-08-sizedown50-diag                1341    3621877  |     629 /  6930720  |  679 / -3886475  |  47%
v4-09-nearfloor                       904    4944251  |     550 /  8162139  |  346 / -4411724  |  61%
v4-10-volconf                        3026    -295287  |     129 /   959521  | 1252 / -2042560  |   4%
v4-11-anchor-w8-rangetop             1044    3945260  |     331 /  9113412  |  704 / -5460450  |  32%
v4-12-rt-ttl4                         996    1536893  |     283 /  5634121  |  707 / -4258992  |  28%
v4-13-rt-nearfloor                    889    4155326  |     527 /  8781731  |  351 / -4642428  |  59%
v4-14-rt-volconf                     3119    -251974  |     136 /   951701  | 1205 / -2381594  |   4%
v4-15-rt-ttl4-nearfloor               789    2796599  |     457 /  6214000  |  325 / -3672623  |  58%
v4-16-rt-ttl4-nearfloor-volconf      1829     366451  |     153 /   704087  |  168 /  -904377  |   8%
v4-17-rt-ttl8-nearfloor-volconf      1951     362655  |     172 /   708199  |  170 /  -921087  |   9%
v4-18-rt-ttl4-nearfloor-volconf-w8   1632    -126739  |     109 /   235370  |  157 /  -636833  |   7%
```

**F1 — the sign structure is universal.** `laggard_rotation` is positive and
`stop_loss` is negative in **19 of 19** arms, without exception, across every
knob the ladder varies (anchor window, TTL, stop ceiling, near-floor, volume
confirmation). This re-derives `project_trade_forensics_2026_06_12` ("laggard
rotation = profit channel, stops eat losses") from a different artifact and a
much wider config span. It is a property of the strategy, not of a cell.

**F2 — volume-confirm-at-fill collapses the profit channel.** The five volconf
arms (10, 14, 16, 17, 18) are the only ones whose laggard share falls to 4–9%
(all others: 28–61%) and the only ones with a flat-or-negative realized total.
They also carry 2–3× the trade count. The mechanism is legible: ejecting at the
fill week returns capital before a rotation can ever harvest it, so the exits
that remain are dominated by stops. Consistent with `project_ladder_v4_null_278pp`,
where volconf's rejection was the one result that survived the null.

## Calibration — what these numbers may not be used for

- **Arm-to-arm top-line comparisons are noise.** The measured null on this base
  is 278pp (a duplicate cell spelled two ways returned 726 vs 448 —
  `project_ladder_v4_null_278pp`), and every arm here is a single draw. The
  `maxstop50` arm's +6.6M is **not** evidence that a 50% ceiling is better.
- **Composition claims are stronger than P&L claims** but still single-draw. F1
  survives because it is a 19-of-19 sign test, not a magnitude comparison; F2
  survives because it separates two disjoint groups on two independent axes
  (share and count) and agrees with a null-controlled prior result.
- Realized trade P&L ≠ `total_return_pct`; open positions at end-of-run are
  excluded, so these totals are not comparable to the scenario's headline.

## Arm 00 of the TTL re-test (post-#2317 tree) — same structure, independently

Recomputed on `ttl-retest-00-null` (26y top-3000, salt 0, tree `59b26c3bf`),
which returned the determinism tripwire exactly (281.707836…):

| exit_trigger | n | P&L \$ | per trade | win% |
|---|---:|---:|---:|---:|
| `laggard_rotation` | 377 | +6,763,531 | +17,940 | 64% |
| `extension_stop` | 2 | +749,388 | +374,694 | 100% |
| `stage3_force_exit` | 4 | +176,186 | +44,046 | 75% |
| `liquidity_exit` | 6 | +38,321 | +6,387 | 67% |
| `stop_loss` | 752 | −5,511,128 | −7,329 | 17% |

**This table is not a partition.** Its rows sum to **1,141 trades / +2,216,298**
against the run's **1,147 round trips / +2,314,952** — **6 trades and \$98,654
are unaccounted for**, and the recompute does not explain them. They are rows
whose `exit_trigger` cell did not fall into one of the five named groups (empty,
or a value not listed); which, is not determined here, and the artifacts are no
longer on disk to check. The shares and per-trade figures above are therefore
over the 1,141 grouped trades, not over the run. The residual is 0.5% of trades
and 4.3% of realized P&L — small enough not to move F1 (a sign test on the two
largest groups) but large enough that no row here should be read as a share of
the run total.

F1 holds on a different code tree and a different build: laggard positive, stops
negative. The two `extension_stop` exits carrying +749,388 between them is the
fat tail showing up in the exit mix — **two trades worth 32% of the run's entire
realized total** (+2,314,952), and 11% of the laggard channel on its own. That is
`project_edge_is_the_fat_tail` in one line of a table.
