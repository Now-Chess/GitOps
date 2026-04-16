# Configuration Guide

Guide for configuring and customizing the GitOps infrastructure.

## Customizing Component Versions

Edit Helm chart versions in kustomization.yaml files:

```yaml
# argocd/eu-central-1/kustomization.yaml
helmCharts:
- name: argo-cd
  repo: https://argoproj.github.io/argo-helm
  version: 5.x.x  # Update version
  releaseName: argocd
```

## Resource Configuration

Modify resource limits in values.yaml:

```yaml
# argocd/eu-central-1/values.yaml
controller:
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

## OIDC Authentication Setup

Update argocd-cm ConfigMap:

```yaml
oidc.config: |
  name: Azure AD
  issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
  clientID: <client-id>
  clientSecret: $oidc.clientSecret
```

## Adding New Regions

1. Create new directory: `<region>/`
2. Copy and adapt configuration from `eu-central-1/`
3. Update domain names and region-specific values
4. Create new root application

## Secrets Configuration

Using Sealed Secrets pattern:

```bash
# Create secret
kubectl create secret generic my-secret \
  --from-literal=password=mysecret \
  --dry-run=client -o yaml > my-secret.yaml

# Seal it
kubeseal -f my-secret.yaml -w my-sealed-secret.yaml

# Commit sealed version
git add my-sealed-secret.yaml
```

## Network Policies

Configure NetworkPolicy for security:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-allow-ingress
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
  - Ingress
```

## Certificate Configuration

Update cert issuer for custom domains:

```yaml
# cert-manager/eu-central-1/cert-issuer.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: custom-issuer
  namespace: kube-devops
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-key
```

## Kargo Customization

Configure Kargo projects and stages:

```yaml
# kargo-projects/orchestration-stack/orch-stage.yaml
apiVersion: kargo.akuity.io/v1alpha1
kind: Stage
metadata:
  name: prod
  namespace: orchestration-kargo
spec:
  subscriptions:
    upstreamStages:
    - name: staging
  promotionMechanisms:
    argocd:
      appUpdates:
      - appName: production-app
```

---
**Last Updated**: 2026-04-16

