---
name: log-work
description: Claim, pause or finish a Racing Sim task in godot/docs/rebuild/QUEUE.md and godot/docs/REBUILD-LOG.md in the house format. Use when starting, pausing or completing queued work, or when asked to log/record progress.
---

# Log work (REBUILD-PLAN.md §9)

**Token rule:** `REBUILD-LOG.md` is 5,000+ lines. Never read it whole. Read only the tail (`tail -n 80`) or grep for a task id (`grep -n "CHI-3D" godot/docs/REBUILD-LOG.md`). Append new entries at the end.

## QUEUE.md (`godot/docs/rebuild/QUEUE.md`)
- Statuses: `open`, `claimed: <model>`, `review: <model>`, `done`, `blocked: <reason>`, `needs owner`.
- Take the first `open` row whose **Who** includes you and whose **Needs** are all `done`.
- Claim = change only that row's status to `claimed: Claude`, one tiny commit to `main`, push.
- Done = set status `review: <reviewer>` and put branch + one-line evidence in the notes column.
- New fix work = a new row in "Review and fixes", not an edit to someone else's row.

## REBUILD-LOG.md entries
Header line, then a short wrapped paragraph (~80 cols), blank lines between entries:

```
CLAIM <task-id> Claude <YYYY-MM-DD>
PAUSED <task-id> <YYYY-MM-DD>   — exact state and the next step
DONE <task-id> <YYYY-MM-DD>     — what changed, gate summary/measurements, what's left undone
```

Rules: report failures as failures; say what was actually inspected vs. assumed; no "verified" without the command that verified it; end with the next step.

Branch per task: `rb/<task-id>-<slug>` (or the owner-assigned branch). Don't merge with a failing or skipped gate.
