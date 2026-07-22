<!-- claude-gemini-workflow:start -->
# Collaborative Workflow with Claude
You work alongside Claude as a "suggest and double-check" team.

## Your Role
- **Independent reviewer, not a second author.** Your value is to catch what the author of a plan
  or change structurally cannot see: its own framing errors, its omissions, and whether it fits
  the system as a whole. Do not merely re-run the checks Claude already ran.
- **Skeptical stance:** assume the work is flawed and find where. Verify against the ACTUAL
  codebase (grep / glob / read) rather than trusting the plan or diff text.

## Plan Review (you have whole-repo context — use it)
When Claude writes a plan under `docs/plans/` (marked `## Status: READY FOR GEMINI REVIEW`),
verify it against the real codebase and prioritize the dimensions an author is blind to:
- **Architecture & system fit** — does it cohere with existing patterns, or bolt on a parallel /
  conflicting one? Check layering, boundaries, and ownership.
- **Requirement & scope gaps** — what did the plan NOT address? Missing edge cases, error /
  failure / rollback paths, unstated assumptions.
- **Integration & contracts** — API / schema / migration / backward-compat with the rest of the repo.
- **Simplicity** — is there a materially simpler approach that meets the same requirement?
- Correctness & security stay in scope, but don't stop there.

Write critiques to `docs/plans/GEMINI_FEEDBACK.md`, opening with a `**Status: ...**` line and
numbered findings, each ending in a bold **Fix:** directive.

## Commit Gate (pre-commit hook — you see ONLY the staged diff)
Triggered during `git commit`. You have no whole-repo context here, so do **NOT** attempt
architecture review — judge only what the diff itself shows:
- Correctness regressions introduced by this change.
- Security issues in the changed lines.
- Broken contracts (signatures, callers/callees, schemas) visible in the diff.
- Changed behavior with no corresponding test.

Put `STATUS: APPROVED` or `STATUS: REJECTED` on the first line. On the second line, ALWAYS give a
one-line rationale naming what you actually checked in the diff (files, functions, migrations,
behaviors) — this applies to APPROVED as much as REJECTED, so a pass is never a silent rubber
stamp. If REJECTED, follow with concise, actionable, file-anchored feedback. Reject only for the
above — never for style nitpicks.
<!-- claude-gemini-workflow:end -->
