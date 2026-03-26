---
description: "Import a .walnut package into the world. Detects encryption, validates integrity (checksums + path safety), previews contents, and routes into a new walnut (full scope), existing walnut capsules (capsule scope), or read-only view (snapshot scope)."
user-invocable: true
---

# Receive

Import walnut context from someone else. The import side of P2P sharing.

A `.walnut` file is a gzip-compressed tar archive with a manifest. Three scopes: full walnut handoff (creates new walnut), capsule-level import (into existing walnut), or a snapshot for read-only viewing. Handles encryption detection and integrity validation before writing anything.

---

## Prerequisites

Read the format spec before processing any package. The template lives relative to the plugin install path:

```
templates/walnut-package/format-spec.md    -- full format specification
templates/walnut-package/manifest.yaml     -- manifest template with field docs
```

The squirrel MUST read both files before importing. Do not reconstruct the manifest schema from memory.

---

## Entry Points

Two ways this skill gets invoked:

### 1. Direct invocation

The human runs `/alive:receive` with a file path argument (or the squirrel asks for it):

```
/alive:receive ~/Desktop/nova-station-capsule-2026-03-26.walnut
```

If no path argument, ask:

```
╭─ 🐿️ receive
│
│  Where's the .walnut file?
│  ▸ Path?
╰─
```

### 2. Inbox scan delegation

The capture skill's inbox scan detects a `.walnut` or `.walnut.age` file in `03_Inputs/` and delegates here. When delegated, the file path is already known -- skip the path prompt and proceed to Step 1.

---

## Flow

### Step 1 -- Meta Preview (encrypted packages only)

If a `.walnut.meta` sidecar exists alongside a `.walnut.age` file, read it and show a preview before prompting for decryption:

```
╭─ 🐿️ package preview (from .walnut.meta)
│
│  Source:   nova-station
│  Scope:    capsule (shielding-review, safety-brief)
│  Created:  2026-03-26
│  Files:    8
│  Encrypted: yes
│
│  Note: "Two capsules from the shielding review -- one still in draft."
│
│  ▸ Decrypt and import?
│  1. Yes
│  2. Cancel
╰─
```

If no `.walnut.meta` exists, skip this preview -- detect encryption in Step 2.

---

### Step 2 -- Encryption Detection

Check the first bytes of the package file for the age header:

```bash
head -c 30 "<package-path>" | grep -q "age-encryption.org/v1"
```

**If encrypted:**

Check that `age` is installed:

```bash
command -v age >/dev/null 2>&1
```

If `age` is NOT installed, block:

```
╭─ 🐿️ encryption
│
│  This package is encrypted but age is not installed.
│  Install: brew install age (macOS) or apt install age (Linux)
│
│  Cannot proceed without age.
╰─
```

If `age` IS installed, decrypt to a temp location:

```bash
STAGING=$(mktemp -d "/tmp/walnut-import-XXXXX")
age -d "<package-path>" | tar -xzf - -C "$STAGING"
```

`age -d` prompts for the passphrase interactively in the terminal. The squirrel does not handle the passphrase.

**If NOT encrypted:**

Extract directly to staging:

```bash
STAGING=$(mktemp -d "/tmp/walnut-import-XXXXX")
tar -xzf "<package-path>" -C "$STAGING"
```

---

### Step 3 -- Path Traversal Validation

**This is a security requirement. Do NOT skip.**

Before reading any extracted content, validate every path in the staging directory:

