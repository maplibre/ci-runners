# ctcache

The clang-tidy cache for MapLibre Native, on a NixOS `t3.small` in `us-east-1`. The
OpenTofu root is [`../opentofu/ctcache/`](../opentofu/README.md). Commands below run
from the repository root. With `just`, the sequence is `just init`, then
`just ctcache::configure`, `just ctcache::plan`, `just ctcache::apply`,
`just ctcache::upload-secret` and `just ctcache::health`.

## Deployment

Copy `opentofu/ctcache/terraform.tfvars.example` to `terraform.tfvars` in the
same directory, and set your SSH public key path and allowed public IPv4 CIDR.
The values file is gitignored. Update the CIDR when your administrative IP changes.

```sh
tofu -chdir=opentofu/ctcache plan -out=deploy.tfplan
tofu -chdir=opentofu/ctcache apply deploy.tfplan
host=$(tofu -chdir=opentofu/ctcache output -raw ctcache_host)
```

Keep the write key locally in `ctcache/secrets/auth-key` (gitignored, mode 600).
For a new service, generate a key with `umask 077; openssl rand -hex 32 > KEY_FILE`.
Preserve the current key when replacing an instance. Once NixOS finishes bootstrapping,
copy it into place and start the service:

```sh
scp -p ctcache/secrets/auth-key "root@$host:/etc/ctcache/auth-key"
ssh "root@$host" 'chmod 600 /etc/ctcache/auth-key; systemctl restart ctcache'
ctcache/scripts/sync-github-secret.sh ctcache/secrets/auth-key
```

The service is skipped until the secret file exists. Re-copy it after instance
replacement; it survives normal reboots. `LoadCredential` gives the unprivileged
service access to the root-owned file. No SSM secret or credential-fetching service
is involved. SSM remains available for administration. Keep a private backup of
the key; previous state versions may contain the former SSM-managed value.

MapLibre Native hardcodes the Elastic IP in `linux-ci.yml` so forks can read the
cache. Change that literal if the EIP changes. `sync-github-config.sh` optionally
updates a repository host variable for other consumers; it never modifies secrets.
The secret script only updates `CTCACHE_AUTH_KEY`. Both scripts support `--dry-run`
and `--repo OWNER/REPO`.

User-data changes replace the server and discard its reconstructible cache. The
Elastic IP is retained. `tofu destroy` in the service root removes that stack but
leaves the shared state bucket. The source is unmodified upstream ctcache; pending
server fixes are tracked in https://github.com/matus-chochlik/ctcache/pull/110.
