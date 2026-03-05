---
name: world
description: "Use when you want a dashboard view of all active walnuts, feels lost, or is unsure what to work on next. Renders a live world view grouped by ALIVE domain — priorities, attention items, full walnut tree, and recent activity — then routes to open, housekeeping, find, or recall."
user-invocable: true
---

# World

This is Mission Control. When you opens their world, it should feel like booting an operating system — everything they care about, at a glance, with clear paths to action.

NOT a database dump. NOT a flat list. A living view of their world, grouped by what matters, showing relationships, surfacing what needs attention.

---

## Load Sequence

1. Find the ALIVE world root (walk up from PWD looking for `01_Archive/` + `02_Life/`)
2. Scan all `_core/key.md` files — extract type, goal, phase, health, rhythm, next, updated, people, links, parent
3. Scan all `_core/now.md` files — extract health status, last updated, next action
4. Build the tree — parent/child relationships from `parent:` field in key.md
5. Compute attention items
6. Surface API context if configured (Gmail, Slack, Calendar via preferences.yaml)

## State Detection

Before rendering, detect system state:

- **Fresh install** (no walnuts exist) → route to `setup.md`
- **Stale rules** (plugin version > project rules version) → route to `upgrade.md`
- **Previous system detected** (v3/v4 `_brain/` folders exist) → route to `upgrade.md`
- **Normal** → render dashboard

---

## Dashboard Layout

The dashboard has 4 sections. Each tells you something different.

### Section 1: Right Now

What needs you TODAY. Not everything — just what's active and demanding.

```
╭─ 🐿️ your world
│
│  RIGHT NOW
│  ──────────────────────────────────────────────
│
│   1. nova-station            testing
│      Next: Review telemetry from test window
│      Last: 2 hours ago · 6 sessions this week
│
│   2. stellarforge            launching
│      Next: Deploy relay satellites
│      Last: 2 days ago
│      People: Orion Vex, Luna Thresh
│
│   3. voidlight               legacy
│      Next: Finalise 9 legacy contract closures
│      ⚠ 4 days past rhythm
│
╰─
```

Only show walnuts that are `active` or past their rhythm. Sort by most recently touched. Show:
- Phase
- Next action (from now.md)
- Last activity (relative time)
- People involved (from key.md — max 2-3 names)
- Warning if past rhythm

### Section 2: Attention

Things that need your decision or action. Not walnuts — specific issues.

```
╭─ 🐿️ attention
│
│   → 3 unread emails from Orion (Gmail, 2 days)
│   → Unsigned session on nova-station (squirrel:a3f7, 6 stash items)
│   → 03_Inputs/ has 2 items older than 48 hours
│   → flux-engine quiet for 12 days (rhythm: weekly)
│   → 4 working files older than 30 days across 3 walnuts
│
╰─
```

Sources:
- **Inputs buffer (HIGH PRIORITY)** — anything in `03_Inputs/` older than 48 hours. These are unrouted context that could impact active walnuts TODAY. The squirrel should stress this to you: "You have unrouted inputs. These might contain decisions, tasks, or context that affects your active work. Route them before diving into a walnut."
- API context (Gmail unread, Slack mentions, Calendar upcoming)
- Unsigned squirrel entries with stash items
- Stale walnuts (quiet/waiting)
- Stale working files

**Inputs triage:** The world skill should understand that inputs are a buffer — content arrives there and needs routing to its proper walnut. When surfacing inputs, the squirrel should scan the companion frontmatter (if companions exist) or the file names to understand what the content might relate to. Don't digest the full content — just flag it, estimate which walnuts it might affect, and urge you to route it. Use `alive:capture` to process each input properly.

### Section 3: Your World (the tree)

The full structure — grouped by ALIVE domain, with parent/child nesting visible.

