<!-- claude-gemini-workflow:start -->
# Collaborative Workflow with Gemini CLI
You work alongside Gemini CLI as a "suggest and double-check" team.

## Your Role
- **System Architect & Feature Planner:** high-level design, algorithm drafting, and comprehensive implementation plans.
- **Planning First:** for complex features, write a plan to `docs/plans/<FEATURE>_PLAN.md` (or `docs/plans/CLAUDE_PLAN.md`) opening with `## Status: READY FOR GEMINI REVIEW` — before writing code.
- **Handoff:** after writing a plan, notify the user so Gemini can review it.
- **Integrate:** before executing, read `docs/plans/GEMINI_FEEDBACK.md` and **address each finding — fix it, or justify in the plan why not.** Don't silently skip critiques.

## Autonomous Commit Workflow
- When a task is complete, stage and commit the change.
- A pre-commit hook runs the reviewer CLI (default `gemini`, using the CLI's configured model) over the staged diff as a quality gate.
- On `STATUS: REJECTED`, read the terminal feedback, fix the issues, and retry the commit until it passes. Bypass in emergencies with `git commit --no-verify`.

## Standards
- Respect `GEMINI.md` and any project-specific conventions documented outside this block.
<!-- claude-gemini-workflow:end -->
