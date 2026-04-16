# Architecture Overview

This document provides a detailed technical architecture of the GitOps infrastructure.

## System Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                        Git Repository                           │
│                   (This GitOps Repository)                      │
│  - Infrastructure as Code                                       │
│  - Application Manifests                                        │
│  - Configuration & Secrets                                      │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                  ┌────────────┴────────────┐
                  ▼                         ▼
        ┌──────────────────┐      ┌──────────────────┐
        │   Kubernetes     │      │  Webhook Triggers│
        │   API Server     │      │   (GitHub/Gitea) │
        └────────┬─────────┘      └──────────────────┘
                 │
    ┌────────────┼────────────────┐
    │            │                │
    ▼            ▼                ▼
┌─────────┐ ┌──────────┐  ┌──────────────┐
│ ArgoCD  │ │ Kargo    │  │ Cert-Manager │
│ Server  │ │ Controller
 │  └─────────┘ └──────────┘  └──────────────┘
    │
    │ Monitors & Syncs
    │
    ▼
┌──────────────────────────────────────────┐
│       Kubernetes Cluster Resources       │
│  - Deployments                           │
│  - Services                              │
│  - ConfigMaps & Secrets                  │
│  - Ingresses                             │
│  - Custom Resources (Kargo, Rollouts)    │
└──────────────────────────────────────────┘
```

## Component Architecture

### 1. Argo CD

**Purpose**: GitOps continuous deployment orchestration

**Components**:
- **API Server**: RESTful API for CLI and UI
- **Repository Server**: Handles Git operations and manifests
- **Application Controller**: Reconciles desired vs. actual state
- **Redis**: Caching and session storage
- **Webhook Receiver**: Listens for Git push events

**Data Flow**:
1. Repository Server pulls latest manifests from Git
2. Application Controller compares desired vs actual state
3. Controller creates/updates/deletes Kubernetes resources
4. API Server provides status and management interface

**Default Configuration**:
- Single replica for development
- Redis for in-memory caching
- Kustomize with Helm support
- Automated pruning and self-healing enabled

### 2. Cert-Manager

**Purpose**: Automated certificate lifecycle management

**Components**:
- **Webhook**: Validates Certificate and Issuer resources
- **Controller**: Watches for certificate requests
- **Issuers**: Define how certificates are obtained (self-signed, Let's Encrypt, etc.)
- **Cert-Manager**: Core reconciliation logic

**Certificate Flow**:
1. Certificate CRD is created in Kubernetes
2. Cert-Manager controller watches for changes
3. Controller contacts issuer to obtain certificate
4. Certificate and private key stored in Kubernetes Secret
5. Controller monitors expiry and auto-renews

**Issuers in Use**:
- Self-signed CA: For internal cluster certificates
- Can be extended with Let's Encrypt (ACME) for public certificates

### 3. Kargo

**Purpose**: Progressive delivery and multi-stage promotion

**Components**:
- **API Server**: Provides REST API and gRPC endpoints
- **Controller**: Reconciles Kargo resources (Promotions, Stages, Warehouses)
- **Webhooks Server**: Internal validating webhooks
- **External Webhooks Server**: Handles external event triggers
- **Management Controller**: Manages Projects and Namespaces
- **Garbage Collector**: Cleans up old Promotions and Freight

**Key Resources**:
- **Warehouse**: Source of deployable artifacts (containers, Helm charts)
- **Freight**: Represents a deployment candidate with specific versions
- **Stage**: Deployment target with promotion rules
- **Promotion**: Represents moving Freight from one Stage to another

**Promotion Flow**:
```
Warehouse (Source)
    ↓
Freight (Versions)
    ↓
Stage 1 (Dev)
    ↓
Promotion to Stage 2 (Staging) → Approval/Analysis
    ↓
Stage 2 (Staging)
    ↓
Promotion to Stage 3 (Production) → Analysis/Verification
    ↓
