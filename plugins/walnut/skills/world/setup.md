---
name: setup
description: First-time world creation. Triggered automatically when walnut:world detects no existing ALIVE structure.
internal: true
---

# Setup — Three Paths to a World

First time. No `.walnut/` folder exists. You just installed Walnut. Make it feel like something just came alive.

All three paths produce the same result: a fully scaffolded ALIVE world with domain folders, `.walnut/` config, and at least one walnut. The only difference is how we collect the information.

---

## Detection Logic

`walnut:world` checks for `01_Archive/`, `02_Life/`, etc. If none found, this fires.

Check two things at the top:

### 1. Is there a world-seed.md in PWD?

The session-new hook will have injected additionalContext containing `"World seed: found at /path/to/world-seed.md"` if one exists. Alternatively, check `$PWD/world-seed.md` directly.

**If world-seed.md exists** → go straight to **Path A**. No menu. No questions.

### 2. No world-seed.md → present the choice

```
╭─ welcome
│
│  No world found here. Let's build one.
│
│  Three ways to start:
│
│   1. Quick start — name + one walnut, 30 seconds
│   2. Terminal setup — guided questions, 3 minutes
│   3. World builder — open the questionnaire in your browser,
│      fill it out, drag the export here, and run /walnut:world again
│
│  → Pick 1, 2, or 3
╰─
```

Wait for user input (numbered selection or free text that maps to one).

- **1** → Path C (Minimal Quick Start)
- **2** → Path B (In-Terminal Survey)
- **3** → Open the HTML questionnaire

For **option 3**: The session-new hook injects `"Onboarding questionnaire: /path/to/world-builder.html"` in additionalContext. The path points to the plugin's bundled HTML file.

Run:
```bash
open /path/to/world-builder.html
```

Then display:
```
╭─ questionnaire opened
│
│  The world builder just opened in your browser.
│
│  Fill it out, hit "Export", and save world-seed.md
│  to this directory:
│    {{PWD}}
│
│  Then run /walnut:world again. I'll pick it up automatically.
╰─
```

End the skill here. The user will come back.

---

## Path A: World Seed (from HTML questionnaire)

### Trigger
`world-seed.md` exists in PWD (detected by hook or direct check).

### Steps

#### A1. Read and parse world-seed.md

Read the file. It contains structured sections with YAML-like data:

```markdown
---
type: world-seed
version: 1.0.1-beta
created: 2026-03-10T12:00:00Z
generator: world-builder-html
---

# World Seed

## Identity
name: Alex Chen
description: Builder shipping AI-native tools
timezone: America/Los_Angeles

## Walnuts

### nova-station
type: venture
goal: Build the first civilian orbital platform
rhythm: daily

### glass-cathedral
type: experiment
goal: Interactive fiction prototype
rhythm: weekly

## People

### ryn-okata
name: Ryn Okata
role: Engineering lead
walnuts: nova-station

### mira-solaris
name: Mira Solaris
role: Co-founder

## Context Sources

gmail:
  type: mcp_live
  status: available
chatgpt:
  type: static_export
  path: ~/exports/chatgpt/
  status: available

## Preferences
spark: true
show_reads: true
health_nudges: true
stash_checkpoint: true
always_watching: true
save_prompt: true

## Voice
character: [direct, warm, technical]
blend: 70% sage, 30% rebel
```

Parse each section. All sections are optional except Identity (which must have at least `name`).

#### A2. Show what's coming

```
╭─ world seed found
│
│  Found world-seed.md with:
│    Name: {{name}}
│    Walnuts: {{count}} ({{list of names}})
│    People: {{count}} ({{list of names}})
│    Context sources: {{count}}
│
│  Building your world now...
╰─
```

#### A3. Scaffold the world

Execute the scaffolding sequence (see **Scaffolding Procedure** below) using all parsed data.

#### A4. Move the seed file

```bash
mv world-seed.md .walnut/world-seed.md
```

Keep it as a record of how the world was created. Never delete it.

#### A5. Present the completed world

Show the **After Setup** display (see below). Then offer:

```
→ Say "open {{first-walnut-name}}" to start working.
```

---

