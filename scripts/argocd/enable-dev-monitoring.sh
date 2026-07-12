#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

kubectl get crd applications.argoproj.io >/dev/null

echo "[1/3] Updating the DEV Argo CD project"
kubectl apply -f "${ROOT_DIR}/argocd/dev/project.yaml"

echo "[2/3] Enabling Kubernetes monitoring"
kubectl apply -f "${ROOT_DIR}/argocd/dev/monitoring.yaml"

echo "Waiting for the Prometheus Operator CRDs"
for _ in $(seq 1 60); do
  if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

if ! kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  echo "ERROR: ServiceMonitor CRD was not created within 300 seconds."
  exit 1
fi

kubectl apply -f "${ROOT_DIR}/argocd/dev/observability-config.yaml"

echo "[3/3] Current applications"
kubectl get applications -n "${ARGOCD_NAMESPACE}"

cat <<'EOF'

Watch installation:
  kubectl get applications -n argocd -w
  kubectl get pods,pvc -n monitoring -w

Grafana port-forward:
  kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

Argo CD port-forward:
  kubectl port-forward -n argocd svc/argocd-server 8080:443
EOF
