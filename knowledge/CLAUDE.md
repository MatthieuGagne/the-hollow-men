# Knowledge Wiki — Schema (The Hollow Men)

Project knowledge base for **The Hollow Men** Godot game, following the Karpathy LLM-wiki
pattern (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). Scope: knowledge
specific to this project — battle system architecture, engine/test gotchas as they manifest
here, "why the code is this way" decisions. Cross-project knowledge (facts that would matter
in a different project) goes to `C:\Code\knowledge` instead, using this same layout.

## Layout

- `*.md` — one concept per page, cross-linked with `[[wikilinks]]`
- `raw/` — immutable source material (articles, transcripts, data); add-only, never edit
- `index.md` — the catalog: EVERY page listed under exactly one category heading
- `log.md` — chronological log: date, page(s) touched, one-line why

## Maintenance rules

- One concept per page. If a page grows to cover two ideas, split it and cross-link.
- Every page starts with frontmatter: `summary:` (one line, written with the words you'd
  actually search for — aliases, class names, and issue numbers included) and optional `tags:`.
- Every page is indexed in `index.md` in the same edit that creates it; every index line
  points to a real page. An unindexed page is invisible.
- Link liberally: `[[page-name]]` for every related concept. A link to a page that doesn't
  exist yet marks something worth writing — it is not an error.
- Don't record what code, git history, or the project's own docs already state — link to
  them instead.
- Sources go in `raw/` unmodified; wiki pages cite them with a relative link.
- Append one line to `log.md` on every substantive change.

## Scope test

"Would this fact matter in a different project?" Yes → `C:\Code\knowledge`. No → here.
Session-loaded working memory (user preferences, feedback on how to work, active work
state) belongs in the Claude Code memory store, not in either wiki.
