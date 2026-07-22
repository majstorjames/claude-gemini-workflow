#!/usr/bin/env bash
#
# Installer for the claude-gemini-workflow kit.
#
# Run from inside the target git repository:
#     bash /path/to/tools/claude-gemini-workflow/install.sh [--dry-run]
#
# Non-destructive: it NEVER overwrites your CLAUDE.md / GEMINI.md content. It only
# adds/refreshes the block between the marker comments, backs up anything it
# touches, and skips files that already exist (config, plan templates, hook).
#
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

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
  echo "  would add .gitignore block: .claude-gemini-workflow.conf, CLAUDE.md.bak, GEMINI.md.bak"
else
  {
    printf '\n%s (local install artifacts)\n' "$GI_MARKER"
    printf '%s\n' ".claude-gemini-workflow.conf"
    printf '%s\n' "CLAUDE.md.bak"
    printf '%s\n' "GEMINI.md.bak"
  } >> "$GITIGNORE"
  echo "  updated .gitignore"
fi

echo ""
echo "Done."
echo "Next steps:"
echo "  - Review the block added to CLAUDE.md / GEMINI.md (originals saved as *.bak)."
echo "  - Edit .claude-gemini-workflow.conf to set the reviewer CLI / model / mode."
echo "  - The review runs on 'git commit'. Bypass with: git commit --no-verify"
echo "  - Undo file edits by restoring the .bak files."
