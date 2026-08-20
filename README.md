# brain — epistemic discipline for Claude Code

Three plugins that make an agent *honest* rather than merely capable. Extracted from a
private harness where each rule was bought with a measured failure, then rewritten for
anyone. From the maker of [brain-mcp](https://github.com/mordechaipotash/brain-mcp).

```
/plugin marketplace add mordechaipotash/brain-marketplace
/plugin install prove-it
/plugin install preflight
/plugin install build-gate
```

## The plugins

### prove-it — verification discipline (skill)
Every number carries its provenance **in the same sentence**. A test that cannot fail
proves nothing. A zero without a named scope is not a zero. Unknown is not healthy.
When wrong, the proof is two-part: mechanism first, then the fix. Load it before
asserting any measured claim — or let the agent load it when you say "prove it".

### preflight — recon before build (skill)
"Map everything, build nothing." Produces a full state-of-the-world spec — files,
schemas, endpoints, crons, git state, prior decisions — with a mandatory Open Questions
section and a menu whose safe default is `[0] STOP — do not implement yet`. Refuses all
mutations mid-run, even if asked nicely.

### build-gate — think first; build on the yes (hook)
A PreToolUse hook. If your **last message** carried a clear go ("build it", "go ahead",
a bare menu number), writes proceed untouched. If it didn't — or explicitly said *don't*
build — the first write becomes one confirmation prompt instead of a silent 91-edit run.
Fail-open by design: a broken gate never blocks work.

**Why it exists, measured:** across 8,815 real prompts from one heavy user, "don't
build / talk only / no impl" appeared 68 times — and 42.6% of them landed *after* file
writes had already started. The default was wrong and it was expensive.

**The hard part is knowing who spoke.** The gate reads the last *human* message — not
skill bodies, not `<task-notification>` blocks from finished background agents (35% of
which contain a "go" token like *merge* or *commit*, because that is what an agent's
completion report says; an unguarded gate can be opened by a background agent). That
one-true-reader lives in `lib/turns.py`, with every exclusion earned by transcript
replay rather than by guessing what a harness injects.

## Design rules these plugins share

- **Cite or abstain** — a claim carries its instrument, or it says `unmeasured`.
- **A rule that must hold deterministically belongs in a hook, not in prose.**
- **Fail-open** — discipline tooling must never become the thing that blocks work.
- **Nothing phones home.** No network calls anywhere in this repo. Verify: grep it.

## License

MIT. The stories in the comments are real; identifying details removed.