```bash
# Check for path traversal (..), absolute paths, and symlinks outside staging
python3 -c "
import os, sys

staging = sys.argv[1]
staging_real = os.path.realpath(staging)
violations = []

for root, dirs, files in os.walk(staging):
    for name in dirs + files:
        full = os.path.join(root, name)
        rel = os.path.relpath(full, staging)

        # Reject .. components
        if '..' in rel.split(os.sep):
            violations.append(f'Path traversal: {rel}')

        # Reject absolute path components embedded in names
        if os.sep + os.sep in full:
            violations.append(f'Suspicious path: {rel}')

        # Reject symlinks pointing outside staging
        if os.path.islink(full):
            target = os.path.realpath(full)
            if not target.startswith(staging_real + os.sep):
                violations.append(f'Symlink escape: {rel} -> {target}')

if violations:
    for v in violations:
        print(v, file=sys.stderr)
    sys.exit(1)
else:
    print('All paths safe.')
" "$STAGING"
```

If any violations are found, abort the import and clean up staging:

```
╭─ 🐿️ import blocked
│
│  This package contains unsafe paths:
│  - [violation details]
│
│  Import aborted. The package may be corrupted or malicious.
╰─
```

```bash
rm -rf "$STAGING"
```

---

### Step 4 -- Manifest Validation

Read `manifest.yaml` from the staging root:

```bash
cat "$STAGING/manifest.yaml"
```

#### 4a. Format version check

Parse `format_version` from the manifest. Check the major version:

- **Major version matches** (currently `1.x.x`) -- proceed.
- **Major version mismatch** -- block:

```
╭─ 🐿️ import blocked
│
│  This package uses format version X.Y.Z.
│  This plugin supports version 1.x.x.
│
│  A newer version of the ALIVE plugin may be required.
╰─
```

- **Minor version ahead** (e.g. package is `1.3.0`, plugin supports `1.0.0`) -- warn but proceed:

```
╭─ 🐿️ heads up
│
│  This package uses format version 1.3.0 (newer than this plugin's 1.0.0).
│  Some optional features may not be recognized. Proceeding anyway.
╰─
```

#### 4b. Plugin version check

Parse `source.plugin_version` from the manifest. Compare the major version against the installed plugin's major version.

- **Major mismatch** -- block with a clear message about updating the plugin.
- **Match** -- proceed.

#### 4c. SHA-256 checksum validation

Validate every file listed in `manifest.files` against its `sha256` checksum:

```bash
python3 -c "
import hashlib, sys, json, os

# Read manifest
import re
staging = sys.argv[1]
manifest_path = os.path.join(staging, 'manifest.yaml')

# Simple YAML parser for the files array
# (avoids PyYAML dependency)
with open(manifest_path) as f:
    manifest_text = f.read()

# Extract files entries using regex
entries = []
for m in re.finditer(r'- path: \"?([^\"\\n]+)\"?\\n\s+sha256: \"?([a-f0-9]{64})\"?\\n\s+size: (\d+)', manifest_text):
    entries.append({'path': m.group(1), 'sha256': m.group(2), 'size': int(m.group(3))})

errors = []
verified = 0

for entry in entries:
    fpath = os.path.join(staging, entry['path'])
    if not os.path.exists(fpath):
        errors.append(f'Missing: {entry[\"path\"]}')
        continue

    with open(fpath, 'rb') as f:
        digest = hashlib.sha256(f.read()).hexdigest()

    if digest != entry['sha256']:
        errors.append(f'Checksum mismatch: {entry[\"path\"]}')
    else:
        verified += 1

# Check for unlisted files
for root, dirs, files in os.walk(staging):
    for name in files:
        full = os.path.join(root, name)
        rel = os.path.relpath(full, staging)
        if rel == 'manifest.yaml':
            continue
        listed = any(e['path'] == rel for e in entries)
        if not listed:
            errors.append(f'Unlisted file: {rel}')

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)
else:
    print(f'{verified} files verified.')
" "$STAGING"
```

If any checksums fail or files are missing/unlisted, show the errors and abort:

```
╭─ 🐿️ integrity check failed
│
│  [error details]
│
│  Import aborted. The package may have been corrupted in transit.
╰─
```

Clean up staging on any failure.

---

### Step 5 -- Content Preview

Read the manifest and show what's inside:

