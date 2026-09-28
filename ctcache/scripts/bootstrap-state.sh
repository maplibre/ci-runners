#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root/bootstrap"
if aws s3api head-bucket --bucket maplibre-ci-runners-tofu-state-373521797162 2>/dev/null; then
  tofu init -backend-config=backend.hcl
  exit 0
fi
# Terraform override files replace the backend block during initial creation.
[[ ! -e backend_override.tf ]] || { echo 'Remove stale backend_override.tf after checking bootstrap state' >&2; exit 1; }
trap 'rm -f backend_override.tf' EXIT
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
tofu init
tofu apply
rm backend_override.tf
trap - EXIT
tofu init -migrate-state -force-copy -backend-config=backend.hcl
