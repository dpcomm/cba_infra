#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[1/4] Applying dev overlay"
kubectl apply -k "${ROOT_DIR}/k8s/overlays/dev"

echo "[2/4] Waiting for rollout"
kubectl rollout status deployment/cba-was-renew -n cba-dev

echo "[3/4] Current resources in cba-dev"
kubectl get all -n cba-dev

cat <<'EOF'
[4/4] Useful log commands
kubectl logs -n cba-dev deploy/cba-was-renew
kubectl logs -n cba-dev deploy/cba-was-renew -f
EOF
