# Create Defect in YouTrack

Automated defect creation workflow. Topic/hint: `$ARGUMENTS`

This is the **GitOps** repo (Kustomize / Helm / Argo CD / Kargo on Kubernetes).
Defects raised here usually belong to project `NCI`, but routing in Step 5 still
applies.

## Step 1 — Gather Context

Use `AskUserQuestion` tool to ask the user (max 4 questions at once):

1. **Component** — Where does the bug occur? (e.g. argocd, kargo, ingress-nginx, cert-manager, postgres, redis, sealed-secrets, a nowchess overlay, a region/deployment)
2. **What breaks** — What is the actual (broken) behavior? (sync failure, render error, pod crashloop, cert not issued, etc.)
3. **Expected** — What should happen instead?
4. **Reproducibility** — Always reproducible? Which cluster/region/overlay triggers it?

If `$ARGUMENTS` already answers some of these, skip those questions.

## Step 2 — Research (if needed)

If the bug involves manifests, overlays, or rendering:
- Search repo for relevant paths (`Grep`/`Bash`) under the affected component dir.
- Render the suspect path: `kustomize build --enable-helm <path>` and inspect output.
- Validate: `kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -`.
- Do NOT guess at root cause. Surface findings before drafting.

## Step 3 — Draft Defect

Compose the full defect report using this template:

```
Summary

[One-sentence description of what is broken.]


Steps to Reproduce

1. Step one
2. Step two
3. Step three


Expected Behavior

[What should happen.]


Actual Behavior

[What actually happens.]


Environment / Notes

[Any relevant context: cluster/region, overlay path, Argo CD app name, kustomize/helm versions, error output — only if applicable.]
```

Rules:
- Steps must be minimal and reproducible (prefer a `kustomize build` / `kubectl --dry-run` command).
- Expected vs actual: concrete and unambiguous.
- Omit "Environment / Notes" section if not relevant.

## Step 4 — Clarify

Show the draft to the user.
**Use `AskUserQuestion` tool to ask:**
- Are steps to reproduce complete and accurate?
- Severity: Blocker / Critical / Major / Minor / Trivial?
- Any related tickets or recent changes to link?

Incorporate feedback. Repeat until user approves.

## Step 5 — Determine Project

> **Project routing rules (always apply these):**
> - Infrastructure (Kubernetes, Argo CD, Kargo, pipelines, CI/CD, DB setup, cloud infra) → `NCI`
> - Backend code (game engine, bots, API, services, coordinator) → `NCS`
> - Frontend code (UI, UX, web app) → `NCWF`

- Kubernetes / Argo CD / Kargo / pipelines / infrastructure → project: `NCI` (default for this repo)
- Backend / coordinator / systems / bot / engine → project: `NCS`
- Frontend / UI / UX → project: `NCWF`

If ambiguous, ask the user.

## Step 6 — Create Issue

Call `mcp__youtrack__create_issue` with:
- `project`: determined in Step 5
- `summary`: concise title describing what is broken (≤72 chars, sentence case)
- `description`: full formatted defect report from Step 3 (Markdown)
- `type`: `Bug`

## Step 7 — Report

Display the created issue ID and URL.
Ask if a linked investigation or fix task is needed.
