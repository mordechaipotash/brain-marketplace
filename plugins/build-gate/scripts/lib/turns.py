#!/usr/bin/env python3
"""
turns.py — ONE definition of "did the user actually say this?".

WHY THIS FILE EXISTS. In one measured harness (2026-08), three hooks were found
reading machine output as the user's words, each having independently reimplemented
"find the last user message":

  - one had no isMeta check: skill bodies arrive as type=user entries, so invoking a
    skill that quotes correction-phrases BY DESIGN made the machine believe the user
    had corrected it. Over 271 replayed transcripts it read 20.9% injected turns as
    the user's, and 26.9% of its detected "corrections" were machine text.
  - the build gate checked isMeta but not <task-notification>: 469 of those
    qualified as "the current instruction", and 35% contained a GO token — merge,
    build, commit — because that is what a finished agent's completion report says.
    A BACKGROUND AGENT COULD OPEN THE BUILD GATE.

The pattern behind every defect: hooks that read the MACHINE (tool inputs, SQL,
paths) never had one; every defect lived in a hook that reads the HUMAN. So the
read-of-the-human gets exactly one implementation, here, with exclusions earned by
transcript replay rather than by reasoning about what the harness might inject —
the leaks you can enumerate from memory are not the ones that cost you.

Exclusions:
    isMeta                  skill bodies + injected context
    <command-...>           the /slash wrapper itself
    <task-notification>     a finished background agent reporting back
    <channel ...>           dictated/relayed input arriving as structured markup
                            (IS the user, but callers must opt in: allow_channel)
    [Base]                  platform system-prompt injections
    Caveat:                 harness advisory text
    [Request interrupted    harness cancellation notice
    tool_result blocks      tool output, never speech
    <local-command-...>     local command echo
    system-reminder         injected reminder text
"""
import json
import os

_PREFIXES = (
    "<command-",
    "<task-notification>",
    "[Request interrupted",
    "[Base]",
    "Caveat:",
)


def _read(path, tail=None):
    """Lines of a transcript. With `tail`, seek from the END instead of slurping —
    transcripts reach hundreds of MB late in a long session, and a hook runs on
    every prompt."""
    if not tail:
        with open(path, "r", errors="replace") as fh:
            return fh.read().splitlines()
    size = os.path.getsize(path)
    block = min(size, max(tail * 4096, 262144))
    with open(path, "rb") as fh:
        fh.seek(size - block)
        chunk = fh.read()
    lines = chunk.decode("utf-8", "replace").splitlines()
    if block < size and lines:
        lines = lines[1:]  # first line is probably a fragment
    return lines[-tail:]


def _text(entry):
    """The text of a user entry, or None if it isn't speech (tool_result, etc.)."""
    c = (entry.get("message") or {}).get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        if any((b or {}).get("type") == "tool_result" for b in c if isinstance(b, dict)):
            return None
        joined = " ".join(b.get("text", "") for b in c
                          if isinstance(b, dict) and b.get("type") == "text")
        return joined or None
    return None


def is_user(entry, text=None, allow_channel=False):
    """True only if this transcript entry is the human speaking."""
    if entry.get("type") != "user" or entry.get("isSidechain") or entry.get("isMeta"):
        return False
    if text is None:
        text = _text(entry)
    if not text or not text.strip():
        return False
    s = text.lstrip()
    if s.startswith(_PREFIXES):
        return False
    if s.startswith("<channel ") and not allow_channel:
        return False
    if "<local-command-" in s or "system-reminder" in s[:200]:
        return False
    return True


def user_turns(transcript_path, allow_channel=False, tail=None):
    """Every turn the human actually spoke, oldest -> newest."""
    out = []
    try:
        lines = _read(transcript_path, tail)
    except Exception:
        return out
    for ln in lines:
        try:
            e = json.loads(ln)
        except Exception:
            continue
        t = _text(e)
        if not is_user(e, t, allow_channel):
            continue
        out.append({"text": t, "ts": e.get("timestamp"), "raw": e})
    return out


def last_from_user(transcript_path, allow_channel=True, tail=400):
    """The human's most recent message, or None. Accepts dictated (channel) turns by
    default, because a hook asking 'what did they just instruct' must hear them."""
    if not transcript_path or not os.path.exists(transcript_path):
        return None
    turns = user_turns(transcript_path, allow_channel=allow_channel, tail=tail)
    return turns[-1]["text"].strip() if turns else None
