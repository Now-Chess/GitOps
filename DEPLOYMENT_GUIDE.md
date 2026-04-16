# Deployment Guide

Detailed step-by-step instructions for deploying the complete GitOps infrastructure.

## Pre-Deployment Checklist

### Environment Verification

```bash
# Check Kubernetes version (1.24+)
kubectl version --short

# Verify node capacity
kubectl describe nodes | grep -E "Name:|cpu:|memory:" | head -15

# Check available storage
kubectl get storageclass

# Verify ingress controller (if using)
kubectl get ingressclass

# Check for existing installations
kubectl get ns | grep -E "argocd|cert-manager|kargo"
```

### Prerequisites Installation

#### 1. Install kubectl (if not present)

**Linux/macOS**:
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Windows (PowerShell)**:
```powershell
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
```

#### 2. Install Helm

**Linux/macOS**:
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Windows (Chocolatey)**:
```powershell
choco install kubernetes-helm
```

#### 3. Install Kustomize

**Linux/macOS**:
```bash
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

#### 4. Install Kustomize Helm Plugin

```bash
# Create plugin directory
mkdir -p ~/.config/kustomize/plugin/kustomize.config.k8s.io/v1/helmchart

# Download plugin (this is typically handled by 'kustomize build --enable-helm')
# The flag --enable-helm automatically enables the plugin
```

#### 5. Configure kubectl Context

```bash
# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context <context-name>

# Verify connection
kubectl cluster-info
kubectl auth can-i get pods --all-namespaces
```

## Automated Deployment

### Using the Provided Script

The quickest way to deploy is using the included deployment script:

```bash
cd scripts
chmod +x deploy-to-cluster.sh
./deploy-to-cluster.sh
```

**What the script does**:
1. Installs Cert-Manager with CRDs
2. Installs Argo CD with full configuration
3. Sets up sealed secrets configuration
4. Deploys the root Argo CD application
5. Displays final access credentials

**Output Example**:
```
----------------------------------------
 🎉 Kubernetes local cluster setup complete!
 🎉 Access ArgoCD at: https://localhost:31443
 🎉 Default login: admin / <generated-password>
----------------------------------------
```

### Script Troubleshooting

If the script fails:

```bash
# Check for error messages
tail -f /tmp/deploy-to-cluster.log  # If logging is redirected

# Manually check what failed
kubectl get pods -A
kubectl describe pod -n <failed-namespace> <pod-name>

# Resume from specific step (modify script as needed)
```

## Manual Step-by-Step Deployment

Use this process if you need more control or the automated script fails.

### Step 1: Create Required Namespaces

```bash
# Create namespaces
kubectl create namespace argocd
kubectl create namespace cert-manager
kubectl create namespace kargo

# Label namespaces
kubectl label namespace cert-manager cert-manager.io/disable-validation=false

# Verify
kubectl get namespaces | grep -E "argocd|cert-manager|kargo"
```

### Step 2: Install Cert-Manager

Cert-Manager must be installed before Argo CD because it provides certificate management.

```bash
# Add Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install Cert-Manager CRDs first
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml

# Wait for CRDs to be available
kubectl wait --for condition=established --timeout=60s crd/certificates.cert-manager.io

# Build and apply cert-manager with kustomize
echo "Installing Cert-Manager..."
kustomize build --enable-helm cert-manager/eu-central-1 | kubectl apply -f -

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=cert-manager \
  -n cert-manager --timeout=300s

# Verify installation
kubectl -n cert-manager get pods
kubectl get crd | grep cert-manager
```

### Step 3: Install Argo CD

```bash
echo "Installing Argo CD..."
kustomize build --enable-helm argocd/eu-central-1 | kubectl apply -f -

# Wait for Argo CD components
echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-application-controller \
  -n argocd --timeout=300s

# Verify installation
kubectl -n argocd get pods
```

### Step 4: Get Argo CD Credentials

```bash
# Retrieve initial admin password
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode)

