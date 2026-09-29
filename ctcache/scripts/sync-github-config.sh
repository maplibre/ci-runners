#!/usr/bin/env bash
# Publish the deployed ctcache IP as a GitHub Actions repository variable.
# Read the address from OpenTofu and check the server before changing GitHub.
# This script never reads or updates the write key.
#
# MapLibre Native hardcodes the Elastic IP so forks can use the cache; this
# optional variable is for other workflows that choose to consume CTCACHE_HOST.
# Usage: sync-github-config.sh [--repo OWNER/REPO] [--dry-run]
set -euo pipefail

repository=maplibre/maplibre-native
dry_run=false

while (($#)); do
  case "$1" in
    --repo)
      repository=${2:?--repo requires OWNER/REPO}
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "Usage: $0 [--repo OWNER/REPO] [--dry-run]" >&2
      exit 2
      ;;
  esac
done

if [[ ! $repository =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo 'Expected a repository in OWNER/REPO form.' >&2
  exit 2
fi

# Resolve the stack relative to this script, not the caller's working directory.
repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
stack_directory="$repository_root/infrastructure/ctcache"
cache_host=$(tofu -chdir="$stack_directory" output -raw ctcache_host)

# Reject missing or invalid output before using it as a network address.
python3 - "$cache_host" <<'PY'
import ipaddress
import sys

address = ipaddress.IPv4Address(sys.argv[1])
if not address.is_global:
    raise SystemExit("ctcache_host must be a public IPv4 address")
PY

# Do not publish an endpoint that is still booting or failed to start.
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 \
  "http://$cache_host:5000/stats" | jq -e 'has("cached_count")' >/dev/null

if $dry_run; then
  printf 'Would set %s variable CTCACHE_HOST=%s\n' "$repository" "$cache_host"
  exit 0
fi

gh variable set CTCACHE_HOST --repo "$repository" --body "$cache_host"
printf 'Set %s variable CTCACHE_HOST=%s\n' "$repository" "$cache_host"
