# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Commands

### Building & Validation
```bash
# Build manifests (with Helm support)
kustomize build --enable-helm <path> > output.yaml

# Validate without applying
kustomize build --enable-helm <path> | kubectl apply --dry-run=client -f -

# Apply manifests to cluster
kustomize build --enable-helm <path> | kubectl apply -f -

# Apply single manifest
kubectl apply -f <file.yaml>
```

### Monitoring & Inspection
```bash
# Watch Argo CD applications
kubectl -n argocd get applications -w
argocd app list

# Check component status
kubectl -n <namespace> get pods
kubectl -n <namespace> logs -f deployment/<name>

# Describe resource
kubectl -n <namespace> describe <resource-type> <name>

# Check application sync status
argocd app get <app-name>
kubectl -n argocd describe application <app-name>
```

### Common Operations
```bash
# Port forward to Argo CD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Get Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode

# Port forward to Kargo API
kubectl port-forward -n kargo svc/kargo-api 8443:443

# Check certificate status
kubectl get certificate -A
kubectl describe certificate -n <namespace> <cert-name>
```

## Architecture Overview

### Component Structure
The repo has three parallel hierarchies for **components**, **regions**, and **deployments**:

1. **Components** (`argocd/`, `cert-manager/`, `kargo/`, `argo-rollouts/`):
   - `base/` - core Kustomization and Helm values
   - `<region>/` (e.g., `eu-central-1/`) - region-specific overrides and values

2. **Regions** (`eu-central-1/`):
   - `root-apps-app.yaml` - root Argo CD application that syncs all other apps
   - `argo-apps/` - Argo Application resources for each component

3. **Projects** (`kargo-projects/orchestration-stack/`):
   - Defines Kargo Warehouse, Stages, Promotions for progressive delivery

### Key Components
- **Argo CD**: Declarative GitOps CD tool - watches this repo and syncs manifests
- **Cert-Manager**: Automates certificate lifecycle (self-signed CA, can add Let's Encrypt)
- **Kargo**: Progressive delivery platform - multi-stage promotions with health checks
- **Argo Rollouts**: Advanced deployment strategies (canary, blue-green)

### How It Works
1. Git commit → Webhook fires → Argo CD fetches latest manifests → Kustomize builds → kubectl applies
2. Sealed Secrets in Git are encrypted at rest, decrypted only in cluster
3. Kargo watches Warehouse for new Freight → auto-promotes or waits for approval → updates Argo CD apps

## Important Patterns

### Kustomization Pattern
Each component follows `base/` + `<region>/` pattern:
- `base/` has shared config, disabled Helm charts (kustomization.yaml)
- `<region>/` enables Helm and overrides values with regional specifics
- To add a new region: copy `eu-central-1/` to new region dir, update domain/values

### Sealed Secrets
- Store encrypted secrets in `secrets/` directory
- Use `kubeseal` CLI to encrypt before committing
- Never commit plaintext credentials
- Sealing keys are NOT in Git (stored in cluster)

### Build with --enable-helm
All Kustomize builds must use `--enable-helm` flag because components use Helm charts. Forgetting this is a common mistake.

### Namespace & Labels
Components deploy to dedicated namespaces:
- `argocd` - Argo CD
- `cert-manager` - Cert-Manager
- `kargo` - Kargo
Avoid cross-namespace resource references; use Argo CD Applications for composition.

## File Locations Reference

```
argocd/base/values.yaml                      # Argo CD Helm values (base)
argocd/eu-central-1/values.yaml              # Argo CD regional overrides
cert-manager/eu-central-1/cert-issuer.yaml   # CA issuer config
kargo/base/values.yaml                       # Kargo Helm values
kargo-projects/orchestration-stack/           # Kargo project definitions
eu-central-1/root-apps-app.yaml              # Root Argo CD app (entry point)
secrets/                                     # Sealed secrets storage
scripts/deploy-to-cluster.sh                 # One-shot cluster bootstrap
```

## Common Tasks

### Add a New Region
1. Create `eu-west-1/` directory structure mirroring `eu-central-1/`
2. Copy component overlays and update domain/version values
3. Create `eu-west-1/root-apps-app.yaml` pointing to regional resources
4. Test: `kustomize build --enable-helm eu-west-1/`

### Update Component Versions
1. Edit Helm chart version in `<component>/<region>/kustomization.yaml`
2. Validate: `kustomize build --enable-helm <component>/<region>/`
3. Apply: `kustomize build --enable-helm <component>/<region>/ | kubectl apply -f -`

### Create a New Secret
1. Create plaintext secret: `kubectl -n <ns> create secret generic my-secret --from-literal=key=value --dry-run=client -o yaml > secret.yaml`
2. Encrypt: `kubeseal -f secret.yaml -w sealed-secret.yaml`
3. Move to `secrets/` directory and commit
4. Cluster controller auto-decrypts when applied

### Sync Application Manually
```bash
argocd app sync <app-name>
# or force sync if stuck
argocd app sync <app-name> --force
```

## Debugging Tips

- Use `--dry-run=client` to validate before applying
- Check `kubectl -n <ns> describe pod <name>` for startup errors
- Use `kubectl -n <ns> logs <pod>` for runtime issues
- Verify Git repository credentials: `kubectl -n argocd get secret repo-credentials -o yaml`
- For Argo CD sync failures: `kubectl -n argocd describe application <app-name>`
- Use `kustomize build . -v` for verbose Kustomize output

## Documentation Index

- **README.md** - Overview, prerequisites, quick start, installation steps
- **ARCHITECTURE.md** - Detailed system design, data flows, security layers
- **DEPLOYMENT_GUIDE.md** - Step-by-step installation for different scenarios
- **CONFIGURATION.md** - Configuration customization guide
- **CONTRIBUTING.md** - Commit message conventions, testing guidelines, release process
- **TROUBLESHOOTING.md** - Common issues and solutions
