#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="cba-dev"

echo "[1/2] Creating OCIR image pull secret in namespace: ${NAMESPACE}"
kubectl create secret docker-registry ocir-secret \
  --namespace "${NAMESPACE}" \
  --docker-server="ap-chuncheon-1.ocir.io" \
  --docker-username="axdhp42jvukm/OCI_USERNAME" \
  --docker-password="OCI_AUTH_TOKEN" \
  --docker-email="your-email@example.com" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[2/2] Creating app env secret (expects .env.dev in current directory)"
kubectl create secret generic cba-was-renew-env \
  --namespace "${NAMESPACE}" \
  --from-env-file=".env.dev" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done. Do not commit real credential values or .env.dev."
