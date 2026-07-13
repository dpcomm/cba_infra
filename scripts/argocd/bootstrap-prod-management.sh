#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "DEPRECATED: use bootstrap-prod.sh instead."
exec "${SCRIPT_DIR}/bootstrap-prod.sh" --applications "$@"
