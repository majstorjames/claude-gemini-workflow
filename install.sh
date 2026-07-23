#!/usr/bin/env bash
#
# Installer for the claude-gemini-workflow kit.
#
# Run from inside the target git repository:
#     bash ~/tools/claude-gemini-workflow/install.sh [--dry-run]
#
# Non-destructive: it NEVER overwrites your CLAUDE.md / GEMINI.md content. It only
# adds/refreshes the block between the marker comments, backs up anything it
# touches, and skips files that already exist (config, plan templates, hook).
#
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --yes|-y)    ASSUME_YES=1 ;;
    *) echo "Unknown option: $arg (supported: --dry-run, --yes)" >&2; exit 2 ;;
  esac
done

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Error: not inside a git repository. cd into your repo and re-run." >&2
  exit 1
}

START_MARK="<!-- claude-gemini-workflow:start -->"
END_MARK="<!-- claude-gemini-workflow:end -->"

# Inject a marked section into a target markdown file without disturbing the
# rest of the file. Replaces the block if the markers exist, appends it if they
# don't, creates the file if it's absent.
inject_section() {
  local target="$1" section="$2"
  local tmp; tmp="$(mktemp)"

  if [ ! -f "$target" ]; then
    cat "$section" > "$tmp"
  elif grep -qF "$START_MARK" "$target"; then
    awk -v start="$START_MARK" -v end="$END_MARK" -v blockfile="$section" '
      index($0, start) && !done {
        while ((getline line < blockfile) > 0) print line
        close(blockfile); done=1; inblock=1; next
      }
      inblock && index($0, end) { inblock=0; next }
      inblock { next }
      { print }
    ' "$target" > "$tmp"
  else
    cat "$target" > "$tmp"
    printf '\n' >> "$tmp"
    cat "$section" >> "$tmp"
  fi

  if [ "$DRY_RUN" = 1 ]; then
    echo "=== $target ==="
    if [ -f "$target" ]; then
      diff -u "$target" "$tmp" || true
    else
      echo "(would create new file)"
      cat "$tmp"
    fi
    rm -f "$tmp"
  else
    [ -f "$target" ] && cp "$target" "$target.bak"
    mv "$tmp" "$target"
    echo "  updated $target${target:+ (backup: $target.bak)}"
  fi
}

echo "Installing claude-gemini-workflow into: $ROOT"
[ "$DRY_RUN" = 1 ] && echo "(dry run — no files will be written)"

# 1) CLAUDE.md / GEMINI.md scaffolds
inject_section "$ROOT/CLAUDE.md" "$SRC_DIR/templates/CLAUDE.section.md"
inject_section "$ROOT/GEMINI.md" "$SRC_DIR/templates/GEMINI.section.md"

# 2) docs/plans templates (create-if-missing)
if [ "$DRY_RUN" != 1 ]; then
  mkdir -p "$ROOT/docs/plans"
fi
for f in CLAUDE_PLAN.template.md GEMINI_FEEDBACK.template.md; do
  dest="$ROOT/docs/plans/$f"
  if [ -f "$dest" ]; then
    echo "  skip docs/plans/$f (exists)"
  elif [ "$DRY_RUN" = 1 ]; then
    echo "  would create docs/plans/$f"
  else
    cp "$SRC_DIR/templates/docs/plans/$f" "$dest"
    echo "  created docs/plans/$f"
  fi
done

# 3) pre-commit hook
HOOK="$ROOT/.git/hooks/pre-commit"
if [ "$DRY_RUN" = 1 ]; then
  echo "  would install .git/hooks/pre-commit"
else
  if [ -f "$HOOK" ]; then
    cp "$HOOK" "$HOOK.bak"
    echo "  backed up existing pre-commit hook -> pre-commit.bak"
  fi
  cp "$SRC_DIR/hooks/pre-commit" "$HOOK"
  chmod +x "$HOOK"
  echo "  installed .git/hooks/pre-commit"
fi

