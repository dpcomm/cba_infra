#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
DEV_NAMESPACE="${DEV_NAMESPACE:-cba-connect-dev}"
REPO_URL="https://github.com/dpcomm/cba_infra.git"
WAS_ONLY="false"

if [[ "${1:-}" == "--was-only" ]]; then
  WAS_ONLY="true"
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--was-only]"
  exit 1
fi

if ! kubectl get namespace "${DEV_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: namespace ${DEV_NAMESPACE} was not found in the current cluster."
  echo "Current context: $(kubectl config current-context)"
  exit 1
fi

echo "Current context: $(kubectl config current-context)"
echo "Target namespace: ${DEV_NAMESPACE}"

if ! kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${ARGOCD_NAMESPACE}"
fi

echo "[1/4] Installing or updating Argo CD"
kubectl apply --server-side -n "${ARGOCD_NAMESPACE}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl rollout status deployment/argocd-server \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-repo-server \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s

echo "[2/4] Registering the private infrastructure repository"
read -r -s -p "GitHub token with read access to dpcomm/cba_infra: " GITHUB_TOKEN
echo

kubectl create secret generic cba-infra-repository \
  -n "${ARGOCD_NAMESPACE}" \
  --from-literal=type=git \
  --from-literal=url="${REPO_URL}" \
  --from-literal=username=git \
  --from-literal=password="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -
unset GITHUB_TOKEN

kubectl label secret cba-infra-repository \
  -n "${ARGOCD_NAMESPACE}" \
  argocd.argoproj.io/secret-type=repository \
  --overwrite

echo "[3/4] Applying DEV Argo CD applications"
kubectl apply -f "${ROOT_DIR}/argocd/dev/project.yaml"
kubectl apply \
  -f "${ROOT_DIR}/argocd/dev/cba-was-renewal.yaml" \
  -f "${ROOT_DIR}/argocd/dev/cba-email-worker.yaml" \
  -f "${ROOT_DIR}/argocd/dev/cba-push-worker.yaml"

if [[ "${WAS_ONLY}" != "true" ]]; then
  kubectl apply -f "${ROOT_DIR}/argocd/dev/cba-management.yaml"
fi

echo "[4/4] Current DEV GitOps status"
kubectl get applications -n "${ARGOCD_NAMESPACE}"
kubectl get deploy,pod -n "${DEV_NAMESPACE}"

cat <<'EOF'

Argo CD bootstrap completed.

Watch the first synchronization:
  kubectl get applications -n argocd -w

Open the Argo CD UI locally:
  kubectl port-forward -n argocd svc/argocd-server 8080:443
EOF