echo "Argo CD Admin Password: $ARGO_PASSWORD"
echo "Store this securely and change it after first login"
```

### Step 5: Access Argo CD UI

**Option A: Port Forward (Development)**

```bash
# Forward local port to Argo CD server
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access at: https://localhost:8080
# Login: admin / <password from step 4>
```

**Option B: Using NodePort (Already configured)**

```bash
# Get the NodePort
kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[0].nodePort}'

# Access at: https://<node-ip>:<nodeport>
# Example: https://192.168.1.100:31443
```

**Option C: Ingress (Production)**

```bash
# Check if Ingress is created
kubectl -n argocd get ingress

# Get ingress hostname
kubectl -n argocd get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'

# Access via configured domain
# Example: https://argo.knockout.janis-eccarius.de
```

### Step 6: Configure Git Repository

Log into Argo CD UI and configure the Git repository:

1. **Navigate to**: Settings → Repositories
2. **Click**: "Connect Repo" → "VIA SSH"
3. **Fill in details**:
   - Repository URL: `git@git.janis-eccarius.de:NowChess/GitOps.git`
   - SSH private key: (Paste your SSH key or upload)
   - Known hosts: (Provide or auto-generate)
4. **Test connection**: Click "Test"
5. **Save**: Click "Save" and "Connect"

**SSH Key Setup**:

```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd_key -N ""

# Add to SSH agent
ssh-add ~/.ssh/argocd_key

# Copy public key to Git provider
cat ~/.ssh/argocd_key.pub | xclip -selection clipboard  # Linux
cat ~/.ssh/argocd_key.pub | pbcopy  # macOS
```

### Step 7: Deploy Root Application

```bash
# Apply the root Argo CD application
kubectl apply -f eu-central-1/root-apps-app.yaml

# Verify the application was created
kubectl -n argocd get application orchestration-root-app-eu-central-1

# Watch sync progress
watch "kubectl -n argocd describe application orchestration-root-app-eu-central-1"

# Or use argocd CLI
argocd app list
argocd app watch orchestration-root-app-eu-central-1
```

### Step 8: Install Kargo (Optional)

If you want to enable progressive delivery with Kargo:

```bash
# Build and apply Kargo configuration
echo "Installing Kargo..."
kustomize build --enable-helm kargo/eu-central-1 | kubectl apply -f -

# Wait for Kargo to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=kargo \
  -n kargo --timeout=300s

# Get Kargo admin password
kubectl -n kargo get secret kargo-admin-password \
  -o jsonpath="{.data.password}" | base64 --decode

# Access Kargo API
kubectl port-forward -n kargo svc/kargo-api 8443:443
# Access at: https://localhost:8443
```

### Step 9: Install Argo Rollouts (Optional)

For progressive deployment strategies:

```bash
echo "Installing Argo Rollouts..."
kustomize build --enable-helm argo-rollouts/eu-central-1 | kubectl apply -f -

