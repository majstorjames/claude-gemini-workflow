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
