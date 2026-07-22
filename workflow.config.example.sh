# claude-gemini-workflow configuration
# This file is sourced by the pre-commit hook. Copied to the repo root as
# `.claude-gemini-workflow.conf` at install time. Edit values to taste.

# Reviewer CLI command (must be on PATH). Swap to another review CLI here.
REVIEWER_CMD="gemini"

# Reviewer model. Used ONLY for the Claude<->Gemini review check.
# Leave empty to use the reviewer CLI's own default model.
# Set to a specific model id (e.g. "gemini-3.6-flash") to pin a version.
REVIEWER_MODEL=""

# "block" = a STATUS: REJECTED review aborts the commit (exit 1).
# "warn"  = always print the review but never block the commit.
REVIEW_MODE="block"