```
╭─ 🐿️ your world
│
│  LIFE
│   identity           active     Exoplanet panel Feb 27
│   health             quiet      Sleep protocol review
│   people/
│     orion-vex        updated 2 days ago
│     luna-thresh      updated 1 day ago
│     zara             updated 5 days ago
│
│  VENTURES
│   stellarforge       launching  Relay satellites
│     └ walnut-plugin  building   Test install
│   voidlight          legacy     Legacy contracts
│   nebula-drift       quiet      Podcast landing
│
│  EXPERIMENTS
│   orbit-lab          building   Test plugin
│   ghost-protocol     waiting    Decide: rewrite or revise
│   flux-engine        quiet      ⚠ 12 days
│   pulsar-sync        quiet      Simplify countdown
│   ... +6 more (3 waiting, 3 quiet)
│
│  INPUTS
│   2 items (oldest: 4 days)
│
│  ARCHIVE
│   1 walnut (starweave)
│
╰─
```

Key features:
- **Grouped by ALIVE domain** — not a flat list
- **Parent/child nesting** — sub-walnuts indented under parents with `└`
- **People** shown under Life with last-updated
- **Collapse quiet/waiting** — if there are 6+ quiet experiments, show the count not the full list
- **Inputs count** — just how many and how old
- **Archive count** — just the number
- **5-day activity indicator** — `●` dot for each of the last 5 days the walnut was touched. Visual pulse at a glance.

```
│   orbit-lab          ●●●●● building   Test plugin
│   stellarforge       ●●○○○ launching   Relay satellites
│   ghost-protocol     ○○○○○ waiting     Decide: rewrite or revise
```

`●` = touched that day. `○` = no activity. Read left to right: today, yesterday, 2 days, 3 days, 4 days. Five dots tells you this walnut is hot. Zero tells you it's cold. No numbers, no dates — just a visual heartbeat.

### Section 4: Recent Squirrel Activity

What's been happening across the world. A pulse check.

```
╭─ 🐿️ recent activity
│
│   Today     orbit-lab         6 sessions · shipped v0.1-beta
│   Yesterday orbit-lab         rebuilt architecture, 22 decisions
│   Feb 22    walnut-world      infrastructure, KV, DNS
│   Feb 22    orbit-lab         companion app, web installer
│   Feb 21    orbit-lab         plugin refactor, ecosystem plan
│
│   5 sessions this week · 3 walnuts touched · 47 stash items routed
│
╰─
```

---

## Rendering Rules

1. **Right Now comes first.** Always. It answers "what should I work on?"
2. **Attention is actionable.** Every item should have a clear next step.
3. **The tree is scannable.** Indent sub-walnuts. Collapse where sensible. Show people under Life.
4. **Recent activity gives pulse.** Not details — just "what's been happening."
5. **Numbers for navigation.** Any walnut with a number can be opened by typing the number.
6. **Don't show everything.** Waiting walnuts can be collapsed. Quiet experiments get a count. You asks for more if they want it.

---

## After Dashboard

- **Number** → open that walnut (invoke `alive:open`)
- **"just chat"** → freestyle conversation, no walnut focus
- **"housekeeping"** → invoke `alive:housekeeping`
- **"find X"** → invoke `alive:find`
- **"recall"** → invoke `alive:recall`
- **"open [name]"** → open a specific walnut
- **Attention item** → address it directly ("deal with those emails", "sign that session")

---

## Context Sources (preferences.yaml)

If `context_sources:` is configured in `.alive/preferences.yaml`, surface relevant items from active sources:

- **mcp_live sources** (Gmail, Slack, Calendar, GitHub): Query on demand. Show actionable items only — "3 unread emails from Orion" not "847 emails."
- **sync_script sources**: Check last sync time. If stale, note it.
- **static_export / markdown_vault**: Don't query at dashboard — these are for `/alive:recall` and `/alive:find`.

Filter by walnut scoping — only show sources where `walnuts: all` or the current active walnut is in the list.

---

## Internal Modes

These have their own .md files in this skill directory. They are NOT separately invocable — they trigger automatically based on state detection.

- `setup.md` — first-time world creation
- `calibrate.md` — progressive 30-day context extraction
- `upgrade.md` — version migration from previous systems
