#!/usr/bin/bash
set -euo pipefail

CLUSTER_NAME="htwg-1"
BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"

# Ensure BIN_DIR is on PATH for this session
export PATH="${BIN_DIR}:${PATH}"

# ----

install_k3d() {
  if command -v k3d &>/dev/null; then
    echo "✅ k3d already installed: $(k3d version | head -1)"
    return
  fi

  echo "🚀 Installing k3d to ${BIN_DIR}..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | K3D_INSTALL_DIR="${BIN_DIR}" USE_SUDO=false bash
  echo "✅ k3d installed: $(k3d version | head -1)"
}

# ----

install_kubectl() {
  if command -v kubectl &>/dev/null; then
    echo "✅ kubectl already installed: $(kubectl version --client 2>/dev/null | head -1)"
    return
  fi

  echo "🚀 Installing kubectl to ${BIN_DIR}..."
  KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
  curl -Lo "${BIN_DIR}/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x "${BIN_DIR}/kubectl"
  echo "✅ kubectl installed: ${KUBECTL_VERSION}"
}

# ----

install_flux_cli() {
  if command -v flux &>/dev/null; then
    echo "✅ flux CLI already installed: $(flux version --client 2>/dev/null | head -1)"
    return
  fi

  echo "🚀 Installing flux CLI to ${BIN_DIR}..."
  FLUX_VERSION=$(curl -Ls https://api.github.com/repos/fluxcd/flux2/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | tr -d v)
  curl -Lo /tmp/flux.tar.gz "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_amd64.tar.gz"
  tar -xzf /tmp/flux.tar.gz -C "${BIN_DIR}" flux
  rm /tmp/flux.tar.gz
  echo "✅ flux CLI installed: v${FLUX_VERSION}"
}

# ----

create_cluster() {
  if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
    echo "✅ Cluster '${CLUSTER_NAME}' already exists."
    return
  fi

  echo "🚀 Creating k3d cluster '${CLUSTER_NAME}'..."

  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --api-port 6443 \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--disable=servicelb@server:0" \
    --k3s-arg "--disable=metrics-server@server:0"

  echo "✅ Cluster '${CLUSTER_NAME}' created!"
}

# ----

install_k3d
install_kubectl
install_flux_cli
create_cluster

echo ""
echo "----------------------------------------"
echo " 🎉 k3d cluster '${CLUSTER_NAME}' ready!"
echo " 🎉 kubeconfig merged — context: k3d-${CLUSTER_NAME}"
echo "----------------------------------------"
echo ""
echo "⚠️  Add ${BIN_DIR} to your PATH permanently if not already set:"
echo "   echo 'export PATH=\"\${HOME}/.local/bin:\${PATH}\"' >> ~/.bashrc"
echo ""
echo "Next step: run deploy-to-cluster-htwg-1.sh"