```
╭─ 🐿️ package contents
│
│  Source:     nova-station
│  Scope:     capsule
│  Capsules:  shielding-review, safety-brief
│  Files:     12
│  Created:   2026-03-26T12:00:00Z
│  Encrypted: yes (decrypted successfully)
│
│  Description: Evaluate radiation shielding vendors for habitat module
│
│  Note: "Two capsules from the shielding review -- one still in draft."
│
│  ▸ Proceed with import?
│  1. Yes
│  2. Cancel
╰─
```

If any capsules have `sensitivity: restricted` or `pii: true`, surface prominently:

```
╭─ 🐿️ sensitivity notice
│
│  vendor-analysis has pii: true
│  safety-brief has sensitivity: restricted
│
│  These flags were set by the sender. Review content carefully.
╰─
```

---

### Step 6 -- Target Selection

Routing depends on scope.

#### Full scope

Always creates a new walnut. Ask which ALIVE domain:

```
╭─ 🐿️ import target
│
│  Full walnut import creates a new walnut.
│
│  ▸ Which domain?
│  1. 02_Life/
│  2. 04_Ventures/
│  3. 05_Experiments/
╰─
```

The walnut name defaults to the source walnut name from the manifest. If a walnut with that name already exists in the chosen domain, ask:

```
╭─ 🐿️ name collision
│
│  A walnut named "nova-station" already exists at 04_Ventures/nova-station/.
│
│  ▸ What to do?
│  1. Rename -- pick a new name
│  2. Cancel
╰─
```

No merge for MVP. Full import always creates fresh.

#### Capsule scope

Import into an existing walnut. Ask which one:

```
╭─ 🐿️ import target
│
│  Capsule import goes into an existing walnut.
│
│  ▸ Which walnut?
│  [list active walnuts from the world, or type a path]
╰─
```

To list active walnuts, scan the ALIVE domains (`02_Life/`, `04_Ventures/`, `05_Experiments/`) for directories containing `_core/key.md`. Present as a numbered list.

If the package contains multiple capsules, default all to the chosen walnut. Offer per-capsule override:

```
╭─ 🐿️ capsule routing
│
│  Importing 2 capsules into [target-walnut]:
│  1. shielding-review
│  2. safety-brief
│
│  ▸ All to [target-walnut], or route individually?
│  1. All to [target-walnut]
│  2. Route each separately
╰─
```

#### Snapshot scope

Read-only view. Show the content without creating or modifying anything:

```
╭─ 🐿️ snapshot from nova-station
│
│  This is a read-only status briefing. Nothing will be written.
│
│  [Show key.md goal, now.md context paragraph, insights frontmatter]
│
│  ▸ Done viewing, or capture as a reference?
│  1. Done
│  2. Capture into a walnut as a reference
╰─
```

If the human picks "Capture as a reference", ask which walnut, then write the snapshot content as a companion in `_core/_references/snapshots/` with type `snapshot`.

---

### Step 7 -- Content Routing

This is the core write step. Behavior depends on scope.

#### 7a. Full scope -- Create new walnut

Follow the walnut scaffolding pattern from `skills/create/SKILL.md`:

1. Create the directory structure at `<domain>/<walnut-name>/`
2. Copy `_core/` contents from staging to the new walnut's `_core/`
3. Create `_core/_capsules/` if not present in the package

**Handle log.md via bash** (the log guardian hook blocks Write tool on log.md):

If the package includes `_core/log.md`, write it via bash:

```bash
cat "$STAGING/_core/log.md" > "<target-walnut>/_core/log.md"
```

Then prepend an import entry at the top of the log (after frontmatter) using the Edit tool:

The import entry:

```markdown
## <ISO-timestamp> -- squirrel:<session_id>

Walnut imported from .walnut package. Source: <source-walnut> (packaged <created-date>).

### References Captured
- walnut-package: <original-filename> -- imported into <domain>/<walnut-name>/

signed: squirrel:<session_id>
```