## Path B: In-Terminal Survey

### Trigger
User chose option 2 from the menu.

### Steps

Use `AskUserQuestion` for each step. These are real form-style questions, not numbered menus.

#### B1. Name

> AskUserQuestion: "What's your name?"

Store as `name`. This goes into `.walnut/key.md` frontmatter and body.

#### B2. Identity (optional)

> AskUserQuestion: "One sentence about yourself — what are you building? (press enter to skip)"

Store as `description`. If skipped, leave the description section in key.md as a comment placeholder.

#### B3. First walnut

> AskUserQuestion: "What's the most important thing you're working on right now? Give it a name."

Store as first walnut `name`.

> AskUserQuestion: "Describe it in a sentence — what's the goal?"

Store as first walnut `goal` and `description`.

> AskUserQuestion: "Is that a venture (revenue-focused), experiment (testing something), or life goal? (venture/experiment/life)"

Store as first walnut `type`. Map to domain:
- `venture` → `04_Ventures/`
- `experiment` → `05_Experiments/`
- `life` → `02_Life/goals/`

> AskUserQuestion: "How often do you work on this? (daily/weekly/monthly)"

Store as first walnut `rhythm`. Default to `weekly` if skipped.

#### B4. Additional walnuts (up to 3 more)

> AskUserQuestion: "Want to add another walnut? (yes/no)"

If yes, repeat the name/goal/type/rhythm questions. Allow up to 3 additional walnuts (4 total). After each, ask again until they say no or hit 3.

#### B5. People (optional, up to 5)

> AskUserQuestion: "Who matters most in your world right now? Give me a name and their role — like 'Ryn - engineering lead' or 'Jake - co-founder'. (press enter to skip)"

If they provide a person, store `name` and `role`. Then ask:

> AskUserQuestion: "Anyone else? (name - role, or press enter to finish)"

Repeat until they skip or hit 5 people.

#### B6. Context sources (optional)

> AskUserQuestion: "Where does your existing context live? Pick all that apply (comma-separated numbers, or press enter to skip):
> 1. Gmail (MCP)
> 2. Slack (sync script)
> 3. ChatGPT export
> 4. Claude Desktop export
> 5. Fathom/Otter transcripts
> 6. Apple Notes
> 7. Notion
> 8. Obsidian vault
> 9. GitHub (MCP)"

Parse their selection. Map each to a context source entry with the appropriate type:
- Gmail → `mcp_live`
- Slack → `sync_script`
- ChatGPT → `static_export`
- Claude Desktop → `static_export`
- Fathom/Otter → `static_export`
- Apple Notes → `static_export`
- Notion → `mcp_live`
- Obsidian → `markdown_vault`
- GitHub → `mcp_live`

All sources start with `status: available` unless they're MCP-based and the MCP server is already connected, in which case use `status: active`.

Do NOT ask about voice or preferences in the terminal flow. Defaults are fine. The human can customize later via `/walnut:settings`.

#### B6b. Credential storage (optional)

> AskUserQuestion: "Where do you keep API keys and tokens? (default: ~/.env)"

Record the path for the `## Credentials` section in `.walnut/key.md`. If they press enter or skip, use `~/.env`.

#### B7. Scaffold

Execute the scaffolding sequence (see **Scaffolding Procedure** below) using collected data.

#### B8. Present the completed world

Show the **After Setup** display (see below).

---

## Path C: Minimal Quick Start

### Trigger
User chose option 1 from the menu, or said something like "just set it up", "quick", "minimal".

### Steps

#### C1. Name

> AskUserQuestion: "What's your name?"

#### C2. First walnut

> AskUserQuestion: "Name the most important thing you're working on right now."

Store as walnut name.

> AskUserQuestion: "Is that a venture, experiment, or life goal? (venture/experiment/life)"

Store as walnut type. Default to `venture` if unclear.

#### C3. Scaffold

Execute the scaffolding sequence with:
- `name` from C1
- `description`: empty (comment placeholder)
- `goal`: empty
- `timezone`: detect from system (`date +%Z` or similar)
- One walnut from C2 with `rhythm: weekly`, goal set to the walnut name
- No people
- No context sources
- All preferences as defaults (commented out in preferences.yaml)

