---
name: review-plan
description: >-
  Mandatory GPT 5.5 review after any implementation plan is drafted. Use
  immediately after writing-plans, Plan mode output, or any multi-step
  implementation plan — before offering execution or calling the plan complete.
---

# Review plan (GPT 5.5)

**Every plan must be reviewed by GPT 5.5 before it is presented as complete or execution starts.** Self-review alone is not enough.

Announce at start: **"Dispatching GPT 5.5 plan review."**

## When this is required

Run this skill **immediately after** any of:

- A plan file is saved (for example `docs/**/plans/*.md`)
- Plan mode produces an implementation plan in chat
- The writing-plans skill finishes a plan
- You draft a multi-step implementation plan inline (3+ tasks or touches multiple packages)

**Skip only when:** the user explicitly says to skip plan review for this session.

> **Global install:** Also at `~/.cursor/skills/review-plan/` with user hook `~/.cursor/hooks.json` (all projects).

## Step 1 — Gather review inputs

Collect before dispatching:

| Input | Source |
|-------|--------|
| `{PLAN}` | Full plan text or path to the saved plan file |
| `{SPEC}` | Original user request, issue body, or brainstorming spec |
| `{CONSTRAINTS}` | Relevant project rules: [AGENTS.md](../../AGENTS.md), privacy principles, git-flow if release-related |

Read the plan file with the Read tool if it was saved to disk.

## Step 2 — Dispatch GPT 5.5 reviewer (mandatory)

Use the **Task** tool with these settings:

| Parameter | Value |
|-----------|-------|
| `subagent_type` | `generalPurpose` |
| `model` | `gpt-5.5-medium` |
| `readonly` | `true` |
| `description` | `GPT 5.5 plan review` |

Fill the prompt from [plan-reviewer-prompt.md](plan-reviewer-prompt.md), replacing all `{PLACEHOLDER}` tokens.

**Do not** substitute a different model. If `gpt-5.5-medium` is unavailable, stop and tell the user — do not silently skip review.

## Step 3 — Act on feedback

| Severity | Action |
|----------|--------|
| **Critical** | Fix in the plan before presenting or executing |
| **Important** | Fix before execution; may present plan with noted fixes in progress |
| **Minor** | Note for execution; fix if trivial |

If Critical or Important issues were found:

1. Update the plan (and saved file if applicable)
2. **Re-dispatch** GPT 5.5 review (Step 2) on the revised plan
3. Repeat until no Critical issues remain and Important issues are resolved or explicitly accepted by the user

## Step 4 — Present the plan

Only after GPT 5.5 review passes, show the user:

1. **Plan location** (path or inline summary)
2. **Review verdict** — one line (Approved / Approved with minor notes / Revised after review)
3. **Notable review findings** — bullets for anything the user should know
4. **Execution options** — if using writing-plans handoff, offer subagent-driven vs inline execution

## Red flags — never do these

- Present a plan as "complete" without GPT 5.5 review
- Skip review because the plan "looks fine" or self-review passed
- Use the parent session model instead of dispatching `gpt-5.5-medium`
- Start implementation before review completes
- Ignore Critical findings
