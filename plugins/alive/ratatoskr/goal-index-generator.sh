#!/bin/bash
# Generates the dynamic goal index for ratatoskr runtime.
# Called by session-new hook. Scans key.md frontmatter for active walnuts.
# Filters: no people, no archived, no complete, no clients, no empty goals.
# Outputs markdown table to stdout for injection via additionalContext.
#
# Usage: bash goal-index-generator.sh /path/to/world

WORLD_ROOT="$1"

if [ -z "$WORLD_ROOT" ] || [ ! -d "$WORLD_ROOT" ]; then
  exit 0
fi

echo "## Active Walnuts"
echo ""

# Find all key.md files, excluding Archive and people
find "$WORLD_ROOT" -path "*/01_Archive" -prune -o \
     -path "*/02_Life/people" -prune -o \
     -path "*/_core/key.md" -print 2>/dev/null | sort | while read -r keyfile; do

  result=$(python3 -c "
import sys, re

try:
    with open('$keyfile', 'r') as f:
        content = f.read()
except:
    sys.exit(1)

# Extract YAML frontmatter
m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m:
    sys.exit(1)

fm = m.group(1)

def get_field(name):
    match = re.search(rf'^{name}:\s*(.+)$', fm, re.MULTILINE)
    return match.group(1).strip().strip('\"').strip(\"'\") if match else ''

walnut_type = get_field('type')
goal = get_field('goal')
phase = get_field('phase')

# Skip: people, clients, complete phase, empty/placeholder goals
if walnut_type in ('person', 'client'):
    sys.exit(1)
if phase == 'complete':
    sys.exit(1)
if not goal or '(needs definition)' in goal.lower():
    sys.exit(1)

print(f'{walnut_type}|{goal}')
" 2>/dev/null)

  if [ -n "$result" ]; then
    walnut_dir=$(dirname "$(dirname "$keyfile")")
    walnut_name=$(basename "$walnut_dir")

    wtype=$(echo "$result" | cut -d'|' -f1)
    goal=$(echo "$result" | cut -d'|' -f2-)

    printf "%-22s | %-10s | %s\n" "$walnut_name" "$wtype" "$goal"
  fi
done