Update the log.md frontmatter (`last-entry`, `entry-count`, `summary`) via Edit.

**Replace @session_id in tasks.md:**

If the package includes `_core/tasks.md`, replace foreign `@session_id` references with `@[source-walnut-name]`:

```bash
python3 -c "
import re, sys, pathlib

tasks_path = sys.argv[1]
source = sys.argv[2]
text = pathlib.Path(tasks_path).read_text()
# Replace @<hex-session-id> with @[source-walnut]
updated = re.sub(r'@([0-9a-f]{6,})', f'@[{source}]', text)
pathlib.Path(tasks_path).write_text(updated)
" "<target-walnut>/_core/tasks.md" "<source-walnut-name>"
```

**Update now.md** with import context via Edit:
- Set `squirrel:` to the current session_id
- Set `updated:` to now
- Keep the existing `phase:` and `next:`

#### 7b. Capsule scope -- Route into existing walnut

For each capsule being imported:

1. **Check for name collision** -- does `_core/_capsules/<capsule-name>/` already exist?

If collision:

```
╭─ 🐿️ name collision
│
│  A capsule named "shielding-review" already exists in [target-walnut].
│
│  ▸ What to do?
│  1. Rename -- pick a new name for the imported capsule
│  2. Replace -- overwrite existing capsule
│  3. Skip -- don't import this capsule
╰─
```

2. **Copy capsule directory** from staging to `<target-walnut>/_core/_capsules/<capsule-name>/`

```bash
mkdir -p "<target-walnut>/_core/_capsules/<capsule-name>"
rsync -a "$STAGING/_core/_capsules/<capsule-name>/" "<target-walnut>/_core/_capsules/<capsule-name>/"
```

3. **Add `received_from:` to the capsule companion** -- edit `companion.md` to add provenance:

```yaml
received_from:
  source_walnut: "<source-walnut-name>"
  method: "walnut-package"
  date: <YYYY-MM-DD>
  package: "<original-filename>"
```

Use the Edit tool on the companion's frontmatter to add this field.

4. **Replace @session_id in tasks within capsule** (if any task-like content exists in version files):

Foreign `@session_id` references are replaced with `@[source-walnut-name]` -- same pattern as full scope.

5. **Flag unknown people** -- scan the imported companion for `people:` or person references (`[[name]]`). If any referenced people don't have walnuts in `02_Life/people/`, stash them:

```
╭─ 🐿️ +1 stash (N)
│  Unknown person referenced in imported capsule: [[kai-tanaka]]
│  → drop?
╰─
```

#### 7c. Snapshot scope -- Capture as reference (optional)

Only if the human chose "Capture as a reference" in Step 6.

Create a companion in the target walnut's `_core/_references/snapshots/`:

```bash
mkdir -p "<target-walnut>/_core/_references/snapshots"
```

Write a companion file:

```markdown
---
type: snapshot
description: "<source-walnut> status snapshot -- <description from manifest>"
source_walnut: "<source-walnut-name>"
date: <created-date-from-manifest>
received: <today's-date>
squirrel: <session_id>
tags: [imported, snapshot]
---

## Summary

Status snapshot from [[<source-walnut-name>]].

## Key Identity

[Contents of key.md from staging]

## Current State

[Contents of now.md from staging]

## Domain Knowledge

[Contents of insights.md from staging]

## Source

Imported from .walnut package: <original-filename>
```

---

### Step 8 -- Cleanup

Move the original `.walnut` (or `.walnut.age`) file from its current location to the archive. If the file came from `03_Inputs/`, move it to `01_Archive/03_Inputs/`:

```bash
# Create archive target if needed
mkdir -p "<world-root>/01_Archive/03_Inputs"

# Move (not delete -- follows archive convention)
mv "<package-path>" "<world-root>/01_Archive/03_Inputs/"
```

If the file was NOT in `03_Inputs/` (e.g. on the Desktop), leave it where it is -- don't move files the human put somewhere intentionally. Only auto-archive from the inbox.