# 3b) Claude Code plan-review hook (ExitPlanMode) + settings registration.
#     The plan-mode analogue of the pre-commit gate: a PreToolUse hook that runs
#     the reviewer over the plan Claude submits. The script is copied into the
#     repo (self-contained, like the git hook); the registration goes into the
#     git-ignored `.claude/settings.local.json` so it never clobbers a
#     team-shared `.claude/settings.json`. $CLAUDE_PROJECT_DIR is expanded by
#     Claude Code at hook time, keeping the command path relocatable.
CC_HOOK_DIR="$ROOT/.claude/hooks"
CC_HOOK="$CC_HOOK_DIR/plan-review"
CC_SETTINGS="$ROOT/.claude/settings.local.json"
CC_CMD='$CLAUDE_PROJECT_DIR/.claude/hooks/plan-review'

if [ "$DRY_RUN" = 1 ]; then
  echo "  would install .claude/hooks/plan-review"
  echo "  would register PreToolUse/ExitPlanMode hook in .claude/settings.local.json"
else
  mkdir -p "$CC_HOOK_DIR"
  cp "$SRC_DIR/hooks/plan-review" "$CC_HOOK"
  chmod +x "$CC_HOOK"
  echo "  installed .claude/hooks/plan-review"

  if command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    if [ -f "$CC_SETTINGS" ]; then
      cp "$CC_SETTINGS" "$CC_SETTINGS.bak"
      # Idempotent: drop any prior ExitPlanMode entry pointing at our command,
      # then append a fresh one — re-running never duplicates the hook.
      if jq --arg cmd "$CC_CMD" '
            .hooks //= {} | .hooks.PreToolUse //= [] |
            .hooks.PreToolUse |= map(select(
              ((.matcher == "ExitPlanMode") and (any((.hooks // [])[]; .command == $cmd))) | not
            )) |
            .hooks.PreToolUse += [ { matcher: "ExitPlanMode", hooks: [ { type: "command", command: $cmd, timeout: 60 } ] } ]
          ' "$CC_SETTINGS" > "$tmp"; then
        mv "$tmp" "$CC_SETTINGS"
        echo "  updated .claude/settings.local.json (backup: .claude/settings.local.json.bak)"
      else
        rm -f "$tmp"
        echo "  ⚠ could not parse existing .claude/settings.local.json — left unchanged. Register the hook manually."
      fi
    else
      jq -n --arg cmd "$CC_CMD" '
        { hooks: { PreToolUse: [ { matcher: "ExitPlanMode", hooks: [ { type: "command", command: $cmd, timeout: 60 } ] } ] } }
      ' > "$tmp" && mv "$tmp" "$CC_SETTINGS"
      echo "  created .claude/settings.local.json"
    fi
  else
    echo "  ⚠ 'jq' not found — cannot safely merge .claude/settings.local.json. Add this manually:"
    echo '      {"hooks":{"PreToolUse":[{"matcher":"ExitPlanMode","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/plan-review","timeout":60}]}]}}'
  fi
fi

# 4) config file (create-if-missing)
CONF="$ROOT/.claude-gemini-workflow.conf"
if [ -f "$CONF" ]; then
  echo "  skip .claude-gemini-workflow.conf (exists)"
elif [ "$DRY_RUN" = 1 ]; then
  echo "  would create .claude-gemini-workflow.conf"
else
  cp "$SRC_DIR/workflow.config.example.sh" "$CONF"
  echo "  created .claude-gemini-workflow.conf"
fi

# 5) scratch dir (under .git, so it's never committed)
[ "$DRY_RUN" != 1 ] && mkdir -p "$ROOT/.git/claude-gemini-workflow"

# 6) ignore local-only install artifacts (idempotent, marker-guarded)
GITIGNORE="$ROOT/.gitignore"
GI_MARKER="# claude-gemini-workflow"
if [ -f "$GITIGNORE" ] && grep -qF "$GI_MARKER" "$GITIGNORE"; then
  echo "  skip .gitignore (already has claude-gemini-workflow block)"
elif [ "$DRY_RUN" = 1 ]; then
  echo "  would add .gitignore block: .claude-gemini-workflow.conf, CLAUDE.md.bak, GEMINI.md.bak, .claude/settings.local.json*, .claude/hooks/plan-review"
else
  {
    printf '\n%s (local install artifacts)\n' "$GI_MARKER"
    printf '%s\n' ".claude-gemini-workflow.conf"
    printf '%s\n' "CLAUDE.md.bak"
    printf '%s\n' "GEMINI.md.bak"
    printf '%s\n' ".claude/settings.local.json"
    printf '%s\n' ".claude/settings.local.json.bak"
    printf '%s\n' ".claude/hooks/plan-review"
  } >> "$GITIGNORE"
  echo "  updated .gitignore"
fi

# 7) reviewer CLI prerequisite check
#    The hook invokes this at commit time. NOTE: `claude` is deliberately NOT
#    checked — no script here invokes it; it's how you DRIVE the workflow (the
#    planner), not a runtime dependency of the gate.
REVIEWER_CMD="gemini"
[ -f "$CONF" ] && REVIEWER_CMD="$( . "$CONF" >/dev/null 2>&1; printf '%s' "${REVIEWER_CMD:-gemini}" )"

echo ""
if command -v "$REVIEWER_CMD" >/dev/null 2>&1; then
  echo "  ✓ reviewer '$REVIEWER_CMD' found on PATH"
else
  echo "  ⚠ reviewer '$REVIEWER_CMD' NOT found on PATH — the commit gate will skip review until it's installed."
  if [ "$REVIEWER_CMD" = "gemini" ]; then
    if ! command -v npm >/dev/null 2>&1; then
      echo "    To install: first install Node.js (https://nodejs.org), then run:"
      echo "        npm install -g @google/gemini-cli"
    elif [ "$DRY_RUN" = 1 ]; then
      echo "    (dry run) would offer to install it via: npm install -g @google/gemini-cli"
    else
      do_install=0
      if [ "$ASSUME_YES" = 1 ]; then
        do_install=1
      elif [ -t 0 ]; then
        printf "    Install the Gemini CLI now (npm install -g @google/gemini-cli)? [y/N] "
        read -r reply || reply=""
        case "$reply" in [Yy]*) do_install=1 ;; esac
      fi
      if [ "$do_install" = 1 ]; then
        echo "    Installing @google/gemini-cli globally via npm..."
        if npm install -g @google/gemini-cli; then
          echo "    ✓ Gemini CLI installed."
        else
          echo "    ✗ npm install failed — install it manually: npm install -g @google/gemini-cli" >&2
        fi
      else
        echo "    Skipped. Install later with: npm install -g @google/gemini-cli   (or run without installing: npx @google/gemini-cli)"
      fi
    fi
  else
    echo "    Install '$REVIEWER_CMD' and ensure it's authenticated (see its own docs)."
  fi
fi

echo ""
echo "Done."
echo "Next steps:"
echo "  - Review the block added to CLAUDE.md / GEMINI.md (originals saved as *.bak)."
echo "  - Edit .claude-gemini-workflow.conf to set the reviewer CLI / model / mode."
echo "  - Authenticate the reviewer CLI on this machine (e.g. run 'gemini' once and sign in)."
echo "  - Gemini must TRUST this folder or reviews silently no-op. The seeded config exports"
echo "    GEMINI_CLI_TRUST_WORKSPACE=true to handle this; or run 'gemini' here once to trust it."
echo "  - The commit review runs on 'git commit'. Bypass with: git commit --no-verify"
echo "  - The PLAN review runs when Claude submits a plan (ExitPlanMode hook). Set"
echo "    PLAN_REVIEW_MODE=warn in .claude-gemini-workflow.conf for review-only, or remove"
echo "    the ExitPlanMode entry from .claude/settings.local.json to disable it."
echo "  - Undo file edits by restoring the .bak files."
