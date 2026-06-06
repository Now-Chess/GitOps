# Create User Story in YouTrack

Automated user-story creation workflow. Topic/hint: `$ARGUMENTS`

This is the **GitOps** repo (Kustomize / Helm / Argo CD / Kargo on Kubernetes).
Stories raised here usually belong to project `NCI`, but routing in Step 5 still
applies. Note: infra work is often framed as a task rather than a user story —
use `Task` type when there is no end-user-facing value.

## Step 1 — Gather Context

Use `AskUserQuestion` tool to ask the user (max 4 questions at once):

1. **Domain** — Is this infrastructure work, or does it touch backend/frontend?
2. **Actor** — Who benefits? (e.g. operator, developer, deployment pipeline, the platform itself)
3. **Action** — What capability/change is needed? (new component, region, rollout strategy, secret, ingress, etc.)
4. **Goal/value** — Why? What outcome does it enable? (reliability, security, cost, velocity)

If `$ARGUMENTS` already answers some of these, skip those questions.

## Step 2 — Research (if needed)

If the topic involves unfamiliar manifests, charts, or constraints:
- Search the repo for relevant paths (use `Grep`/`Bash`); read `ARCHITECTURE.md` / `CONFIGURATION.md` for structure.
- Render relevant overlays: `kustomize build --enable-helm <path>`.
- Use `WebSearch` for Helm chart docs, Argo CD / Kargo / Kubernetes API references.
- Do NOT guess. Surface findings before drafting.

## Step 3 — Draft Story

Compose the full story using this template:

```
As a [type of user/actor]
I want to [perform an action / have a capability]
So that [achieve a goal or value]


Description

[Additional context or operational rationale for this story.]


Acceptance Criteria

[List the specific, measurable criteria that define when this story is done:]

- Criterion 1
- Criterion 2
- Criterion 3


Implementation Notes

[Technical notes: affected components/overlays, charts, regions, design refs, constraints.]
```

Rules:
- User story line: plain English, present tense, from the actor's perspective.
- Acceptance criteria: testable, unambiguous, one condition each (e.g. "kustomize build renders without error", "Argo CD app syncs healthy").
- Implementation notes: optional — only include if there are known constraints, related tickets, or design refs.

## Step 4 — Clarify Acceptance Criteria

Show the draft to the user.
**Use `AskUserQuestion` tool to ask:**
- Are the acceptance criteria complete and correct?
- Any implementation constraints to add?
- Priority (if known)?

Incorporate feedback. Repeat until user approves.

## Step 5 — Determine Project

> **Project routing rules (always apply these):**
> - Infrastructure (Kubernetes, Argo CD, Kargo, pipelines, CI/CD, DB setup, cloud infra) → `NCI`
> - Backend code (game engine, bots, API, services, coordinator) → `NCS`
> - Frontend code (UI, UX, web app) → `NCWF`

- Kubernetes / Argo CD / Kargo / pipelines / infrastructure → project: `NCI` (default for this repo)
- Backend / coordinator / systems / bot / engine → project: `NCS`
- Frontend / UI / UX → project: `NCWF`

If still ambiguous, ask the user.

## Step 6 — Create Issue

Call `mcp__youtrack__create_issue` with:
- `project`: determined in Step 5
- `summary`: concise title derived from the "I want to" clause (≤72 chars, sentence case)
- `description`: full formatted story from Step 3 (Markdown)
- `type`: `Task` for purely technical infra work (default here), `Feature` if it delivers user-facing value.

## Step 7 — Link Issues

After creation, ask the user (use `AskUserQuestion` if interactive, otherwise infer from context):

> Are there related issues to link? (skip if none)

Collect any issue IDs the user mentions. For each, determine the correct relation and call `mcp__youtrack__link_issues`:

| Situation | Relation to use |
|-----------|----------------|
| This must be done before another | `blocks` |
| Another must be done before this | `is blocked by` |
| They share domain or are related | `relates to` |
| This is a child of an epic/story | `subtask of` |
| This is a parent grouping subtasks | `parent for` |
| This depends on another ticket's output | `depends on` |

If the user mentions an issue in the description or implementation notes (e.g. "see NCS-42", "after NCI-12 is done"), auto-detect and suggest linking it — confirm before creating the link.

## Step 8 — Report

Display the created issue ID and URL.
List any links created (relation type + linked issue ID).
Ask if a linked sub-task or implementation ticket is needed.
