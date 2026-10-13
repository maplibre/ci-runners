# Forgejo

Forgejo serves https://git.maplibre.org from an ARM `m7g.large` in `eu-central-1`,
with PostgreSQL on the same server. The OpenTofu root is
[`../opentofu/forgejo/`](../opentofu/README.md); its state stays in the `us-east-1`
bucket. Run `just init`, then `just forgejo::configure` and set your SSH public key
path, then `just forgejo::plan` and `just forgejo::apply`.

## Data

Repositories, LFS objects and the database live on a separate 100 GB volume mounted
at `/data`. It is protected from destruction and snapshotted daily at 03:00 UTC,
keeping 14 snapshots. One volume keeps the database and repositories consistent
within each snapshot. Forgejo generates its own secrets on the data volume.

## Configuration changes

The instance itself is replaceable: user-data formats the volume only when it is
blank, then bootstraps NixOS. OpenTofu ignores later user-data and AMI changes, and
the server disables `amazon-init` so a reboot does not re-run user-data. Ship
configuration changes with `just forgejo::deploy`, which copies `forgejo/nix` to
`/etc/nixos` and switches there. x86 machines cannot build the ARM system, so
`just forgejo::check` only evaluates it.

## DNS and access

`git.maplibre.org` points at the `forgejo_host` output in `dns/dnsconfig.js`,
without `CF_PROXY_ON`: the proxy rejects uploads over 100 MB and does not carry SSH.
Update that record if the Elastic IP changes. Caddy obtains the certificate once the
name resolves. Registration is disabled; create the first administrator with
`just forgejo::create-admin USERNAME EMAIL`. Port 22 is public for Git over SSH, and
sshd accepts only keys.

## Resizing

Changing `instance_type` stops and starts the same instance. To grow the data
volume, change its `size`, apply, then run `resize2fs` on the server.
`tofu destroy` stops at the protected data volume.
