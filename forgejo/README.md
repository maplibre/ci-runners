# Forgejo

Forgejo serves https://git.maplibre.org from an Intel `m7i.large` in `eu-central-1`,
with PostgreSQL on the same server. OpenTofu in
[`../opentofu/forgejo/`](../opentofu/README.md) manages the AWS resources, and its
state stays in the `us-east-1` bucket. deploy-rs deploys the NixOS configuration in
`nix/`. Run `just init`, then `just forgejo::configure` and set your SSH public key
path, then `just forgejo::plan`, `just forgejo::apply` and `just forgejo::deploy`.

## Data

Repositories, LFS objects and the database live on a separate 100 GB volume mounted
at `/data`; a blank volume is formatted on first mount. It is protected from
destruction and snapshotted daily at 03:00 UTC, keeping 14 snapshots. One volume
keeps the database and repositories consistent within each snapshot. Forgejo
generates its own secrets on the data volume. The `git` user has fixed IDs so the
volume's ownership stays valid on a new instance.

## Configuration changes

`just forgejo::deploy` evaluates `nix/` locally and builds the system on the server,
so it works from macOS as well as Linux. It rolls back automatically if the new
configuration breaks SSH. `just forgejo::check` evaluates the configuration without
building it. The instance boots the NixOS project's AMI without user-data; OpenTofu
ignores newer AMIs, which only provide the base system for the first deploy.

## DNS and access

`git.maplibre.org` points at the `forgejo_host` output in `dns/dnsconfig.js`,
without `CF_PROXY_ON`: the proxy rejects uploads over 100 MB and does not carry SSH.
Update that record if the Elastic IP changes. Caddy obtains the certificate once the
name resolves. Registration is disabled; create the first administrator with
`just forgejo::create-admin USERNAME EMAIL`. Port 22 is public for Git over SSH, and
sshd accepts only keys.

## Replacing and resizing

`just forgejo::replace` plans a new instance with the same data volume and Elastic
IP. Apply it, remove the old host key with `ssh-keygen -R`, then deploy. The new
instance has a new SSH host key, which Git users will also notice. Changing
`instance_type` within the same architecture stops and starts the same instance. To
grow the data volume, change its `size`, apply, then run `resize2fs` on the server.
`tofu destroy` stops at the protected data volume.
