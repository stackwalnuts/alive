# Changelog

All notable changes to the Walnut plugin are documented here.

## [1.0.0] - 2026-03-25

### The Walnut Rebrand

First release as **Walnut**. Everything that was "alive" is now "walnut."

### Changed
- **Brand:** alive → Walnut. Plugin name: `walnut`. Namespace: `walnut:*`
- **GitHub:** org `alivecomputer` → `stackwalnuts`. Repo `alive-claude` → `claude-code`
- **System folder:** `.alive/` → `.walnut/`
- **All 15 hook scripts:** `alive-*` → `walnut-*`
- **Marketplace:** name `alivecomputer` → `stackwalnuts`
- **Install:** `claude plugin install walnut@walnut`

### Added
- **Auto-migration:** session-new hook detects `.alive/` and renames to `.walnut/` automatically
- **`migrate-alive-to-v1` skill** (non-user-invocable) — handles edge cases when both `.alive/` and `.walnut/` exist
- **Backward compat in all hooks** — `find_world` checks both `.walnut/` and `.alive/` config paths

## [1.0.1-beta] — 2026-03-12

### Added
- **Capsule architecture** — self-contained units of work replace `_working/` and `_references/`. Capsules have companions, versioned drafts, and raw source material. Full lifecycle: `draft → prototype → published → done`. Graduation to walnut root on v1 ship.
- **3 new skills:** `walnut:mine-for-context` (deep context extraction), `walnut:build-extensions` (create custom skills/rules/hooks), `walnut:my-context-graph` (interactive world graph)
- **Inbox scan mode** — `walnut:capture-context` with no content falls back to scanning `03_Inputs/` for unrouted files
- **Context graph** — D3.js force-directed visualization of your entire world
- **World index generator** — `_index.yaml` built from all walnut and capsule frontmatter
- **Capsule routing heuristic** — automatic routing of content to capsules by goal alignment
- **Multi-agent capsule collaboration** — active session claims, capsule-scoped tasks, append-only work logs
- **Cross-capsule shared references** — raw files live where first captured, other capsules link via `sources:` path

### Changed
- **Walnut anatomy** — system files live in `_core/`. `_capsules/` and `_squirrels/` are the only system folders. Everything else is live context.
- **Skill renames:** `housekeeping` → `tidy`, `config` → `tune`, `recall` → `history`
- **Rules restructured** — 6 rule files: capsules, human, squirrels, standards, voice, world
- **Templates updated** for capsule structure
- **All hooks** updated with backward compatibility for flat walnut structures

### Removed
- `_working/` and `_references/` folders (migrated to capsules, legacy still supported)

## [1.0.0-beta] — 2026-03-10

### Added
- **12 skills:** world, load, save, capture, find, create, tidy, tune, history, mine, extend, map
- **6 foundational rules:** capsules, human, squirrels, standards, voice, world
- **12 hooks:** session lifecycle, log guardian, rules guardian, archive enforcer, external guard, root guardian, context watch, inbox check, pre-compact, post-write
- **Squirrel caretaker runtime** — stash mechanic, session signing, zero-context handoff
- **Walnut framework** — 5-domain folder structure (Archive, Life, Inputs, Ventures, Experiments)
- **Walnut system** — 5 core files (key.md, now.md, log.md, insights.md, tasks.md)
- **Onboarding** — first-run world builder experience
- **Statusline** — terminal status bar with session info, context warnings, and stash count
- **Templates** for all system file types

## [0.1.0-beta] — 2026-02-23

Initial release. 9 skills, flat walnut structure, basic session management.
