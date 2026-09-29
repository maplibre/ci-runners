# OpenTofu infrastructure

Each directory is an independent root with its own provider lockfile and S3 state
key. `bootstrap/` manages the shared state bucket; `ctcache/` manages the server.
Service-specific NixOS configuration and operator scripts live in `../ctcache/`.
Add future stacks alongside these roots with a distinct state key. Keep shared
modules out of the layout until there is actual duplication to extract.

From the repository root, use `nix develop ./ctcache/nix` for the tools. AWS
credentials must target account `373521797162`, region `us-east-1`. Run `just` to
list shared commands and `just ctcache` to list service commands. Run `just init`
at the repository root, then `just ctcache::configure`, `just ctcache::plan`,
`just ctcache::apply`, `just ctcache::upload-secret`, and `just ctcache::health`.
You can also run the service commands directly from `ctcache/`, such as `just plan`.

## Existing state bucket

The bucket already exists. Initialize each root directly:

```sh
tofu -chdir=infrastructure/bootstrap init
tofu -chdir=infrastructure/ctcache init
```

The directory move preserves the bucket and keys (`bootstrap/terraform.tfstate`
and `ctcache/terraform.tfstate`). It needs no remote state migration or import.
Discard old saved plans and generate new ones from the new paths.

## Creating the state bucket from scratch

Only for an account where this bucket does not exist: create it with local state,
then explicitly enable the S3 backend and migrate. Keep the local state until the
migration succeeds. The backend file is temporarily renamed, not rewritten.

```sh
just bootstrap-local-init
just bootstrap-plan
just bootstrap-apply
just bootstrap-migrate
```

If creation fails, finish or repair it before restoring the backend file. If
migration fails, keep the local state and retry initialization. Never commit the
intermediate backend-file removal. The bucket is private, encrypted, versioned,
and protected from destruction; the roots use native S3 locking.

## ctcache deployment

Copy `infrastructure/ctcache/terraform.tfvars.example` to `terraform.tfvars` in the
same directory, and set your SSH public key path and allowed public IPv4 CIDR.
The values file is gitignored. Update the CIDR when your administrative IP changes.

```sh
tofu -chdir=infrastructure/ctcache plan -out=deploy.tfplan
tofu -chdir=infrastructure/ctcache apply deploy.tfplan
host=$(tofu -chdir=infrastructure/ctcache output -raw ctcache_host)
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
