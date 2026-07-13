#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install-runtime-infra.sh --env <dev|prod>

Optional env vars:
  NAMESPACE           Override namespace
  RABBITMQ_PASSWORD   RabbitMQ password. If unset, the script prompts securely.
  REDIS_PASSWORD      Redis password for PROD. If unset, the script prompts securely.
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
CHART_DIR="${ROOT_DIR}/charts/cba-runtime"

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
REDIS_SECRET_NAME="redis-auth"
REDIS_PASSWORD_KEY="password"
REUSE_RABBITMQ_SECRET=false

if [[ "${TARGET_ENV}" == "prod" && -z "${RABBITMQ_PASSWORD:-}" ]] \
  && kubectl get secret "${RABBITMQ_SECRET_NAME}" --namespace "${NAMESPACE}" >/dev/null 2>&1; then
  REUSE_RABBITMQ_SECRET=true
  echo "Reusing existing RabbitMQ auth secret: ${RABBITMQ_SECRET_NAME}"
elif [[ -z "${RABBITMQ_PASSWORD:-}" ]]; then
  read -r -s -p "RabbitMQ password for ${TARGET_ENV}: " RABBITMQ_PASSWORD
  echo
fi

if [[ "${REUSE_RABBITMQ_SECRET}" == false && -z "${RABBITMQ_PASSWORD:-}" ]]; then
  echo "ERROR: RabbitMQ password cannot be empty."
  exit 1
fi

if [[ "${TARGET_ENV}" == "prod" && -z "${REDIS_PASSWORD:-}" ]]; then
  read -r -s -p "Redis password for ${TARGET_ENV}: " REDIS_PASSWORD
  echo
fi

if [[ "${TARGET_ENV}" == "prod" && -z "${REDIS_PASSWORD:-}" ]]; then
  echo "ERROR: Redis password cannot be empty for PROD."
  exit 1
fi

rabbitmq_password_file="$(mktemp)"
redis_password_file="$(mktemp)"
trap 'rm -f "${rabbitmq_password_file}" "${redis_password_file}"' EXIT
chmod 600 "${rabbitmq_password_file}" "${redis_password_file}"
if [[ "${REUSE_RABBITMQ_SECRET}" == false ]]; then
  printf '%s' "${RABBITMQ_PASSWORD}" > "${rabbitmq_password_file}"
fi
if [[ "${TARGET_ENV}" == "prod" ]]; then
  printf '%s' "${REDIS_PASSWORD}" > "${redis_password_file}"
fi

echo "[1/4] Ensuring namespace exists: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

if [[ "${REUSE_RABBITMQ_SECRET}" == false ]]; then
  echo "[2/4] Creating RabbitMQ auth secret: ${RABBITMQ_SECRET_NAME}"
  kubectl create secret generic "${RABBITMQ_SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-file="${RABBITMQ_PASSWORD_KEY}=${rabbitmq_password_file}" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "[2/4] Keeping existing RabbitMQ auth secret: ${RABBITMQ_SECRET_NAME}"
fi

if [[ "${TARGET_ENV}" == "prod" ]]; then
  echo "[3/4] Creating Redis auth secret: ${REDIS_SECRET_NAME}"
  kubectl create secret generic "${REDIS_SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-file="${REDIS_PASSWORD_KEY}=${redis_password_file}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "[4/4] Installing runtime infra chart"
helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 5m

echo
echo "Runtime infra endpoints for ${TARGET_ENV}:"
if [[ "${TARGET_ENV}" == "prod" ]]; then
  echo "  REDIS_URL=redis://:<redis-password>@redis:6379"
else
  echo "  REDIS_URL=redis://redis:6379"
fi
echo "  RABBITMQ_URL=amqp://cba:<password>@rabbitmq:5672"
