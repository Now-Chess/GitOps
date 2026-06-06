# Estimate Issue Time in YouTrack

Sprint planning time estimator. Issue ID or empty for full current sprint: `$ARGUMENTS`

This is the **GitOps** repo. Sprint mode defaults to project `NCI`.

## Step 1 — Determine Scope

**Single-issue mode** (`$ARGUMENTS` set):
- Call `mcp__youtrack__get_issue` on `$ARGUMENTS`.
- Proceed with that issue only.

**Sprint mode** (`$ARGUMENTS` empty):
- Call `mcp__youtrack__search_issues` with query `project: NCI Sprints: {current sprint} #Unresolved`.
- If query returns 0 results, use `AskUserQuestion` to ask for the sprint name, then retry with `project: NCI Sprints: {name}`.
- Collect all returned issues.

## Step 2 — Build Issue Tree

For each top-level issue from Step 1:
1. Fetch full details via `mcp__youtrack__get_issue`: summary, description, acceptance criteria, Type, existing `Zeitschätzung`, linked issues.
2. Identify subtasks from links with relation `subtask of` (i.e. issues where the fetched issue is the parent).
3. Recursively fetch subtasks until all leaves are known.
4. Group into tree: Epic → Story → Task/Subtask.

**Leaf node** = issue with no subtask children.
**Parent node** = issue that has at least one subtask child.

## Step 3 — Estimate Leaf Nodes

For each leaf node:
1. Read: summary, description, acceptance criteria, implementation notes.
2. If scope is unclear, search the repo (`Grep`/`Bash`) and render affected overlays (`kustomize build --enable-helm <path>`) to gauge complexity.
3. Assign estimate using this scale:

| Size | Criteria | Estimate |
|------|----------|----------|
| Trivial | Single value/label/tag change, 1-file tweak | 30m |
| Small | One overlay/patch, clear scope, no unknowns | 1h–2h |
| Medium | New component overlay or chart values + Argo CD app wiring | 3h–5h |
| Large | New region/deployment, cross-component, secret + ingress + rollout | 1d–2d |
| XL | New cluster/platform component, migration, research spike | 3d–5d |

4. Record: estimate + one-line reasoning.
5. Skip leaf if it already has `Zeitschätzung` set — note it as pre-estimated.

## Step 4 — Roll Up for Display

YouTrack auto-sums `Zeitschätzung` from subtasks up to parents — **do not write estimates to parent nodes**.

Compute display-only rolled-up totals:
- Parent total = sum of all descendant leaf estimates (including pre-estimated ones).
- Flag any branch where some leaves are missing estimates (partial roll-up).

## Step 5 — Show Summary + Confirm

Display full tree with estimates. Format:

```
Epic  NCI-10: Multi-region rollout            [4h 30m]  ← rolled up
  Story NCI-11: Add eu-central-1 overlay       [2h 30m]  ← rolled up
    Task  NCI-12: Region kustomization          1h 30m   ← leaf (new)
    Task  NCI-13: Argo CD app + sync wave        1h       ← leaf (new)
  Story NCI-14: Cert + ingress for region      [2h]      ← rolled up
    Task  NCI-15: cert-manager Certificate       2h       ← leaf (pre-set, skipped)
```

Legend: `[X]` = display-only roll-up (not written). Plain = will be written to YouTrack.

If sprint mode, show grand total at bottom:
```
Sprint total: Xd Yh Zm  (N issues, M leaves to update)
```

**Use `AskUserQuestion` tool:**
- Does the breakdown look right?
- Any estimates to adjust before writing to YouTrack?

Incorporate all feedback before proceeding.

## Step 6 — Write Estimates

On user approval, write estimates **only to leaf nodes** (bottom-up order):
- For each leaf with a new estimate, call `mcp__youtrack__update_issue` with field `Zeitschätzung` = approved estimate.
- YouTrack period format: `"30m"`, `"1h 30m"`, `"1d"`, `"2d 4h"`.
- Skip leaves already pre-estimated.

## Step 7 — Report

List all updated issues with set estimates.
Show final rolled-up totals per Epic/Story (read back from YouTrack via `mcp__youtrack__get_issue` if needed).
In sprint mode, show total sprint estimate.
