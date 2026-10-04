# Issue tracker: Local Markdown

Tickets for this repo are private, local working files under `.scratch/`. Ticket directories are not committed; no shared tickets are expected. Specs may be committed when they need to persist.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create one ticket per file under `.scratch/<feature-slug>/issues/` locally. Do not commit tickets or treat them as shared unless the user explicitly asks.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or issue number directly.
