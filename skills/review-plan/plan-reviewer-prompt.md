# Plan review prompt template

Copy into the Task tool `prompt` field. Replace `{PLACEHOLDER}` tokens.

---

You are an independent plan reviewer. You have **no** prior context from the planning session — judge only from what is below.

## Your job

Review this implementation plan for correctness, completeness, and fit with project constraints. Be rigorous. The planner already self-reviewed; your job is to catch what they missed.

## Spec / requirements

{SPEC}

## Project constraints

{CONSTRAINTS}

## Plan under review

{PLAN}

## Review checklist

1. **Spec coverage** — Every requirement maps to a concrete task. List gaps.
2. **Placeholder scan** — Flag TBD, TODO, "implement later", vague steps ("add error handling"), or steps without actual code/commands where code is needed.
3. **Consistency** — Types, names, file paths, and APIs match across tasks.
4. **Scope** — No unrelated changes; YAGNI respected.
5. **Testing** — Each behaviour change has a verifiable test step with exact commands and expected output.
6. **Privacy & product truth** — No claims that recording can be proven; no cloud/telemetry unless explicitly requested; local-first preserved.
7. **Repo conventions** — Matches AGENTS.md (branching, package boundaries, Flutter/Dart patterns).
8. **Risk** — Ordering bugs, missing migrations, breaking changes, or steps that could leave the repo in a broken state.

## Output format

```markdown
## Plan review (GPT 5.5)

**Verdict:** APPROVED | APPROVED WITH NOTES | NEEDS REVISION

### Strengths
- ...

### Issues

#### Critical (must fix before execution)
- ...

#### Important (should fix before execution)
- ...

#### Minor (optional)
- ...

### Spec coverage gaps
- ...

### Recommendation
[One paragraph: proceed, revise and re-review, or split the plan]
```

Be specific. Reference task numbers and file paths. If the plan is solid, say so briefly — do not invent problems.