#### C4. Present the completed world

Show the **After Setup** display (see below).

---

## Scaffolding Procedure

This is the shared build sequence. All three paths call this with their collected data.

### Input Data Shape

```
world:
  name: string (required)
  goal: string (optional, defaults to "")
  description: string (optional, defaults to "")
  timezone: string (optional, detect from system)

walnuts: array of:
  - name: string
    type: venture | experiment | life
    goal: string
    description: string (optional)
    rhythm: daily | weekly | monthly (default: weekly)

people: array of:
  - name: string
    role: string
    context: string (optional)

context_sources: object (optional)
  key: { type: string, status: string }

preferences: object (optional)
  key: value pairs for preferences.yaml

voice: object (optional)
  character: array of strings
  blend: string
  never_say: array of strings
```

### Execution Steps

Show progress as each item is created:

```
╭─ building your world...
│
```

#### Step 1: Domain folders

Create these directories (use `mkdir -p`):

```
01_Archive/
02_Life/
02_Life/people/
02_Life/goals/
03_Inputs/
04_Ventures/
05_Experiments/
.walnut/
.walnut/_squirrels/
```

Show:
```
│  ▸ 01_Archive/
│  ▸ 02_Life/
│  ▸ 02_Life/people/
│  ▸ 02_Life/goals/
│  ▸ 03_Inputs/
│  ▸ 04_Ventures/
│  ▸ 05_Experiments/
```

#### Step 2: World identity — .walnut/key.md

Read the template from the plugin: `templates/world/key.md`

Replace template variables:
- `{{name}}` → world name
- `{{goal}}` → world goal (or empty string)
- `{{date}}` → today's date in YYYY-MM-DD format
- `{{timezone}}` → detected or provided timezone
- `{{description}}` → world description (or empty string)

If people were provided, fill in the `## Key People` section with entries like:
```
- **{{person.name}}** — {{person.role}}. [[{{person-name-slugified}}]]
```

And fill in the `## Connections` section with entries like:
```
- [[{{walnut-name-slugified}}]] — {{walnut.goal}}
```

If the human provided a credential storage path, fill in the `## Credentials` section:
```
env_file: {{env_file_path}}
```
If not provided, leave it as the template default (`~/.env`).

Write to `.walnut/key.md`.

Show:
```
│  ▸ .walnut/key.md (your identity)
```

#### Step 3: Preferences — .walnut/preferences.yaml

Read the template from the plugin: `templates/world/preferences.yaml`

If preferences were provided (Path A only), uncomment the relevant lines and set values.

If voice config was provided (Path A only), uncomment the voice section and fill values.

If context sources were provided, uncomment the `context_sources:` section and add each source:
```yaml
context_sources:
  gmail:
    type: mcp_live
    status: available
    walnuts: all
```

For paths B and C with no explicit preferences, write the template as-is (all commented out = defaults).

Write to `.walnut/preferences.yaml`.

Show:
```
│  ▸ .walnut/preferences.yaml (defaults)
```

#### Step 4: Overrides — .walnut/overrides.md

Read the template from the plugin: `templates/world/overrides.md`

Write as-is. No variable replacement needed.

Show:
```
│  ▸ .walnut/overrides.md (your customizations)
```

#### Step 5: Create each walnut

For each walnut in the list:

**Determine the folder path:**
- `venture` → `04_Ventures/{{walnut-name-slugified}}/`
- `experiment` → `05_Experiments/{{walnut-name-slugified}}/`
- `life` → `02_Life/goals/{{walnut-name-slugified}}/`

**Slugify the name:** lowercase, spaces to hyphens, strip non-alphanumeric except hyphens. Examples: "Nova Station" → "nova-station", "Glass Cathedral" → "glass-cathedral".

**Create the directory structure:**
```
{{domain}}/{{slug}}/
{{domain}}/{{slug}}/_core/
{{domain}}/{{slug}}/_core/_working/
{{domain}}/{{slug}}/_core/_references/
```

**Create walnut files from templates:**

For each file in `templates/walnut/` (key.md, now.md, log.md, tasks.md, insights.md):

