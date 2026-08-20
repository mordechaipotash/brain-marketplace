#!/usr/bin/env bash
# BUILD GATE — makes "think first; build on the yes" deterministic instead of advisory.
# A rule that must hold every time belongs in a hook, not in prose.
#
# WHY: measured over 8,815 real Claude Code prompts from one heavy user — "don't build" /
# "talk only" / "no impl" appeared 68 times, and 29 of those (42.6%) landed AFTER file
# writes had already started (worst case: 91 edits before the human could stop it). The
# default was wrong and it was expensive: people are strongest before the build and
# weakest inside it.
#
# WHAT IT DOES: PreToolUse on writes + mutating MCP calls + mutating SQL. Looks at the
# LAST user message only — the instruction driving this turn. A clear go → the write
# proceeds untouched. No clear go → the write becomes ONE "ask" prompt, never a silent
# 91-edit run. This never denies; it interposes a single confirmation.
#
# FAIL-OPEN by design: if the transcript is unreadable or parsing fails, the write is
# allowed. A broken gate must not block work.
set -euo pipefail
GATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export GATE_DIR
# side-effect heartbeat: the mtime of this file is the proof the gate ran (never self-report)
HB_FILE="${CLAUDE_PLUGIN_DATA:-/tmp}/build-gate.last_run"; : > "$HB_FILE" 2>/dev/null || true

input="$(cat)"

printf '%s' "$input" | python3 -c '
import json, os, re, sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)                     # fail-open

ti   = d.get("tool_input") or {}
path = ti.get("file_path") or ti.get("path") or ""
tp   = d.get("transcript_path") or ""
tool = d.get("tool_name") or ""

# --- is this call actually a mutation? -------------------------------------------------
# The gate follows INTENT-TO-MUTATE, not a list of five tool names — scoping it to named
# operations once permitted closing a GitHub issue and altering a cloud resource by
# omission.

MUTATING_MCP = re.compile(r"""
    apply_migration | deploy_ | create_ | delete_ | update_ | merge_ | push_ | pause_ |
    restore_ | reset_ | rebase_ | provision_ | configure_ | _send\b | send_message |
    trash_ | label_ | unlabel_ | buy_ | add_issue_comment | forward\b | reply\b
""", re.X)

# execute_sql-style tools are read-only most of the time — gate on the STATEMENT, not the
# tool name, or "read-only queries are always open" becomes a lie.
WRITE_SQL = re.compile(
    r"^\s*(?:with\b.*?\)\s*)?(insert|update|delete|drop|alter|create|truncate|grant|"
    r"revoke|comment\s+on|refresh\s+materialized)\b", re.I | re.S)

is_file_write = bool(path)
is_mcp_write  = tool.startswith("mcp__") and bool(MUTATING_MCP.search(tool))
sql = ti.get("query") or ti.get("sql") or ""
is_sql_write  = bool(sql) and bool(WRITE_SQL.match(sql))

if not (is_file_write or is_mcp_write or is_sql_write):
    sys.exit(0)                     # reading, querying, searching — always open

# --- always open: scratch, temp, transcripts, logs ------------------------------------
EXEMPT = (
    "/scratchpad/", "/private/tmp/", "/tmp/", "/var/folders/",
    "/.claude/projects/", "/.claude/todos/",
)
if is_file_write and (any(s in path for s in EXEMPT)
                      or path.endswith((".log", ".jsonl"))):
    sys.exit(0)

# --- find the last REAL user message ---------------------------------------------------
# lib/turns.py is the one shared definition of "the human actually said this". A previous
# version of this gate read <task-notification> blocks as instructions: 35% of finished-
# agent reports contain a GO token (merge, build, commit) — a background agent could open
# the gate. NOTE: this block runs inside python3 -c SINGLE QUOTES. No apostrophes, ever.
sys.path.insert(0, os.path.join(os.environ.get("GATE_DIR", ""), "lib"))
try:
    from turns import last_from_user
except Exception:
    sys.exit(0)                     # fail-open

txt = last_from_user(tp)
if txt is None:
    sys.exit(0)                     # fail-open

low = txt.lower()

# A bare numeric menu pick IS a yes — a primary approval channel for menu-driven flows.
if re.fullmatch(r"[0-9]{1,6}[.,\s]*", low):
    sys.exit(0)

# An explicit stop WINS over any go-token in the same message. Caught on real data:
# "dont build brainstorm how to make X first class" matched "build" and let a write
# through — a negated build read as permission. This runs first.
NOGO = re.compile(r"""
    \b(dont|don.t|do\ not|no\ more|stop|never)\s+
      (build|implement|code|creat|produc|writ|touch|chang|edit|suggest)
  | \b(talk\ only|no\ impl|just\ talk|only\ talk|brainstorm\ only)\b
  | \bthink\ (with\ me|first)\b
""", re.X)

if NOGO.search(low):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": (
            "BUILD GATE — the current instruction explicitly says NOT to build "
            f"(\"{txt[:90]}\"). Bring the thinking, not the file."
        ),
    }}))
    sys.exit(0)

GO = re.compile(r"""
    \b(build|rebuild|implement|apply|deploy|ship|commit|push|merge|migrate|install|
       write\ it|make\ it|create\ it|do\ it|go\ ahead|proceed|execute|run\ it|
       fix\ it|patch|refactor|wire\ it|hook\ it|land\ it|add\ the|update\ the)\b
  | ^\s*(yes|yep|okay|sure|please\ do)\b
  | ^\s*go\s*[.!]?\s*$
  | ^\s*go\s+(ahead|for\ it|build|do|make|ship)\b
""", re.X)
# "go" alone is a yes; "go deep", "go look", "go 10x deeper" are research verbs —
# caught on real data: "go deep and look online" once opened the gate it should not have.

if GO.search(low):
    sys.exit(0)

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": (
        "BUILD GATE — no clear go in the current instruction "
        f"(\"{txt[:90]}\"). Think first; build on the yes. "
        "Gated: creating or modifying project files, migrations, deploys, sends, commits. "
        "If this write was actually asked for, approve; if the agent is racing ahead, "
        "deny and ask for the thinking instead."
    ),
}}))
' 2>/dev/null || exit 0

exit 0
