# Fix Defect from YouTrack

Automated defect-fix workflow. Ticket ID: `$ARGUMENTS`

This is the **GitOps** repo (Kustomize / Helm / Argo CD / Kargo). There is no
compile/unit-test step — validation gates are:
- Render: `kustomize build --enable-helm <path>` (must succeed for every changed path)
- Dry-run: `kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -`

Run both for **every overlay/path touched by the fix**.

## Step 1 — Fetch Ticket

Call `mcp__youtrack__get_issue` with ID `$ARGUMENTS`.
Extract and display: summary, description, steps to reproduce, Priority, Subsystem.

## Step 2 — Create Worktree

Derive branch name from ticket:
- `type` from YouTrack issue type: `bug` → `fix`, `feature`/`task` → `feat`, `refactor` → `refactor`, else `chore`
- `scope` from affected component (kebab-case, omit if unclear)
- `description` from ticket summary: lowercase, kebab-case, max 40 chars, drop articles

Branch format: `<type>/<ticket-id>-<description>`
Example: `fix/NCI-123-argocd-app-sync-loop`

Call `EnterWorktree` with that branch name.
All subsequent file work happens inside this worktree.

## Step 3 — Identify Root Cause (read-only)

1. Render the suspect path(s): `kustomize build --enable-helm <path>` — capture errors.
2. Dry-run validate: `kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -` — capture failures.
3. Spawn `cavecrew-investigator` with: ticket description + render/dry-run output → locate root cause (files, line numbers, what's wrong).
4. **If anything is ambiguous (reproduction unclear, scope uncertain, conflicting signals), use `AskUserQuestion` tool to ask — max 4 questions at once.**
5. **Report findings to user. No file writes yet. Wait for acknowledgement before continuing.**

## Step 3b — Complexity Assessment + Subtasks

After root cause confirmed, assess scope:

**Simple** (1–2 files, single overlay, < 1 hour estimated): proceed directly to Step 4.

**Complex** (3+ files, multiple components/regions, or estimated > 1 hour): create subtasks before changing manifests.

To create subtasks:
1. Break fix into discrete, independently-completable tasks (e.g. "Fix sync-wave annotation on argocd app", "Patch ingress host in eu-central-1 overlay", "Update sealed-secret for redis").
2. For each subtask call `mcp__youtrack__create_issue` with:
   - `project`: based on subtask content — do **not** inherit from parent. Infrastructure → `NCI`; backend code → `NCS`; frontend/UI → `NCWF`. If ambiguous, ask user.
   - `summary`: concise action-oriented title
   - `type`: `Task`
   - `description`: what to do and why
3. Call `mcp__youtrack__link_issues` to link each subtask to `$ARGUMENTS` with relation `subtask of`.
4. Check if the ticket description or comments mention other issue IDs. For each mentioned ID, suggest a link and confirm with user:
   - Fix depends on another fix finishing first → `is blocked by`
   - This fix blocks another ticket → `blocks`
   - Logically related but independent → `relates to`
5. List created subtask IDs and any additional links to user.

Then proceed to Step 4, implementing subtasks in order.

## Step 4 — Fix

1. Implement fix (use the `general-purpose` agent for non-trivial multi-file changes; inline edits for small ones).
2. For **every changed path**, run `kustomize build --enable-helm <path>` — must render without error.
3. For **every changed path**, run `kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -` — must pass.
4. If the change touches secrets, re-seal as required (`scripts/seal-secrets.sh`) — never commit plaintext secrets.
   - **Do NOT proceed to Step 5 until all changed paths render and dry-run clean.**
If any step fails, iterate until all pass.

## Step 5 — Review

Spawn `cavecrew-reviewer` on the full diff.
Display findings grouped by severity.

## Step 5b — Apply Review Findings

If the review produced any findings (any severity):
1. Implement all agreed fixes.
2. Re-render + re-dry-run every changed path (Step 4.2–4.3) — must be clean.
3. Re-spawn `cavecrew-reviewer` on the updated diff to confirm all findings are resolved.

Repeat until review is clean or user explicitly accepts remaining findings.

## Step 6 — Confirm + Push

Show summary: ticket, branch, files changed, review findings.
**Use `AskUserQuestion` tool to ask for explicit approval before pushing.** Include any open questions about commit message scope or body if unclear.

On approval, commit following Conventional Commits:

```
<type>(<scope>): <short description, imperative, ≤50 chars>

<optional body: what changed and why, wrap at 72 chars>

Closes $ARGUMENTS
https://knockoutwhist.youtrack.cloud/issue/$ARGUMENTS
```

- `type`: same as branch type (`fix`, `feat`, `refactor`, `chore`, etc.)
- `scope`: affected component (`argocd`, `kargo`, `nowchess`, `ingress-nginx`, `cert-manager`, `postgres`, `redis`, `sealed-secrets`, `metrics-server`, or region e.g. `eu-central-1`, `htwg-1`)
- Subject: imperative mood, no period, lowercase
- Footer `Closes $ARGUMENTS` and ticket URL always present

Push branch to remote.

## Step 7 — Comment on Ticket

After successful push, call `mcp__youtrack__add_issue_comment` on `$ARGUMENTS` with:

```
Branch `<branch-name>` pushed.

<one-sentence summary of what was changed and why>

Files changed:
- <file1>
- <file2>
```

## Step 7b — Additional Links

After commenting, ask the user if `$ARGUMENTS` should be linked to any other issues not already linked:

| Situation | Relation |
|-----------|---------|
| This fix blocks another open ticket | `blocks` |
| Another ticket must ship first | `is blocked by` |
| Related defect or story | `relates to` |
| Duplicate of another defect | `duplicates` |

Scan the ticket description and comments for any issue IDs that were mentioned but not yet linked. Suggest those automatically.

Call `mcp__youtrack__link_issues` for each confirmed link.

## Step 8 — Cleanup

Call `ExitWorktree` with `discard_changes: true` to delete the worktree.
(Branch was pushed in step 6 — commits are safe on remote; `discard_changes: true` bypasses the local-ahead guard.)
Report: branch pushed, ticket commented, links created, worktree deleted, done.
