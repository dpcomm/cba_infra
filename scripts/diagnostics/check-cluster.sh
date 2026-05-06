#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-cluster.sh --env <dev|prod>
EOF
}

if [[ $# -lt 2 || "${1:-}" != "--env" ]]; then
  usage
  exit 1
fi

TARGET_ENV="$2"

case "${TARGET_ENV}" in
  dev)
    NAMESPACE="cba-dev"
    INGRESS_NAME="cba-dev-ingress"
    EXTRA_NAMESPACE="monitoring"
    EXTRA_CHECK_TEXT="Docker Caddy should proxy dev.recba.me, api.dev.recba.me, admin.dev.recba.me to the ingress NodePort."
    ;;
  prod)
    NAMESPACE="cba-prod"
    INGRESS_NAME="cba-prod-ingress"
    EXTRA_NAMESPACE="cert-manager"
    EXTRA_CHECK_TEXT="DNS for recba.me/api.recba.me/admin.recba.me should point to the OCI Load Balancer."
    ;;
  *)
    echo "ERROR: unsupported env: ${TARGET_ENV}"
    usage
    exit 1
    ;;
esac

echo "[1/5] Namespaces"
kubectl get ns "${NAMESPACE}" ingress-nginx "${EXTRA_NAMESPACE}"

echo "[2/5] Workload"
kubectl get deploy,svc,ingress -n "${NAMESPACE}"

echo "[3/5] Ingress controller service"
kubectl get svc -n ingress-nginx

echo "[4/5] Ingress details"
kubectl describe ingress "${INGRESS_NAME}" -n "${NAMESPACE}"

if [[ "${TARGET_ENV}" == "dev" ]]; then
  cat <<'EOF'
[5/5] Checks
- Docker Caddy should terminate 80/443 on the host.
- Docker Caddy should proxy dev.recba.me, api.dev.recba.me, admin.dev.recba.me to the ingress NodePort.
- Verify the host gateway from the Docker network with: ip addr show docker0
EOF
else
  cat <<'EOF'
[5/5] Checks
- Confirm OCI Load Balancer external IP is assigned to ingress-nginx.
- Confirm DNS for recba.me/api.recba.me/admin.recba.me points to the OCI Load Balancer.
- Confirm cert-manager has issued recba-me-tls before switching production traffic.
EOF
fi
