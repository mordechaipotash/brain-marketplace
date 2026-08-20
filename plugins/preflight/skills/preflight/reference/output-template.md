# Preflight output template (strict shape)

```markdown
# PREFLIGHT — <target>, <date>

SCOPE      <one sentence: what was mapped; what was excluded>
MEASURED   <time + the instruments actually used: the greps, queries, list calls>
UNMEASURED <what this recon did NOT look at, and therefore says nothing about>

## Precedent — what was already decided
<dated citations, or "no prior precedent found in <places looked>">

## What exists
<per surface: filesystem / database / env / endpoints / crons / overlapping tooling /
git state / dependencies — only surfaces that are relevant, each with concrete names>

## Gaps
1. <thing the build needs that does not exist>
2. ...

## Open questions (must be non-empty)
1. <decision the user has not made, stated as a question with the options>
2. ...

## Build spec
1. <numbered, sequential, concrete identifiers, no code bodies>
2. ...

## Menu
[1] <first build step, smallest safe increment>
[2] <second option>
[3] <alternative approach if one surfaced>
[0] STOP — do not implement yet
```

Rules: every count in the report carries its instrument inline; anything unmeasured
is labeled `unmeasured`, never guessed; the menu's [0] is always STOP.
