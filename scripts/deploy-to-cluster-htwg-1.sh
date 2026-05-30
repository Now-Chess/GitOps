#!/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ----

generate_flux_manifests() {
  clear
  echo "----------------------------------------"
  echo " ⌛ Generate FluxCD manifests"
  echo " ⌛ Install FluxCD controllers"
  echo " ⌛ Setup Sealed Secrets"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  GOTK="$REPO_ROOT/htwg-1/flux-system/gotk-components.yaml"
  if [[ -s "$GOTK" ]]; then
    echo "✅ gotk-components.yaml already exists, skipping download."
  else
    echo "🚀 Downloading FluxCD controller manifests..."
    FLUX_VERSION=$(curl -Ls https://api.github.com/repos/fluxcd/flux2/releases/latest \
      | grep '"tag_name"' | cut -d'"' -f4)
    curl -Lo "$GOTK" \
      "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/install.yaml"
    echo "✅ Downloaded FluxCD ${FLUX_VERSION} → $GOTK"
    echo "⚠️  Commit this file to the repository."
    read -rp "Press Enter after committing gotk-components.yaml..."
  fi
}

# ----

install_flux() {
  clear
  echo "----------------------------------------"
  echo " ✅ Generate FluxCD manifests"
  echo " ⌛ Install FluxCD controllers"
  echo " ⌛ Setup Sealed Secrets"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  echo "🚀 Installing FluxCD controllers..."
  kubectl apply -f "$REPO_ROOT/htwg-1/flux-system/gotk-components.yaml"
  echo "⏳ Waiting for FluxCD controllers to be ready..."
  kubectl -n flux-system rollout status deployment/source-controller --timeout=120s
  kubectl -n flux-system rollout status deployment/kustomize-controller --timeout=120s
  kubectl -n flux-system rollout status deployment/helm-controller --timeout=120s
  echo "✅ FluxCD controllers ready!"
}

# ----

setup_sealed_secrets() {
  clear
  echo "----------------------------------------"
  echo " ✅ Generate FluxCD manifests"
  echo " ✅ Install FluxCD controllers"
  echo " ⌛ Setup Sealed Secrets"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  echo "🔑 Restoring sealed-secrets key..."
  read -rp "Path to sealed-secrets key backup (leave blank to skip — new key will be generated): " KEY_FILE
  if [[ -n "$KEY_FILE" ]]; then
    "$SCRIPT_DIR/sealed-secrets-key.sh" import "$KEY_FILE"
    echo "✅ Sealed-secrets key imported."
  else
    echo "⚠️  Skipped. New key will be generated after controller deploys."
    echo "⚠️  Re-seal all secrets in secrets/nowchess/htwg-1-prod/ with the new key."
  fi

  echo "🚀 Installing sealed-secrets controller..."
  kubectl apply -f "$REPO_ROOT/htwg-1/flux-apps/sources.yaml"
  kubectl apply -f "$REPO_ROOT/htwg-1/flux-apps/sealed-secrets.yaml"
  echo "⏳ Waiting for sealed-secrets controller to be ready (this may take a few minutes)..."
  kubectl -n kube-system rollout status deployment/sealed-secrets --timeout=300s
  echo "✅ Sealed-secrets controller ready!"
}

# ----

bootstrap_flux() {
  clear
  echo "----------------------------------------"
  echo " ✅ Generate FluxCD manifests"
  echo " ✅ Install FluxCD controllers"
  echo " ✅ Setup Sealed Secrets"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  echo "🚀 Applying GitRepository source..."
  kubectl apply -f "$REPO_ROOT/htwg-1/flux-apps/gitrepository.yaml"

  echo "⏳ Waiting for GitRepository to be ready..."
  kubectl -n flux-system wait gitrepository/gitops --for=condition=ready --timeout=120s

  echo "🚀 Applying root Kustomization..."
  kubectl apply -f "$REPO_ROOT/htwg-1/root-ks.yaml"

  echo "✅ FluxCD bootstrap complete!"
  echo ""
  echo "FluxCD will now reconcile all components. Monitor with:"
  echo "  flux get kustomizations -A"
  echo "  flux get helmreleases -A"
}

# ----

generate_flux_manifests
install_flux
setup_sealed_secrets
bootstrap_flux

clear
echo "----------------------------------------"
echo " 🎉 htwg-1 cluster bootstrap complete!"
echo " 🎉 Cluster IP: 141.37.74.142"
echo " 🎉 NowChess: http://141.37.74.142"
echo "----------------------------------------"
echo ""
echo "Next steps:"
echo "  1. Seal secrets in secrets/nowchess/htwg-1-prod/ (if not done)"
echo "  2. Monitor reconciliation: flux get all -A"
echo "  3. Check NowChess pods: kubectl -n nowchess get pods"
