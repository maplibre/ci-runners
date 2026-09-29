set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

# List shared infrastructure commands.
default:
    @just --list

# Enter the pinned development environment (includes just and OpenTofu).
dev:
    nix develop ./ctcache/nix

# Forward service commands, for example: just ctcache plan.
ctcache *args:
    @just --justfile ctcache/justfile "$@"

# Connect both existing stacks to their unchanged S3 state keys.
init:
    tofu -chdir=infrastructure/bootstrap init
    tofu -chdir=infrastructure/ctcache init

# Plan changes to the shared state bucket.
bootstrap-plan:
    tofu -chdir=infrastructure/bootstrap plan -out=bootstrap.tfplan

# Apply the previously reviewed shared-state plan.
bootstrap-apply:
    tofu -chdir=infrastructure/bootstrap apply bootstrap.tfplan

# First-time setup only: use local state before the bucket exists.
bootstrap-local-init:
    mv infrastructure/bootstrap/backend.tf infrastructure/bootstrap/backend.tf.disabled
    tofu -chdir=infrastructure/bootstrap init

# After creating the bucket: explicitly migrate local bootstrap state to S3.
bootstrap-migrate:
    mv infrastructure/bootstrap/backend.tf.disabled infrastructure/bootstrap/backend.tf
    tofu -chdir=infrastructure/bootstrap init -migrate-state

# Format only the infrastructure and ctcache Nix configuration.
fmt:
    tofu fmt -recursive infrastructure
    nixfmt ctcache/nix/*.nix

# Check configuration and synchronization scripts without changing infrastructure.
check:
    tofu fmt -check -recursive infrastructure
    tofu -chdir=infrastructure/bootstrap validate
    tofu -chdir=infrastructure/ctcache validate
    nixfmt --check ctcache/nix/*.nix
    shellcheck ctcache/scripts/*.sh
    python3 -m unittest discover -s ctcache/tests -p test_sync.py
