# OpenTofu infrastructure

Each directory is an independent root with its own provider lockfile and S3 state
key. `bootstrap/` manages the shared state bucket; `ctcache/` and `forgejo/` manage
servers. Service-specific NixOS configuration, operator scripts and deployment
notes live in [`../ctcache/`](../ctcache/README.md) and
[`../forgejo/`](../forgejo/README.md).
Add future stacks alongside these roots with a distinct state key. Keep shared
modules out of the layout until there is actual duplication to extract.

From the repository root, use `nix develop ./ctcache/nix` for the tools. AWS
credentials must target account `373521797162`; each root sets its own region.
Run `just` to list shared commands and `just ctcache` or `just forgejo` to list
service commands. Run `just init` at the repository root before using either service.
You can also run the service commands directly from the service directory, such as
`just plan`.

## Existing state bucket

The bucket already exists in `us-east-1`. Initialize each root directly:

```sh
tofu -chdir=opentofu/bootstrap init
tofu -chdir=opentofu/ctcache init
tofu -chdir=opentofu/forgejo init
```

Each root's state key is its directory name, such as `forgejo/terraform.tfstate`.

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
