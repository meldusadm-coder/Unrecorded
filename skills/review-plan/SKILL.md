---
name: review-plan
description: >-
  Offer optional GPT 5.5 review after any implementation plan is drafted. Use
  after writing-plans, Plan mode output, or any multi-step implementation plan
  — ask the user before dispatching review.
---

# Review plan (GPT 5.5, optional)

GPT 5.5 plan review is **optional** (saves credits). After every plan, **ask the user** before dispatching.

> **Global install:** Also at `~/.cursor/skills/review-plan/` with user hook `~/.cursor/hooks.json` (all projects).

## When to offer review

After any of:

- A plan file is saved (for example `docs/**/plans/*.md`)
- Plan mode produces an implementation plan in chat
- The writing-plans skill finishes a plan
- You draft a multi-step implementation plan inline (3+ tasks or touches multiple packages)

## Step 1 — Present the plan

Show the user:

1. **Plan location** (path or inline summary)
2. **Execution options** — if using writing-plans handoff, offer subagent-driven vs inline execution

Then **always ask** (exact wording or close):

> **Do you want this reviewed by GPT?**

Do **not** dispatch GPT 5.5 review unless the user says yes (or clearly agrees: "review it", "yes please", etc.).

If the user says no or wants to proceed without review, continue to execution — do not ask again unless they request review later.

## Step 2 — Dispatch GPT 5.5 reviewer (only if user said yes)

Announce: **"Dispatching GPT 5.5 plan review."**

Gather inputs:

| Input | Source |
|-------|--------|
| `{PLAN}` | Full plan text or path to the saved plan file |
| `{SPEC}` | Original user request, issue body, or brainstorming spec |
| `{CONSTRAINTS}` | Relevant project rules: [AGENTS.md](../../AGENTS.md), privacy principles, git-flow if release-related |

Read the plan file with the Read tool if it was saved to disk.

Use the **Task** tool:

| Parameter | Value |
|-----------|-------|
| `subagent_type` | `generalPurpose` |
| `model` | `gpt-5.5-medium` |
| `readonly` | `true` |
| `description` | `GPT 5.5 plan review` |

Fill the prompt from [plan-reviewer-prompt.md](plan-reviewer-prompt.md), replacing all `{PLACEHOLDER}` tokens.

**Do not** substitute a different model. If `gpt-5.5-medium` is unavailable, tell the user — do not silently skip.

## Step 3 — Act on feedback (if review ran)

| Severity | Action |
|----------|--------|
| **Critical** | Fix in the plan before executing |
| **Important** | Fix before execution; may note fixes in progress |
| **Minor** | Note for execution; fix if trivial |

If Critical or Important issues were found:

1. Update the plan (and saved file if applicable)
2. Ask whether to **re-run GPT review** on the revised plan (optional again)
3. Repeat review only if the user agrees

## Step 4 — After review (or if skipped)

- If reviewed: share **review verdict** and notable findings
- Then offer execution or next steps

## Red flags — never do these

- Dispatch GPT 5.5 review without asking first (unless user already asked for review this turn)
- Auto-run review to "save the user a step" — always ask
- Use the parent session model instead of `gpt-5.5-medium` when review was requested
- Ignore Critical findings when the user chose review and wants to execute
