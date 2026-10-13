set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

mod ctcache 'ctcache/justfile'

# List shared infrastructure commands.
default:
    @just --list

# Enter the pinned development environment (includes just and OpenTofu).
dev:
    nix develop ./ctcache/nix

# Connect both existing stacks to their unchanged S3 state keys.
init: ctcache::init
    tofu -chdir=infrastructure/bootstrap init

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
fmt: ctcache::fmt
    tofu fmt -recursive infrastructure

# Check configuration and synchronization scripts without changing infrastructure.
check: ctcache::check
    tofu fmt -check -recursive infrastructure
    tofu -chdir=infrastructure/bootstrap validate