Stage 3 (Production)
```

### 4. Argo Rollouts

**Purpose**: Progressive deployment strategies (Canary, Blue-Green)

**Components**:
- **Rollouts Controller**: Manages Rollout resources
- **Analysis Engine**: Evaluates deployment health via metrics
- **Progressive Deployment**: Gradually shifts traffic to new version

**Deployment Strategies**:
- **Canary**: Gradually shift traffic (e.g., 5% → 50% → 100%)
- **Blue-Green**: Maintain two active environments, switch traffic
- **Traffic Shifting**: Use service mesh integration (Istio/SMI)

## Data Flow Diagrams

### GitOps Sync Flow

```
┌──────────────┐
│  Git Commit  │
└──────┬───────┘
       │
       ├─→ GitHub Webhook
       │
       └─→ Argo CD Webhook Receiver
           │
           ├─→ Repository Server: Fetch Latest Manifests
           │
           ├─→ Parse & Validate (Kustomize/Helm)
           │
           └─→ Application Controller
               │
               ├─→ Compare: Git State vs. Cluster State
               │
               ├─→ Generate Diff
               │
               └─→ Apply Changes to Cluster
                   │
                   └─→ Update Application Status
```

### Kargo Promotion Flow

```
┌─────────────────┐
│ New Artifact    │
│ Published       │
└────────┬────────┘
         │
         └─→ Webhook Event
            │
            └─→ Kargo API
               │
               ├─→ Create Freight
               │
               └─→ Check Stage Promotions
                   │
                   ├─→ Auto-Promotion Enabled?
                   │   ├─ Yes → Create Promotion
                   │   └─ No → Wait for Manual Approval
                   │
                   └─→ Kargo Controller Reconciles
                       │
                       ├─→ Update Argo CD Applications
                       │
                       ├─→ Monitor Health
                       │
                       ├─→ Run Analysis (via Argo Rollouts)
                       │
                       └─→ Approve/Reject Next Promotion
```

## Security Architecture

### Multi-Layer Security

```
┌─────────────────────────────────────────────────────────┐
│ 1. Git Repository Security                              │
│    - SSH key authentication                              │
│    - Branch protection rules                             │
│    - Code review requirements                            │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Secrets Encryption                                   │
│    - Sealed Secrets (bitnami-labs)                       │
│    - Encrypted at rest in Git                            │
│    - Decrypted only in cluster                           │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ 3. RBAC (Role-Based Access Control)                     │
│    - Argo CD projects limit access                       │
│    - Kargo OIDC integration                              │
│    - Kubernetes RBAC policies                            │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Network Security                                     │
│    - Namespace isolation                                │
│    - Network policies                                   │
│    - TLS for all communications                          │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Pod Security                                         │
│    - Non-root users                                     │
│    - Read-only filesystems                              │
│    - Security contexts                                  │
└─────────────────────────────────────────────────────────┘
```

## State Management

### What State is Stored Where

```
┌────────────────────────────────────────┐
│ Git Repository                         │
├────────────────────────────────────────┤
│ ✓ Infrastructure manifests             │
│ ✓ Application configurations           │
│ ✓ Sealed secrets                       │
│ ✓ Kustomize overlays                   │
│ ✓ Helm values                          │
│ ✗ Cluster runtime state                │
│ ✗ User credentials (plaintext)         │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│ Kubernetes Cluster (etcd)              │
├────────────────────────────────────────┤
│ ✓ Applied manifests                    │
│ ✓ Running resource state                │
│ ✓ Sealed secrets (encrypted)           │
│ ✓ Argo CD applications                 │
│ ✓ Kargo Promotions/Freight             │
│ ✗ Git history                          │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│ External Storage                       │
├────────────────────────────────────────┤
│ ✓ Container registries                 │
│ ✓ Helm repositories                    │
│ ✓ Git repository                       │
│ ✓ Certificate authority keys           │
│ ✗ Sensitive credentials (plaintext)    │
└────────────────────────────────────────┘
```

## Scalability Considerations

### Horizontal Scaling

**Argo CD**:
- Multiple application-controller replicas for sharding
- Multiple server replicas for load distribution
- Shared Redis for session management

**Kargo**:
- Multiple controller replicas for resource sharding
- Multiple API server replicas behind load balancer
- Webhook servers scale independently

### Vertical Scaling

**Resource Limits by Component**:

```
Argo CD Controller:
  - Requests: 250m CPU, 256Mi Memory
  - Limits: 500m CPU, 512Mi Memory

Argo CD Server:
  - Requests: 125m CPU, 128Mi Memory
  - Limits: 250m CPU, 256Mi Memory

