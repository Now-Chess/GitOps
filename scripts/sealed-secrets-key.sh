#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="kube-system"

usage() {
  echo "Manage sealed-secrets controller keys for cluster migration."
  echo ""
  echo "Usage:"
  echo "  $0 export [output-file]   Export active key(s) to YAML (default: sealed-secrets-key-backup.yaml)"
  echo "  $0 import <input-file>    Import key(s) to new cluster before first ArgoCD sync"
  echo ""
  echo "IMPORTANT: Never commit the backup file to Git. Store in Passwords.kdbx."
  exit 1
}

export_key() {
  local out="${1:-sealed-secrets-key-backup.yaml}"

  local keys
  keys=$(kubectl -n "$NAMESPACE" get secret \
    -l sealedsecrets.bitnami.com/sealed-secrets-key \
    -o name 2>/dev/null)

  if [[ -z "$keys" ]]; then
    echo "Error: no sealed-secrets keys found in namespace $NAMESPACE" >&2
    exit 1
  fi

  # Strip runtime-only fields so the manifest is re-applicable
  kubectl -n "$NAMESPACE" get secret \
    -l sealedsecrets.bitnami.com/sealed-secrets-key \
    -o yaml \
    | kubectl neat \
    > "$out" 2>/dev/null \
    || kubectl -n "$NAMESPACE" get secret \
         -l sealedsecrets.bitnami.com/sealed-secrets-key \
         -o yaml \
       | grep -v $'^\t' \
       | python3 -c "
import sys, yaml
docs = list(yaml.safe_load_all(sys.stdin))
# Remove a List wrapper if present, emit individual documents
if len(docs) == 1 and docs[0].get('kind') == 'List':
    docs = docs[0]['items']
strip = {'resourceVersion', 'uid', 'selfLink', 'creationTimestamp',
         'generation', 'managedFields'}
for d in docs:
    meta = d.get('metadata', {})
    for f in strip:
        meta.pop(f, None)
    d['metadata'] = meta
print(yaml.dump_all(docs, default_flow_style=False))
" > "$out"

  local count
  count=$(echo "$keys" | wc -l | tr -d ' ')
  echo "Exported $count key(s) to: $out"
  echo ""
  echo "WARNING: Store this file securely (e.g. Passwords.kdbx). Never commit to Git."
}

import_key() {
  local in="${1:?'import requires a file argument — run: $0 import <file>'}"

  if [[ ! -f "$in" ]]; then
    echo "Error: file not found: $in" >&2
    exit 1
  fi

  echo "Importing sealed-secrets key(s) from: $in"
  kubectl apply -f "$in"

  echo ""
  echo "Key imported. If the sealed-secrets controller is already running, restart it:"
  echo "  kubectl -n kube-system rollout restart deployment/sealed-secrets"
  echo ""
  echo "Apply this BEFORE ArgoCD syncs the secrets application."
}

case "${1:-}" in
  export) export_key "${2:-}" ;;
  import) import_key "${2:-}" ;;
  *) usage ;;
esac
