#!/bin/bash

# Walnut namespace guard — only fire inside an ALIVE world
find_world() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/01_Archive" ] && [ -d "$dir/02_Life" ]; then
      WORLD_ROOT="$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}
find_world || exit 0

# Hook: Rules Guardian — PreToolUse (Edit|Write)
# Blocks edits to plugin-managed rules, CLAUDE.md, and plugin cache files.
# Conductor customizations go in .claude/rules/user-overrides.md instead.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Always allow: user overrides, preferences, walnut-level config
case "$FILE_PATH" in
  */user-overrides.md|*/preferences.yaml|*/_core/config.yaml)
    exit 0
    ;;
esac

DENY_MSG='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"🐿️ This file is managed by the walnut plugin and will be overwritten on update. Put your customizations in .claude/rules/user-overrides.md instead."}}'

# Block: plugin-managed rules in World's .claude/rules/
case "$FILE_PATH" in
  "$WORLD_ROOT/.claude/rules/"*)
    BASENAME=$(basename "$FILE_PATH")
    case "$BASENAME" in
      voice.md|behaviours.md|conventions.md|squirrels.md|conductor.md|world.md)
        echo "$DENY_MSG"
        exit 0
        ;;
    esac
    ;;
esac

# Block: World's .claude/CLAUDE.md (plugin-managed)
if [ "$FILE_PATH" = "$WORLD_ROOT/.claude/CLAUDE.md" ]; then
  echo "$DENY_MSG"
  exit 0
fi

# Block: anything in the walnut plugin cache
case "$FILE_PATH" in
  */.claude/plugins/cache/alivecomputer/walnut/*)
    echo "$DENY_MSG"
    exit 0
    ;;
esac

exit 0