# Verify installation
kubectl -n argo-rollouts get pods
```

## Post-Deployment Configuration

### 1. Update Argo CD Admin Password

```bash
# Generate bcrypt hash
PASSWORD="mynewpassword"
HASH=$(htpasswd -nbBC 10 admin "$PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')

# Update secret
kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p "{\"data\":{\"admin.password\":\"$(echo -n $HASH | base64 -w0)\"}}"

# Logout and re-login with new password
```

### 2. Configure OIDC (Optional but Recommended)

Create/update `argocd/eu-central-1/values.yaml`:

```yaml
configs:
  cm:
    oidc.config: |
      name: Azure AD
      issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
      clientID: <your-client-id>
      clientSecret: $oidc.azuread.clientSecret
      requestedScopes:
        - openid
        - profile
        - email
        - groups
```

### 3. Set Up Monitoring/Alerts

Enable ServiceMonitors for Prometheus:

```yaml
# In argocd/eu-central-1/values.yaml
controller:
  metrics:
    serviceMonitor:
      enabled: true
      interval: 30s
      
server:
  metrics:
    serviceMonitor:
      enabled: true
```

### 4. Configure Backup Strategy

```bash
# Install velero for backup
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.backupStorageLocation.bucket=<bucket-name> \
  --set configuration.backupStorageLocation.provider=aws
```

### 5. Enable Network Policies (Production)

```yaml
# Create network policy template
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
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
```

## Verification Checklist

After deployment, verify all components:

```bash
# ✓ All pods running
kubectl get pods -A | grep -E "argocd|cert-manager|kargo"

# ✓ Persistent volumes mounted
kubectl get pvc -A

# ✓ Services accessible
kubectl get svc -A | grep -E "argocd|cert-manager|kargo"

# ✓ Argo CD application synced
argocd app list

# ✓ Certificates valid
kubectl get certificate -A
kubectl describe certificate -n <namespace> <cert-name>

# ✓ No pod errors
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# ✓ DNS resolution working
kubectl run -it --rm debug --image=alpine --restart=Never -- \
  nslookup argocd-server.argocd.svc.cluster.local
```

## Deployment Validation Script

Create a validation script:

```bash
#!/bin/bash
# validate-deployment.sh

set -e

echo "Validating GitOps Deployment..."

# Check Cert-Manager
echo "✓ Checking Cert-Manager..."
kubectl -n cert-manager get pods -q | grep Running &>/dev/null || \
  (echo "✗ Cert-Manager pods not running" && exit 1)

# Check Argo CD
echo "✓ Checking Argo CD..."
kubectl -n argocd get pods -q | grep Running &>/dev/null || \
  (echo "✗ Argo CD pods not running" && exit 1)

# Check root application
echo "✓ Checking root application..."
ROOT_APP=$(kubectl -n argocd get application -o jsonpath='{.items[0].metadata.name}')
STATUS=$(kubectl -n argocd get application $ROOT_APP -o jsonpath='{.status.operationState.phase}')
echo "  Root app: $ROOT_APP (Status: $STATUS)"

# Check certificates
echo "✓ Checking certificates..."
CERTS=$(kubectl get certificate -A -o jsonpath='{.items[*].metadata.name}')
echo "  Certificates found: ${#CERTS[@]}"

echo ""
echo "✅ All validation checks passed!"
```

## Troubleshooting Deployment

### Cert-Manager CRD Issues

```bash
# If cert-manager CRDs fail to install:
kubectl get crd | grep cert-manager

# Delete and reinstall
kubectl delete crd certificates.cert-manager.io
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml
```

### Pod Crash Loop

```bash
# Check pod logs
kubectl -n <namespace> logs <pod-name>

# Check pod status
kubectl -n <namespace> describe pod <pod-name>

# Check resource availability
kubectl describe nodes
```

### Git Repository Connection Issues

```bash
# Test Git connectivity from pod
kubectl -n argocd exec -it <argocd-repo-server-pod> -- bash

# Inside pod:
ssh -v git@git.janis-eccarius.de
git clone git@git.janis-eccarius.de:NowChess/GitOps.git
```

### Certificate Issues

```bash
# Check cert-manager controller logs
kubectl -n cert-manager logs -l app.kubernetes.io/name=cert-manager

# Check certificate status
kubectl get certificate -A -o wide
kubectl describe certificate <cert-name> -n <namespace>

# Manually trigger renewal
kubectl annotate certificate <cert-name> -n <namespace> \
  cert-manager.io/issue-temporary-certificate="true" --overwrite
```

## Uninstall (if needed)

```bash
# Remove applications first (preserves data)
kubectl delete -f eu-central-1/root-apps-app.yaml

# Remove Kargo
helm uninstall kargo -n kargo
kubectl delete ns kargo

# Remove Argo CD
helm uninstall argocd -n argocd
kubectl delete ns argocd

# Remove Cert-Manager
helm uninstall cert-manager -n cert-manager
kubectl delete ns cert-manager
kubectl delete crd certificates.cert-manager.io
```

---

**Last Updated**: 2026-04-16
**Version**: 1.0

