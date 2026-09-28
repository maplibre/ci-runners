#!/usr/bin/env bash
set -euo pipefail
repo=maplibre/maplibre-native
dry_run=false
while (($#)); do
  case "$1" in
    --repo) repo=${2:?--repo requires OWNER/REPO}; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    *) echo "Usage: $0 [--repo OWNER/REPO] [--dry-run]" >&2; exit 2 ;;
  esac
done
[[ $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid repository' >&2; exit 2; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
host=$(tofu -chdir="$root/terraform" output -raw ctcache_host)
python3 - "$host" <<'PY'
import ipaddress, sys
address = ipaddress.IPv4Address(sys.argv[1])
if not address.is_global:
    raise SystemExit('ctcache_host must be a public IPv4 address')
PY
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 "http://$host:5000/stats" | jq -e 'has("cached_count")' >/dev/null
if "$dry_run"; then
  printf 'Would set %s variable CTCACHE_HOST=%s and synchronize secret CTCACHE_AUTH_KEY\n' "$repo" "$host"
  exit 0
fi
parameter=$(tofu -chdir="$root/terraform" output -raw auth_parameter_name)
[[ $parameter == /maplibre/ctcache/auth-key ]] || { echo 'Unexpected authentication parameter' >&2; exit 1; }
# Read and validate before invoking gh: a failed AWS request must not clear the secret.
key=$(aws ssm get-parameter --region us-east-1 --name "$parameter" --with-decryption --query Parameter.Value --output text)
[[ $key =~ ^[A-Za-z0-9]{64}$ ]] || { echo 'Invalid authentication key' >&2; exit 1; }
printf '%s' "$key" | gh secret set CTCACHE_AUTH_KEY --repo "$repo"
unset key
gh variable set CTCACHE_HOST --repo "$repo" --body "$host"
printf 'Synchronized ctcache configuration for %s (%s)\n' "$repo" "$host"