Read the template. Replace variables:
- `{{name}}` → walnut display name (original casing)
- `{{type}}` → walnut type (venture/experiment/life)
- `{{goal}}` → walnut goal
- `{{description}}` → walnut description (or goal repeated if no separate description)
- `{{date}}` → today's date in YYYY-MM-DD format
- `{{session_id}}` → current session ID (from stdin JSON or "setup")
- `{{next}}` → "Define first outcomes and tasks"

For key.md specifically:
- Set `rhythm:` to the walnut's rhythm value
- If people are associated with this walnut, fill the `## Key People` section

Write each file to `{{domain}}/{{slug}}/_core/{{filename}}`.

Show:
```
│  ▸ {{domain}}/{{slug}}/
│  ▸   _core/key.md — "{{goal}}"
│  ▸   _core/now.md — phase: starting
│  ▸   _core/log.md — first entry signed
│  ▸   _core/insights.md — empty, ready
│  ▸   _core/tasks.md — empty, ready
```

#### Step 6: Create people walnuts

For each person in the list:

**Slugify the name:** "Ryn Okata" → "ryn-okata", "Mira Solaris" → "mira-solaris"

**Create the directory structure:**
```
02_Life/people/{{slug}}/
02_Life/people/{{slug}}/_core/
02_Life/people/{{slug}}/_core/_working/
02_Life/people/{{slug}}/_core/_references/
```

**Create walnut files from templates:**

Use the same `templates/walnut/` templates with:
- `{{name}}` → person's display name
- `{{type}}` → `person`
- `{{goal}}` → person's role
- `{{description}}` → person's context (or role if no context)
- `{{date}}` → today
- `{{session_id}}` → current session ID or "setup"
- `{{next}}` → ""

Show:
```
│  ▸ 02_Life/people/{{slug}}/
│  ▸   _core/key.md — "{{role}}"
```

#### Step 7: Close the progress box

```
│
│  Done. Five domains. {{walnut_count}} walnuts. Your world is alive.
╰─
```

---

## After Setup (all paths converge here)

Display this summary. Fill in actual values for every placeholder.

```
╭─ your world is alive
│
│  World: {{PWD}}
│  Walnuts: {{comma-separated list of walnut names with their domain}}
│  People: {{comma-separated list of people names, or "none yet"}}
│  Context sources: {{comma-separated list, or "none yet"}}
│
│  12 skills ready:
│    world · load · save · capture · find · create · tidy · tune · history · mine · extend · map
│
│  Say "load {{first-walnut-name}}" to start working.
│  Say "world" anytime to see everything.
│
│  → Build your world.
╰─
```

---

## What Setup Creates

| Path | Purpose |
|------|---------|
| `01_Archive/` | Graduated walnuts |
| `02_Life/people/` | Person walnuts |
| `02_Life/goals/` | Life goals |
| `03_Inputs/` | Buffer — content arrives, gets routed out within 48h |
| `04_Ventures/` | Revenue intent |
| `05_Experiments/` | Testing grounds |
| `.walnut/key.md` | World identity (name, goal, timezone, people, connections) |
| `.walnut/preferences.yaml` | Toggles, context sources, voice config |
| `.walnut/overrides.md` | User rule customizations (never overwritten by updates) |
| `.walnut/_squirrels/` | Centralized session entries |
| `[walnut]/_core/key.md` | Walnut identity and standing context |
| `[walnut]/_core/now.md` | Current state synthesis |
| `[walnut]/_core/log.md` | Prepend-only event spine |
| `[walnut]/_core/tasks.md` | Work queue |
| `[walnut]/_core/insights.md` | Evergreen domain knowledge |
| `[walnut]/_core/_working/` | Scratch space for in-progress work |
| `[walnut]/_core/_references/` | Captured external content |

## What Setup Does NOT Do

- Import or index existing context (use `/walnut:mine-for-context` after setup)
- Configure MCP integrations (use `/walnut:settings`)
- Set up voice customization in terminal paths (use `/walnut:settings`)
- Create the walnut.world link (use `/walnut:settings`)
- Symlink rules or agents.md (handled by session-new hook, not setup)
