# Agent skills (tool-agnostic)

Step-by-step playbooks for AI assistants (Cursor, Copilot, Claude Code, Codex, Gemini CLI, etc.). **Not** tied to `.cursor/` — safe to commit and share.

## How to use

| You say (examples) | Skill to load |
|--------------------|---------------|
| "create release", "start release", "release 0.2.0" | [create-release/SKILL.md](create-release/SKILL.md) |
| "ship release", "run release workflow", "tag and upload" | [ship-release/SKILL.md](ship-release/SKILL.md) |
| "create branch for issue 42", "feature branch from issue" | [create-feature-branch/SKILL.md](create-feature-branch/SKILL.md) |
| "hotfix", "patch production" | [hotfix/SKILL.md](hotfix/SKILL.md) |
| "backmerge", "sync main to dev" | [backmerge/SKILL.md](backmerge/SKILL.md) |
| "release status", "where are we with main/dev" | [release-status/SKILL.md](release-status/SKILL.md) |

**Agents:** When the user’s request matches a row above, **read that `SKILL.md` in full** before running commands, then follow it step by step. Report progress after each step; ask before destructive or irreversible actions (push, merge, workflow dispatch).

**Humans:** `@skills/create-release/SKILL.md` in chat, or paste the file into your assistant’s project instructions.

Canonical git docs: [docs/git-flow.md](../docs/git-flow.md). Product rules: [AGENTS.md](../AGENTS.md).
