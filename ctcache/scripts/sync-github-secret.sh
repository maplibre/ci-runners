#!/usr/bin/env bash
# Set GitHub's ctcache write key from the same local file copied to the server.
# This does not generate a key, contact the server, or change the host variable.
# Usage: sync-github-secret.sh [--repo OWNER/REPO] [--dry-run] SECRET_FILE
set -euo pipefail

repository=maplibre/maplibre-native
dry_run=false
secret_file=

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
    -*)
      echo "Usage: $0 [--repo OWNER/REPO] [--dry-run] SECRET_FILE" >&2
      exit 2
      ;;
    *)
      if [[ -n $secret_file ]]; then
        echo 'Supply exactly one secret file.' >&2
        exit 2
      fi
      secret_file=$1
      shift
      ;;
  esac
done

if [[ ! $repository =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo 'Expected a repository in OWNER/REPO form.' >&2
  exit 2
fi
if [[ -z $secret_file || ! -r $secret_file ]]; then
  echo 'Supply a readable secret file.' >&2
  exit 2
fi

# Validate before calling gh, so a bad or empty file cannot clear the secret.
write_key=$(cat -- "$secret_file")
if [[ ! $write_key =~ ^[A-Za-z0-9]{64}$ ]]; then
  echo 'The write key must contain 64 ASCII letters or digits.' >&2
  exit 1
fi

if $dry_run; then
  printf 'Would set %s secret CTCACHE_AUTH_KEY from the supplied file\n' "$repository"
  exit 0
fi

# Standard input keeps the key out of command arguments and terminal output.
printf '%s' "$write_key" | gh secret set CTCACHE_AUTH_KEY --repo "$repository"
unset write_key
printf 'Set %s secret CTCACHE_AUTH_KEY\n' "$repository"
