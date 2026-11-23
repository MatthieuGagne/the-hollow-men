---
name: prd
description: Use when creating a new PRD for a feature — creates a GitHub issue with the PRD content. No local file is created. Can be used with or without a prior brainstorming session.
---

# PRD — The Hollow Men

Read `~/.claude/skills/base-prd/SKILL.md` first: it owns the PRD structure, the filing and update commands, and
the rules about local files and `writing-plans`. Apply the project rules below on top of it.

## Pre-draft gate

Always invoke the `grilling` skill — it surfaces requirements, acceptance criteria, scope, and
Godot constraints. Once grilling is satisfied, proceed to drafting.

## Filing

Default repo (no `--repo` needed); no labels or board wiring.

## Project content

`Files Impacted` lists scenes and scripts:

```
- `scenes/foo.tscn` — ...
- `scripts/foo.gd` — ...
```

`Notes` must cover, when relevant: autoload signals added or changed, the GUT test coverage plan,
ATB battle system concerns, YarnSpinner node group design, SceneManager transitions, and Mobile
renderer concerns.
