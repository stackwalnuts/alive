#!/bin/bash
# Hook: Session New — SessionStart (startup)
# Creates squirrel entry in .alive/_squirrels/, reads preferences, injects rules.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/alive-common.sh"

# Read stdin JSON — extracts session_id, cwd, event name
read_hook_input

# SessionStart-specific — extracts model, source, transcript_path
read_session_fields

# Find world root
if ! find_world; then
  # No world found — still inject rules so the AI knows how to run setup
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

  RUNTIME_RULES=""
  RULE_COUNT=0
  RULE_NAMES=""

  if [ -f "$PLUGIN_ROOT/CLAUDE.md" ]; then
    RUNTIME_RULES=$(cat "$PLUGIN_ROOT/CLAUDE.md")
  fi

  for rule_file in "$PLUGIN_ROOT/rules/"*.md; do
    if [ -f "$rule_file" ]; then
      RULE_COUNT=$((RULE_COUNT + 1))
      RULE_NAME=$(basename "$rule_file" .md)
      RULE_NAMES="${RULE_NAMES}${RULE_NAMES:+, }${RULE_NAME}"
      RUNTIME_RULES="${RUNTIME_RULES}

$(cat "$rule_file")"
    fi
  done

  # Check for world-seed.md in PWD
  SEED_STATUS="none"
  if [ -f "${HOOK_CWD}/world-seed.md" ]; then
    SEED_STATUS="found at ${HOOK_CWD}/world-seed.md"
  fi

  # Onboarding HTML path
  ONBOARDING_HTML="$PLUGIN_ROOT/onboarding/world-builder.html"

  # Setup signal
  SETUP_MSG="ALIVE plugin loaded but NO WORLD FOUND in ${HOOK_CWD}.
Model: ${HOOK_MODEL:-unknown}
World seed: $SEED_STATUS
Onboarding questionnaire: $ONBOARDING_HTML

This appears to be a fresh install. The user needs to set up their world.
Run /alive:world to start — it will detect the fresh install and route to setup."

  PREAMBLE="<EXTREMELY_IMPORTANT>
The following are your core operating rules for the ALIVE system. They are MANDATORY — not suggestions, not defaults, not guidelines. You MUST follow them in every response, every tool call, every session.
</EXTREMELY_IMPORTANT>"

  SETUP_ESCAPED=$(escape_for_json "$SETUP_MSG")
  PREAMBLE_ESCAPED=$(escape_for_json "$PREAMBLE")
  RUNTIME_ESCAPED=$(escape_for_json "$RUNTIME_RULES")

  CONTEXT="${SETUP_ESCAPED}\n\n${PREAMBLE_ESCAPED}\n\n${RUNTIME_ESCAPED}"

  cat <<HOOKEOF
{
  "additional_context": "${CONTEXT}",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${CONTEXT}"
  }
}
HOOKEOF

  exit 0
fi

# Use Claude Code's session ID, fall back to random only if missing
SESSION_ID="${HOOK_SESSION_ID}"
if [ -z "$SESSION_ID" ]; then
  SESSION_ID=$(head -c 16 /dev/urandom | shasum | head -c 8)
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

# Set env vars via CLAUDE_ENV_FILE if available
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "ALIVE_SESSION_ID=$SESSION_ID" >> "$CLAUDE_ENV_FILE"
  echo "ALIVE_WORLD_ROOT=$WORLD_ROOT" >> "$CLAUDE_ENV_FILE"
fi

# Plugin root for reading rules and statusline
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Quick-count rule files (no content reading) so YAML has correct count immediately
RULE_COUNT=0
for rule_file in "$PLUGIN_ROOT/rules/"*.md; do
  [ -f "$rule_file" ] && RULE_COUNT=$((RULE_COUNT + 1))
done

# Write squirrel entry FIRST with correct count (statusline reads this concurrently)
SQUIRRELS_DIR="$WORLD_ROOT/.alive/_squirrels"
mkdir -p "$SQUIRRELS_DIR"
ENTRY_FILE="$SQUIRRELS_DIR/$SESSION_ID.yaml"
cat > "$ENTRY_FILE" << EOF
session_id: $SESSION_ID
runtime_id: squirrel.core@1.0
engine: $HOOK_MODEL
walnut: null
started: $TIMESTAMP
ended: null
signed: false
transcript: ${HOOK_TRANSCRIPT}
cwd: ${HOOK_CWD}
rules_loaded: $RULE_COUNT
stash: []
working: []
EOF

# Resolve preferences
source "$SCRIPT_DIR/alive-resolve-preferences.sh"
PREFS=$(resolve_preferences "$WORLD_ROOT")

