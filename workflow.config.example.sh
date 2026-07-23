# claude-gemini-workflow configuration
# This file is sourced by the pre-commit hook. Copied to the repo root as
# `.claude-gemini-workflow.conf` at install time. Edit values to taste.

# Reviewer CLI command (must be on PATH). Swap to another review CLI here.
REVIEWER_CMD="gemini"

# Reviewer model. Used ONLY for the Claude<->Gemini review check.
# Leave empty to use the reviewer CLI's own default model.
# NOTE: the gemini CLI does NOT validate this — an unknown id silently falls
# back to a default — so only pin a confirmed-real model id.
# gemini-3.5-flash is the "most intelligent" flash and a strong reviewer.
REVIEWER_MODEL="gemini-3.5-flash"

# "block" = a STATUS: REJECTED review aborts the commit (exit 1).
# "warn"  = always print the review but never block the commit.
REVIEW_MODE="block"

# Strictness of the PLAN gate — the Claude Code ExitPlanMode hook that reviews a
# plan Claude generates BEFORE any code is written (the plan-mode analogue of the
# commit gate above). Uses the same REVIEWER_CMD / REVIEWER_MODEL as the commit
# gate — only the strictness is separate.
# "block" = a STATUS: REJECTED plan is denied and the feedback is fed back to
#           Claude to revise the plan before you see it.
# "warn"  = always print the review but never block the plan.
PLAN_REVIEW_MODE="block"

# Gemini refuses to run in an "untrusted" folder in headless/automated mode —
# exactly how the pre-commit hook calls it — which makes the review silently
# no-op. This file is sourced by the hook, so exporting the trust flag here makes
# the review invocation run. Affects the review call only. Comment out to opt out
# (then trust the folder once interactively by running `gemini` in the repo).
export GEMINI_CLI_TRUST_WORKSPACE=true
