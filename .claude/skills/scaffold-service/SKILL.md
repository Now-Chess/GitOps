---
name: scaffold-service
description: Scaffold a new NowChess microservice or add/change configuration in this GitOps repo. Use when asked to "add a microservice", "add a new service", "wire a new deployment", "add an env var / ConfigMap", "add a new config", or "register a new image" for the nowchess stack. Knows the base + overlay + image-automation layout and the kustomize/dry-run validation gate.
---

# Scaffold a NowChess service / configuration (GitOps)

A NowChess microservice is an Argo Rollouts **blue/green Rollout** with an
**active + preview Service pair**, an **HPA**, environment via a shared
**ConfigMap** + **Secrets**, and an **image** registered (and tag-automated via
Kargo) in every region/stage overlay.

Always read the existing `nowchess-account` service as the reference example
before writing — copy its shape, don't invent one.

Files that define the base stack (`nowchess/base/`):

| File | Holds |
|------|-------|
| `nowchess-rollouts.yaml` | one `Rollout` per service |
| `nowchess-services.yaml` | `<svc>-active` + `<svc>-preview` Services |
| `nowchess-hpa.yaml`      | one `HorizontalPodAutoscaler` per service |
| `nowchess-env-config.yaml` | shared `nowchess-env-config` ConfigMap |
| `kustomization.yaml`     | resource list + `rollout-transform.yaml` + openapi schema |

Overlays: `nowchess/{eu-central-1-prod,eu-central-1-staging,htwg-1-prod}/` —
each `kustomization.yaml` sets namespace, patches HPA replicas + ConfigMap, and
pins `images:` tags. Image tag bumps are automated by Kargo under
`kargo-projects/nowchess/`.

---

## Mode A — Add a new microservice `<svc>` (service name `nowchess-<svc>`)

1. **Pick a unique container port.** Check the ports already used in
   `nowchess-services.yaml` (8080 core, 8083 account, 8087 bot-platform, …) and
   choose a free one. Use the same port for container, active and preview.

2. **Rollout** — append a `Rollout` to `nowchess/base/nowchess-rollouts.yaml`,
   modelled on `nowchess-account`:
   - `metadata.name` + `labels.app` + `selector.matchLabels.app` =
     `nowchess-<svc>`.
   - `spec.strategy.blueGreen.activeService: nowchess-<svc>-active`,
     `previewService: nowchess-<svc>-preview` (match the existing blueGreen
     block).
   - `image: ghcr.io/now-chess/now-chess-systems/<svc>:latest`,
     `imagePullPolicy: Always`, `imagePullSecrets: ghcr-pull-secret`.
   - `envFrom` the `nowchess-env-config` ConfigMap; add only the extra `env`
     this service needs (reuse the existing secret refs where applicable).
   - Update the grafana scrape annotation `metrics_portNumber` to the chosen port.

3. **Services** — append `nowchess-<svc>-active` and `nowchess-<svc>-preview` to
   `nowchess/base/nowchess-services.yaml` (`selector.app: nowchess-<svc>`, the
   chosen port). Both are required — blue/green needs the pair.

4. **HPA** — append a `HorizontalPodAutoscaler` to
   `nowchess/base/nowchess-hpa.yaml` with
   `scaleTargetRef: { apiVersion: argoproj.io/v1alpha1, kind: Rollout, name: nowchess-<svc> }`.

   `nowchess-rollouts.yaml`, `-services.yaml`, `-hpa.yaml` are already in the
   base `kustomization.yaml` `resources:` — **no new resource entry needed** for
   these. Only add to `resources:` when you create a brand-new file.

5. **Register the image in every overlay.** In each
   `nowchess/<overlay>/kustomization.yaml` add to `images:`:
   ```yaml
   - name: ghcr.io/now-chess/now-chess-systems/<svc>
     newTag: <current-version>
   ```
   If staging caps replicas, also add the per-overlay HPA patch
   (`maxReplicas: 1`) like the sibling services in `eu-central-1-staging`.

6. **Kargo image automation** — add the new image to the warehouse subscription
   and promotion steps under `kargo-projects/nowchess/` (mirror an existing
   service entry in `ncs-warehouse.yaml` and `ncs-promotion-template.yaml`) so
   tag bumps are automated.

7. **Secrets / RBAC** — if the service needs DB creds, JWT keys, or coordinator
   RBAC, add the refs the same way `account`/`coordinator` do. Never commit
   plaintext secrets — re-seal with `scripts/seal-secrets.sh`.

## Mode B — Add / change configuration

- **Shared env var** → add the key to `nowchess/base/nowchess-env-config.yaml`,
  then override per environment with a ConfigMap patch in each overlay's
  `kustomization.yaml` (see the `nowchess-env-config` patch in
  `eu-central-1-staging`).
- **New ConfigMap / Secret file** → create the YAML, add it to the relevant
  `kustomization.yaml` `resources:`, and wire it into the Rollout via `envFrom`
  / `valueFrom` (the `rollout-transform.yaml` nameReference rules already remap
  ConfigMap/Secret names inside Rollouts).
- **Region-specific value** → patch it in the overlay only; keep the base
  generic.

---

## Validation gate (always, before reporting done)

For **every** changed overlay path:

```bash
kustomize build --enable-helm nowchess/<overlay>                      # renders clean
kustomize build --enable-helm nowchess/<overlay> | kubectl apply --dry-run=client -f -
```

Both must succeed for all three overlays (`eu-central-1-prod`,
`eu-central-1-staging`, `htwg-1-prod`). Fix and re-run until clean. Then report
the files touched and the overlays validated. Do not apply to a live cluster
unless explicitly asked — Argo CD syncs from `main`.
