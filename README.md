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

Two of these steps are also **enforced automatically**, so the loop holds even when nobody
remembers to run it:

- **Plan gate** — when Claude submits a plan in Claude Code's plan mode (the `ExitPlanMode` tool),
  a `PreToolUse` hook runs the reviewer over the plan _before_ you approve it. `STATUS: REJECTED`
  (in `block` mode) denies the plan and feeds the critique straight back to Claude to revise; in
  `warn` mode it just prints the review. Same reviewer, same rubric as step 2.
- **Commit gate** — on `git commit`, a pre-commit hook runs the reviewer over the staged diff and
  prints a pass/fail banner: a green **✓ REVIEW PASSED** with an itemized checklist of what was
  verified, or a red **✗ REVIEW FAILED** with actionable feedback. `STATUS: REJECTED` aborts the
  commit; Claude fixes and retries — at most twice, then it stops and hands everything to you
  rather than looping. (Color shows only on an interactive terminal.)

**Optional — arbitration.** A rejected gate doesn't mean the reviewer was right. If the repo has a
`.claude/agents/gate-arbiter.md` agent (the installer seeds one), Claude routes the findings there
first. The arbiter judges each finding **cold** — it didn't write the code and has no conversation
context — against the diff and the repo, and returns a per-finding verdict:

- **VALID** → Claude fixes it, using the arbiter's precise fix description.
- **INVALID** → dismissed, with the evidence that refutes it.
- **UNCERTAIN** → **escalated to you**, with both the reviewer's claim and the arbiter's reasoning.