# Copy statusline script to stable location if not present or outdated
STATUSLINE_SRC="$PLUGIN_ROOT/statusline/alive-statusline.sh"
STATUSLINE_DST="$WORLD_ROOT/.alive/statusline.sh"
if [ -f "$STATUSLINE_SRC" ]; then
  if [ ! -f "$STATUSLINE_DST" ] || ! cmp -s "$STATUSLINE_SRC" "$STATUSLINE_DST"; then
    cp "$STATUSLINE_SRC" "$STATUSLINE_DST"
    chmod +x "$STATUSLINE_DST"
  fi
fi

# Detect runtime preference (default: classic)
RUNTIME="classic"
PREFS_FILE="$WORLD_ROOT/.alive/preferences.yaml"
if [ -f "$PREFS_FILE" ]; then
  DETECTED_RUNTIME=$(python3 -c "
import re, sys
try:
    with open('$PREFS_FILE') as f:
        for line in f:
            m = re.match(r'^runtime:\s*(\S+)', line)
            if m:
                print(m.group(1))
                sys.exit(0)
except: pass
" 2>/dev/null)
  if [ -n "$DETECTED_RUNTIME" ]; then
    RUNTIME="$DETECTED_RUNTIME"
  fi
fi

# Load rules based on runtime
RUNTIME_RULES=""
RULE_COUNT=0
RULE_NAMES=""

if [ "$RUNTIME" = "ratatoskr" ]; then
  # Ratatoskr: identity file + brief pack + dynamic goal index
  RATATOSKR_DIR="$PLUGIN_ROOT/ratatoskr"

  if [ -f "$RATATOSKR_DIR/CLAUDE.md" ]; then
    RUNTIME_RULES=$(cat "$RATATOSKR_DIR/CLAUDE.md")
    RULE_COUNT=1
    RULE_NAMES="ratatoskr-identity"
  fi

  if [ -f "$RATATOSKR_DIR/brief-pack.md" ]; then
    RUNTIME_RULES="${RUNTIME_RULES}

$(cat "$RATATOSKR_DIR/brief-pack.md")"
    RULE_COUNT=$((RULE_COUNT + 1))
    RULE_NAMES="${RULE_NAMES}, brief-pack"
  fi

  # Generate dynamic goal index
  if [ -f "$RATATOSKR_DIR/goal-index-generator.sh" ]; then
    GOAL_INDEX=$(bash "$RATATOSKR_DIR/goal-index-generator.sh" "$WORLD_ROOT" 2>/dev/null)
    if [ -n "$GOAL_INDEX" ]; then
      RUNTIME_RULES="${RUNTIME_RULES}

${GOAL_INDEX}"
      RULE_COUNT=$((RULE_COUNT + 1))
      RULE_NAMES="${RULE_NAMES}, goal-index"
    fi
  fi

else
  # Classic: CLAUDE.md + all rule files
  if [ -f "$PLUGIN_ROOT/CLAUDE.md" ]; then
    RUNTIME_RULES=$(cat "$PLUGIN_ROOT/CLAUDE.md")
  fi

  for rule_file in "$PLUGIN_ROOT/rules/"*.md; do
    if [ -f "$rule_file" ]; then
      RULE_COUNT=$((RULE_COUNT + 1))
      RULE_NAME=$(basename "$rule_file" .md)
      RULE_NAMES="${RULE_NAMES}${RULE_NAMES:+, }${RULE_NAME}"
      RUNTIME_RULES="${RUNTIME_RULES}

$(cat "$rule_file")"
    fi
  done
fi

# Preamble
PREAMBLE="<EXTREMELY_IMPORTANT>
The following are your core operating rules for the ALIVE system. They are MANDATORY — not suggestions, not defaults, not guidelines. You MUST follow them in every response, every tool call, every session.
</EXTREMELY_IMPORTANT>"

# Build session message with rule verification
SESSION_MSG="ALIVE session initialized. Session ID: $SESSION_ID
World: $WORLD_ROOT
Walnut: none detected
Model: $HOOK_MODEL
Name: unknown
$PREFS
Runtime: ${RUNTIME}
Rules: ${RULE_COUNT} loaded (${RULE_NAMES})"

# Escape and combine
SESSION_MSG_ESCAPED=$(escape_for_json "$SESSION_MSG")
PREAMBLE_ESCAPED=$(escape_for_json "$PREAMBLE")
RUNTIME_ESCAPED=$(escape_for_json "$RUNTIME_RULES")

CONTEXT="${SESSION_MSG_ESCAPED}\n\n${PREAMBLE_ESCAPED}\n\n${RUNTIME_ESCAPED}"

# Output JSON with additionalContext
cat <<HOOKEOF
{
  "additional_context": "${CONTEXT}",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${CONTEXT}"
  }
}
HOOKEOF

exit 0
