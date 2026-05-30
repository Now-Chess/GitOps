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
  echo " ⌛ Apply Git source secret"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  GOTK="$REPO_ROOT/htwg-1/flux-system/gotk-components.yaml"
  if [[ -f "$GOTK" ]]; then
    echo "✅ gotk-components.yaml already exists, skipping generation."
  else
    echo "🚀 Generating FluxCD controller manifests..."
    flux install --export > "$GOTK"
    echo "✅ Generated $GOTK"
    echo "⚠️  Commit this file to the repository before continuing."
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
  echo " ⌛ Apply Git source secret"
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
  echo " ⌛ Apply Git source secret"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  echo "🔑 Restoring sealed-secrets key..."
  read -rp "Path to sealed-secrets key backup (leave blank to skip — new key will be generated): " KEY_FILE
  if [[ -n "$KEY_FILE" ]]; then
    "$SCRIPT_DIR/sealed-secrets-key.sh" import "$KEY_FILE"
    echo "✅ Sealed-secrets key imported."
  else
    echo "⚠️  Skipped. New sealed-secrets key will be generated after controller deploys."
    echo "⚠️  All secrets in secrets/nowchess/htwg-1-prod/ and secrets/flux/ must be re-sealed with the new key."
  fi

  # Install sealed-secrets now (before FluxCD bootstraps) so we can decrypt the gitops-ssh secret
  echo "🚀 Installing sealed-secrets controller..."
  kubectl apply -f "$REPO_ROOT/htwg-1/flux-apps/sealed-secrets.yaml"
  echo "⏳ Waiting for sealed-secrets controller to be ready (this may take a few minutes)..."
  kubectl -n kube-system wait helmrelease/sealed-secrets \
    --for=condition=ready --timeout=300s 2>/dev/null || \
  kubectl -n kube-system rollout status deployment/sealed-secrets --timeout=300s
  echo "✅ Sealed-secrets controller ready!"
}

# ----

apply_git_source_secret() {
  clear
  echo "----------------------------------------"
  echo " ✅ Generate FluxCD manifests"
  echo " ✅ Install FluxCD controllers"
  echo " ✅ Setup Sealed Secrets"
  echo " ⌛ Apply Git source secret"
  echo " ⌛ Bootstrap FluxCD"
  echo "----------------------------------------"

  echo "🔑 Applying gitops-ssh SealedSecret..."
  GIT_SECRET="$REPO_ROOT/secrets/flux/gitops-ssh-htwg-1.yaml"

  if grep -q "REPLACE_WITH_SEALED_VALUE" "$GIT_SECRET"; then
    echo "❌ $GIT_SECRET is a placeholder — seal it first:"
    echo ""
    echo "  ssh-keygen -t ed25519 -f gitops-deploy-key -N \"\" -C \"flux-htwg-1\""
    echo "  kubectl -n flux-system create secret generic gitops-ssh \\"
    echo "    --from-file=identity=./gitops-deploy-key \\"
    echo "    --from-literal=known_hosts=\"\$(ssh-keyscan -H git.janis-eccarius.de 2>/dev/null)\" \\"
    echo "    --dry-run=client -o yaml \\"
    echo "    | kubeseal --controller-namespace kube-system -o yaml > $GIT_SECRET"
    echo ""
    echo "  Then add gitops-deploy-key.pub as a deploy key in Gitea:"
    echo "  https://git.janis-eccarius.de/NowChess/GitOps/settings/keys"
    exit 1
  fi

  kubectl apply -f "$GIT_SECRET"
  echo "✅ gitops-ssh secret applied and will be decrypted by sealed-secrets."
}

# ----

bootstrap_flux() {
  clear
  echo "----------------------------------------"
  echo " ✅ Generate FluxCD manifests"
  echo " ✅ Install FluxCD controllers"
  echo " ✅ Setup Sealed Secrets"
  echo " ✅ Apply Git source secret"
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
apply_git_source_secret
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
