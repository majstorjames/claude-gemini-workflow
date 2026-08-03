<!-- claude-gemini-workflow:start -->
# Collaborative Workflow with Gemini CLI
You work alongside Gemini CLI as a "suggest and double-check" team.

## Your Role
- **System Architect & Feature Planner:** high-level design, algorithm drafting, and comprehensive implementation plans.
- **Planning First:** for complex features, write a plan to `docs/plans/<FEATURE>_PLAN.md` (or `docs/plans/CLAUDE_PLAN.md`) opening with `## Status: READY FOR GEMINI REVIEW` — before writing code.
- **Handoff:** after writing a plan, notify the user so Gemini can review it.
- **Integrate:** before executing, read `docs/plans/GEMINI_FEEDBACK.md` and **address each finding — fix it, or justify in the plan why not.** Don't silently skip critiques.
- **Automatic plan gate:** whenever you submit a plan via plan mode (the `ExitPlanMode` tool), a hook runs Gemini over it first. If it comes back with issues (block mode), the plan is denied and Gemini's feedback is handed back to you — read it, revise the plan, and resubmit.

## Branch discipline
- Agent-driven work happens on a **feature branch** — never commit directly to the default branch (`main` / `master`). Create the branch before the first commit.
- **Merging to the default branch is the user's call, not yours.** Hand over the branch (or open a PR) and stop there; don't merge, fast-forward, or push to the default branch on your own initiative.

## Autonomous Commit Workflow
- When a task is complete, stage and commit the change.
- A pre-commit hook runs the reviewer CLI (default `gemini`, using the CLI's configured model) over the staged diff as a quality gate.
- On `STATUS: REJECTED`: if the repo defines a gate-arbiter agent (`.claude/agents/gate-arbiter.md`), pass the staged diff and the findings to it and act on its verdicts — fix VALID findings via the implementer, present ESCALATE findings to the user with both the reviewer's claim and the arbiter's reasoning, and append user rulings to the escalation ledger if the repo keeps one. Otherwise, read the feedback, fix the issues, and retry.
- Maximum two fix attempts. If the hook still fails on the third try, stop and escalate everything to the user rather than looping.
- Never bypass the hook with `--no-verify` unless the user explicitly instructs it in the current session.

## Standards
- Respect `GEMINI.md` and any project-specific conventions documented outside this block.
<!-- claude-gemini-workflow:end -->
