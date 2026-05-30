#!/usr/bin/bash
set -euo pipefail

REMOTE_HOST="chess@141.37.74.142"
REMOTE_API_PORT="6443"
LOCAL_PORT="6443"
KUBECONFIG_FILE="${HOME}/.kube/htwg-1.yaml"

# ----

fetch_kubeconfig() {
  echo "📥 Fetching kubeconfig from remote..."
  mkdir -p "$(dirname "$KUBECONFIG_FILE")"
  ssh "$REMOTE_HOST" "~/.local/bin/k3d kubeconfig get htwg-1" \
    | sed "s|server: https://0.0.0.0:${REMOTE_API_PORT}|server: https://127.0.0.1:${LOCAL_PORT}|" \
    > "$KUBECONFIG_FILE"
  chmod 600 "$KUBECONFIG_FILE"
  echo "✅ Kubeconfig saved to ${KUBECONFIG_FILE}"
}

# ----

cleanup() {
  echo ""
  echo "🔌 Closing tunnel..."
  kill "$SSH_PID" 2>/dev/null || true
  exit 0
}

# ----

# Re-fetch kubeconfig if flag passed or file missing
if [[ "${1:-}" == "--refresh" ]] || [[ ! -f "$KUBECONFIG_FILE" ]]; then
  fetch_kubeconfig
fi

export KUBECONFIG="$KUBECONFIG_FILE"

echo "🔗 Starting SSH tunnel: localhost:${LOCAL_PORT} → ${REMOTE_HOST}:${REMOTE_API_PORT}"
ssh -N -L "${LOCAL_PORT}:localhost:${REMOTE_API_PORT}" "$REMOTE_HOST" &
SSH_PID=$!

trap cleanup INT TERM

# Wait for tunnel to be ready
sleep 1
if ! kill -0 "$SSH_PID" 2>/dev/null; then
  echo "❌ SSH tunnel failed to start."
  exit 1
fi

echo "✅ Tunnel active (PID ${SSH_PID})"
echo ""
echo "Use in another terminal:"
echo "  export KUBECONFIG=${KUBECONFIG_FILE}"
echo "  kubectl get nodes"
echo ""
echo "Or source this file:"
echo "  source <(echo 'export KUBECONFIG=${KUBECONFIG_FILE}')"
echo ""
echo "Press Ctrl+C to close tunnel."

wait "$SSH_PID"
