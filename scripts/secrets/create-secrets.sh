#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-secrets.sh --env <dev|prod> [--namespace <namespace>]
Optional env vars:
  NAMESPACE      Override namespace
  ENV_FILE       Override app env file path
  OCIR_ENV_FILE  Override OCIR env file path
EOF
}

TARGET_ENV=""
NAMESPACE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --env)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --env requires a value."
        exit 1
      fi
      TARGET_ENV="${2:-}"
      shift 2
      ;;
    --namespace)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --namespace requires a value."
        exit 1
      fi
      NAMESPACE_OVERRIDE="${2:-}"
      shift 2
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

if [[ -z "${TARGET_ENV}" ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

case "${TARGET_ENV}" in
  dev)
    DEFAULT_NAMESPACE="cba-connect-dev"
    DEFAULT_ENV_FILE="${ROOT_DIR}/.env.dev"
    ;;
  prod)
    DEFAULT_NAMESPACE="cba-connect-prod"
    DEFAULT_ENV_FILE="${ROOT_DIR}/.env.prod"
    ;;
  *)
    echo "ERROR: unsupported env: ${TARGET_ENV}"
    usage
    exit 1
    ;;
esac

NAMESPACE="${NAMESPACE_OVERRIDE:-${NAMESPACE:-${DEFAULT_NAMESPACE}}}"
ENV_FILE="${ENV_FILE:-${DEFAULT_ENV_FILE}}"
OCIR_ENV_FILE="${OCIR_ENV_FILE:-${ROOT_DIR}/.ocir.env}"

if [[ -f "${OCIR_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${OCIR_ENV_FILE}"
fi

required_vars=(
  OCIR_SERVER
  OCIR_TENANCY_NAMESPACE
  OCIR_USERNAME
  OCIR_AUTH_TOKEN
  OCIR_EMAIL
)

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "ERROR: ${var_name} is not set."
    echo "Set env vars or create ${OCIR_ENV_FILE} first."
    exit 1
  fi
done

if [[ "${OCIR_USERNAME}" == "OCI_USERNAME" || "${OCIR_AUTH_TOKEN}" == "OCI_AUTH_TOKEN" ]]; then
  echo "ERROR: Placeholder values detected in OCIR credentials."
  echo "Set real OCIR_USERNAME / OCIR_AUTH_TOKEN."
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: env file not found: ${ENV_FILE}"
  echo "Set ENV_FILE=/path/to/.env.${TARGET_ENV} if the file lives elsewhere."
  exit 1
fi

echo "[0/2] Ensuring namespace exists: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[1/2] Creating OCIR image pull secret in namespace: ${NAMESPACE}"
kubectl create secret docker-registry ocir-secret \
  --namespace "${NAMESPACE}" \
  --docker-server="${OCIR_SERVER}" \
  --docker-username="${OCIR_TENANCY_NAMESPACE}/${OCIR_USERNAME}" \
  --docker-password="${OCIR_AUTH_TOKEN}" \
  --docker-email="${OCIR_EMAIL}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[2/2] Creating app env secret from: ${ENV_FILE}"
kubectl create secret generic cba-was-renewal-env \
  --namespace "${NAMESPACE}" \
  --from-env-file="${ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done."
