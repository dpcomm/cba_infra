#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
PROD_NAMESPACE="${PROD_NAMESPACE:-cba-connect-prod}"
REPO_URL="https://github.com/dpcomm/cba_infra.git"

if ! kubectl get namespace "${PROD_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: namespace ${PROD_NAMESPACE} was not found in the current cluster."
  exit 1
fi

echo "Current context: $(kubectl config current-context)"
echo "Target namespace: ${PROD_NAMESPACE}"

if ! kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${ARGOCD_NAMESPACE}"
fi

kubectl apply --server-side -n "${ARGOCD_NAMESPACE}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl rollout status deployment/argocd-server \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status deployment/argocd-repo-server \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s
kubectl rollout status statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" --timeout=300s

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
  argocd.argoproj.io/secret-type=repository --overwrite

kubectl apply -k "${ROOT_DIR}/argocd/prod"
kubectl get applications -n "${ARGOCD_NAMESPACE}"
