---
name: prd
description: Use when creating a new PRD for a feature — creates a GitHub issue with the PRD content. No local file is created. Can be used with or without a prior brainstorming session.
---

## Before You Begin

Always invoke the `grill-me` skill — it will surface requirements, acceptance criteria, scope, and Godot constraints. Once grill-me is satisfied, proceed to drafting.

---

Create a new PRD as a GitHub issue.

## Steps

1. **Draft the PRD content** from the brainstorming session or the user's description. Use this structure:

```
## Goal
One sentence: what this feature does and why it matters for the game.

## Requirements
- R1: ...

## Acceptance Criteria
- [ ] AC1: ...

## Out of Scope
- ...

## Files Impacted
- `scenes/foo.tscn` — ...
- `scripts/foo.gd` — ...

## Notes
<!-- Technical context: scenes impacted, autoload signals added/changed,
     GUT test coverage plan, ATB battle system concerns, YarnSpinner node group design,
     SceneManager transitions, Mobile renderer concerns, open questions -->
```

   **Required in Notes:** include any relevant technical context gathered during design — which autoload signals are added or changed, what GUT tests cover the logic, any Mobile renderer concerns, and specific files impacted when known. This ensures subsequent sessions start informed.

2. **Create a GitHub issue** with the full PRD content as the body:
   ```sh
   gh issue create --repo MatthieuGagne/noir-fantasy-rpg --title "feat: <feature name>" --body "<PRD content>"
   ```
   Capture the issue number from the URL in the output.

3. Report the issue URL to the user.

## Updating an Existing PRD

When updating a PRD (e.g., after a new brainstorming session or scope change):

- **Always use `gh issue edit`** to rewrite the issue body directly — never add a comment:
  ```sh
  gh issue edit <N> --repo MatthieuGagne/noir-fantasy-rpg --body "<full updated PRD content>"
  ```
- The issue body is the single source of truth — it must always reflect the current design.

## Important

- **No local file is created.** The GitHub issue is the single source of truth for the PRD.
- Do NOT invoke `writing-plans` after this. The implementation plan is written in a separate session when the user is ready to build.
