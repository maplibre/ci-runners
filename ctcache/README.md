# MapLibre ctcache

OpenTofu manages the AWS resources; a locked NixOS configuration installs and runs
upstream [ctcache](https://github.com/matus-chochlik/ctcache). The service exposes
HTTP port 5000 with anonymous reads and authenticated writes. Its 100 GiB encrypted
gp3 root disk has an **80 GiB cache limit**, leaving space for NixOS and logs.

## Tools and first deployment

From this repository, enter `nix develop ./ctcache/nix` (or use `path:./ctcache/nix`
before adding new files to Git). This provides OpenTofu, AWS CLI, GitHub CLI, and
validation tools. AWS credentials must target account `373521797162`; all resources
are in `us-east-1`. GitHub CLI needs Actions variable and secret write permissions
for `maplibre/maplibre-native`.

```sh
ctcache/scripts/bootstrap-state.sh
tofu -chdir=ctcache/terraform init
tofu -chdir=ctcache/terraform plan -out=deploy.tfplan
tofu -chdir=ctcache/terraform apply deploy.tfplan
```

Bootstrap creates the dedicated encrypted, versioned, private state bucket and
migrates its own state to S3. Both roots use native S3 locking. The bucket is
protected from destruction. Local state, plans, and provider installations are
ignored by Git. The write key is sensitive but **is present in OpenTofu state**;
restrict bucket access accordingly. Never copy state or plans into `ctcache/nix`:
that directory is the public Nix build source.

After EC2 starts, `amazon-init` applies the embedded NixOS configuration. Allow
several minutes for downloads and activation; an EC2 running state alone does not
mean ctcache is ready. User data contains configuration and dependency pins only.
The instance reads its write key from `/maplibre/ctcache/auth-key` in SSM Parameter
Store at runtime. SSH is disabled; manage the server through AWS Systems Manager.

```sh
host=$(tofu -chdir=ctcache/terraform output -raw ctcache_host)
curl --fail "http://$host:5000/stats"
ctcache/scripts/sync-github-config.sh --dry-run
ctcache/scripts/sync-github-config.sh
```

The synchronization script validates the address and health response before updating
GitHub. It sets `CTCACHE_AUTH_KEY` first, then repository variable `CTCACHE_HOST`.
`--repo OWNER/REPO` selects another repository; the default is
`maplibre/maplibre-native`. It can be run from any working directory, never prints
the write key, and does not rotate it. If the second GitHub update fails, rerun the
script to complete synchronization. Setting the variable does not modify workflows:
the MapLibre workflow PR must be merged for main-branch CI to use it.

## Updates, recovery, and removal

Edit the NixOS module or package, build/test it, then plan and apply OpenTofu. User
data changes replace the instance; a newer official NixOS 26.05 AMI also appears
as a replacement in the plan. The Elastic IP stays stable. Cache data is stored on
disk, but the upstream server only saves its index periodically during cache
activity; recent entries can be lost on restart or reboot. All cache data is
discarded on instance replacement or destruction. This cache is reconstructible;
there are no scheduled snapshots.
After replacements, wait for health and rerun the synchronization script.

To update dependencies, run `nix flake update --flake ./ctcache/nix` and review the
lockfile. To update ctcache, change its pinned revision and source hash, and update
the workflow's upstream client revision alongside it. The package uses unmodified
upstream source. Server fixes are proposed in
[ctcache#110](https://github.com/matus-chochlik/ctcache/pull/110) rather than
maintained locally.
Until those fixes are released and the source pin is updated, the upstream server
allows GET-based cache purges and can log write keys in request URLs.

The live deployment remains on the previously deployed, patched revision
(`cb16c03`). Removing the patch has not been applied to AWS; the current OpenTofu
plan replaces the instance with unmodified upstream code.
The service uses journald (512 MiB limit); weekly Nix GC removes generations older
than 14 days. Cache eviction remains upstream's age/LRU policy within the size limit.
HTTP is intentional for compatibility and does not encrypt network traffic.

Use SSM Run Command (`AWS-RunShellScript`) for diagnostics:
`systemctl is-active ctcache`, `journalctl -u amazon-init -u ctcache`, and `df -h /`.
Avoid printing process arguments or credential files: the server's CLI takes the
write key as an argument. To refresh a changed SSM key on the server, restart
`ctcache-credentials` and then `ctcache`, and rerun the GitHub synchronization script.

To rotate the key declaratively, plan with
`-replace=random_password.auth`, apply, then refresh credentials and GitHub as above.
To remove the service, run `tofu -chdir=ctcache/terraform destroy`; this removes the
instance, disk, EIP, role, security group, and SSM key. It does not delete the state
bucket or clear GitHub settings. The old manually managed instance was retired as a
one-time migration and is not represented in the new state.

## Validation

```sh
tofu -chdir=ctcache/terraform validate
tofu -chdir=ctcache/bootstrap validate
nix build ./ctcache/nix#ctcache -o /tmp/ctcache-package
nix build ./ctcache/nix#nixosConfigurations.ctcache.config.system.build.toplevel -o /tmp/ctcache-system
python3 ctcache/tests/test_server.py /tmp/ctcache-package
python3 -m unittest discover -s ctcache/tests -p test_sync.py
shellcheck ctcache/scripts/*.sh
```

The server test checks reads, write authentication, and dashboard assets.
Synchronization tests mock cloud commands and verify that invalid output, unhealthy servers, and failed credential
reads cause no GitHub writes. Validate the MapLibre workflow with `actionlint` and
exercise the draft branch's Linux workflow before merging.
