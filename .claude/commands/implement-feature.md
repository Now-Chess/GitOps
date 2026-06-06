# Implement Feature from YouTrack

Automated feature-implementation workflow. Ticket ID: `$ARGUMENTS`

This is the **GitOps** repo (Kustomize / Helm / Argo CD / Kargo). In-project =
`NCI`. There is no compile/unit-test step — validation gates are:
- Render: `kustomize build --enable-helm <path>` (must succeed for every changed path)
- Dry-run: `kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -`

This workflow implements the given ticket **and all of its subtasks**, while
respecting `blocked by` dependencies. Tasks that live in other projects
(`NCS`, `NCWF`, or any project other than `NCI`) are never edited here — they
are collected and reported at the end with a ready-to-run prompt.

## Step 1 — Fetch Ticket + Build Task Tree

1. Call `mcp__youtrack__get_issue` with ID `$ARGUMENTS`.
2. Extract and display: summary, description, acceptance criteria, Priority, Subsystem, and the **issue links**.
3. From the links, build the task tree:
   - **Subtasks** = issues linked as `subtask of` / `parent for` (children of `$ARGUMENTS`). Recurse: fetch each subtask with `get_issue` and collect its subtasks too.
   - **Blocked-by** = for every task in the tree, record issues linked as `is blocked by`.
4. Classify each task by project (the prefix before the dash in the issue ID):
   - **In-project** = `NCI`.
   - **Out-of-project** = `NCS`, `NCWF`, or any other prefix. These are **never implemented here**.
5. Display the full tree: root, subtasks (nested), and for each its blockers + project tag.

## Step 2 — Resolve Implementation Order

1. Filter to **in-project (`NCI`), not-yet-resolved** tasks only (root + subtasks). Out-of-project tasks are excluded from implementation.
2. Topologically sort by `blocked by`: a task is only implementable once all its in-project blockers are resolved.
3. A task is **blocked** (cannot start) if any blocker is:
   - an in-project task that is not yet resolved in this run, **or**
   - an out-of-project task (`NCS`/`NCWF`/etc.) — these can't be resolved here.
4. Produce two lists:
   - **Implementable order** — `NCI` tasks, dependency-sorted.
   - **Blocked tasks** — with the blocker(s) that stop them.
5. **Report both lists to the user.** Wait for acknowledgement before continuing.

## Step 3 — Create Worktree

Derive branch name from the root ticket `$ARGUMENTS`:
- `type` from YouTrack issue type: `feature`/`task` → `feat`, `refactor` → `refactor`, `bug` → `fix`, else `chore`
- `scope` from affected component (kebab-case, omit if unclear)
- `description` from ticket summary: lowercase, kebab-case, max 40 chars, drop articles

Branch format: `<type>/<ticket-id>-<description>`
Example: `feat/NCI-456-add-eu-central-1-region`

Call `EnterWorktree` with that branch name.
All subsequent file work happens inside this worktree. All implementable
tasks (root + subtasks) are implemented on this one branch.

## Step 4 — Understand Requirements (read-only)

1. Render the relevant baseline overlays (`kustomize build --enable-helm <path>`) — confirm they render clean before changing anything.
2. For the root + each implementable subtask, spawn `cavecrew-investigator` with: that task's description + acceptance criteria → locate affected components/overlays, charts, Argo CD apps, regions, integration touch-points. Use `ARCHITECTURE.md` / `CONFIGURATION.md` for structure.
3. **If anything is ambiguous (scope unclear, acceptance criteria missing, design decisions needed), use `AskUserQuestion` tool to ask — max 4 questions at once.**
4. **Report plan to user: per task — what will be added/changed, which paths, which components. No file writes yet. Wait for acknowledgement before continuing.**

## Step 5 — Implement (per task, in dependency order)

For each task in the implementable order from Step 2, do the following before moving to the next:

1. Implement task (use the `general-purpose` agent for non-trivial multi-file changes; inline edits for small ones).
2. For **every changed path**, run `kustomize build --enable-helm <path>` — must render without error.
3. For **every changed path**, run `kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -` — must pass.
4. If the change touches secrets, re-seal as required (`scripts/seal-secrets.sh`) — never commit plaintext secrets.
   - **Do NOT proceed to the next task until all changed paths render and dry-run clean.**

If any step fails, iterate until all pass. Once a task is fully validated it
counts as **resolved** for the purpose of unblocking later tasks — re-check
Step 2's blocked list: any task whose blockers are now all resolved becomes
implementable.

## Step 6 — Review

Spawn `cavecrew-reviewer` on the full diff (covering all implemented tasks).
Display findings grouped by severity.

## Step 6b — Apply Review Findings

If the review produced any findings (any severity):
1. Implement all agreed fixes.
2. Re-render + re-dry-run every changed path (Step 5.2–5.3) — must be clean.
3. Re-spawn `cavecrew-reviewer` on the updated diff to confirm all findings are resolved.

Repeat until review is clean or user explicitly accepts remaining findings.

## Step 7 — Confirm + Push

Show summary: root ticket, implemented subtasks, branch, files changed, review findings.
**Use `AskUserQuestion` tool to ask for explicit approval before pushing.** Include any open questions about commit message scope or body if unclear.

On approval, commit following Conventional Commits:

```
<type>(<scope>): <short description, imperative, ≤50 chars>

<optional body: what changed and why, wrap at 72 chars>

Closes $ARGUMENTS
<also list Closes <ID> for each implemented subtask>
https://knockoutwhist.youtrack.cloud/issue/$ARGUMENTS
```

- `type`: same as branch type (`feat`, `refactor`, `chore`, etc.)
- `scope`: affected component (`argocd`, `kargo`, `nowchess`, `ingress-nginx`, `cert-manager`, `postgres`, `redis`, `sealed-secrets`, `metrics-server`, or region e.g. `eu-central-1`, `htwg-1`)
- Subject: imperative mood, no period, lowercase
- Footer `Closes <ID>` for the root and every resolved subtask, plus the root ticket URL.

Push branch to remote.

## Step 8 — Comment on Tickets

After successful push, call `mcp__youtrack__add_issue_comment` on `$ARGUMENTS` **and on each implemented subtask** with:

```
Branch `<branch-name>` pushed.

<one-sentence summary of what was added and why>

Files changed:
- <file1>
- <file2>
```

## Step 9 — Cleanup

Call `ExitWorktree` with `discard_changes: true` to delete the worktree.
(Branch was pushed in step 7 — commits are safe on remote; `discard_changes: true` bypasses the local-ahead guard.)

## Step 10 — Report Blocked + Cross-Project Tasks

Final report to the user, in two sections:

### Blocked in-project tasks
List any `NCI` tasks that could **not** be implemented, with the blocker(s)
that stopped them. (These can be re-run with this command once blockers clear.)

### Cross-project tasks (NCS / NCWF / other)
For every out-of-project task discovered in the tree (whether it was a subtask
or a blocker), output one entry:

```
- <ID> [<PROJECT>]: <summary>
  Prompt: /implement-feature <ID>
```

Where `Prompt` is a short, copy-pasteable instruction to implement that task in
its own project — e.g. the ticket ID plus a one-line description of what the
other project needs to do so this project's blocked tasks can proceed.

End with: branch pushed, tickets commented, worktree deleted, plus the counts of
implemented / blocked / cross-project tasks.
