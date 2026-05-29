#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  deploy-dev.sh [--was-tag <tag>] [--management-tag <tag>] [--was-only]

When a fixed tag is provided, Helm updates the Deployment image and Kubernetes
rolls the pods naturally. Without a tag, the chart default latest_dev is used
and the script restarts the dev deployments to pull the refreshed mutable tag.

Examples:
  ./scripts/deploy/deploy-dev.sh
  ./scripts/deploy/deploy-dev.sh --was-tag dev-202605291041-69d9e5d
  ./scripts/deploy/deploy-dev.sh --was-tag dev-202605291041-69d9e5d --management-tag dev-202605291050-a1b2c3d
  ./scripts/deploy/deploy-dev.sh --was-tag dev-202605291041-69d9e5d --was-only
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="${NAMESPACE:-cba-connect-dev}"
CHART_DIR="${ROOT_DIR}/charts/cba-app"
VALUES_DIR="${CHART_DIR}/values/dev"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-180s}"

WAS_IMAGE_TAG="${WAS_IMAGE_TAG:-}"
MANAGEMENT_IMAGE_TAG="${MANAGEMENT_IMAGE_TAG:-}"
WAS_ONLY="${WAS_ONLY:-false}"

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --was-tag)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --was-tag requires a value."
        exit 1
      fi
      WAS_IMAGE_TAG="${2}"
      shift 2
      ;;
    --management-tag)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --management-tag requires a value."
        exit 1
      fi
      MANAGEMENT_IMAGE_TAG="${2}"
      shift 2
      ;;
    --was-only)
      WAS_ONLY="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: ${1}"
      usage
      exit 1
      ;;
  esac
done

release_status() {
  local release="$1"
  local deployment="$2"

  kubectl rollout status "deployment/${deployment}" -n "${NAMESPACE}" --timeout="${ROLLOUT_TIMEOUT}"
  kubectl get deploy,pod -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${release}"
}

helm_deploy() {
  local release="$1"
  local values_file="$2"
  local image_tag="${3:-}"
  local helm_args=()

  if [[ -n "${image_tag}" ]]; then
    helm_args+=(--set "image.tag=${image_tag}")
  fi

  echo "Deploying ${release}"
  helm upgrade --install "${release}" "${CHART_DIR}" \
    -n "${NAMESPACE}" \
    --create-namespace \
    -f "${values_file}" \
    "${helm_args[@]}"
}

uses_latest_dev() {
  [[ -z "${1:-}" || "${1}" == "latest_dev" ]]
}

DEPLOYED_RELEASES=()

remember_release() {
  DEPLOYED_RELEASES+=("${1}:${2}")
}

echo "[1/4] Deploying dev apps with Helm"
helm_deploy "cba-was-renewal" "${VALUES_DIR}/cba-was-renewal.yaml" "${WAS_IMAGE_TAG}"
remember_release "cba-was-renewal" "cba-was-renewal"

if [[ "${WAS_ONLY}" != "true" ]]; then
  helm_deploy "cba-management" "${VALUES_DIR}/cba-management.yaml" "${MANAGEMENT_IMAGE_TAG}"
  remember_release "cba-management" "cba-management"
fi

helm_deploy "cba-was-renewal-push-worker" "${VALUES_DIR}/cba-push-worker.yaml" "${WAS_IMAGE_TAG}"
remember_release "cba-was-renewal-push-worker" "cba-was-renewal-push-worker"

helm_deploy "cba-was-renewal-email-worker" "${VALUES_DIR}/cba-email-worker.yaml" "${WAS_IMAGE_TAG}"
remember_release "cba-was-renewal-email-worker" "cba-was-renewal-email-worker"

if uses_latest_dev "${WAS_IMAGE_TAG}" && uses_latest_dev "${MANAGEMENT_IMAGE_TAG}"; then
  echo "[2/4] Restarting dev deployments to pick up refreshed latest_dev images"
  kubectl rollout restart deployment/cba-was-renewal -n "${NAMESPACE}"
  if [[ "${WAS_ONLY}" != "true" ]]; then
    kubectl rollout restart deployment/cba-management -n "${NAMESPACE}"
  fi
  kubectl rollout restart deployment/cba-was-renewal-push-worker -n "${NAMESPACE}"
  kubectl rollout restart deployment/cba-was-renewal-email-worker -n "${NAMESPACE}"
else
  echo "[2/4] Skipping manual restart because fixed image tags trigger a rollout"
fi

echo "[3/4] Waiting for rollout"
for item in "${DEPLOYED_RELEASES[@]}"; do
  release_status "${item%%:*}" "${item##*:}"
done

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