Cert-Manager:
  - Requests: 100m CPU, 64Mi Memory
  - Limits: 200m CPU, 128Mi Memory

Kargo API:
  - Requests: 100m CPU, 128Mi Memory
  - Limits: 500m CPU, 512Mi Memory
```

## High Availability Setup

### Production Configuration

```
┌─────────────────────────────────────────────────────────┐
│ Multi-Zone Kubernetes Cluster                           │
│ (3+ availability zones)                                 │
│                                                         │
│ ┌──────────┐    ┌──────────┐    ┌──────────┐          │
│ │ Zone A   │    │ Zone B   │    │ Zone C   │          │
│ │ Master   │    │ Master   │    │ Master   │          │
│ │ Worker   │    │ Worker   │    │ Worker   │          │
│ └──────────┘    └──────────┘    └──────────┘          │
│                                                         │
│ Distributed Storage:                                    │
│ - etcd replicated across zones                         │
│ - PVC/PV with cross-zone replication                   │
└─────────────────────────────────────────────────────────┘
```

### Component Redundancy

- Argo CD: 2-3 replicas of each component
- Cert-Manager: 2-3 controller replicas
- Kargo: 2-3 API server replicas, 2-3 controller replicas
- Redis: Redis-HA with 3 sentinels

## Disaster Recovery

### Backup Strategy

```
Daily Backups:
┌─────────────────────────────────────────────────┐
│ Git Repository Commits                          │
│ (Automatically backed up by Git hosting)         │
├─────────────────────────────────────────────────┤
│ Kubernetes etcd                                 │
│ (velero or native etcd backup)                  │
├─────────────────────────────────────────────────┤
│ Sealing Keys for Sealed Secrets                 │
│ (Secured storage, NOT in Git)                   │
└─────────────────────────────────────────────────┘
```

### Recovery Procedures

1. **Git Corruption**: Use distributed copies, restore from backups
2. **etcd Corruption**: Restore from latest backup
3. **Secrets Key Loss**: Complete cluster recreation needed
4. **Application State**: Redeploy from Git (source of truth)

## Monitoring & Observability

### Key Metrics to Monitor

```
Argo CD Metrics:
- Application sync status
- Reconciliation lag
- Git repository fetch rate
- API server response times

Cert-Manager Metrics:
- Certificate renewal status
- Certificate expiry tracking
- Issuer availability

Kargo Metrics:
- Promotion success rate
- Stage health
- Freight warehouse size
- Webhook latency

System Metrics:
- Pod CPU/Memory usage
- Node capacity
- PVC utilization
- Network I/O
```

### Integration Points

- **Prometheus**: Scrape metrics from `/metrics` endpoints
- **Grafana**: Visualize metrics and dashboards
- **AlertManager**: Send alerts for critical issues
- **Logs**: Aggregate logs from all components

## Integration with External Systems

### Git Integration

```
Supported Git Providers:
├─ GitHub (via SSH)
├─ GitLab (via SSH)
├─ Gitea (via SSH)
└─ Self-hosted Git

Authentication:
├─ SSH keys (primary)
├─ HTTPS with personal tokens
└─ SSH agent forwarding
```

### CI/CD Pipeline Integration

```
Build Pipeline → Container Registry → Webhook → Kargo
                                           ↓
                                    Create Freight
                                           ↓
                                    Promote to Stages
                                           ↓
                                    Update Argo CD Applications
```

## Network Architecture

### Kubernetes Network Design

```
┌────────────────────────────────────────────────────┐
│ Cluster Network                                    │
│                                                   │
│ ┌──────────────┐  ┌──────────────┐               │
│ │ Namespace    │  │ Namespace    │               │
│ │ argocd       │  │ cert-manager │               │
│ │              │  │              │               │
│ │ Service:     │  │ Service:     │               │
│ │ 10.0.0.0/24  │  │ 10.0.1.0/24  │               │
│ └──────────────┘  └──────────────┘               │
│                                                   │
│ Pod CIDR: 10.1.0.0/16                            │
│ Service CIDR: 10.0.0.0/12                        │
│                                                   │
│ DNS: CoreDNS for internal resolution              │
│ Ingress: Optional external access                 │
└────────────────────────────────────────────────────┘
```

---

**Last Updated**: 2026-04-16
**Version**: 1.0

