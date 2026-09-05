---
name: brainstorming
description: "The Hollow Men's fork of brainstorming — use instead of superpowers:brainstorming in this project. Standalone exploration tool for turning ideas into designs (PRD writing, plan writing, debugging, or standalone exploration), with a Godot constraint checklist and a grilling gate feeding GitHub-issue PRDs. Explores user intent, requirements and design before implementation."
---

# Brainstorming Ideas Into Designs

## Overview

Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST present it and get approval.

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Explore project context** — check files, docs, recent commits
2. **Ask clarifying questions** — one per message, to understand purpose/constraints/success criteria; prefer multiple choice, break multi-part topics into separate questions
3. **Propose 2-3 approaches** — with trade-offs; lead with your recommendation and explain why
4. **Present design** — in sections scaled to their complexity (a few sentences if straightforward, up to 200-300 words if nuanced); get user approval after each section; cover architecture, components, data flow, error handling, testing; work through the Godot Constraint Checklist explicitly for any Godot feature; go back and clarify if something doesn't make sense (if the user says no, revise and re-present)
5. **Invoke grilling** — use the `grilling` skill to stress-test the approved design. `grilling` will NOT re-invoke brainstorming — it produces a Resolved/Unresolved/Risk summary only. Continue only after that summary is generated.
6. **Resolved / Unresolved / Deferred summary** — output a short bullet list per category:
   - **Resolved:** decisions that are settled
   - **Unresolved:** open questions that must be answered before implementation begins
   - **Deferred:** items deliberately set aside (not blocking now)
   If Unresolved is non-empty, stop and resolve those questions before continuing.

**Brainstorming ends here.** After the resolved/unresolved/deferred summary is presented, the session is complete. The user will invoke `prd` and `writing-plans` when they are ready — do not auto-invoke them.

## Godot Constraint Checklist

When designing any Godot feature, explicitly address these in your design:

| Constraint | Question to answer |
|------------|-------------------|
| **Autoloads** | Does this touch SceneManager or a future singleton? Which signals are emitted/connected? |
| **Scene tree** | Which scene owns this node? Is it instanced or a child? Does it need `@onready`? |
| **Signals** | Does UI poll state or connect to signals? (Must connect — never poll.) |
| **GDScript** | Any typed arrays, custom resources, or `@export` vars needed? |
| **Testability** | Which logic can be GUT-tested headlessly? |
| **Mobile renderer** | Any shaders or features incompatible with the Mobile renderer? |
| **Dialogue** | Does this interact with YarnSpinner? (C# integration TBD — note the open architectural question.) |
| **Battle/investigation** | Does this touch the ATB battle system or investigation mechanic? Which signals/events? |

## Key Principles

- **One question at a time** — don't overwhelm with multiple questions
- **Multiple choice preferred** — easier to answer than open-ended when possible
- **YAGNI ruthlessly** — remove unnecessary features from all designs
- **Explore alternatives** — always propose 2-3 approaches before settling
- **Incremental validation** — present design, get approval before moving on
- **Be flexible** — go back and clarify when something doesn't make sense
- **Godot constraints first** — work through the constraint checklist before finalizing any Godot design
