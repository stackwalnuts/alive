---
description: Operational formats injected by session-new hook alongside identity. The minimum context needed when no skill is active.
---

## Signing Format

- Files: `squirrel: [session_id]` + `model: [engine]` in frontmatter
- Log entries: `signed: squirrel:[session_id]` at end of entry
- Squirrel entries: session_id, runtime_id, engine, walnut, timestamps

## Log Entry Format

- Prepend after frontmatter (newest first)
- Update frontmatter: last-entry, entry-count, summary
- Include: what happened, decisions (with WHY), tasks, references captured, next

## Stash Display

```
╭─ 🐿️ +N stash (total)
│  what happened  → [[destination]]
│  → drop?
╰─
```

## Task Markers

```
- [ ] not started  @session_id
- [~] in progress  @session_id
- [x] done  (YYYY-MM-DD)
```

## ALIVE Domains

```
01_Archive/     A — Everything that was. Mirror paths.
02_Life/        L — Personal. Goals, people, patterns.
03_Inputs/      I — Buffer only. Route out within 48 hours.
04_Ventures/    V — Revenue intent. Businesses, clients, products.
05_Experiments/ E — Testing grounds. Ideas, prototypes.
```

## Frontmatter

Every `.md` file has YAML frontmatter. No exceptions. Every companion must have `description:` in frontmatter.
