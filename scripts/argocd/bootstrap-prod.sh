#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-prod.sh [--applications]

Installs or updates Argo CD and registers the private cba_infra repository.
Without --applications it only creates the Argo CD Project. Use --applications
after the runtime migration is complete to register all PROD applications.
EOF
}

APPLY_APPLICATIONS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --applications)
      APPLY_APPLICATIONS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

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

kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
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

kubectl apply -f "${ROOT_DIR}/argocd/prod/project.yaml"

if [[ "${APPLY_APPLICATIONS}" == true ]]; then
  kubectl apply -k "${ROOT_DIR}/argocd/prod"
  kubectl get applications -n "${ARGOCD_NAMESPACE}"
else
  echo "Argo CD is ready. Register applications after the runtime migration:"
  echo "  $0 --applications"
fi
