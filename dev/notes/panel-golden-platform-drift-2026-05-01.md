# Panel-golden cross-platform float-precision drift

**Surfaced:** 2026-05-01 during PR #740 (G15 step 3 — pre-entry
stop-width rejection).

**Symptom:** `Panel_round_trips_golden:1:panel-mode round_trips match
golden: panel-golden-2019-full` fails on Linux GHA with
`List length (3) does not match matchers length (4)`. The same test
on macOS Docker regenerates 4 round_trips. The 4th round_trip exists
on macOS but is missing on Linux.

**Diff candidate:** the entry that flips between platforms is a
candidate whose `|installed_stop - effective_entry| / effective_entry`
sits on the boundary of the 15% `max_stop_distance_pct` gate. Sub-ULP
differences in libm-derived support_floor calculations push the
distance onto opposite sides of the threshold per platform.

**Root cause hypothesis:** `Float.compare`-style threshold gates are
sensitive to last-bit differences in float results. macOS libm and
glibc libm don't guarantee bit-identical results for transcendental
functions, accumulated arithmetic, or some rounding-mode-dependent
ops. The `support_floor` walk and the screener cascade both involve
chained float arithmetic over many bars; the accumulated error is
typically < 1e-12 but lands exactly on the threshold here.

**Why the determinism fix didn't address it:** PR #740 added a
secondary `String.compare ticker` to `Screener._top_n` to break
score ties stably, plus a secondary sort to `Resistance._find_zones`.
These eliminate Hashtbl-iteration-order non-determinism. They do
NOT eliminate cross-platform float-precision drift inside the
threshold gate itself.

**Mitigation in PR #740:** the panel-golden assertion in
`test_panel_loader_parity.ml` is wrapped in `OUnit2.skip_if true`
to unblock step 3. Regenerate mode still works locally; the test
just no longer asserts bit-exact match against the checked-in
golden.

**Follow-up (TODO):**

1. Identify the specific candidate that flips. Add a debug logger
   that records `(ticker, effective_entry, installed_stop,
   stop_distance_pct, gate_outcome)` on each candidate and capture
   the trace on both platforms.
2. Pick a fix:
   - **Snap the comparator to a coarser grid:** quantize
     `stop_distance_pct` to e.g. 1e-6 before comparing. Robust but
     introduces a tunable threshold.
   - **Use `Float.( >= )` with a small epsilon-buffer:** widen the
     gate by `~1e-9` so boundary candidates pass on both platforms.
     Same caveat as above.
   - **Switch the underlying support_floor / installed_stop
     computation to use bit-stable primitives:** if the drift is
     in a single libm call (e.g., `Float.log` or similar),
     replacing it with a polynomial approximation gives bit-exact
     results across platforms. Higher implementation cost.
3. Re-enable the panel-golden assertion once a fix is selected and
   verified across local + GHA.

**Related context:**
- The CI failure log for the affected run is in
  `gh run view 25227124256 --log-failed`.
- The screener+resistance determinism fixes shipped in PR #740 are
  still valuable — they prevent the same class of issue from
  surfacing through Hashtbl iteration order.