Also move the `.walnut.meta` sidecar if present:

```bash
[ -f "<meta-path>" ] && mv "<meta-path>" "<world-root>/01_Archive/03_Inputs/"
```

Clean up the staging directory:

```bash
rm -rf "$STAGING"
```

---

### Step 9 -- Stash & Summary

Stash the import event for logging at next save:

```
╭─ 🐿️ +1 stash (N)
│  Imported [scope] package from [source-walnut]: [capsule names or "full walnut"] into [target]
│  → drop?
╰─
```

Show the final summary:

**Full scope:**

```
╭─ 🐿️ imported
│
│  Walnut: 04_Ventures/nova-station/
│  Source: nova-station (packaged 2026-03-26)
│  Files:  23 files imported
│  Scope:  full
│
│  The walnut is alive. Open it with /alive:load nova-station.
╰─
```

**Capsule scope:**

```
╭─ 🐿️ imported
│
│  Target: [target-walnut]
│  Capsules imported:
│    - shielding-review (12 files)
│    - safety-brief (4 files)
│  Source: nova-station
│
│  Open the walnut with /alive:load [target-walnut].
╰─
```

**Snapshot scope (viewed only):**

```
╭─ 🐿️ snapshot viewed
│
│  Source: nova-station
│  No files written.
╰─
```

**Snapshot scope (captured as reference):**

```
╭─ 🐿️ imported
│
│  Snapshot captured as reference in [target-walnut].
│  File: _core/_references/snapshots/<date>-<source>-snapshot.md
│  Source: nova-station
╰─
```

---

### Step 10 -- Post-import

Offer to open the imported content:

```
╭─ 🐿️ next
│
│  ▸ Open [walnut-name] now?
│  1. Yes -- /alive:load [name]
│  2. No -- stay here
╰─
```

For capsule imports, offer to open the target walnut (not the capsule directly -- capsules are opened via the walnut).

---

## Edge Cases

**Package from `03_Inputs/` with no `.walnut.meta`:** Proceed normally. Meta is optional.

**Encrypted package without `age` installed:** Block with install instructions. Do not attempt extraction.

**Empty capsule (companion only, no raw/drafts):** Import it. The companion context has value on its own.

**Cross-capsule relative paths in sources:** Preserve as-is. They're historical metadata. The paths will reference capsules that may not exist in the target walnut -- that's fine.

**Duplicate import (same package imported twice):** For MVP, just import again. The name collision handler (Step 7b) catches capsule conflicts. Let the human decide rename/replace/skip.

**Package with no `manifest.yaml`:** This is not a valid `.walnut` package. Show an error:

```
╭─ 🐿️ invalid package
│
│  No manifest.yaml found. This doesn't appear to be a valid .walnut package.
│  A .walnut file must contain manifest.yaml at its root.
╰─
```

**Corrupted archive (tar extraction fails):** Catch the error and report:

```
╭─ 🐿️ extraction failed
│
│  Could not extract the archive. It may be corrupted or not a valid .walnut file.
│  Error: [tar error message]
╰─
```

**Multiple `.walnut` files in `03_Inputs/`:** The inbox scan in capture handles this by listing all items. Each `.walnut` file is processed individually via a separate receive invocation.

**Package contains files outside `_core/`:** The format spec says packages contain `_core/` contents. Files outside `_core/` in the archive are flagged as unexpected in checksum validation (Step 4c, "unlisted file" check) and excluded.

---

## Scope Summary (Quick Reference)

| Scope | Creates | Target | User picks | Writes to log |
|-------|---------|--------|------------|---------------|
| **full** | New walnut | ALIVE domain | Domain | Via bash (new walnut) |
| **capsule** | Capsule dirs | Existing walnut | Walnut + optional per-capsule | Via stash (at save) |
| **snapshot** | Nothing (or reference) | View-only (or existing walnut) | View or capture | Via stash (if captured) |
