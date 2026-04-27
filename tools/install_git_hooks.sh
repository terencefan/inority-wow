#!/usr/bin/env bash
set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
hooks_path="$repo_root/.githooks"

if [ ! -d "$hooks_path" ]; then
	echo "Hooks directory not found: $hooks_path" >&2
	exit 1
fi

cd "$repo_root"
git config core.hooksPath .githooks

echo "Git hooks installed."
echo "core.hooksPath = .githooks"
