#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMESPACE="${NAMESPACE:-cba-dev}"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env.dev}"
OCIR_ENV_FILE="${OCIR_ENV_FILE:-${ROOT_DIR}/.ocir.env}"

if [[ -f "$OCIR_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$OCIR_ENV_FILE"
fi

required_vars=(
  OCIR_SERVER
  OCIR_TENANCY_NAMESPACE
  OCIR_USERNAME
  OCIR_AUTH_TOKEN
  OCIR_EMAIL
)

for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: $v is not set."
    echo "Set env vars or create $OCIR_ENV_FILE first."
    exit 1
  fi
done

if [[ "${OCIR_USERNAME}" == "OCI_USERNAME" || "${OCIR_AUTH_TOKEN}" == "OCI_AUTH_TOKEN" ]]; then
  echo "ERROR: Placeholder values detected in OCIR credentials."
  echo "Set real OCIR_USERNAME / OCIR_AUTH_TOKEN."
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found: $ENV_FILE"
  echo "Run from cba_infra root or set ENV_FILE=/path/to/.env.dev"
  exit 1
fi

echo "[1/2] Creating OCIR image pull secret in namespace: ${NAMESPACE}"
kubectl create secret docker-registry ocir-secret \
  --namespace "${NAMESPACE}" \
  --docker-server="${OCIR_SERVER}" \
  --docker-username="${OCIR_TENANCY_NAMESPACE}/${OCIR_USERNAME}" \
  --docker-password="${OCIR_AUTH_TOKEN}" \
  --docker-email="${OCIR_EMAIL}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[2/2] Creating app env secret from: ${ENV_FILE}"
kubectl create secret generic cba-was-renew-env \
  --namespace "${NAMESPACE}" \
  --from-env-file="${ENV_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done."
