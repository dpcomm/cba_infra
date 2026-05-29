#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-runtime-infra.sh --env <dev|prod>

Optional env vars:
  NAMESPACE           Override namespace
  RABBITMQ_PASSWORD   RabbitMQ password. If unset, the script prompts securely.
EOF
}

TARGET_ENV=""

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --env)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --env requires a value."
        exit 1
      fi
      TARGET_ENV="${2}"
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
CHART_DIR="${ROOT_DIR}/infra-charts"

case "${TARGET_ENV}" in
  dev)
    DEFAULT_NAMESPACE="cba-connect-dev"
    VALUES_FILE="${CHART_DIR}/values/dev.yaml"
    ;;
  prod)
    DEFAULT_NAMESPACE="cba-connect-prod"
    VALUES_FILE="${CHART_DIR}/values/prod.yaml"
    ;;
  *)
    echo "ERROR: unsupported env: ${TARGET_ENV}"
    usage
    exit 1
    ;;
esac

NAMESPACE="${NAMESPACE:-${DEFAULT_NAMESPACE}}"
RELEASE="cba-runtime-infra"
RABBITMQ_SECRET_NAME="rabbitmq-auth"
RABBITMQ_PASSWORD_KEY="password"

if [[ -z "${RABBITMQ_PASSWORD:-}" ]]; then
  read -r -s -p "RabbitMQ password for ${TARGET_ENV}: " RABBITMQ_PASSWORD
  echo
fi

if [[ -z "${RABBITMQ_PASSWORD}" ]]; then
  echo "ERROR: RabbitMQ password cannot be empty."
  exit 1
fi

tmp_password_file="$(mktemp)"
trap 'rm -f "${tmp_password_file}"' EXIT
chmod 600 "${tmp_password_file}"
printf '%s' "${RABBITMQ_PASSWORD}" > "${tmp_password_file}"

echo "[1/3] Ensuring namespace exists: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[2/3] Creating RabbitMQ auth secret: ${RABBITMQ_SECRET_NAME}"
kubectl create secret generic "${RABBITMQ_SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-file="${RABBITMQ_PASSWORD_KEY}=${tmp_password_file}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[3/3] Installing runtime infra chart"
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 5m

echo
echo "Runtime infra endpoints for ${TARGET_ENV}:"
echo "  REDIS_URL=redis://redis:6379"
echo "  RABBITMQ_URL=amqp://cba:<password>@rabbitmq:5672"
