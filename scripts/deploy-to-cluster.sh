#!/usr/bin/bash
set -euo pipefail

# ----

install_cert_manager() {
  clear
  echo "----------------------------------------"
  echo " ⌛ Install Cert-Manager"
  echo " ⌛ Install ArgoCD"
  echo " ⌛ Setup Sealed Secrets"
  echo " ⌛ Finish Setup"
  echo "----------------------------------------"

  echo "🚀 Installing Cert-Manager..."
  kustomize build --enable-helm ../cert-manager/eu-central-1 | kubectl apply -f -
  echo "✅ Cert-Manager installed successfully!"
}


# ----

install_argocd() {
  clear
  echo "----------------------------------------"
  echo " ✅ Install Cert-Manager"
  echo " ⌛ Install ArgoCD"
  echo " ⌛ Setup Sealed Secrets"
  echo " ⌛ Finish Setup"
  echo "----------------------------------------"

  echo "🚀 Installing ArgoCD..."
  kustomize build --enable-helm ../argocd/eu-central-1 | kubectl apply --server-side=true -f -
  echo "✅ ArgoCD installed successfully!"
}


# ----

install_cert_manager
install_argocd

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/baremetal/deploy.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
sleep 5s

kubectl apply -f ../eu-central-1/root-apps-app.yaml

clear

ARGO_PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

echo "----------------------------------------"
echo " 🎉 Kubernetes local cluster setup complete!"
echo " 🎉 Access ArgoCD at: https://localhost:31443"
echo " 🎉 Default login: admin / $ARGO_PW"
echo "----------------------------------------"
