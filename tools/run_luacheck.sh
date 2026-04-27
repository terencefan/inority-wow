#!/usr/bin/env bash
set -eu

fail_on_warnings=0

while [ "$#" -gt 0 ]; do
	case "$1" in
	--fail-on-warnings)
		fail_on_warnings=1
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

if ! command -v luacheck >/dev/null 2>&1; then
	echo "luacheck is not installed or not on PATH. Install it first, then rerun this script." >&2
	exit 1
fi

cd "$repo_root"

set +e
output=$(luacheck --config "$repo_root/.luacheckrc" src tests tools 2>&1)
status=$?
set -e

if [ -n "$output" ]; then
	printf '%s\n' "$output"
fi

if [ "$status" -eq 0 ]; then
	exit 0
fi

if [ "$fail_on_warnings" -ne 1 ] && printf '%s\n' "$output" | grep -Eq 'Total:[[:space:]]+[0-9]+[[:space:]]+warnings?[[:space:]]+/[[:space:]]+0[[:space:]]+errors'; then
	exit 0
fi

exit "$status"
