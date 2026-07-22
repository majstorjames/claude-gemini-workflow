# claude-gemini-workflow

A portable, drop-in kit for the **"Claude plans → Gemini reviews"** collaboration loop.
Claude acts as architect/planner; a reviewer CLI (Gemini by default) double-checks both the
_plans_ and the _staged code_ before it lands.

## The loop

1. **Plan** — Claude writes an implementation plan to `docs/plans/<FEATURE>_PLAN.md` opening
   with `## Status: READY FOR GEMINI REVIEW`, then notifies you.
2. **Review** — Gemini verifies the plan against the real codebase as an _independent_ reviewer,
   focusing on what the author is blind to — architecture/system fit, requirement & edge-case
   gaps, integration/contract compatibility, and simpler alternatives — and writes critiques to
   `docs/plans/GEMINI_FEEDBACK.md` (opening with a `**Status: ...**` line + numbered **Fix:**
   items).
3. **Integrate** — Claude reads the feedback and folds it in before coding.
4. **Commit gate** — on `git commit`, a pre-commit hook runs the reviewer over the staged diff.
   `STATUS: REJECTED` aborts the commit with actionable feedback; Claude fixes and retries.

## Install

**1. Get the kit** — clone it once to a stable location outside any single project:

```bash
git clone https://github.com/majstorjames/claude-gemini-workflow ~/tools/claude-gemini-workflow
# update later with:  git -C ~/tools/claude-gemini-workflow pull
```

**2. Install into a repo** — from inside the git repo you want to add the workflow to:

```bash
cd /path/to/your-repo
bash ~/tools/claude-gemini-workflow/install.sh --dry-run   # preview — writes nothing
bash ~/tools/claude-gemini-workflow/install.sh             # apply
```

The installer is **non-destructive**:

- Your existing `CLAUDE.md` / `GEMINI.md` are never overwritten — the scaffold is injected
  between `<!-- claude-gemini-workflow:start -->` / `:end` markers (replaced on re-run, appended
  if absent). Originals are backed up to `*.bak`.
- Plan templates, the config file, and any pre-existing `pre-commit` hook are backed up / only
  created if missing.
- Re-running is idempotent.

## Applying to other repositories

The kit is self-contained: the installer targets **the git repo of your current directory** and
reads its templates/hook from **its own folder**. So the single central clone from the Install
step above can install into any number of repos — just `cd` into each one and run its
`install.sh`:

```bash
cd /path/to/other-repo
bash ~/tools/claude-gemini-workflow/install.sh --dry-run   # preview
bash ~/tools/claude-gemini-workflow/install.sh             # apply
```

**Alternative — vendored per repo:** clone the kit _into_ a repo (e.g. under `tools/`) and run it
locally, so the workflow travels with that project:

```bash
cd /path/to/other-repo
git clone https://github.com/majstorjames/claude-gemini-workflow tools/claude-gemini-workflow
bash tools/claude-gemini-workflow/install.sh
```

Each install is non-destructive and idempotent, and adds a `.gitignore` block for its own local
artifacts automatically. After installing, remember to:

- edit `.claude-gemini-workflow.conf` for the reviewer CLI / model / mode;
- ensure the reviewer CLI (e.g. `gemini`) is installed **and authenticated** on that machine;
- bypass a review with `git commit --no-verify`; undo file edits via the `*.bak` files.

## Configure

Installed to the repo root as `.claude-gemini-workflow.conf`:

```sh
REVIEWER_CMD="gemini"   # swap to another review CLI (codex, claude, etc.)
REVIEWER_MODEL=""       # empty = use the CLI's default model; set (e.g. "gemini-3.6-flash") to pin one
REVIEW_MODE="block"     # "block" = reject aborts commit; "warn" = review only
```

> The reviewer model is for the **review check only** — it does not touch your app's own LLM
> configuration.

The hook invokes the reviewer as `"$REVIEWER_CMD" [-m "$REVIEWER_MODEL"]` with the prompt piped on
stdin — the `-m` flag is only passed when `REVIEWER_MODEL` is non-empty, so an empty value lets the
CLI choose its own default model. To use a CLI with different flags, edit `.git/hooks/pre-commit`.

## Bypass

```bash
git commit --no-verify
```

## Uninstall

Restore the `*.bak` files, delete `.claude-gemini-workflow.conf`, and remove
`.git/hooks/pre-commit` (or restore `pre-commit.bak`).

## Contents

```
install.sh                     one-command installer (--dry-run supported)
workflow.config.example.sh     default reviewer CLI / model / mode
hooks/pre-commit               the review-gate hook
templates/
  CLAUDE.section.md            planner scaffold (Claude side)
  GEMINI.section.md            reviewer scaffold (Gemini side)
  docs/plans/*.template.md     plan + feedback skeletons
```

## License

[MIT](LICENSE) — free to use, modify, and distribute.
