---
name: project_stop_anchor_surface_is_dds
description: "#2408 stop-anchor surface re-measured on the fixed basis (2026-09-03): every anchor-on arm's edge is ONE admission, DDS 2020-10-05 (+$0.5–0.8M, larger than each arm's total); ex-DDS anchor-on is below the null at every buffer; the old 'salt-robust +60pp from buffer 0.92' was the D2 entry-bar artifact stopping DDS out at narrow widths — buffer axis is flat once D2 is fixed"
metadata: 
  node_type: memory
  type: project
  originSessionId: c7c971d0-92c7-4c65-a853-b1c877ee64fa
  modified: 2026-09-04T01:44:13.160Z
---

**Measured 2026-09-03** (`dev/experiments/stop-anchor-rebase-2026-09-03/`,
merged as PR #2658 → 7c477be08 after two text-only QC reworks; build e4984c5fe, 2019–23 × top-3000-2019, record-lineage cell-B base, salt 0;
old-basis comparison = `wip/sa2408-specs`, 2026-08-31):

| buffer | off (fixed) | on (fixed) | on ex-DDS |
|---|---:|---:|---:|
| 1.0 (null) | 9.30% (realised −$76k) | 73.35% | −$219k |
| 0.98 | 21.53% | 83.12% | −$171k |
| 0.96 | −15.72% | 66.09% | −$155k |
| 0.92 | 22.24% | 55.59% (s1 71.03, s2 102.46) | −$113k (s1 +$12k, s2 +$122k) |

DDS 2020-10-05 → 2022-02-14 (laggard exit) is in every anchor-on arm and no
anchor-off arm. The anchor changes the *admission set*: the E-anchored stop
sits inside `max_stop_distance_pct` 0.15 where the support-floor stop did
not, so DDS passes `Stop_too_wide` only with the anchor on.

**Why the old read looked robust:** on the old basis `on-b1.0` entered DDS
2020-10-05 and was stopped out 2020-10-06 for +$824 (entry-bar stop-out,
D2), while `on-b0.92`'s ~11.7% stop survived that bar → +$564k at all three
salts. Salts perturb paths, not that first-bar decision. The "+81/+95/+91 vs
25/24/13" headline was one monster × one artifact.

**How to apply:** do not promote `stop_anchor_at_entry_base` or any buffer
value off this cell. A promotion case must show the gate change is
systematically right (second window, blind-judge #2389) and must be read
ex-monster. Any lever whose arms differ in entry-bar-stop exposure measured
before 2026-09-03 is suspect for exactly this reason. Related:
[[project_lever_reads_invert_on_fixed_sim]], [[project_d1d2_mechanism_decomposition]],
[[project_top500_composition_golden_is_gme]], [[project_edge_is_the_fat_tail]].

**Salts (added 20:10):** null 9.30 / 7.93 / −6.40; on-b0.92 55.6 / 71.0 /
102.5 with DDS +$496k at every salt; ex-DDS on-b0.92 vs null −$37k / +$74k /
+$298k — sign-indeterminate, spread 3× the null's. At buffer 0.885 (≈15%) on and off are
bit-identical, pinning the gate mechanism. **Verdict: REJECT as promotion
candidate off this cell; keep as axis.**

**The lever that DID survive: `initial_stop_buffer 0.98` (≈5.9% fallback,
anchor off)** — beats the null 3/3 salts (+$155k / +$76k / +$341k), shared
drift ≈ 0, same top trade, edge = the null's 19 / 31 / 26 extra 4%-stop
whipsaw deaths. No shared monster; at salt 2 STMP (−$166k, null-only) is half
the delta — ex-STMP +$155k / +$76k / +$175k, still 3/3. Agrees with the arc grid's s6 keep-as-axis. Next: a proper
buffer {1.0, 0.98} surface on the record convention across 2000–04 and 26y,
salts {0,1,2}, ex-monster read ([[project_fallback_stop_half_book_band]]).

**Caveat from the follow-on surface (2026-09-03 21:35,
`stop-width-surface-2026-09-03`):** on the RECORD convention (clock 0, no
freeze / anchor-4) the same 5.9% width on 2019–23 is MSTR 2020-10-12
(+$580k, wide arm at every salt, never in the null; ex-MSTR the wide arm is
−$96k / −$269k / −$106k vs the null). The cell-B win stands; it does not
transfer to the record base on that window. The width's structural footprint
(−20…−30 stop exits) is identical in both bases; whether the survivors pay for
themselves is base- and regime-dependent. 2000–04 salts + 26y pending.
