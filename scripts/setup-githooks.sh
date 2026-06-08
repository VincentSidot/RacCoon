#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

git -C "$repo_root" config core.hooksPath .githooks
chmod +x "$repo_root/.githooks/commit-msg" "$repo_root/.githooks/pre-commit"

echo "Configured Git hooks at $repo_root/.githooks"
