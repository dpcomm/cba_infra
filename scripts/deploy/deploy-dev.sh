#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "[1/4] Applying dev overlay"
kubectl apply -k "${ROOT_DIR}/k8s/overlays/dev"

echo "[2/4] Waiting for rollout"
kubectl rollout status deployment/cba-was-renewal -n cba-dev
kubectl rollout status deployment/cba-management -n cba-dev

echo "[3/4] Current resources in cba-dev"
kubectl get all -n cba-dev

cat <<'EOF'
[4/4] Useful log commands
kubectl logs -n cba-dev deploy/cba-was-renewal
kubectl logs -n cba-dev deploy/cba-was-renewal -f
kubectl logs -n cba-dev deploy/cba-management
kubectl logs -n cba-dev deploy/cba-management -f
EOF
