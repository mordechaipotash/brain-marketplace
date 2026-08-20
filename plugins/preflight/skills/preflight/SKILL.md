---
name: preflight
description: Maps the full current state of a build target — files, database schemas, env vars, endpoints, crons, overlapping tooling, git state, and prior decisions — then produces a one-shot build spec without writing or modifying anything. Use when the user says "preflight", "don't build yet", "don't implement anything", "map everything first", "what would we need to one-shot this", "no assumptions just map it", or otherwise asks for reconnaissance before implementation. Output is a structured spec ending in a menu where [0] STOP — do not implement yet is the safe default. Refuses all mutations until the user explicitly chooses to proceed.
---

# /preflight — recon before build

## Invariant: NO MUTATIONS

You MUST NOT take any action that changes state. Reading and querying are allowed;
mutating is forbidden.

**Forbidden during a preflight run:**
- `Edit`, `Write`, `NotebookEdit`
- Any database migration, deploy, branch-create/merge, or DDL/DML — SQL is
  SELECT / EXPLAIN only
- `Bash` that writes files in the repo, `git commit`, `git push`, PR creation,
  package installs, or any network call with side effects (POST / PUT / DELETE)
- Browser automation clicks/fills against real systems
- Any MCP tool whose name implies mutation (`create_*`, `update_*`, `delete_*`,
  `deploy_*`, `send_*`, `apply_*`, `merge_*`, ...)

**Allowed:** `Read`, `Grep`, `Glob`; read-only `Bash` (`ls`, `find`, `git status/log/diff`,
`gh ... view`, GET APIs); read-only SQL; read-only MCP tools; `WebFetch`/`WebSearch`;
read-only subagents — briefed with this same NO MUTATIONS gate.

If the user mid-stream says "actually just build it," **refuse and finish the recon**.
They choose to proceed via the menu at the end. (One exception: if they abort the
preflight itself, stop entirely.)

## Workflow

Copy this checklist into your response and tick items as you complete them.

```
Preflight progress:
- [ ] Step 1: Confirm scope (one sentence back to the user)
- [ ] Step 2: Precedent check (what was already decided?)
- [ ] Step 3: Parallel surface mapping
- [ ] Step 4: Synthesize gaps + open questions
- [ ] Step 5: Produce build spec
- [ ] Step 6: Output via reference/output-template.md and STOP
```

### Step 1 — Confirm scope
One sentence stating what you are about to map and what you are explicitly
excluding. Do not start mapping until this is written.

### Step 2 — Precedent check (BEFORE surface mapping)
The anti-relitigation heart of preflight: recover what was ALREADY decided so you
build forward, not in circles. The worst failure is not a miss — it is presenting a
**superseded** decision as current.

Check, in whatever exists in this project: decision logs / ADRs, memory or notes
systems, prior specs, issue threads, commit messages on the relevant paths, and any
conversation-memory tools available in the session. If two sources disagree on what
is current, treat it as a supersession flag — do not trust either silently; confirm
against a third source or the code itself.

Always include a precedent section in the output: cite what you found (with dates),
or state plainly "no prior precedent found in <the places you looked>".

### Step 3 — Parallel surface mapping
For each relevant surface, gather what exists (parallel read-only subagents where
the mapping spans many files):
- **Filesystem** — files, dirs, scripts, configs touching the target
- **Database** — schemas, tables, migrations history, functions, known advisors
- **Env vars / secrets** — names referenced in code and where they live
  (read names, never values)
- **Endpoints / external APIs** — what's called, where the contracts live
- **Crons / scheduled jobs** — pg_cron, launchd/systemd, CI schedules
- **Overlapping tooling** — existing skills, commands, agents, scripts that
  already do part of this
- **Git state** — branch, ahead/behind, uncommitted files, recent relevant commits
- **External dependencies** — libraries, services, accounts the build relies on

### Step 4 — Synthesize gaps and open questions
Every piece of the proposed build that does not exist yet is a gap. Every decision
the user has not made (or the recon surfaced ambiguity about) is an open question.
**The Open Questions section MUST be non-empty.** If you cannot find any, the recon
was too shallow — look harder, or raise the ones a smart implementer would.

### Step 5 — Produce build spec
Sequential, numbered, referencing concrete file paths / table names / function
names / cadences / env var names. No code beyond identifier names. The spec is what
gets handed to an agent or a focused next session.

### Step 6 — Output and STOP
Render using [reference/output-template.md](reference/output-template.md) as the
strict shape. The final element is the menu, and `[0] STOP — do not implement yet`
is the safe default.

After printing the report, do nothing else. Do not "just create the migration file
too." Do not "stub the function while we're here." The user chooses what happens
next via the menu.

## Anti-trigger guard
If the user has already explicitly said "build it" / "just do it" / "go ahead and
implement", or selected a go option from a previous preflight menu, this skill does
NOT fire. Preflight is for *before* the build is authorized.
