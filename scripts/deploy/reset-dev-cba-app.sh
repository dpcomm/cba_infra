#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  reset-dev-cba-app.sh [--execute]

Deletes the dev cba-app Helm releases and reinstalls them with the current
chart selectors. This is intended for dev-only chart cleanup, such as changing
nameOverride from the legacy helm-charts label to cba-app.

Default mode prints the commands only. Add --execute to run them.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
NAMESPACE="${NAMESPACE:-cba-connect-dev}"
EXECUTE="false"

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --execute)
      EXECUTE="true"
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

RELEASES=(
  cba-was-renewal
  cba-management
  cba-was-renewal-push-worker
  cba-was-renewal-email-worker
)

run() {
  if [[ "${EXECUTE}" == "true" ]]; then
    "$@"
  else
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
  fi
}

echo "Target namespace: ${NAMESPACE}"
echo "This will recreate dev cba-app releases with the current chart selectors."

for release in "${RELEASES[@]}"; do
  run helm uninstall "${release}" -n "${NAMESPACE}" --ignore-not-found
done

if [[ "${EXECUTE}" == "true" ]]; then
  echo "Waiting briefly for old dev resources to disappear"
  sleep 5
fi

run "${ROOT_DIR}/scripts/deploy/deploy-dev.sh"

if [[ "${EXECUTE}" != "true" ]]; then
  cat <<EOF

Dry-run only. To actually reset dev:
  ${ROOT_DIR}/scripts/deploy/reset-dev-cba-app.sh --execute

Afterwards verify selectors:
  kubectl get deploy -n ${NAMESPACE} -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.selector.matchLabels.app\\.kubernetes\\.io/name}{"\\n"}{end}'
EOF
fi