The template carries an **undismissable concerns** placeholder: fill it with your repo's critical
domains (data integrity, auth, money, migrations, public contracts — whatever applies), and
findings touching them can only be fixed or escalated, never dismissed. Findings are classified by
practical effect rather than wording, and ties break toward escalation. If the repo keeps a
`decisions.md` at its root, the arbiter reads it first and won't re-escalate what you've already
ruled on. This is why the reviewer scaffold insists each finding be specific and evidence-anchored:
it has to survive being judged by someone who wasn't there.

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
- `.claude/agents/gate-arbiter.md` is created only if absent — an existing one is left completely
  alone, so the concerns you wrote into it survive every upgrade.
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
- ensure the reviewer CLI (e.g. `gemini`) is installed, **authenticated**, and — for Gemini —
  able to **trust this folder** (see [Prerequisites & trust](#prerequisites--trust));
- fill in the **undismissable concerns** placeholder in `.claude/agents/gate-arbiter.md` with your
  repo's critical domains (the installer reminds you when it creates the file);
- undo file edits via the `*.bak` files; bypass a review with `git commit --no-verify` (see
  [Bypass](#bypass)).

The installer also **checks for the reviewer CLI** at the end. If `gemini` is missing it offers
to install it (`npm install -g @google/gemini-cli`); pass `--yes` to auto-confirm in
non-interactive use. `claude` itself is **not** checked or installed — no script invokes it; it's
how you *drive* the workflow, not a runtime dependency of the commit gate.

### Opting out / retiring

If a repo decides to retire the workflow, make that decision stick against future installer runs:
create `.claude-gemini-workflow.disabled` at the repo root with a one-line reason (ideally a
pointer to the decision doc), and remove the hooks per [Uninstall](#uninstall). From then on every
`install.sh` run against that repo — including `--dry-run` — is a no-op: it prints the reason and
exits before touching any file, so a habitual re-run can't silently reinstate the workflow.
Delete the sentinel file to re-enable installs.

## Configure

Installed to the repo root as `.claude-gemini-workflow.conf`:

```sh
REVIEWER_CMD="gemini"    # swap to another review CLI (codex, claude, etc.)
REVIEWER_MODEL=""        # empty = use the CLI's default model; set (e.g. "gemini-3.6-flash") to pin one
REVIEW_MODE="block"      # commit gate: "block" = reject aborts commit; "warn" = review only
PLAN_REVIEW_MODE="block" # plan gate: "block" = reject denies + revises the plan; "warn" = review only
export GEMINI_CLI_TRUST_WORKSPACE=true   # let Gemini run in this folder headlessly (see below)
```

> The reviewer model is for the **review check only** — it does not touch your app's own LLM
> configuration.

The hook invokes the reviewer as `"$REVIEWER_CMD" [-m "$REVIEWER_MODEL"]` with the prompt piped on
stdin — the `-m` flag is only passed when `REVIEWER_MODEL` is non-empty, so an empty value lets the
CLI choose its own default model. To use a CLI with different flags, edit `.git/hooks/pre-commit`.

## Prerequisites & trust

The reviewer CLI must be **installed and authenticated** on the machine that commits. For the
default reviewer that's the [Gemini CLI](https://github.com/google-gemini/gemini-cli):

```bash
npm install -g @google/gemini-cli   # or run without installing: npx @google/gemini-cli
gemini                              # once, to sign in
```

The **plan gate** also needs [`jq`](https://jqlang.github.io/jq/) — the installer uses it to merge
the hook into `.claude/settings.local.json`, and the hook uses it to read the plan out of the
`ExitPlanMode` payload. Without `jq` the commit gate still works; the plan gate degrades safely
(the installer prints the entry to add by hand, and the hook fails open rather than blocking).

**Workspace trust.** Gemini refuses to run in an "untrusted" folder in the headless/automated
mode the pre-commit hook uses — so an untrusted repo makes the review **silently no-op** (the hook
prints a loud ⚠ `REVIEW DID NOT RUN — commit allowed (UNREVIEWED)` banner and lets the commit
through). Fix it either way:

- **Config (default):** the seeded `.claude-gemini-workflow.conf` exports
  `GEMINI_CLI_TRUST_WORKSPACE=true`. The hook sources the conf, so this makes the review call run.
  Comment the line out to opt out.
- **Interactive:** run `gemini` in the repo once and accept the trust prompt.

> **Upgrading an existing install:** `git pull` the kit and re-run `install.sh`. It refreshes the
> hooks and the marked `CLAUDE.md` / `GEMINI.md` blocks, and **appends any config keys the kit has
> gained** (e.g. `PLAN_REVIEW_MODE`) to your `.claude-gemini-workflow.conf` — backing it up to
> `.claude-gemini-workflow.conf.bak` first. Your existing **values are never changed** (a key
> that's already set, even if commented out, is left alone), so you only edit a value when you want
> to override its default.

## Troubleshooting

**⚠ REVIEW DID NOT RUN — commit allowed (UNREVIEWED).** Both gates **fail open**: if the reviewer
CLI errors, the commit (or plan) goes through *unreviewed* rather than being blocked by a broken
tool. That banner means no review happened — treat it as a failure, not a pass. The hook reads the
reviewer's stderr and names the likely cause; the three seen in practice:

| Symptom in stderr | Cause | Fix |
|---|---|---|
| `API_KEY_INVALID` / `API key not valid` | invalid or not-yet-propagated API key | check `GEMINI_API_KEY`; if the key is new, wait a few minutes and retry |
| `UNAUTHENTICATED` / `ACCESS_TOKEN_TYPE_UNSUPPORTED` | CLI not authenticated, or a stale credential | run `gemini` interactively and re-select the auth method |
| trust / untrusted-folder wording | workspace not trusted | see [Prerequisites & trust](#prerequisites--trust) |

**`AQ.`-prefixed keys are valid.** Google's current API-key format starts with `AQ.`, not the older
`AIza`. Don't rotate a key just because of its prefix. A freshly created key can be rejected for a
few minutes before it propagates, so retry the identical invocation before concluding it's bad.

**Multiple `gemini` installs shadow each other.** A Homebrew and an npm install can sit on the same
PATH at different versions, so the one you tested interactively isn't the one the hook runs.
`which -a gemini` reveals it — keep exactly one.

**OAuth may be unavailable.** Google-account (OAuth) sign-in for individuals can be blocked pending
the Antigravity migration. API-key auth is the reliable path for the hooks.

**`git pull` on a kit clone aborts over `.gitignore`.** An older install edited the kit's own
tracked `.gitignore`. Run `git checkout -- .gitignore` and pull again; current installs detect the
kit's own repo and skip that step.

## Bypass

```bash
git commit --no-verify                         # skip the commit gate for one commit
```

This is a **user-authorized** escape hatch, not an agent one: the Claude scaffold instructs Claude
never to reach for `--no-verify` on its own — only when you explicitly tell it to in that session.
A gate Claude can silently skip is not a gate. When Claude can't get past the reviewer, the
intended outcome is escalation to you, not a bypass.

For the **plan gate**: set `PLAN_REVIEW_MODE="warn"` in `.claude-gemini-workflow.conf` to make it
review-only, or remove the `ExitPlanMode` entry from `.claude/settings.local.json` to disable it.

## Uninstall

Restore the `*.bak` files, delete `.claude-gemini-workflow.conf`, and remove
`.git/hooks/pre-commit` (or restore `pre-commit.bak`). For the plan gate, remove
`.claude/hooks/plan-review` and the `ExitPlanMode` entry from `.claude/settings.local.json`. For
arbitration, delete `.claude/agents/gate-arbiter.md` — with no arbiter present, Claude falls back
to reading the reviewer's feedback directly.

To make the removal permanent, also create a `.claude-gemini-workflow.disabled` sentinel at the
repo root with a one-line reason — future `install.sh` runs then no-op instead of reinstalling
(see [Opting out / retiring](#opting-out--retiring)).

## Contents

```
install.sh                     one-command installer (--dry-run supported)
workflow.config.example.sh     default reviewer CLI / model / mode
hooks/pre-commit               the commit review-gate hook (git)
hooks/plan-review              the plan review-gate hook (Claude Code ExitPlanMode)
templates/
  CLAUDE.section.md            planner scaffold (Claude side)
  GEMINI.section.md            reviewer scaffold (Gemini side)
  agents/gate-arbiter.template.md  arbiter agent that adjudicates failed-gate findings
  docs/plans/*.template.md     plan + feedback skeletons

seeded in your repo (create-if-missing):
decisions.md                   escalation ledger — gate dispute rulings the arbiter reads first
```

## License

[MIT](LICENSE) — free to use, modify, and distribute.
