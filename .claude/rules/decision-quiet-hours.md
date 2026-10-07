# Decision quiet hours: no questions 23:00–11:00 Pacific; defer them to 11:00

User instruction, 2026-10-07: *"make a rule that don't ask question between 11PM and 11AM — if there is
important decisions, defer them until 11AM."* It came the same day as *"are we in autonomous mode now? do
you have to ask the questions?"*, after an autonomous session stopped on two questions, each of which
already had a recommended option.

## The rule

1. **Between 23:00 and 11:00 America/Los_Angeles, never ask the user anything.**
   - Check `TZ=America/Los_Angeles date +%H` before any `AskUserQuestion`, or any message that ends
     waiting on a reply.
   - Covers interactive sessions and every agent or cloud session that can reach the user.
2. **In quiet hours, keep working.**
   - Take the recommended, reversible option, and state the choice and its tradeoff in the next status
     update so the user can override it at 11:00.
   - A decision that needs the user is one that is irreversible, outward-facing, or has no
     recommendation. Park it, then carry on with other queued work rather than idling the container.
   - To park it, record it under **"Decisions waiting (deferred to 11:00 PT)"** in the newest
     `dev/notes/next-session-priorities-*.md`, or in the session's status message. Give the options,
     the tradeoffs and a recommendation, the same as an `AskUserQuestion` would.
3. **At or after 11:00 PT**, raise the parked decisions, at most once and batched.
4. **Outside quiet hours, autonomous sessions still prefer acting over asking.**
   - When an option is marked (Recommended) and is reversible, take it and report it.
   - Ask only for irreversible or outward-facing calls, or where there is genuinely no recommendation.

## What this does not change

- **Destructive or irreversible actions still need confirmation.** Deleting data, force-pushing shared
  history and publishing externally are examples. In quiet hours, that means they wait until 11:00; it
  does not mean doing them unconfirmed.
- **Hard holds stay holds.** The `do-not-merge` label, red CI and QC verdicts are unaffected; this rule
  is about questions, not gates.

Related: `memory/feedback_autonomous_take_recommended`, `memory/feedback_no_permission_asking`.
