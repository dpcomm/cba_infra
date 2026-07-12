#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

kubectl apply -f "${ROOT_DIR}/argocd/dev/project.yaml"
kubectl apply -f "${ROOT_DIR}/argocd/dev/cba-management.yaml"
kubectl get application cba-management-dev -n argocd
