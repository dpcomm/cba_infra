#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  deploy-prod.sh --was-tag <tag> [--was-replicas <count>] [--management-tag <tag>] [--with-workers] [--execute]
  deploy-prod.sh <was-tag> [--execute]

Default mode renders manifests only. Add --execute or set ALLOW_PROD_APPLY=true
to apply changes to the current Kubernetes context.

Examples:
  ./scripts/deploy/deploy-prod.sh --was-tag 2026.05.26-abcdef
  ./scripts/deploy/deploy-prod.sh --was-tag 2026.05.26-abcdef --was-replicas 1 --execute
  ./scripts/deploy/deploy-prod.sh --was-tag 2026.05.26-abcdef --with-workers --execute
  ./scripts/deploy/deploy-prod.sh --was-tag 2026.05.26-abcdef --management-tag 2026.05.26-abcdef --execute
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="${NAMESPACE:-cba-connect-prod}"
CHART_DIR="${ROOT_DIR}/helm-charts"
VALUES_DIR="${CHART_DIR}/values/prod"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-false}"

WAS_IMAGE_TAG=""
WAS_REPLICAS=""
MANAGEMENT_IMAGE_TAG=""
WITH_WORKERS="false"
EXECUTE_FLAG="false"

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
    --was-replicas)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --was-replicas requires a value."
        exit 1
      fi
      WAS_REPLICAS="${2}"
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
    --with-workers)
      WITH_WORKERS="true"
      shift
      ;;
    --execute)
      EXECUTE_FLAG="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "${WAS_IMAGE_TAG}" ]]; then
        WAS_IMAGE_TAG="${1}"
        shift
      else
        echo "ERROR: unknown argument: ${1}"
        usage
        exit 1
      fi
      ;;
  esac
done

validate_prod_tag() {
  local tag="$1"
  local label="$2"

  if [[ -z "${tag}" ]]; then
    echo "ERROR: ${label} image tag is required."
    usage
    exit 1
  fi

  if [[ "${tag}" == "latest" || "${tag}" == *"latest_dev"* || "${tag}" == *"PLACEHOLDER"* ]]; then
    echo "ERROR: ${label} image tag must be fixed. Refusing tag: ${tag}"
    exit 1
  fi
}

validate_prod_tag "${WAS_IMAGE_TAG}" "WAS"
if [[ -n "${MANAGEMENT_IMAGE_TAG}" ]]; then
  validate_prod_tag "${MANAGEMENT_IMAGE_TAG}" "management"
fi
if [[ -n "${WAS_REPLICAS}" && ! "${WAS_REPLICAS}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --was-replicas must be a non-negative integer."
  exit 1
fi

CTX="$(kubectl config current-context)"
echo "Current kubectl context: ${CTX}"

if [[ "${CTX}" != *prod* && "${CTX}" != *oke* && "${CTX}" != *cdfyuekpl6a* && "${ALLOW_NON_PROD_CONTEXT:-false}" != "true" ]]; then
  echo "Refusing to continue: context does not look like production/OKE."
  echo "Set ALLOW_NON_PROD_CONTEXT=true only if you are intentionally testing."
  exit 1
fi

should_execute() {
  [[ "${EXECUTE_FLAG}" == "true" || "${ALLOW_PROD_APPLY}" == "true" ]]
}

helm_render() {
  local release="$1"
  local values_file="$2"
  local image_tag="$3"
  shift 3

  helm template "${release}" "${CHART_DIR}" \
    -n "${NAMESPACE}" \
    -f "${values_file}" \
    --set "image.tag=${image_tag}" \
    "$@"
}

helm_apply() {
  local release="$1"
  local values_file="$2"
  local image_tag="$3"
  shift 3

  helm upgrade --install "${release}" "${CHART_DIR}" \
    -n "${NAMESPACE}" \
    --create-namespace \
    --atomic \
    --timeout 10m \
    -f "${values_file}" \
    --set "image.tag=${image_tag}" \
    "$@"
}

deploy_release() {
  local release="$1"
  local deployment="$2"
  local values_file="$3"
  local image_tag="$4"
  shift 4

  if should_execute; then
    echo "Deploying ${release} to ${NAMESPACE}"
    helm_apply "${release}" "${values_file}" "${image_tag}" "$@"
    kubectl rollout status "deployment/${deployment}" -n "${NAMESPACE}"
  else
    echo "[dry-run] Rendering ${release}"
    helm_render "${release}" "${values_file}" "${image_tag}" "$@" | sed -n '1,180p'
  fi
}

WAS_HELM_ARGS=()
if [[ -n "${WAS_REPLICAS}" ]]; then
  WAS_HELM_ARGS+=(--set "replicaCount=${WAS_REPLICAS}")
fi

deploy_release "cba-was-renewal" \
  "cba-was-renewal" \
  "${VALUES_DIR}/cba-was-renewal.yaml" \
  "${WAS_IMAGE_TAG}" \
  "${WAS_HELM_ARGS[@]}"

if [[ "${WITH_WORKERS}" == "true" ]]; then
  deploy_release "cba-was-renewal-push-worker" \
    "cba-was-renewal-push-worker" \
    "${VALUES_DIR}/cba-push-worker.yaml" \
    "${WAS_IMAGE_TAG}"

  deploy_release "cba-was-renewal-email-worker" \
    "cba-was-renewal-email-worker" \
    "${VALUES_DIR}/cba-email-worker.yaml" \
    "${WAS_IMAGE_TAG}"
fi

if [[ -n "${MANAGEMENT_IMAGE_TAG}" ]]; then
  deploy_release "cba-management" \
    "cba-management" \
    "${VALUES_DIR}/cba-management.yaml" \
    "${MANAGEMENT_IMAGE_TAG}"
fi

if should_execute; then
  echo "Current prod resources in ${NAMESPACE}"
  helm list -n "${NAMESPACE}"
  kubectl get deploy,svc,ingress -n "${NAMESPACE}"
  kubectl get pods -n "${NAMESPACE}"
else
  cat <<'EOF'
Dry-run mode: no resources applied.
To actually apply:
  ./scripts/deploy/deploy-prod.sh --was-tag <tag> --execute
  ./scripts/deploy/deploy-prod.sh --was-tag <tag> --management-tag <tag> --with-workers --execute
EOF
fi
