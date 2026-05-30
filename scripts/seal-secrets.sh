#!/usr/bin/env bash
set -euo pipefail

CONTROLLER_NAME="sealed-secrets"
CONTROLLER_NS="kube-system"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"

seal_file() {
  local f="$1"
  local tmp="${f}.tmp"
  kubeseal \
    --controller-name="$CONTROLLER_NAME" \
    --controller-namespace="$CONTROLLER_NS" \
    --format=yaml \
    < "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "sealed: $f"
}

# Only seal plain Secrets (not already-sealed SealedSecrets or kustomizations)
while IFS= read -r -d '' f; do
  if grep -q "^kind: Secret$" "$f" 2>/dev/null; then
    seal_file "$f"
  fi
done < <(find "$SECRETS_DIR" -name "*.yaml" ! -name "kustomization.yaml" -print0)

echo "done — commit the sealed files and push"
