# GitOps for the KnockOut-Whist Project

This repository contains the GitOps configuration for deploying and managing the KnockOut-Whist project using modern DevOps tools and practices. It leverages GitOps principles to ensure that infrastructure and application deployments are version-controlled, auditable, and automated.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Components](#components)
- [Installation Guide](#installation-guide)
- [Configuration](#configuration)
- [Secrets Management](#secrets-management)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This GitOps repository implements a complete infrastructure-as-code solution for Kubernetes deployments in the EU Central 1 region. It provides:

- **Declarative Infrastructure**: All configurations are defined in Git
- **Automated Deployments**: Argo CD automatically syncs cluster state with Git
- **Progressive Delivery**: Kargo manages safe, progressive deployments across environments
- **Certificate Management**: Automated certificate provisioning via cert-manager
- **Secrets Management**: Encrypted secret storage with sealed-secrets pattern
- **Monitoring & Logging**: Integration points for observability tools

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   ArgoCD (Namespace)                 │  │
│  │  - Application Controller                           │  │
│  │  - Server (UI & API)                                │  │
│  │  - Repo Server                                      │  │
│  │  - Redis (Session Store)                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Cert-Manager (Namespace)                │  │
│  │  - Webhook                                          │  │
│  │  - Controller                                       │  │
│  │  - CA Issuer                                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                Kargo (Namespace)                     │  │
│  │  - API Server                                       │  │
│  │  - Controller                                       │  │
│  │  - Webhooks Server                                  │  │
│  │  - Management Controller                            │  │
│  │  - External Webhooks Server                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Kargo Projects (Orchestration)              │  │
│  │  - Promotion Pipelines                              │  │
│  │  - Warehouse                                        │  │
│  │  - Stages                                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Argo Rollouts (Optional)                     │  │
│  │  - Canary Deployments                               │  │
│  │  - Progressive Rollout Controller                   │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
           │
           ▼
    ┌─────────────────┐
    │   Git Repo      │
    │ (This Repo)     │
    └─────────────────┘
```

## Prerequisites

### System Requirements

- **Kubernetes**: Version 1.24+ (tested with 1.26+)
- **kubectl**: Latest stable version
- **Helm**: 3.10+
- **Kustomize**: 5.0+ (with Helm plugin enabled)
- **Git**: 2.40+

### Cluster Requirements

- Minimum 2 CPU cores, 4GB RAM (for development)
- Production: 4+ CPU cores, 8GB+ RAM recommended
- Storage class configured for persistent volumes
- Ingress controller (optional, for external access)
- cert-manager CRDs installed before cert-manager deployment

### Network Requirements

- Outbound access to container registries (quay.io, ghcr.io, ecr-public.aws.com)
- Git repository access (SSH key configured)
- DNS resolution for configured domains
- Port 443 (HTTPS) for API access
- Port 6379 (Redis) for internal Argo CD communication

## Quick Start

### 1. Clone the Repository

```bash
git clone git@git.janis-eccarius.de:NowChess/GitOps.git
cd GitOps
```

### 2. Prepare Your Kubernetes Cluster

Ensure your kubectl context points to the target cluster:

```bash
kubectl cluster-info
kubectl get nodes
```

### 3. Automatic Installation

For a complete automated setup (recommended for initial deployment):

```bash
cd scripts
chmod +x deploy-to-cluster.sh
./deploy-to-cluster.sh
```

This script will:
- Install Cert-Manager and required CRDs
- Install and configure Argo CD
- Configure sealed secrets for GitOps
- Deploy the root Argo CD application
- Display access credentials

### 4. Manual Installation (Step-by-Step)

If you prefer manual control or need to customize the installation:

#### Step 1: Install Cert-Manager

```bash
kustomize build --enable-helm cert-manager/eu-central-1 | kubectl apply -f -

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cert-manager \
  -n cert-manager --timeout=300s
```

#### Step 2: Install Argo CD

```bash
kustomize build --enable-helm argocd/eu-central-1 | kubectl apply -f -

# Wait for Argo CD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s
```

#### Step 3: Get Initial Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

#### Step 4: Access Argo CD

**Port Forward (Development)**:
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Access at https://localhost:8080
```

**Ingress (Production)**:
- If using an ingress controller, access via configured domain (e.g., `argo.knockout.janis-eccarius.de`)

#### Step 5: Deploy Root Application

```bash
kubectl apply -f eu-central-1/root-apps-app.yaml

# Monitor deployment
kubectl -n argocd get applications
argocd app list
```

## Directory Structure

```
GitOps/
├── README.md                           # This file
├── scripts/
│   └── deploy-to-cluster.sh           # Automated deployment script
├── argocd/                            # Argo CD configuration
│   ├── base/                          # Base kustomization
│   │   ├── cert-manager-namespace.yaml
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── eu-central-1/                  # Regional overrides
│       ├── kube-devops.yaml
│       ├── kustomization.yaml
│       └── values.yaml
├── cert-manager/                      # Cert-Manager configuration
│   ├── base/
│   │   ├── cert-manager-namespace.yaml
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── eu-central-1/
│       ├── cert-issuer.yaml
│       ├── kustomization.yaml
├── kargo/                             # Kargo progressive delivery
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── eu-central-1/
│       ├── kustomization.yaml
│       └── values.yaml
├── kargo-projects/                    # Kargo project definitions
│   └── orchestration-stack/
│       ├── kustomization.yaml
│       ├── orch-project.yaml
│       ├── orch-projectconfig.yaml
│       ├── orch-promotion-template.yaml
│       ├── orch-stage.yaml
│       └── orch-warehouse.yaml
├── argo-rollouts/                     # Argo Rollouts configuration
│   └── eu-central-1/
│       ├── kube-devops.yaml
│       └── kustomization.yaml
├── eu-central-1/                      # Regional deployment root
│   ├── root-apps-app.yaml             # Root Argo CD application
│   └── argo-apps/                     # All deployed applications
│       ├── argo-rollouts/
│       ├── cert-manager/
│       ├── kargo/
│       └── kargo-projects/
├── secrets/                           # Encrypted secrets
│   ├── kustomization.yaml
│   ├── gitea/
│   ├── github/
│   └── kargo/
└── Passwords.kdbx                     # Password manager file (DO NOT COMMIT)
```

## Components

### Argo CD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

**Configuration Files**:
- `argocd/eu-central-1/values.yaml` - Main Helm values

**Key Features Enabled**:
- Helm support with `kustomize.buildOptions: --enable-helm`
- Automated pruning and self-healing
- Kustomize integration
- Redis caching
- Status badge support

**Access**:
```bash
# Via port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

**Next Steps**:
1. Change default admin password in Argo CD UI
2. Configure Git repository credentials
3. Set up OIDC/SSO for authentication
4. Create additional Argo CD projects for RBAC

### Cert-Manager

Cert-Manager automates certificate management in Kubernetes using cert-manager and Let's Encrypt.

**Configuration Files**:
- `cert-manager/base/values.yaml` - Base Helm configuration
- `cert-manager/eu-central-1/cert-issuer.yaml` - Certificate issuer configuration

**Certificate Issuers**:
- Self-signed CA issuer for internal certificates
- Integration with Let's Encrypt for public certificates (can be configured)

**Usage**:
```bash
# View certificate issuers
kubectl get issuers -n cert-manager

# Monitor certificate requests
kubectl get certificaterequest -A
```

### Kargo

Kargo is a progressive delivery platform that automates and secures multi-stage promotion of Freight across a series of Stages.

**Configuration Files**:
- `kargo/base/values.yaml` - Core Kargo configuration
- `kargo/eu-central-1/values.yaml` - Regional overrides
- `kargo-projects/orchestration-stack/` - Project definitions

**Key Features**:
- Multi-stage promotion pipelines
- Integration with Argo CD and Argo Rollouts
- OIDC authentication support
- External webhook integrations
- Garbage collection for old promotions and freight

**Access**:
```bash
# Port forward to Kargo API
kubectl port-forward -n kargo svc/kargo-api 8443:443

# Get admin credentials
kubectl -n kargo get secret kargo-admin-password -o jsonpath="{.data.password}"
```

### Argo Rollouts

Argo Rollouts provides advanced deployment strategies (Canary, Blue-Green, etc.).

**Configuration Files**:
- `argo-rollouts/eu-central-1/kube-devops.yaml` - Deployment spec
- `argo-rollouts/eu-central-1/kustomization.yaml` - Kustomization

**Features**:
- Canary deployments
- Blue-green deployments
- Progressive rollouts with automated analysis
- Integration with analysis tools

## Installation Guide

### Detailed Installation Steps

#### Prerequisites Verification

```bash
# Verify Kubernetes version
kubectl version --short

# Check node capacity
kubectl top nodes

# Verify storage class exists
kubectl get storageclass

# Check for existing cert-manager
kubectl get crd | grep cert-manager
```

#### Step 1: Namespace Setup

```bash
# Create namespaces
kubectl create namespace argocd
kubectl create namespace cert-manager
kubectl create namespace kargo

# Label namespaces for cert-manager
kubectl label namespace cert-manager cert-manager.io/inject-enabled=true
```

#### Step 2: Install Cert-Manager

```bash
# Add cert-manager CRDs first
kustomize build cert-manager/base | kubectl apply -f -

# Wait for CRDs
sleep 5

# Install cert-manager
kustomize build --enable-helm cert-manager/eu-central-1 | kubectl apply -f -

# Verify installation
kubectl -n cert-manager get pods
kubectl get crd | grep certmanager
```

#### Step 3: Install Argo CD

```bash
kustomize build --enable-helm argocd/eu-central-1 | kubectl apply -f -

# Wait for readiness
kubectl -n argocd wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server --timeout=300s
```

#### Step 4: Configure Secrets

```bash
# Create Git repository secret
kubectl -n argocd create secret generic repo-credentials \
  --from-file=sshPrivateKey=$HOME/.ssh/id_rsa \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Step 5: Deploy Applications

```bash
# Apply root application
kubectl apply -f eu-central-1/root-apps-app.yaml

# Monitor sync status
watch "kubectl -n argocd get applications"
```

### Post-Installation Configuration

#### 1. Update Admin Credentials

```bash
# Generate new password hash
PASSWORD=$(echo 'mypassword' | htpasswd -nbBC 10 admin | tr -d ':\n' | sed 's/$2y/$2a/')

# Update secret
kubectl -n argocd patch secret argocd-secret -p \
  "{\"data\":{\"admin.password\":\"$(echo -n $PASSWORD | base64)\"}\
  \"admin.passwordMtime\":\"$(date -u +'%Y-%m-%dT%H:%M:%SZ' | base64)\"}"
```

#### 2. Configure Git Repository

In Argo CD UI:
1. Settings → Repositories
2. Connect Repo → Via SSH
3. Enter repository URL: `git@git.janis-eccarius.de:NowChess/GitOps.git`
4. Upload SSH private key
5. Save and verify

#### 3. Enable OIDC Authentication (Optional)

Update `argocd/eu-central-1/values.yaml`:

```yaml
configs:
  cm:
    oidc.config: |
      name: <Your Provider>
      issuer: <https://provider/endpoint>
      clientID: <client-id>
      clientSecret: $oidc.clientSecret
```

## Configuration

### Regional Configuration

This repository is configured for **EU Central 1** region. To add new regions:

1. Create new directory: `eu-west-1/`
2. Copy and adapt configuration from `eu-central-1/`
3. Update domain names and region-specific values
4. Create new root application for the region

### Customizing Component Versions

Edit the Helm chart versions in respective `kustomization.yaml` files:

```yaml
# Example: argocd/eu-central-1/kustomization.yaml
helmCharts:
- name: argo-cd
  repo: https://argoproj.github.io/argo-helm
  version: 5.x.x  # Update version here
  releaseName: argocd
  namespace: argocd
```

### Resource Limits

Default resource requests/limits can be modified in `values.yaml` files:

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

## Secrets Management

### Secret Storage Strategy

This repository uses the **Sealed Secrets** pattern:

1. **Encrypted Storage**: Secrets are encrypted in Git using sealing keys
2. **Key Management**: Sealing keys are stored securely outside Git
3. **Decryption**: Sealed secrets are automatically decrypted by the cluster

### Creating New Secrets

```bash
# Install kubeseal (one-time)
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/kubeseal-0.18.0-linux-amd64.tar.gz
tar xfz kubeseal-0.18.0-linux-amd64.tar.gz -C /usr/local/bin

# Create a new secret
kubectl -n <namespace> create secret generic my-secret \
  --from-literal=password=mysecret \
  --dry-run=client -o yaml > my-secret.yaml

# Seal it
kubeseal -f my-secret.yaml -w my-sealed-secret.yaml

# Commit sealed secret to Git
git add my-sealed-secret.yaml
git commit -m "Add sealed secret"
git push
```

### Accessing Secret Credentials

Located in `secrets/` directory:

- **GitHub**: `secrets/github/` - GitHub access tokens
- **Gitea**: `secrets/gitea/` - Gitea repository access
- **Kargo**: `secrets/kargo/` - Kargo admin credentials

**Never commit unencrypted secrets to Git.**

## Troubleshooting

### Common Issues and Solutions

#### 1. Pods Not Starting

```bash
# Check pod status and events
kubectl -n <namespace> describe pod <pod-name>

# View logs
kubectl -n <namespace> logs <pod-name>
```

#### 2. Certificate Issues

```bash
# Check certificate status
kubectl get certificate -A
kubectl describe certificate -n <namespace> <cert-name>

# Check cert-manager logs
kubectl -n cert-manager logs -f deployment/cert-manager
```

#### 3. Argo CD Sync Failures

```bash
# Get application status
kubectl -n argocd get application

# Detailed status
kubectl -n argocd describe application <app-name>

# Resync
argocd app sync <app-name>
```

#### 4. Git Repository Connection Issues

```bash
# Check repository credentials
kubectl -n argocd get secret repo-credentials -o yaml

# Test repository access
kubectl -n argocd exec -it <argocd-repo-server-pod> -- bash
# Try: ssh -v git@git.janis-eccarius.de
```

### Debugging Commands

```bash
# View all resources in cluster
kubectl get all -A

# Get cluster events
kubectl get events -A --sort-by='.lastTimestamp'

# Check resource quotas
kubectl describe resourcequota -A

# Monitor node status
kubectl describe nodes
```

### Support Resources

- **Argo CD Docs**: https://argo-cd.readthedocs.io/
- **Cert-Manager Docs**: https://cert-manager.io/docs/
- **Kargo Docs**: https://kargo.akuity.io/
- **Argo Rollouts Docs**: https://argoproj.github.io/argo-rollouts/

## Contributing

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```

2. Make your changes and test locally:
   ```bash
   kustomize build <path> | kubectl apply --dry-run=client -f -
   ```

3. Commit with descriptive messages:
   ```bash
   git commit -m "feat: add new certificate issuer"
   ```

4. Push to repository:
   ```bash
   git push origin feature/my-feature
   ```

5. Create merge request for review

### Best Practices

- **Small, focused commits**: Each commit should represent one logical change
- **Test before committing**: Use `--dry-run` to validate
- **Document changes**: Update this README for significant changes
- **Use semantic versioning**: Tag releases appropriately
- **Follow naming conventions**: Use descriptive names for branches, commits, and resources

### Policy and Guidelines

- All changes must go through Git version control
- Never manually apply Kubernetes manifests to production
- Always validate with `kustomize build` before deployment
- Encrypt all secrets before committing
- Keep sealed-secrets keys secure (not in Git)
- Regular security audits of repository access

## Additional Resources

### Documentation Files

- `DEPLOYMENT_GUIDE.md` - Detailed deployment instructions
- `ARCHITECTURE.md` - System architecture overview
- `TROUBLESHOOTING.md` - Extended troubleshooting guide
- `UPGRADE_GUIDE.md` - Version upgrade procedures

### Useful Commands Reference

```bash
# Kustomize build and apply
kustomize build . | kubectl apply -f -
kustomize build . | kubectl apply --dry-run=client -f -

# Watch applications
kubectl -n argocd get applications -w
argocd app list
argocd app watch <app-name>

# Get application details
argocd app get <app-name>
kubectl -n argocd describe application <app-name>

# Manual sync
argocd app sync <app-name>

# Access logs
kubectl -n argocd logs -f deployment/argocd-controller
kubectl -n cert-manager logs -f deployment/cert-manager
```

---

**Last Updated**: 2026-04-16
**Maintained By**: NowChess DevOps Team
**Repository**: https://git.janis-eccarius.de/NowChess/GitOps
