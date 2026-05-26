#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="${NAMESPACE:-cba-connect-dev}"
CHART_DIR="${ROOT_DIR}/helm-charts"
VALUES_DIR="${CHART_DIR}/values/dev"

release_status() {
  local release="$1"
  local deployment="$2"

  kubectl rollout status "deployment/${deployment}" -n "${NAMESPACE}"
  kubectl get deploy,pod -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${release}"
}

helm_deploy() {
  local release="$1"
  local values_file="$2"

  echo "Deploying ${release}"
  helm upgrade --install "${release}" "${CHART_DIR}" \
    -n "${NAMESPACE}" \
    --create-namespace \
    -f "${values_file}"
}

echo "[1/4] Deploying dev apps with Helm"
helm_deploy "cba-was-renewal" "${VALUES_DIR}/cba-was-renewal.yaml"
helm_deploy "cba-management" "${VALUES_DIR}/cba-management.yaml"
helm_deploy "cba-was-renewal-push-worker" "${VALUES_DIR}/cba-push-worker.yaml"
helm_deploy "cba-was-renewal-email-worker" "${VALUES_DIR}/cba-email-worker.yaml"

echo "[2/4] Restarting dev deployments to pick up refreshed latest_dev images"
kubectl rollout restart deployment/cba-was-renewal -n "${NAMESPACE}"
kubectl rollout restart deployment/cba-management -n "${NAMESPACE}"
kubectl rollout restart deployment/cba-was-renewal-push-worker -n "${NAMESPACE}"
kubectl rollout restart deployment/cba-was-renewal-email-worker -n "${NAMESPACE}"

echo "[3/4] Waiting for rollout"
release_status "cba-was-renewal" "cba-was-renewal"
release_status "cba-management" "cba-management"
release_status "cba-was-renewal-push-worker" "cba-was-renewal-push-worker"
release_status "cba-was-renewal-email-worker" "cba-was-renewal-email-worker"

echo "[4/4] Current resources in ${NAMESPACE}"
helm list -n "${NAMESPACE}"
kubectl get deploy,svc,ingress -n "${NAMESPACE}"
kubectl get pods -n "${NAMESPACE}"

cat <<EOF
[done] Useful log commands
kubectl logs -n ${NAMESPACE} deploy/cba-was-renewal -f
kubectl logs -n ${NAMESPACE} deploy/cba-management -f
kubectl logs -n ${NAMESPACE} deploy/cba-was-renewal-push-worker -f
kubectl logs -n ${NAMESPACE} deploy/cba-was-renewal-email-worker -f
EOF
