#!/usr/bin/env bash
set -eu

check_mode=0

while [ "$#" -gt 0 ]; do
	case "$1" in
	--check)
		check_mode=1
		;;
	*)
		echo "Unknown argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)

if ! command -v stylua >/dev/null 2>&1; then
	echo "stylua is not installed or not on PATH. Install it first, then rerun this script." >&2
	exit 1
fi

cd "$repo_root"

if [ "$check_mode" -eq 1 ]; then
	exec stylua --check --respect-ignores src tests tools Locale
fi

exec stylua --respect-ignores src tests tools Locale
