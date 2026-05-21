---
description: Code-health follow-ups must actually land. Don't bump linter limits, add `@large-module` markers, or paper over linter trips with escape-hatch flags as a substitute for the underlying refactor.
harness: project
---

# Code-health discipline

Splitting work into separate PRs for review focus is valid; **deferring
the follow-up code-health work indefinitely is not**. When a linter or
quality check trips, the answer is to fix the underlying issue, not
bump the limit or add an escape-hatch marker.

## What NOT to do

- Bump `HARD_LIMIT` / `SOFT_LIMIT` / `MAX_LARGE_PCT` as a workaround.
- Add `@large-module` markers to files just to satisfy a linter — the
  marker is reserved for legitimately-large coordinator modules whose
  fragmentation would damage per-cycle reading order, not for skipping
  refactors.
- Add path exceptions to `linter_exceptions.conf` without both:
  - A clear `review_at` trigger (date or PR number).
  - A real, documented reason — not "follow-up tracked in #N" without
    the follow-up actually being opened and worked.
- Land "follow-up tracked in #N" comments without opening + working
  the follow-up. Trackers without action are not deferral; they're
  permanent debt.

## Why

Per `feedback_no_deferred_codehealth.md` 2026-05-07: PR #916 (P1
stale-hold detector) pushed `simulator.ml` to 519 lines (>500 hard
limit). The dune-runtest cache had been hiding the violation; PR #919
merging invalidated the cache and revealed it — plus **8 other
file-length violations, 5 function-length, 99 nesting, and multiple
magic-number / status-integrity violations** that had accumulated
unnoticed across the codebase. Main went red and 4 PRs blocked
simultaneously.

The accumulation happened because earlier PRs had used `@large-module`
markers + cache-skipped CI runs to defer the actual extraction. Code
health that "wasn't strictly required for the feature" got pushed off
the immediate critical path; it accumulated silently until a single
cache invalidation fired all alarms at once.

## What TO do

When a linter trips:

1. **First instinct: extract / refactor the offending code.** The
   linter is the canonical signal that the module/function is too
   large or too nested; the fix is to reduce it.
2. **Only then consider an `@large-module` marker** if the file is
   genuinely a coordinator (e.g., orchestrates a multi-stage pipeline
   with sequential reading-order dependencies) and the alternative is
   harming readability. The marker is rare — its presence in the
   codebase should be unusual enough that adding one prompts review.
3. **Bumping limits is a last resort** that must be accompanied by:
   - A concrete refactor plan, ideally as a separate PR scoped to the
     extraction.
   - A tracking issue with a real owner + date.
   - The bump landing in the same PR as the plan + issue link.
4. **Cleanup work should be proactive, not reactive.** If the cleanup
   agent (`code-health`) only fires on linter failure, it's already
   too late — accumulation is a leading indicator. Watch trends:
   file-length growth across multiple PRs, new `@large-module` markers
   landing, function-length being dialled up — those are signals to
   schedule cleanup *now*, not "we'll get to it" notes.

## Splitting fixes from features

Splitting a feature into "fix" + "feature" PRs (per the PR-structure
guidance in CLAUDE.md) is still right — but each split must actually
land. "Out of scope for this PR" is fine in a PR body; "deferred
forever" is not. If the fix-half PR doesn't land within a few sessions
of the feature-half, the feature-half should be reverted, not left as
a permanent debt on main.
