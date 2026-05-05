#!/usr/bin/env bash
set -euo pipefail

# Skeleton only: guarded by default to prevent accidental production apply.
# Usage example:
#   ./scripts/deploy-prod.sh v1.0.0
#   ALLOW_PROD_APPLY=true ./scripts/deploy-prod.sh v1.0.0

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <IMAGE_TAG> [--execute]"
  exit 1
fi

IMAGE_TAG="$1"
EXECUTE_FLAG="${2:-}"
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-false}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY_DIR="${ROOT_DIR}/k8s/overlays/prod"
IMAGE_REPO="ap-chuncheon-1.ocir.io/axdhp42jvukm/cba_was_renew"

CTX="$(kubectl config current-context)"
echo "Current kubectl context: ${CTX}"

if [[ "${CTX}" != *prod* && "${CTX}" != *oke* ]]; then
  echo "Refusing to continue: context does not look like production/OKE."
  exit 1
fi

if ! command -v kustomize >/dev/null 2>&1; then
  echo "kustomize binary is required for image tag update in this skeleton."
  exit 1
fi

pushd "${OVERLAY_DIR}" >/dev/null
kustomize edit set image "${IMAGE_REPO}=${IMAGE_REPO}:${IMAGE_TAG}"
popd >/dev/null

echo "Updated prod overlay image tag to: ${IMAGE_TAG}"
echo "Preview:"
kubectl kustomize "${OVERLAY_DIR}" | head -n 40

if [[ "${EXECUTE_FLAG}" == "--execute" || "${ALLOW_PROD_APPLY}" == "true" ]]; then
  kubectl apply -k "${OVERLAY_DIR}"
  kubectl rollout status deployment/cba-was-renew -n cba-prod
else
  cat <<'EOF'
Dry-run mode (default): no resources applied.
To actually apply:
  ALLOW_PROD_APPLY=true ./scripts/deploy-prod.sh <IMAGE_TAG>
or
  ./scripts/deploy-prod.sh <IMAGE_TAG> --execute
EOF
fi
