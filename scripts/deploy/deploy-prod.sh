#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <IMAGE_TAG> [--execute]"
  exit 1
fi

IMAGE_TAG="$1"
EXECUTE_FLAG="${2:-}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OVERLAY_DIR="${ROOT_DIR}/k8s/overlays/prod"
IMAGE_PATCH_FILE="${OVERLAY_DIR}/patches/deployment-image.yaml"

CTX="$(kubectl config current-context)"
echo "Current kubectl context: ${CTX}"

if [[ "${CTX}" != *prod* && "${CTX}" != *oke* ]]; then
  echo "Refusing to continue: context does not look like production/OKE."
  exit 1
fi

if grep -q "latest_dev" <<<"${IMAGE_TAG}"; then
  echo "Refusing to continue: prod image tag must be fixed and must not use latest_dev."
  exit 1
fi

if grep -q "PLACEHOLDER_PROD_TAG" "${IMAGE_PATCH_FILE}"; then
  sed -i.bak "s/PLACEHOLDER_PROD_TAG/${IMAGE_TAG}/g" "${IMAGE_PATCH_FILE}"
else
  sed -E -i.bak "s#(image:[[:space:]]+.+:).*#\\1${IMAGE_TAG}#" "${IMAGE_PATCH_FILE}"
fi

rm -f "${IMAGE_PATCH_FILE}.bak"

echo "Updated prod overlay image tag to: ${IMAGE_TAG}"
echo "Preview:"
kubectl kustomize "${OVERLAY_DIR}" | sed -n '1,80p'

if [[ "${EXECUTE_FLAG}" == "--execute" || "${ALLOW_PROD_APPLY}" == "true" ]]; then
  kubectl apply -k "${OVERLAY_DIR}"
  kubectl rollout status deployment/cba-was-renewal -n cba-prod
else
  cat <<'EOF'
Dry-run mode (default): no resources applied.
To actually apply:
  ALLOW_PROD_APPLY=true ./scripts/deploy-prod.sh <IMAGE_TAG>
or
  ./scripts/deploy-prod.sh <IMAGE_TAG> --execute
EOF
fi
